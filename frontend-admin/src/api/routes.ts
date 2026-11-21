import { http } from "@/utils/http";
import type { ApiResult } from "@/api/user";

export const getAsyncRoutes = () => {
  return http.request<ApiResult<Array<any>>>("get", "/auth/routes");
};
