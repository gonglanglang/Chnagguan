import '../cache/global_cache.dart';

export '../cache/global_cache.dart';

/// 兼容旧引用的类型别名；所有新代码必须直接使用 [GlobalCache]（见 docs/02-开发规范.md 4.4 节）
typedef AppStorage = GlobalCache;
