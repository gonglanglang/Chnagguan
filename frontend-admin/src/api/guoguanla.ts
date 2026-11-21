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
  status: number;
  remark: string;
  lastActiveAt: string;
  createdAt: string;
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
    stem: string;
    options: string[];
    answerIndex: number;
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
  questionFormat: "SINGLE_CHOICE" | "MULTI_CHOICE" | "FILL_BLANK" | "JUDGE";
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
}

export interface SysConfigItem {
  id: number;
  configKey: string;
  configValue: string;
  description: string;
  updatedAt: string;
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

// 3. 学生管理
export const getUserPage = (params: Record<string, any>) =>
  http.get<ApiResult<PageData<StudentUser>>, any>("/users", { params });

export const getUserDetail = (id: number) =>
  http.get<ApiResult<StudentDetail>, any>(`/users/${id}`);

export const createUser = (data: Record<string, any>) =>
  http.post<ApiResult<number>, any>("/users", { data });

export const updateUser = (id: number, data: Record<string, any>) =>
  http.request<ApiResult<void>>("put", `/users/${id}`, { data });

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
