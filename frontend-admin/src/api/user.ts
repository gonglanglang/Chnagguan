import { http } from "@/utils/http";

export type ApiResult<T = any> = {
  code: number;
  message: string;
  data: T;
  timestamp: number;
};

export type UserResult = ApiResult<{
  id: number;
  avatar: string;
  username: string;
  nickname: string;
  roles: Array<string>;
  permissions: Array<string>;
  accessToken: string;
  refreshToken: string;
  expires: Date;
}>;

export type RefreshTokenResult = ApiResult<{
  accessToken: string;
  refreshToken: string;
  expires: Date;
}>;

/** 管理员登录 */
export const getLogin = (data?: object) => {
  return http.request<UserResult>("post", "/auth/login", { data });
};

/** 刷新 token */
export const refreshTokenApi = (data?: object) => {
  return http.request<RefreshTokenResult>("post", "/auth/refresh-token", { data });
};

/** 退出登录 */
export const logoutApi = () => {
  return http.request<ApiResult<void>>("post", "/auth/logout");
};
