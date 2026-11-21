/**
 * 「过关啦」修仙数学体系专属 SVG 矢量图标注册表
 * 统一输出纯矢量 Path 数据，可在 UniApp（Data URI 跨端兼容 H5/App/小程序）与管理后台共用。
 */

export type GglIconName =
  | "gate-home"
  | "home"
  | "cultivate-scroll"
  | "wrong-sword"
  | "edit"
  | "dao-user"
  | "user"
  | "realm-lotus"
  | "trophy"
  | "spark"
  | "star-fill"
  | "notes"
  | "video-play"
  | "play-circle"
  | "brush"
  | "eraser"
  | "undo"
  | "clear"
  | "camera"
  | "upload"
  | "book"
  | "lock"
  | "unlock"
  | "check"
  | "check-circle"
  | "check-circle-fill"
  | "close"
  | "close-circle"
  | "close-circle-fill"
  | "warning"
  | "info"
  | "info-circle"
  | "notice"
  | "notification"
  | "time"
  | "theme"
  | "skin"
  | "wifi"
  | "refresh"
  | "trash"
  | "delete"
  | "back"
  | "arrow-left"
  | "right"
  | "empty";

type GlyphBuilder = (color: string) => string;

const GLYPHS: Record<string, GlyphBuilder> = {
  // 山门关隘（首页）
  "gate-home": (c) => `
    <path d="M3 10.5L12 3.5L21 10.5" stroke="${c}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M5.5 9.2V20H18.5V9.2" stroke="${c}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M9.5 20V14.2C9.5 12.82 10.62 11.7 12 11.7C13.38 11.7 14.5 12.82 14.5 14.2V20" stroke="${c}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M8 7.5H16" stroke="${c}" stroke-width="1.6" stroke-linecap="round"/>
  `,

  // 修炼宝卷（修炼/视频课堂）
  "cultivate-scroll": (c) => `
    <rect x="4" y="4.5" width="16" height="15" rx="3" stroke="${c}" stroke-width="1.9"/>
    <path d="M10.2 9.2L15.2 12L10.2 14.8V9.2Z" fill="${c}" stroke="${c}" stroke-width="1.4" stroke-linejoin="round"/>
    <path d="M7.5 2.8V5.2M16.5 2.8V5.2" stroke="${c}" stroke-width="1.8" stroke-linecap="round"/>
  `,

  // 斩错剑册（错题本）
  "wrong-sword": (c) => `
    <path d="M5.5 4.2C5.5 3.54 6.04 3 6.7 3H16.5C17.6 3 18.5 3.9 18.5 5V19.2C18.5 20.19 17.7 21 16.7 21H6.7C6.04 21 5.5 20.46 5.5 19.8V4.2Z" stroke="${c}" stroke-width="1.9"/>
    <path d="M9 3V21" stroke="${c}" stroke-width="1.7"/>
    <path d="M12.2 9.5L15.4 12.7M15.4 9.5L12.2 12.7" stroke="${c}" stroke-width="1.8" stroke-linecap="round"/>
    <path d="M12 16H15.5" stroke="${c}" stroke-width="1.8" stroke-linecap="round"/>
  `,

  // 修士元神（我的）
  "dao-user": (c) => `
    <circle cx="12" cy="8.4" r="3.6" stroke="${c}" stroke-width="1.9"/>
    <path d="M9.6 4.8L12 2.8L14.4 4.8" stroke="${c}" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M5 19.8C5.6 16.4 8.5 14.4 12 14.4C15.5 14.4 18.4 16.4 19 19.8" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
  `,

  // 青莲道果（境界）
  "realm-lotus": (c) => `
    <path d="M12 4C9.8 7.1 9.5 10.6 12 14C14.5 10.6 14.2 7.1 12 4Z" stroke="${c}" stroke-width="1.8" stroke-linejoin="round"/>
    <path d="M6.2 7.4C6.6 11.2 8.7 13.8 12 14.6C8.8 14.9 5.5 13.8 4 11C4.5 9.4 5.2 8.2 6.2 7.4Z" stroke="${c}" stroke-width="1.8" stroke-linejoin="round"/>
    <path d="M17.8 7.4C17.4 11.2 15.3 13.8 12 14.6C15.2 14.9 18.5 13.8 20 11C19.5 9.4 18.8 8.2 17.8 7.4Z" stroke="${c}" stroke-width="1.8" stroke-linejoin="round"/>
    <path d="M5 18.5H19" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
  `,

  trophy: (c) => `
    <path d="M7.5 4.5H16.5V9.8C16.5 12.29 14.49 14.3 12 14.3C9.51 14.3 7.5 12.29 7.5 9.8V4.5Z" stroke="${c}" stroke-width="1.9" stroke-linejoin="round"/>
    <path d="M7.5 6.2H4.8C4.8 8.9 5.7 10.6 7.5 11.2" stroke="${c}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M16.5 6.2H19.2C19.2 8.9 18.3 10.6 16.5 11.2" stroke="${c}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M12 14.3V18.8M8.5 19.2H15.5" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
  `,

  spark: (c) => `
    <path d="M12 3L14.2 9.4L20.5 11.6L14.2 13.8L12 20.2L9.8 13.8L3.5 11.6L9.8 9.4L12 3Z" stroke="${c}" stroke-width="1.85" stroke-linejoin="round"/>
  `,

  "star-fill": (c) => `
    <path d="M12 3.2L14.7 8.7L20.8 9.6L16.4 13.9L17.4 20L12 17.1L6.6 20L7.6 13.9L3.2 9.6L9.3 8.7L12 3.2Z" fill="${c}" stroke="${c}" stroke-width="1.4" stroke-linejoin="round"/>
  `,

  notes: (c) => `
    <rect x="5" y="3.5" width="14" height="17" rx="2.4" stroke="${c}" stroke-width="1.9"/>
    <path d="M8.5 8.5H15.5M8.5 12.2H15.5M8.5 15.9H13" stroke="${c}" stroke-width="1.8" stroke-linecap="round"/>
  `,

  "video-play": (c) => `
    <rect x="3" y="5" width="18" height="14" rx="2.8" stroke="${c}" stroke-width="1.9"/>
    <path d="M10.2 9.2L15.4 12L10.2 14.8V9.2Z" fill="${c}"/>
  `,

  "play-circle": (c) => `
    <circle cx="12" cy="12" r="9" stroke="${c}" stroke-width="1.9"/>
    <path d="M10.2 8.8L15.6 12L10.2 15.2V8.8Z" fill="${c}"/>
  `,

  brush: (c) => `
    <path d="M16.8 4.2L19.8 7.2L9.2 17.8L5.2 18.8L6.2 14.8L16.8 4.2Z" stroke="${c}" stroke-width="1.9" stroke-linejoin="round"/>
    <path d="M14.4 6.6L17.4 9.6" stroke="${c}" stroke-width="1.8"/>
  `,

  eraser: (c) => `
    <path d="M14.5 4.5L19.8 9.8L11.2 18.4H5.8L4.2 16.8L14.5 4.5Z" stroke="${c}" stroke-width="1.9" stroke-linejoin="round"/>
    <path d="M9.4 10.6L14.4 15.6" stroke="${c}" stroke-width="1.8"/>
    <path d="M11.2 18.4H20" stroke="${c}" stroke-width="1.8" stroke-linecap="round"/>
  `,

  undo: (c) => `
    <path d="M8.5 7.5H4.5V3.5" stroke="${c}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M4.8 7.5C6.8 5.2 9.8 4.2 12.8 4.8C16.7 5.6 19.4 9.1 19 13.1C18.6 16.9 15.4 19.6 11.6 19.6C8.8 19.6 6.4 18.1 5.2 15.8" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
  `,

  clear: (c) => `
    <path d="M4.5 7H19.5M9.5 4H14.5" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
    <path d="M6.8 7L7.6 19.2C7.66 19.95 8.28 20.5 9.03 20.5H14.97C15.72 20.5 16.34 19.95 16.4 19.2L17.2 7" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
    <path d="M10.2 10.8V16.5M13.8 10.8V16.5" stroke="${c}" stroke-width="1.8" stroke-linecap="round"/>
  `,

  camera: (c) => `
    <path d="M4 8.5C4 7.4 4.9 6.5 6 6.5H8.4L9.8 4.5H14.2L15.6 6.5H18C19.1 6.5 20 7.4 20 8.5V17.5C20 18.6 19.1 19.5 18 19.5H6C4.9 19.5 4 18.6 4 17.5V8.5Z" stroke="${c}" stroke-width="1.9" stroke-linejoin="round"/>
    <circle cx="12" cy="13" r="3.2" stroke="${c}" stroke-width="1.9"/>
  `,

  upload: (c) => `
    <path d="M12 15.5V4.8M12 4.8L8.2 8.6M12 4.8L15.8 8.6" stroke="${c}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M4.8 14.8V17.5C4.8 18.6 5.7 19.5 6.8 19.5H17.2C18.3 19.5 19.2 18.6 19.2 17.5V14.8" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
  `,

  book: (c) => `
    <path d="M4.5 5.2C4.5 4.2 5.3 3.5 6.2 3.5H12V19.5H6.2C5.3 19.5 4.5 20.2 4.5 21V5.2Z" stroke="${c}" stroke-width="1.9" stroke-linejoin="round"/>
    <path d="M19.5 5.2C19.5 4.2 18.7 3.5 17.8 3.5H12V19.5H17.8C18.7 19.5 19.5 20.2 19.5 21V5.2Z" stroke="${c}" stroke-width="1.9" stroke-linejoin="round"/>
  `,

  lock: (c) => `
    <rect x="5" y="10.2" width="14" height="9.8" rx="2.4" stroke="${c}" stroke-width="1.9"/>
    <path d="M8.2 10.2V7.6C8.2 5.5 9.9 3.8 12 3.8C14.1 3.8 15.8 5.5 15.8 7.6V10.2" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
    <circle cx="12" cy="14.9" r="1.2" fill="${c}"/>
  `,

  unlock: (c) => `
    <rect x="5" y="10.2" width="14" height="9.8" rx="2.4" stroke="${c}" stroke-width="1.9"/>
    <path d="M8.2 10.2V7.6C8.2 5.5 9.9 3.8 12 3.8C13.7 3.8 15.1 4.9 15.6 6.5" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
  `,

  check: (c) => `
    <path d="M5.2 12.6L9.8 17.2L19 7.6" stroke="${c}" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"/>
  `,

  "check-circle": (c) => `
    <circle cx="12" cy="12" r="9" stroke="${c}" stroke-width="1.9"/>
    <path d="M8.2 12.2L10.8 14.8L16 9.4" stroke="${c}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
  `,

  "check-circle-fill": (c) => `
    <circle cx="12" cy="12" r="9.5" fill="${c}"/>
    <path d="M8.2 12.2L10.8 14.8L16 9.4" stroke="#ffffff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  `,

  close: (c) => `
    <path d="M6.5 6.5L17.5 17.5M17.5 6.5L6.5 17.5" stroke="${c}" stroke-width="2" stroke-linecap="round"/>
  `,

  "close-circle": (c) => `
    <circle cx="12" cy="12" r="9" stroke="${c}" stroke-width="1.9"/>
    <path d="M9 9L15 15M15 9L9 15" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
  `,

  "close-circle-fill": (c) => `
    <circle cx="12" cy="12" r="9.5" fill="${c}"/>
    <path d="M9 9L15 15M15 9L9 15" stroke="#ffffff" stroke-width="2" stroke-linecap="round"/>
  `,

  warning: (c) => `
    <path d="M12 4L20.5 19H3.5L12 4Z" stroke="${c}" stroke-width="1.9" stroke-linejoin="round"/>
    <path d="M12 10V14" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
    <circle cx="12" cy="16.6" r="0.9" fill="${c}"/>
  `,

  info: (c) => `
    <circle cx="12" cy="12" r="9" stroke="${c}" stroke-width="1.9"/>
    <path d="M12 11.2V16.2" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
    <circle cx="12" cy="8.2" r="1" fill="${c}"/>
  `,

  notice: (c) => `
    <path d="M5.5 14V10C5.5 9.17 6.17 8.5 7 8.5H10.2L16.5 5.2V18.8L10.2 15.5H7C6.17 15.5 5.5 14.83 5.5 14Z" stroke="${c}" stroke-width="1.9" stroke-linejoin="round"/>
    <path d="M19.2 9.2C20.2 10.8 20.2 13.2 19.2 14.8" stroke="${c}" stroke-width="1.8" stroke-linecap="round"/>
  `,

  time: (c) => `
    <circle cx="12" cy="12" r="9" stroke="${c}" stroke-width="1.9"/>
    <path d="M12 7.5V12.2L15.2 14" stroke="${c}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
  `,

  theme: (c) => `
    <path d="M12 3.5C7.3 3.5 3.5 7.2 3.5 11.8C3.5 15.7 6.4 18.6 9.8 18.6H11.2C12 18.6 12.6 19.2 12.4 20C12.3 20.5 12.7 21 13.3 21C17.4 21 20.5 17.5 20.5 12.7C20.5 7.4 16.8 3.5 12 3.5Z" stroke="${c}" stroke-width="1.9"/>
    <circle cx="8" cy="11" r="1.1" fill="${c}"/>
    <circle cx="11" cy="7.8" r="1.1" fill="${c}"/>
    <circle cx="15.2" cy="8.8" r="1.1" fill="${c}"/>
  `,

  wifi: (c) => `
    <path d="M3.8 9.2C8.4 5 15.6 5 20.2 9.2" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
    <path d="M6.8 12.8C9.8 10 14.2 10 17.2 12.8" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
    <path d="M9.8 16.2C11 15.1 13 15.1 14.2 16.2" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
    <circle cx="12" cy="18.8" r="1.2" fill="${c}"/>
  `,

  refresh: (c) => `
    <path d="M18.8 7.5A7.6 7.6 0 0 0 5.5 8.5" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
    <path d="M18.8 3.8V7.6H15" stroke="${c}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M5.2 16.5A7.6 7.6 0 0 0 18.5 15.5" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
    <path d="M5.2 20.2V16.4H9" stroke="${c}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
  `,

  back: (c) => `
    <path d="M14.8 5.5L8.2 12L14.8 18.5" stroke="${c}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  `,

  right: (c) => `
    <path d="M9.2 5.5L15.8 12L9.2 18.5" stroke="${c}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  `,

  empty: (c) => `
    <rect x="4" y="5" width="16" height="14" rx="2.5" stroke="${c}" stroke-width="1.8"/>
    <path d="M4 13.5H8.5L10 15.5H14L15.5 13.5H20" stroke="${c}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
  `,
};

// 兼容旧名称映射，统一收口到专属图标库
const ALIAS_MAP: Record<string, string> = {
  home: "gate-home",
  edit: "brush",
  user: "dao-user",
  notification: "notice",
  "info-circle": "info",
  skin: "theme",
  delete: "clear",
  trash: "clear",
  "arrow-left": "back",
};

export function resolveGlyphSvgBody(name: string, color: string): string {
  const key = ALIAS_MAP[name] || name;
  const builder = GLYPHS[key] || GLYPHS.info;
  return builder(color);
}

export function buildGglIconSvg(name: string, color = "#16a34a"): string {
  const body = resolveGlyphSvgBody(name, color).replace(/\s+/g, " ").trim();
  return `<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none">${body}</svg>`;
}

export function buildGglIconDataUri(name: string, color = "#16a34a"): string {
  return `data:image/svg+xml;utf8,${encodeURIComponent(buildGglIconSvg(name, color))}`;
}
