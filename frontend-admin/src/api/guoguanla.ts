import { http } from "@/utils/http";
import type { ApiResult } from "@/api/user";

export interface PageData<T> {
  records: T[];
  total: number;
  pageNum: number;
  pageSize: number;
}

export interface RealmConfig {
  id: number;
  realmCode: string;
  realmName: string;
  realmOrder: number;
  gradeCode: string;
  difficultyLabel: string;
  description: string;
  unlockGates: number;
  examQuestionCount: number;
  examPassScore: number;
  enabled: number;
  chapterCount: number;
  gateCount: number;
  questionCount: number;
  studentCount: number;
}

export interface DashboardOverview {
  userCount: number;
  activeUserCount: number;
  chapterCount: number;
  gateCount: number;
  questionCount: number;
  staticQuestionCount: number;
  dynamicQuestionCount: number;
  totalQuizCount: number;
  totalWrongCount: number;
  realmStats: Array<{
    realmCode: string;
    realmName: string;
    difficultyLabel: string;
    gradeCode: string;
    chapterCount: number;
    questionCount: number;
    studentCount: number;
  }>;
  topWrongChapters: Array<{
    chapterName: string;
    gradeCode: string;
    wrongCount: number;
  }>;
}

export interface StudentUser {
  id: number;
  username: string;
  nickname: string;
  phoneMasked: string;
  avatarUrl: string;
  gradeCode: string;
  gradeName: string;
  realmCode: string;
  realmName: string;
  realmOrder: number;
  passedGateCount: number;
  wrongCount: number;
  pendingEssayCount?: number;
  status: number;
  remark: string;
  lastActiveAt: string;
  createdAt: string;
}

export interface QuizSessionItem {
  itemIndex: number;
  questionFormat: string;
  stem: string;
  options: string[];
  answerIndex: number;
  userIndex: number | null;
  referenceAnswer: string;
  userAnswerText: string;
  userAnswerImageUrl: string;
  userSelfCorrect: boolean | null;
  correct: boolean;
  analysis: string;
}

export interface EssayAnswerItem {
  id: number;
  sessionNo: string;
  itemIndex: number;
  userId: number;
  studentNickname?: string;
  studentUsername?: string;
  studentRealmName?: string;
  realmCode?: string;
  realmName?: string;
  chapterId?: number;
  chapterName: string;
  gateId?: number;
  gateName: string;
  stem: string;
  referenceAnswer: string;
  analysis?: string;
  answerText: string;
  answerImageUrl: string;
  selfCorrect: number | null;
  teacherStatus: number;
  teacherComment: string;
  teacherImageUrl?: string;
  createdAt: string;
  reviewedAt: string | null;
}

export interface VideoSeriesItem {
  id: number;
  title: string;
  coverImageKey: string;
  coverImageUrl: string;
  intro: string;
  realmCode: string;
  realmName: string;
  sortOrder: number;
  enabled: number;
  lessonCount: number;
  createdAt: string;
  updatedAt: string;
}

export interface NoteAttachmentItem {
  name: string;
  objectKey: string;
  url: string;
  size: number;
  contentType: string;
}

export interface VideoLessonItem {
  id: number;
  seriesId: number;
  title: string;
  coverImageKey?: string;
  coverImageUrl?: string;
  videoKey: string;
  videoUrl: string;
  durationSec: number;
  classNotes: string;
  notesAttachments?: NoteAttachmentItem[];
  sortOrder: number;
  enabled: number;
  createdAt: string;
  updatedAt: string;
}

export interface VideoSeriesDetail {
  series: VideoSeriesItem;
  lessons: VideoLessonItem[];
}

export interface StudentDetail {
  profile: StudentUser;
  chapterProgress: Array<{
    chapterId: number;
    gradeCode: string;
    chapterName: string;
    passedCount: number;
    totalGates: number;
    lastPlayedAt: string;
  }>;
  wrongQuestions: Array<{
    id: number;
    gradeCode: string;
    chapterName: string;
    gateName: string;
    questionFormat?: string;
    stem: string;
    options: string[];
    answerIndex: number;
    referenceAnswer?: string;
    lastAnswerImageUrl?: string;
    wrongCount: number;
    isMastered: number;
    lastWrongAt: string;
  }>;
  recentRecords: Array<{
    id: number;
    sessionNo: string;
    mode: string;
    realmCode?: string;
    score?: number;
    chapterName: string;
    gateName: string;
    totalCount: number;
    correctCount: number;
    isPassed: number;
    startedAt: string;
    submittedAt: string;
  }>;
}

export interface GradeItem {
  id: number;
  gradeCode: string;
  gradeName: string;
  icon: string;
  sortOrder: number;
  enabled: number;
}

export interface ChapterItem {
  id: number;
  chapterCode: string;
  gradeCode: string;
  gradeName: string;
  realmCode: string;
  realmName: string;
  name: string;
  description: string;
  isCustom: number;
  sortOrder: number;
  enabled: number;
  gateCount: number;
  questionCount: number;
  updatedAt: string;
}

export interface GateItem {
  id: number;
  chapterId: number;
  gateIndex: number;
  gateName: string;
  star: number;
  questionCount: number;
  passCount: number;
  enabled: number;
  actualQuestionCount: number;
}

export interface QuestionItem {
  id: number;
  gradeCode: string;
  gradeName: string;
  realmCode: string;
  realmName: string;
  chapterId: number;
  chapterName: string;
  gateId: number;
  gateName: string;
  questionMode: "STATIC" | "DYNAMIC_TEMPLATE";
  questionFormat: "SINGLE_CHOICE" | "MULTI_CHOICE" | "FILL_BLANK" | "JUDGE" | "ESSAY";
  stem: string;
  options: string[];
  answer: Record<string, any>;
  analysis: string;
  generatorCode: string | null;
  templateRule: Record<string, any> | null;
  difficulty: number;
  tags: string[];
  ext: Record<string, any> | null;
  source: string;
  version: number;
  sortOrder: number;
  enabled: number;
  updatedAt: string;
}

export interface GeneratedSample {
  stem: string;
  options: string[];
  answerIndex: number;
  analysis: string;
  questionFormat?: string;
  referenceAnswer?: string;
  diagram?: Record<string, any> | null;
  imageUrl?: string | null;
}

export interface AppDefaultThemeConfig {
  uiSkin: "welkui" | "skribble" | "forui";
  themeHex: string;
  themeName: string;
  darkMode: boolean;
  version: string;
}

export interface SysConfigItem {
  id: number;
  configKey: string;
  configValue: string;
  description: string;
  updatedAt: string;
}

export interface AppVersionInfo {
  currentVersion: string;
  latestVersion: string;
  latestVersionCode: number;
  hasUpdate: boolean;
  forceUpdate: boolean;
  releaseNotes: string;
  downloadUrl: string;
  githubReleaseUrl: string;
  githubRepo: string;
  githubReachable: boolean;
  publishedAt: string;
  source: string;
}

export interface AiConfigInfo {
  enabled: boolean;
  baseUrl: string;
  resolvedEndpoint: string;
  apiKeyMasked: string;
  hasApiKey: boolean;
  model: string;
  visionModel: string;
  temperature: number;
  maxTokens: number;
  timeoutSec: number;
  systemPrompt: string;
}

export interface AiTestResult {
  ok: boolean;
  latencyMs?: number;
  endpoint?: string;
  model?: string;
  reply?: string;
  errorMessage?: string;
}

// 1. 数据概览
export const getDashboardOverview = () =>
  http.get<ApiResult<DashboardOverview>, any>("/dashboard/overview");

// 2. 修仙境界与基础配置
export const getRealms = () =>
  http.get<ApiResult<RealmConfig[]>, any>("/realms");

export const updateRealm = (id: number, data: Record<string, any>) =>
  http.request<ApiResult<void>>("put", `/realms/${id}`, { data });

export const getConfigs = () =>
  http.get<ApiResult<SysConfigItem[]>, any>("/configs");

export const updateConfig = (configKey: string, configValue: string) =>
  http.request<ApiResult<void>>("put", "/configs", {
    data: { configKey, configValue }
  });

export const getAdminDefaultTheme = () =>
  http.get<ApiResult<AppDefaultThemeConfig>, any>("/theme/default");

export const updateAdminDefaultTheme = (data: {
  uiSkin: "welkui" | "skribble" | "forui";
  themeHex: string;
  themeName: string;
  darkMode: boolean;
}) => http.request<ApiResult<AppDefaultThemeConfig>>("put", "/theme/default", { data });

export const getAiConfig = () =>
  http.get<ApiResult<AiConfigInfo>, any>("/ai/config");

export const updateAiConfig = (data: {
  enabled: boolean;
  baseUrl: string;
  apiKey?: string;
  clearApiKey?: boolean;
  model: string;
  visionModel?: string;
  temperature?: number;
  maxTokens?: number;
  timeoutSec?: number;
  systemPrompt?: string;
}) => http.request<ApiResult<AiConfigInfo>>("put", "/ai/config", { data });

export const testAiConfig = (data?: {
  baseUrl?: string;
  apiKey?: string;
  model?: string;
  timeoutSec?: number;
}) => http.post<ApiResult<AiTestResult>, any>("/ai/test", { data, timeout: 90000 });

export const getAdminAppVersion = (refresh = false) =>
  http.get<ApiResult<AppVersionInfo>, any>("/app/version/latest", {
    params: { refresh }
  });

export interface ApkDirectUploadInitResult {
  objectKey: string;
  uploadUrl: string;
  contentType: string;
  storageType: string;
  directUpload: boolean;
}

export const initAppApkUpload = (data: { fileName: string; version?: string }) =>
  http.post<ApiResult<ApkDirectUploadInitResult>, any>("/app/upload-apk/init", {
    data
  });

export const publishAppApk = (data: {
  objectKey: string;
  version?: string;
  versionCode?: number;
  releaseNotes?: string;
  forceUpdate?: boolean;
}) =>
  http.post<ApiResult<AppVersionInfo>, any>("/app/upload-apk/publish", {
    data
  });

export const uploadAppApk = (formData: FormData) =>
  http.post<ApiResult<AppVersionInfo>, any>("/app/upload-apk", {
    data: formData,
    headers: { "Content-Type": "multipart/form-data" },
    timeout: 300000
  });

// 3. 学生管理
export const getUserPage = (params: Record<string, any>) =>
  http.get<ApiResult<PageData<StudentUser>>, any>("/users", { params });

export const getUserDetail = (id: number) =>
  http.get<ApiResult<StudentDetail>, any>(`/users/${id}`);

export const createUser = (data: Record<string, any>) =>
  http.post<ApiResult<number>, any>("/users", { data });

export const updateUser = (id: number, data: Record<string, any>) =>
  http.request<ApiResult<void>>("put", `/users/${id}`, { data });

export const updateUserPassword = (id: number, password: string) =>
  http.request<ApiResult<void>>("put", `/users/${id}/password`, {
    data: { password }
  });

export const getUserQuizRecordDetail = (id: number, sessionNo: string) =>
  http.get<ApiResult<QuizSessionItem[]>, any>(`/users/${id}/quiz-records/${sessionNo}`);

export const getUserEssayAnswers = (id: number, params?: { pageNum?: number; pageSize?: number }) =>
  http.get<ApiResult<PageData<EssayAnswerItem>>, any>(`/users/${id}/essay-answers`, { params });

export const getEssayAnswerDetail = (essayId: number) =>
  http.get<ApiResult<EssayAnswerItem>, any>(`/users/essay-answers/${essayId}`);

export const getEssayAnswerImageBlob = (essayId: number) =>
  http.request<Blob>("get", `/users/essay-answers/${essayId}/image`, {
    responseType: "blob"
  });

export const uploadEssayReviewImage = (essayId: number, formData: FormData) =>
  http.post<ApiResult<{ objectKey: string; previewUrl: string; storageType: string }>, any>(
    `/users/essay-answers/${essayId}/review-image`,
    {
      data: formData,
      headers: { "Content-Type": "multipart/form-data" }
    }
  );

export const reviewEssayAnswer = (
  essayId: number,
  data: { teacherStatus: number; teacherComment: string; teacherImageKey?: string }
) =>
  http.request<ApiResult<void>>("put", `/users/essay-answers/${essayId}/review`, {
    data
  });

export const updateUserRealm = (id: number, realmCode: string) =>
  http.request<ApiResult<void>>("put", `/users/${id}/realm`, {
    data: { realmCode }
  });

export const updateUserStatus = (id: number, status: number) =>
  http.request<ApiResult<void>>("put", `/users/${id}/status`, {
    data: { status }
  });

export const deleteUser = (id: number) =>
  http.request<ApiResult<void>>("delete", `/users/${id}`);

// 4. 章节与关卡
export const getChapters = (params?: Record<string, any>) =>
  http.get<ApiResult<ChapterItem[]>, any>("/chapters", { params });

export const createChapter = (data: Record<string, any>) =>
  http.post<ApiResult<number>, any>("/chapters", { data });

export const updateChapter = (id: number, data: Record<string, any>) =>
  http.request<ApiResult<void>>("put", `/chapters/${id}`, { data });

export const deleteChapter = (id: number) =>
  http.request<ApiResult<void>>("delete", `/chapters/${id}`);

export const getGatesByChapter = (chapterId: number) =>
  http.get<ApiResult<GateItem[]>, any>(`/chapters/${chapterId}/gates`);

export const updateGate = (gateId: number, data: Record<string, any>) =>
  http.request<ApiResult<void>>("put", `/gates/${gateId}`, { data });

// 5. 题库管理
export const getQuestionPage = (params: Record<string, any>) =>
  http.get<ApiResult<PageData<QuestionItem>>, any>("/questions", { params });

export const getQuestionDetail = (id: number) =>
  http.get<ApiResult<QuestionItem>, any>(`/questions/${id}`);

export const createQuestion = (data: Record<string, any>) =>
  http.post<ApiResult<number>, any>("/questions", { data });

export const updateQuestion = (id: number, data: Record<string, any>) =>
  http.request<ApiResult<void>>("put", `/questions/${id}`, { data });

export const toggleQuestionStatus = (id: number, enabled: number) =>
  http.request<ApiResult<void>>("patch", `/questions/${id}/status`, {
    data: { enabled }
  });

export const deleteQuestion = (id: number) =>
  http.request<ApiResult<void>>("delete", `/questions/${id}`);

export const previewGenerateQuestion = (data: Record<string, any>) =>
  http.post<ApiResult<GeneratedSample[]>, any>("/questions/preview-generate", {
    data
  });

export const uploadQuestionImage = (formData: FormData) =>
  http.post<ApiResult<{ objectKey: string; previewUrl: string; storageType: string }>, any>(
    "/questions/upload-image",
    {
      data: formData,
      headers: { "Content-Type": "multipart/form-data" },
      timeout: 120000
    }
  );

// 6. 教学视频管理
export const getVideoSeriesPage = (params?: Record<string, any>) =>
  http.get<ApiResult<PageData<VideoSeriesItem>>, any>("/videos/series", { params });

export const getVideoSeriesDetail = (id: number) =>
  http.get<ApiResult<VideoSeriesDetail>, any>(`/videos/series/${id}`);

export const createVideoSeries = (data: Record<string, any>) =>
  http.post<ApiResult<number>, any>("/videos/series", { data });

export const updateVideoSeries = (id: number, data: Record<string, any>) =>
  http.request<ApiResult<void>>("put", `/videos/series/${id}`, { data });

export const deleteVideoSeries = (id: number) =>
  http.request<ApiResult<void>>("delete", `/videos/series/${id}`);

export const uploadVideoCover = (formData: FormData) =>
  http.post<ApiResult<{ objectKey: string; previewUrl: string; storageType: string }>, any>(
    "/videos/upload-cover",
    {
      data: formData,
      headers: { "Content-Type": "multipart/form-data" },
      timeout: 120000
    }
  );

export const uploadVideoMedia = (formData: FormData, onProgress?: (percent: number) => void) =>
  http.post<ApiResult<{ objectKey: string; previewUrl: string; storageType: string }>, any>(
    "/videos/upload-media",
    {
      data: formData,
      headers: { "Content-Type": "multipart/form-data" },
      timeout: 600000,
      onUploadProgress: (evt: any) => {
        if (onProgress && evt?.total) {
          onProgress(Math.min(100, Math.round((evt.loaded * 100) / evt.total)));
        }
      }
    }
  );

export interface VideoMultipartPartUrl {
  partNumber: number;
  uploadUrl: string;
}

export interface VideoMultipartInitResult {
  uploadId: string;
  objectKey: string;
  chunkSize: number;
  storageType: string;
  directUpload?: boolean;
  partContentType?: string;
  partUploadUrls?: VideoMultipartPartUrl[];
}

export class OssDirectNetworkError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "OssDirectNetworkError";
  }
}

function putBlobDirectToOss(options: {
  uploadUrl: string;
  blob: Blob;
  contentType?: string;
  signal?: AbortSignal;
  timeoutMs?: number;
  label?: string;
  onProgress?: (loadedBytes: number) => void;
}): Promise<{ eTag: string }> {
  return new Promise((resolve, reject) => {
    if (options.signal?.aborted) {
      reject(new DOMException("Upload aborted", "AbortError"));
      return;
    }

    const label = options.label || "直传 OSS";
    const xhr = new XMLHttpRequest();
    xhr.open("PUT", options.uploadUrl, true);
    xhr.timeout = options.timeoutMs ?? 180000;
    xhr.withCredentials = false;
    xhr.setRequestHeader("Content-Type", options.contentType || "application/octet-stream");

    let settled = false;
    const cleanup = () => {
      if (options.signal) {
        options.signal.removeEventListener("abort", onAbort);
      }
    };
    const onAbort = () => {
      if (settled) return;
      settled = true;
      cleanup();
      xhr.abort();
      reject(new DOMException("Upload aborted", "AbortError"));
    };
    if (options.signal) {
      options.signal.addEventListener("abort", onAbort, { once: true });
    }

    xhr.upload.onprogress = evt => {
      if (evt.lengthComputable && options.onProgress) {
        options.onProgress(evt.loaded);
      }
    };

    xhr.onload = () => {
      if (settled) return;
      settled = true;
      cleanup();
      if (xhr.status >= 200 && xhr.status < 300) {
        options.onProgress?.(options.blob.size);
        const rawTag = (xhr.getResponseHeader("ETag") || xhr.getResponseHeader("etag") || "").trim();
        resolve({ eTag: rawTag });
        return;
      }
      reject(new Error(`${label}失败 (HTTP ${xhr.status})`));
    };

    xhr.onerror = () => {
      if (settled) return;
      settled = true;
      cleanup();
      reject(new OssDirectNetworkError(`${label}网络或跨域受限`));
    };

    xhr.ontimeout = () => {
      if (settled) return;
      settled = true;
      cleanup();
      reject(new Error(`${label}超时`));
    };

    xhr.send(options.blob);
  });
}

export async function uploadPartDirectToOss(options: {
  uploadUrl: string;
  partNumber: number;
  blob: Blob;
  contentType?: string;
  signal?: AbortSignal;
  onProgress?: (loadedBytes: number) => void;
}): Promise<{ partNumber: number; eTag: string }> {
  const res = await putBlobDirectToOss({
    uploadUrl: options.uploadUrl,
    blob: options.blob,
    contentType: options.contentType,
    signal: options.signal,
    timeoutMs: 180000,
    label: `直传 OSS 第 ${options.partNumber} 片`,
    onProgress: options.onProgress
  });
  return { partNumber: options.partNumber, eTag: res.eTag };
}

export async function uploadApkDirectToOss(options: {
  uploadUrl: string;
  file: Blob;
  contentType?: string;
  onProgress?: (percent: number) => void;
}): Promise<void> {
  await putBlobDirectToOss({
    uploadUrl: options.uploadUrl,
    blob: options.file,
    contentType: options.contentType || "application/vnd.android.package-archive",
    timeoutMs: 300000,
    label: "直传 APK 至 OSS",
    onProgress: loaded => {
      if (options.onProgress && options.file.size > 0) {
        options.onProgress(Math.min(99, Math.round((loaded * 99) / options.file.size)));
      }
    }
  });
}

export const initVideoMultipart = (data: { fileName: string; contentType: string; fileSize: number }) =>
  http.post<ApiResult<VideoMultipartInitResult>, any>(
    "/videos/upload-media/init",
    { data }
  );

export const uploadVideoPart = (
  formData: FormData,
  options?: { signal?: AbortSignal; onProgress?: (loadedBytes: number) => void }
) =>
  http.post<ApiResult<{ partNumber: number; eTag: string }>, any>("/videos/upload-media/part", {
    data: formData,
    headers: { "Content-Type": "multipart/form-data" },
    timeout: 180000,
    signal: options?.signal,
    onUploadProgress: (evt: any) => {
      if (options?.onProgress && typeof evt?.loaded === "number") {
        options.onProgress(evt.loaded);
      }
    }
  });

export const completeVideoMultipart = (data: {
  uploadId: string;
  objectKey: string;
  parts: Array<{ partNumber: number; eTag: string }>;
}) =>
  http.post<ApiResult<{ objectKey: string; previewUrl: string; storageType: string }>, any>(
    "/videos/upload-media/complete",
    { data, timeout: 120000 }
  );

export const abortVideoMultipart = (data: { uploadId: string; objectKey: string }) =>
  http.post<ApiResult<void>, any>("/videos/upload-media/abort", { data });

export const uploadNoteAttachment = (formData: FormData) =>
  http.post<ApiResult<{ name: string; objectKey: string; previewUrl: string; size: number; contentType: string; storageType: string }>, any>(
    "/videos/upload-attachment",
    {
      data: formData,
      headers: { "Content-Type": "multipart/form-data" },
      timeout: 120000
    }
  );

export const createVideoLesson = (seriesId: number, data: Record<string, any>) =>
  http.post<ApiResult<number>, any>(`/videos/series/${seriesId}/lessons`, { data });

export const updateVideoLesson = (lessonId: number, data: Record<string, any>) =>
  http.request<ApiResult<void>>("put", `/videos/lessons/${lessonId}`, { data });

export const deleteVideoLesson = (lessonId: number) =>
  http.request<ApiResult<void>>("delete", `/videos/lessons/${lessonId}`);
