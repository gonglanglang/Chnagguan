import request, { uploadFileRequest } from "@/utils/request";
import type {
  AppUserProfile,
  AppVersionInfo,
  AuthResult,
  ChapterCard,
  CheckItemResult,
  EssayAnswerRecord,
  GateCard,
  HomeSummary,
  LoginPayload,
  QuizStartResult,
  RealmItem,
  RegisterPayload,
  SubmitResult,
  UploadAnswerImageResult,
  WrongQuestionItem,
} from "@/types/guoguanla";

function formatGuestCsv(ids?: number[]): string | undefined {
  if (!ids || ids.length === 0) return undefined;
  return ids.join(",");
}

export const AppAuthAPI = {
  login(data: LoginPayload) {
    return request<AuthResult>({
      url: "/app/auth/login",
      method: "POST",
      data,
      skipAuth: true,
    });
  },
  register(data: RegisterPayload) {
    return request<AuthResult>({
      url: "/app/auth/register",
      method: "POST",
      data,
      skipAuth: true,
    });
  },
  logout() {
    return request<void>({
      url: "/app/auth/logout",
      method: "POST",
      silent: true,
    });
  },
};

export const AppBankAPI = {
  getHomeSummary(silent = false, guestPassedIds?: number[]) {
    return request<HomeSummary>({
      url: "/app/home/summary",
      method: "GET",
      params: { guestPassedIds: formatGuestCsv(guestPassedIds) },
      silent,
    });
  },
  getRealms(guestPassedIds?: number[]) {
    return request<RealmItem[]>({
      url: "/app/realms",
      method: "GET",
      params: { guestPassedIds: formatGuestCsv(guestPassedIds) },
    });
  },
  getChaptersByRealm(realmCode: string, guestPassedIds?: number[]) {
    return request<ChapterCard[]>({
      url: `/app/realms/${realmCode}/chapters`,
      method: "GET",
      params: { guestPassedIds: formatGuestCsv(guestPassedIds) },
    });
  },
  getGatesByChapter(chapterId: number, guestPassedIds?: number[]) {
    return request<GateCard[]>({
      url: `/app/chapters/${chapterId}/gates`,
      method: "GET",
      params: { guestPassedIds: formatGuestCsv(guestPassedIds) },
    });
  },
};

export const AppUserAPI = {
  getProfile(silent = false) {
    return request<AppUserProfile>({
      url: "/app/user/profile",
      method: "GET",
      silent,
    });
  },
  updateProfile(data: { nickname: string }) {
    return request<AppUserProfile>({
      url: "/app/user/profile",
      method: "PUT",
      data,
    });
  },
  getChapterRecords() {
    return request<ChapterCard[]>({
      url: "/app/user/chapter-records",
      method: "GET",
    });
  },
  getEssayAnswers(params?: { pageNum?: number; pageSize?: number }) {
    return request<PageResult<EssayAnswerRecord>>({
      url: "/app/user/essay-answers",
      method: "GET",
      params,
    });
  },
};

export interface AnswerSubmitPayload {
  itemIndex: number;
  selectedIndex?: number;
  answerText?: string;
  answerImageKey?: string;
  selfCorrect?: boolean;
}

export const AppQuizAPI = {
  start(data: { gateId: number; guestPassedGateIds?: number[] }) {
    return request<QuizStartResult>({
      url: "/app/quiz/start",
      method: "POST",
      data,
    });
  },
  uploadAnswerImage(filePath: string, sessionNo: string, itemIndex: number) {
    return uploadFileRequest<UploadAnswerImageResult>({
      url: "/app/quiz/upload-answer-image",
      filePath,
      formData: {
        sessionNo,
        itemIndex: String(itemIndex),
      },
    });
  },
  checkItem(data: {
    sessionNo: string;
    itemIndex: number;
    selectedIndex?: number;
    answerText?: string;
    answerImageKey?: string;
    selfCorrect?: boolean;
  }) {
    return request<CheckItemResult>({
      url: "/app/quiz/check-item",
      method: "POST",
      data,
    });
  },
  gradeEssay(data: {
    sessionNo: string;
    itemIndex: number;
    correct: boolean;
    answerText?: string;
    answerImageKey?: string;
  }) {
    return request<CheckItemResult>({
      url: "/app/quiz/essay-grade",
      method: "POST",
      data,
    });
  },
  submit(data: { sessionNo: string; answers: AnswerSubmitPayload[] }) {
    return request<SubmitResult>({
      url: "/app/quiz/submit",
      method: "POST",
      data,
    });
  },
};

export const AppRealmExamAPI = {
  start() {
    return request<QuizStartResult>({
      url: "/app/realm/exam/start",
      method: "POST",
    });
  },
  submit(data: { sessionNo: string; answers: AnswerSubmitPayload[] }) {
    return request<SubmitResult>({
      url: "/app/realm/exam/submit",
      method: "POST",
      data,
    });
  },
};

export const AppWrongAPI = {
  getPage(params: { realmCode?: string; chapterId?: number; pageNum?: number; pageSize?: number }) {
    return request<PageResult<WrongQuestionItem>>({
      url: "/app/wrong-questions",
      method: "GET",
      params,
    });
  },
  startRedo(data?: { realmCode?: string; chapterId?: number; limit?: number }) {
    return request<QuizStartResult>({
      url: "/app/wrong-questions/redo/start",
      method: "POST",
      data: data ?? {},
    });
  },
  submitRedo(data: { sessionNo: string; answers: AnswerSubmitPayload[] }) {
    return request<SubmitResult>({
      url: "/app/wrong-questions/redo/submit",
      method: "POST",
      data,
    });
  },
  markMastered(id: number) {
    return request<void>({
      url: `/app/wrong-questions/${id}/master`,
      method: "PUT",
    });
  },
  clearAll() {
    return request<void>({
      url: "/app/wrong-questions/clear",
      method: "DELETE",
    });
  },
};

export const AppVersionAPI = {
  checkLatest(params: { currentVersion: string; versionCode: number }) {
    return request<AppVersionInfo>({
      url: "/app/version/latest",
      method: "GET",
      params,
      skipAuth: true,
      silent: true,
      timeout: 8000,
    });
  },
};
