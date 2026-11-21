import { ApiCode } from "@/enums/api-code-enum";
import { getAccessToken, getAuthSessionRevision } from "@/utils/auth";

export class RequestError extends Error {
  code?: string | number;
  statusCode?: number;

  constructor(message: string, code?: string | number, statusCode?: number) {
    super(message);
    this.name = "RequestError";
    this.code = code;
    this.statusCode = statusCode;
  }
}

export interface RequestOptions {
  url: string;
  method?: "GET" | "POST" | "PUT" | "DELETE";
  data?: Record<string, any> | any[];
  params?: Record<string, any>;
  header?: Record<string, string>;
  skipAuth?: boolean;
  silent?: boolean;
  timeout?: number;
}

let unauthorizedHandler: (() => void) | null = null;

export function setUnauthorizedHandler(handler: () => void): void {
  unauthorizedHandler = handler;
}

function getBaseUrl(): string {
  // #ifdef H5
  return import.meta.env.VITE_API_BASE || "/api";
  // #endif
  // #ifndef H5
  const origin = (import.meta.env.VITE_API_URL || "http://localhost:8080").replace(/\/$/, "");
  const prefix = import.meta.env.VITE_API_BASE || "/api";
  return `${origin}${prefix.startsWith("/") ? prefix : `/${prefix}`}`;
  // #endif
}

function appendQuery(url: string, params?: Record<string, any>): string {
  if (!params) return url;
  const pairs = Object.entries(params)
    .filter(([, val]) => val !== undefined && val !== null && val !== "")
    .map(([key, val]) => `${encodeURIComponent(key)}=${encodeURIComponent(String(val))}`);
  if (pairs.length === 0) return url;
  return `${url}${url.includes("?") ? "&" : "?"}${pairs.join("&")}`;
}

function showToastMessage(title: string, silent?: boolean): void {
  if (silent) return;
  uni.showToast({
    title: title.slice(0, 40),
    icon: "none",
    duration: 2200,
  });
}

export function request<T = any>(options: RequestOptions): Promise<T> {
  const {
    url,
    method = "GET",
    data,
    params,
    header = {},
    skipAuth = false,
    silent = false,
    timeout = 15000,
  } = options;

  const requestUrl = appendQuery(`${getBaseUrl()}${url.startsWith("/") ? url : `/${url}`}`, params);
  const token = skipAuth ? null : getAccessToken();
  const revision = getAuthSessionRevision();

  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...header,
  };
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }

  return new Promise<T>((resolve, reject) => {
    uni.request({
      url: requestUrl,
      method,
      data,
      header: headers,
      timeout,
      success: (res) => {
        const body = res.data as ApiResponse<T> | undefined;
        const statusCode = res.statusCode;

        if (statusCode === 401 || body?.code === ApiCode.UNAUTHORIZED) {
          if (revision === getAuthSessionRevision() && unauthorizedHandler) {
            unauthorizedHandler();
          }
          const msg = body?.message || "登录已过期，请重新登录";
          showToastMessage(msg, silent);
          reject(new RequestError(msg, ApiCode.UNAUTHORIZED, statusCode));
          return;
        }

        if (statusCode >= 200 && statusCode < 300 && body && body.code === ApiCode.SUCCESS) {
          resolve(body.data);
          return;
        }

        const msg = body?.message || `请求失败 (${statusCode})`;
        showToastMessage(msg, silent);
        reject(new RequestError(msg, body?.code ?? statusCode, statusCode));
      },
      fail: (err) => {
        const msg = err.errMsg?.includes("timeout") ? "请求超时，请稍后重试" : "网络连接失败，请检查后端服务";
        showToastMessage(msg, silent);
        reject(new RequestError(msg, "NETWORK_ERROR", 0));
      },
    });
  });
}

export default request;
