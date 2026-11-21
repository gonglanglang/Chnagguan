/**
 * 后端统一响应业务码（Java Result<T> 返回数字 200）
 */
export const ApiCode = {
  /** 成功 */
  SUCCESS: 200,
  /** 未登录或登录态失效 */
  UNAUTHORIZED: 401,
} as const;
