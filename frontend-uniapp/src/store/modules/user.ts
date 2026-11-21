import { defineStore } from "pinia";
import { AppAuthAPI, AppBankAPI, AppUserAPI } from "@/api/guoguanla";
import { USER_INFO_KEY } from "@/constants";
import type {
  AppUserProfile,
  HomeSummary,
  LoginPayload,
  RealmItem,
  RegisterPayload,
} from "@/types/guoguanla";
import {
  clearGuestPassedIds,
  clearTokens,
  getAccessToken,
  getAuthSessionRevision,
  getGuestPassedIds,
  saveGuestPassedIds,
  setTokens as persistTokens,
} from "@/utils/auth";
import { Storage } from "@/utils/storage";

const DEFAULT_REALMS: RealmItem[] = [
  {
    realmCode: "lianqi",
    realmName: "练气",
    realmOrder: 1,
    gradeCode: "g7",
    difficultyLabel: "难度一 · 基础",
    description: "",
    unlockGates: 0,
    examQuestionCount: 5,
    examPassScore: 60,
    chapterCount: 0,
    gateCount: 0,
    passedGateCount: 0,
    unlocked: true,
    isCurrent: true,
    isLower: false,
    isHigher: false,
    examEligible: false,
    examRemainingGates: 0,
  },
  {
    realmCode: "zhuji",
    realmName: "筑基",
    realmOrder: 2,
    gradeCode: "g8",
    difficultyLabel: "难度二 · 入门",
    description: "",
    unlockGates: 0,
    examQuestionCount: 5,
    examPassScore: 60,
    chapterCount: 0,
    gateCount: 0,
    passedGateCount: 0,
    unlocked: false,
    isCurrent: false,
    isLower: false,
    isHigher: true,
    examEligible: false,
    examRemainingGates: 0,
  },
  {
    realmCode: "jiedan",
    realmName: "结丹",
    realmOrder: 3,
    gradeCode: "g9",
    difficultyLabel: "难度三 · 提升",
    description: "",
    unlockGates: 0,
    examQuestionCount: 6,
    examPassScore: 70,
    chapterCount: 0,
    gateCount: 0,
    passedGateCount: 0,
    unlocked: false,
    isCurrent: false,
    isLower: false,
    isHigher: true,
    examEligible: false,
    examRemainingGates: 0,
  },
  {
    realmCode: "jiaying",
    realmName: "假婴",
    realmOrder: 4,
    gradeCode: "h1",
    difficultyLabel: "难度四 · 强化",
    description: "",
    unlockGates: 0,
    examQuestionCount: 6,
    examPassScore: 70,
    chapterCount: 0,
    gateCount: 0,
    passedGateCount: 0,
    unlocked: false,
    isCurrent: false,
    isLower: false,
    isHigher: true,
    examEligible: false,
    examRemainingGates: 0,
  },
  {
    realmCode: "yuanying",
    realmName: "元婴",
    realmOrder: 5,
    gradeCode: "h2",
    difficultyLabel: "难度五 · 高阶",
    description: "",
    unlockGates: 0,
    examQuestionCount: 8,
    examPassScore: 75,
    chapterCount: 0,
    gateCount: 0,
    passedGateCount: 0,
    unlocked: false,
    isCurrent: false,
    isLower: false,
    isHigher: true,
    examEligible: false,
    examRemainingGates: 0,
  },
  {
    realmCode: "huashen",
    realmName: "化神",
    realmOrder: 6,
    gradeCode: "h3",
    difficultyLabel: "难度六 · 巅峰",
    description: "",
    unlockGates: 0,
    examQuestionCount: 8,
    examPassScore: 80,
    chapterCount: 0,
    gateCount: 0,
    passedGateCount: 0,
    unlocked: false,
    isCurrent: false,
    isLower: false,
    isHigher: true,
    examEligible: false,
    examRemainingGates: 0,
  },
];

export const useUserStore = defineStore("user", () => {
  const accessToken = ref<string>(getAccessToken() || "");
  const userInfo = ref<AppUserProfile | undefined>(Storage.get<AppUserProfile>(USER_INFO_KEY));
  const guestPassedIds = ref<number[]>(getGuestPassedIds());
  const homeSummary = ref<HomeSummary | null>(null);

  const isAuthenticated = computed(() => !!accessToken.value);

  const realms = computed<RealmItem[]>(() =>
    homeSummary.value?.realms?.length ? homeSummary.value.realms : DEFAULT_REALMS,
  );

  const currentRealm = computed<RealmItem>(() => {
    const matched = realms.value.find((r) => r.isCurrent);
    if (matched) return matched;
    if (userInfo.value?.realmCode) {
      const byCode = realms.value.find((r) => r.realmCode === userInfo.value?.realmCode);
      if (byCode) return byCode;
    }
    return realms.value[0];
  });

  const appNotice = computed<string>(() => homeSummary.value?.appNotice || "");
  const guestModeEnabled = computed<boolean>(() => homeSummary.value?.guestModeEnabled ?? true);

  const passedGateCount = computed<number>(() => {
    if (isAuthenticated.value && userInfo.value) {
      return userInfo.value.passedGateCount ?? 0;
    }
    return guestPassedIds.value.length;
  });

  function setSession(token: string, profile: AppUserProfile): void {
    persistTokens(token);
    accessToken.value = token;
    userInfo.value = profile;
    Storage.set(USER_INFO_KEY, profile);
  }

  function resetSession(): void {
    clearTokens();
    accessToken.value = "";
    userInfo.value = undefined;
    Storage.remove(USER_INFO_KEY);
  }

  function recordGuestPassedGate(gateId: number): void {
    if (isAuthenticated.value) return;
    if (!guestPassedIds.value.includes(gateId)) {
      guestPassedIds.value = saveGuestPassedIds([...guestPassedIds.value, gateId]);
    }
  }

  async function loadHomeSummary(silent = false): Promise<HomeSummary> {
    const guestIds = isAuthenticated.value ? undefined : getGuestPassedIds();
    const summary = await AppBankAPI.getHomeSummary(silent, guestIds);
    homeSummary.value = summary;
    if (summary.profile && accessToken.value) {
      userInfo.value = summary.profile;
      Storage.set(USER_INFO_KEY, summary.profile);
    }
    return summary;
  }

  async function login(payload: Omit<LoginPayload, "guestPassedGateIds">): Promise<AppUserProfile> {
    const guestIds = getGuestPassedIds();
    const res = await AppAuthAPI.login({
      ...payload,
      guestPassedGateIds: guestIds,
    });
    setSession(res.token, res.profile);
    if (guestIds.length > 0) {
      clearGuestPassedIds();
      guestPassedIds.value = [];
    }
    return res.profile;
  }

  async function register(
    payload: Omit<RegisterPayload, "guestPassedGateIds">,
  ): Promise<AppUserProfile> {
    const guestIds = getGuestPassedIds();
    const res = await AppAuthAPI.register({
      ...payload,
      guestPassedGateIds: guestIds,
    });
    setSession(res.token, res.profile);
    if (guestIds.length > 0) {
      clearGuestPassedIds();
      guestPassedIds.value = [];
    }
    return res.profile;
  }

  async function loadUserInfo(silent = false): Promise<AppUserProfile> {
    const revision = getAuthSessionRevision();
    const data = await AppUserAPI.getProfile(silent);
    if (revision === getAuthSessionRevision()) {
      userInfo.value = data;
      Storage.set(USER_INFO_KEY, data);
    }
    return data;
  }

  async function updateProfile(data: { nickname: string }): Promise<AppUserProfile> {
    const updated = await AppUserAPI.updateProfile(data);
    userInfo.value = updated;
    Storage.set(USER_INFO_KEY, updated);
    return updated;
  }

  async function logout(): Promise<void> {
    const revision = getAuthSessionRevision();
    try {
      await AppAuthAPI.logout();
    } catch {
      // Ignore logout request error
    } finally {
      if (revision === getAuthSessionRevision()) {
        resetSession();
        uni.reLaunch({ url: "/subPages/login/index" });
      }
    }
  }

  return {
    accessToken,
    userInfo,
    guestPassedIds,
    homeSummary,
    isAuthenticated,
    realms,
    currentRealm,
    appNotice,
    guestModeEnabled,
    passedGateCount,
    loadHomeSummary,
    login,
    register,
    loadUserInfo,
    updateProfile,
    recordGuestPassedGate,
    logout,
    resetSession,
  };
});
