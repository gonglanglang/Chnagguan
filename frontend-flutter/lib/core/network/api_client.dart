import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../app/app_config.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.code, this.statusCode});

  final String message;
  final Object? code;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401 || code == 401;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.tokenGetter,
    required this.revisionGetter,
    this.onUnauthorized,
  }) : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 25),
            headers: const {'Content-Type': 'application/json'},
            validateStatus: (status) => status != null && status < 600,
          ),
        );

  final Dio _dio;
  final String Function() tokenGetter;
  final int Function() revisionGetter;
  void Function()? onUnauthorized;

  String get baseUrl => _dio.options.baseUrl;

  String get baseOrigin {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return '';
    return uri.hasPort
        ? '${uri.scheme}://${uri.host}:${uri.port}'
        : '${uri.scheme}://${uri.host}';
  }

  String get clientPlatform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.windows => 'windows',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  void updateBaseUrl(String newBaseUrl) {
    var trimmed = newBaseUrl.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    _dio.options.baseUrl = trimmed.isEmpty ? AppConfig.defaultApiBaseUrl : trimmed;
  }

  Dio get rawDio => _dio;

  Future<T> request<T>({
    required String path,
    String method = 'GET',
    Object? data,
    Map<String, dynamic>? queryParameters,
    bool skipAuth = false,
    Duration? timeout,
    required T Function(dynamic raw) parser,
  }) async {
    final revision = revisionGetter();
    final headers = <String, dynamic>{
      'X-Client-Platform': clientPlatform,
    };
    if (!skipAuth) {
      final token = tokenGetter();
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final filteredQuery = queryParameters == null
        ? null
        : Map<String, dynamic>.fromEntries(
            queryParameters.entries.where(
              (e) =>
                  e.value != null &&
                  (e.value is! String || (e.value as String).isNotEmpty),
            ),
          );

    try {
      final response = await _dio.request<dynamic>(
        path.startsWith('/') ? path : '/$path',
        data: data,
        queryParameters: filteredQuery,
        options: Options(
          method: method,
          headers: headers,
          receiveTimeout: timeout,
          sendTimeout: timeout,
        ),
      );
      return _unwrap<T>(response, revision: revision, parser: parser);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioError(e);
    } catch (e) {
      throw ApiException('网络请求失败：$e');
    }
  }

  Future<T> uploadBytes<T>({
    required String path,
    required Uint8List bytes,
    required String filename,
    String fieldName = 'file',
    Map<String, dynamic>? extraFields,
    Duration? timeout,
    required T Function(dynamic raw) parser,
  }) async {
    final revision = revisionGetter();
    final headers = <String, dynamic>{};
    final token = tokenGetter();
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final formMap = <String, dynamic>{
      ...?extraFields,
      fieldName: MultipartFile.fromBytes(bytes, filename: filename),
    };

    try {
      final response = await _dio.post<dynamic>(
        path.startsWith('/') ? path : '/$path',
        data: FormData.fromMap(formMap),
        options: Options(
          headers: headers,
          contentType: 'multipart/form-data',
          sendTimeout: timeout ?? const Duration(seconds: 35),
          receiveTimeout: timeout ?? const Duration(seconds: 35),
        ),
      );
      return _unwrap<T>(response, revision: revision, parser: parser);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioError(e);
    } catch (e) {
      throw ApiException('文件上传失败：$e');
    }
  }

  Future<({Uint8List bytes, String? fileName})> downloadBytes({
    required String path,
    String method = 'POST',
    Object? data,
    Duration? timeout,
  }) async {
    final revision = revisionGetter();
    final headers = <String, dynamic>{
      'X-Client-Platform': clientPlatform,
    };
    final token = tokenGetter();
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    try {
      final response = await _dio.request<List<int>>(
        path.startsWith('/') ? path : '/$path',
        data: data,
        options: Options(
          method: method,
          headers: headers,
          responseType: ResponseType.bytes,
          receiveTimeout: timeout ?? const Duration(seconds: 60),
          sendTimeout: timeout ?? const Duration(seconds: 30),
        ),
      );
      final statusCode = response.statusCode ?? 0;
      final rawBytes = Uint8List.fromList(response.data ?? const <int>[]);
      if (statusCode == 401) {
        if (revision == revisionGetter()) {
          onUnauthorized?.call();
        }
        throw const ApiException('登录已过期，请重新登录', code: 401, statusCode: 401);
      }
      final contentType =
          response.headers.value('content-type')?.toLowerCase() ?? '';
      if (statusCode < 200 ||
          statusCode >= 300 ||
          contentType.contains('application/json')) {
        String msg = '导出失败 ($statusCode)';
        try {
          final decoded = jsonDecode(utf8.decode(rawBytes));
          if (decoded is Map<String, dynamic>) {
            final bizCode = decoded['code'];
            if (bizCode == 401 && revision == revisionGetter()) {
              onUnauthorized?.call();
            }
            final m = decoded['message']?.toString();
            if (m != null && m.isNotEmpty) msg = m;
          }
        } catch (_) {
          // ignore non-json error body
        }
        throw ApiException(msg, statusCode: statusCode);
      }
      final disposition = response.headers.value('content-disposition') ?? '';
      String? fileName;
      final utf8Match =
          RegExp(r"filename\*=UTF-8''([^;]+)", caseSensitive: false)
              .firstMatch(disposition);
      if (utf8Match != null) {
        fileName = Uri.decodeComponent(utf8Match.group(1)!.trim());
      } else {
        final plainMatch =
            RegExp(r'filename="?([^";]+)"?', caseSensitive: false)
                .firstMatch(disposition);
        if (plainMatch != null) {
          fileName = plainMatch.group(1)!.trim();
        }
      }
      return (bytes: rawBytes, fileName: fileName);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioError(e);
    } catch (e) {
      throw ApiException('导出文件失败：$e');
    }
  }

  Future<({bool reachable, int? costMs, int? statusCode})> probeHomeSummary() async {
    final stopwatch = Stopwatch()..start();
    try {
      final res = await _dio.get<dynamic>(
        '/app/home/summary',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      stopwatch.stop();
      return (
        reachable: true,
        costMs: stopwatch.elapsedMilliseconds,
        statusCode: res.statusCode,
      );
    } catch (_) {
      stopwatch.stop();
      return (reachable: false, costMs: null, statusCode: null);
    }
  }

  T _unwrap<T>(
    Response<dynamic> response, {
    required int revision,
    required T Function(dynamic raw) parser,
  }) {
    final statusCode = response.statusCode ?? 0;
    final body = response.data;
    final map = body is Map<String, dynamic> ? body : null;
    final bizCode = map?['code'];

    if (statusCode == 401 || bizCode == 401) {
      if (revision == revisionGetter()) {
        onUnauthorized?.call();
      }
      final msg = map?['message']?.toString();
      throw ApiException(
        (msg != null && msg.isNotEmpty) ? msg : '登录已过期，请重新登录',
        code: 401,
        statusCode: statusCode,
      );
    }

    if (statusCode >= 200 && statusCode < 300 && map != null && bizCode == 200) {
      return parser(map['data']);
    }

    final msg = map?['message']?.toString();
    throw ApiException(
      (msg != null && msg.isNotEmpty) ? msg : '请求失败 ($statusCode)',
      code: bizCode ?? statusCode,
      statusCode: statusCode,
    );
  }

  ApiException _mapDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const ApiException('请求超时，请稍后重试', code: 'TIMEOUT', statusCode: 0);
    }
    return const ApiException(
      '网络连接失败，请检查后端服务是否已启动',
      code: 'NETWORK_ERROR',
      statusCode: 0,
    );
  }
}

String friendlyErrorMessage(Object error, [String fallback = '操作失败，请稍后重试']) {
  if (error is ApiException) {
    return error.message.isNotEmpty ? error.message : fallback;
  }
  final str = error.toString().replaceFirst('Exception: ', '').trim();
  return str.isNotEmpty ? str : fallback;
}
