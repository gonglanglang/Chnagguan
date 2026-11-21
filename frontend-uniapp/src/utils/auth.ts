import { Storage } from "./storage";
import { ACCESS_TOKEN_KEY, GUEST_PASSED_GATES_KEY, REFRESH_TOKEN_KEY } from "@/constants";

let sessionRevision = 0;

export function getAuthSessionRevision(): number {
  return sessionRevision;
}

export function getAccessToken(): string | null {
  return Storage.get<string>(ACCESS_TOKEN_KEY) || null;
}

export function setTokens(accessToken: string, refreshToken = "", renewing = false): void {
  Storage.set(ACCESS_TOKEN_KEY, accessToken);
  if (refreshToken) {
    Storage.set(REFRESH_TOKEN_KEY, refreshToken);
  }
  if (!renewing) sessionRevision += 1;
}

export function clearTokens(): void {
  Storage.remove(ACCESS_TOKEN_KEY);
  Storage.remove(REFRESH_TOKEN_KEY);
  sessionRevision += 1;
}

export function normalizeGuestIds(ids: unknown): number[] {
  if (!Array.isArray(ids)) return [];
  const valid = ids
    .map((id) => Number(id))
    .filter((id) => Number.isInteger(id) && id > 0);
  return Array.from(new Set(valid));
}

export function getGuestPassedIds(): number[] {
  return normalizeGuestIds(Storage.get<unknown>(GUEST_PASSED_GATES_KEY, []));
}

export function saveGuestPassedIds(ids: number[]): number[] {
  const clean = normalizeGuestIds(ids);
  Storage.set(GUEST_PASSED_GATES_KEY, clean);
  return clean;
}

export function clearGuestPassedIds(): void {
  Storage.remove(GUEST_PASSED_GATES_KEY);
}

function getCurrentPagePath(): string {
  const pages = getCurrentPages();
  if (pages.length === 0) return "/pages/index/index";

  const currentPage = pages[pages.length - 1];
  const route = currentPage.route || "";
  const options = (currentPage as { options?: Record<string, string> }).options || {};

  const query = Object.entries(options)
    .map(([key, value]) => `${key}=${value}`)
    .join("&");

  return query ? `/${route}?${query}` : `/${route}`;
}

export function ensureAuthenticated(): boolean {
  if (getAccessToken()) return true;

  const redirect = encodeURIComponent(getCurrentPagePath());
  uni.navigateTo({
    url: `/subPages/login/index?redirect=${redirect}`,
    fail: () => {
      uni.reLaunch({ url: `/subPages/login/index?redirect=${redirect}` });
    },
  });

  return false;
}
