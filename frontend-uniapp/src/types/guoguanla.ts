export interface LevelProgress {
  levelId: number;
  icon: string;
  levelName: string;
  quote: string;
  minGates: number;
  nextMinGates: number | null;
  nextIcon: string | null;
  nextLevelName: string | null;
}

export interface RealmItem {
  realmCode: string;
  realmName: string;
  realmOrder: number;
  gradeCode: string;
  difficultyLabel: string;
  description: string;
  unlockGates: number;
  examQuestionCount: number;
  examPassScore: number;
  chapterCount: number;
  gateCount: number;
  passedGateCount: number;
  unlocked: boolean;
  isCurrent: boolean;
  isLower: boolean;
  isHigher: boolean;
  examEligible: boolean;
  examRemainingGates: number;
}

export interface AppUserProfile {
  id: number;
  username: string;
  nickname: string;
  avatarUrl: string;
  gradeCode: string;
  gradeName: string;
  realmCode: string;
  realmName: string;
  realmOrder: number;
  difficultyLabel: string;
  nextRealmCode: string | null;
  nextRealmName: string | null;
  realmPassedGates: number;
  realmTotalGates: number;
  examUnlockGates: number;
  examRemainingGates: number;
  examEligible: boolean;
  examQuestionCount: number;
  examPassScore: number;
  passedGateCount: number;
  level: LevelProgress | null;
}

export interface AuthResult {
  token: string;
  profile: AppUserProfile;
}

export interface GradeItem {
  gradeCode: string;
  gradeName: string;
  icon: string;
  chapterCount: number;
}

export interface HomeSummary {
  guestModeEnabled: boolean;
  appNotice: string;
  profile: AppUserProfile | null;
  grades: GradeItem[];
  realms: RealmItem[];
}

export interface ChapterCard {
  id: number;
  chapterCode: string;
  gradeCode: string;
  realmCode: string;
  realmName: string;
  realmOrder: number;
  name: string;
  description: string;
  isCustom: number;
  passedCount: number;
  totalGates: number;
  lockedByRealm: boolean;
  suppressed: boolean;
}

export interface GateCard {
  id: number;
  chapterId: number;
  gateIndex: number;
  gateName: string;
  star: number;
  questionCount: number;
  passCount: number;
  passed: boolean;
  locked: boolean;
  lockedByRealm: boolean;
  suppressed: boolean;
  empty: boolean;
}

export interface ClientQuestionItem {
  itemIndex: number;
  questionFormat: string;
  stem: string;
  options: string[];
}

export interface QuizStartResult {
  sessionNo: string;
  mode: "GATE" | "WRONG_REDO" | "ADVANCE_EXAM" | string;
  realmCode: string | null;
  realmName: string | null;
  realmOrder: number | null;
  suppressedMode: boolean;
  passScore: number | null;
  chapterId: number | null;
  chapterName: string;
  gateId: number | null;
  gateName: string;
  star: number | null;
  passCount: number;
  totalCount: number;
  guestMode: boolean;
  items: ClientQuestionItem[];
}

export interface CheckItemResult {
  itemIndex: number;
  correct: boolean;
  correctIndex: number;
  analysis: string;
}

export interface WrongReviewItem {
  stem: string;
  correctAnswer: string;
  analysis: string;
}

export interface SubmitResult {
  sessionNo: string;
  mode: "GATE" | "WRONG_REDO" | "ADVANCE_EXAM" | string;
  totalCount: number;
  correctCount: number;
  score: number | null;
  passScore: number | null;
  passCount: number;
  passed: boolean;
  newlyPassed: boolean;
  totalPassedGates: number;
  promotedLevel: LevelProgress | null;
  promotedRealm: RealmItem | null;
  wrongItems: WrongReviewItem[];
  masteredCount: number;
}

export interface WrongQuestionItem {
  id: number;
  gradeCode: string;
  realmCode: string;
  realmName: string;
  chapterId: number | null;
  chapterName: string;
  gateName: string;
  stem: string;
  options: string[];
  answerIndex: number;
  analysis: string;
  wrongCount: number;
  lastWrongAt: string;
}

export interface LoginPayload {
  account: string;
  password: string;
  guestPassedGateIds?: number[];
}

export interface RegisterPayload {
  username: string;
  password: string;
  nickname: string;
  guestPassedGateIds?: number[];
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
