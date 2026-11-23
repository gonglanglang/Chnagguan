/**
 * 「过关啦」修仙数学体系专属 SVG 矢量图标注册表
 * 统一输出纯矢量 Path 数据，可在 UniApp（Data URI 跨端兼容 H5/App/小程序）与管理后台共用。
 */

export type GglIconName =
  | "gate-home"
  | "home"
  | "flag"
  | "cultivate-scroll"
  | "circle-play"
  | "wrong-sword"
  | "notebook-pen"
  | "edit"
  | "pen-line"
  | "layers"
  | "graduation-cap"
  | "chart-column"
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
  | "hand"
  | "zoom-in"
  | "zoom-out"
  | "expand"
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
  | "alert-circle"
  | "info"
  | "info-circle"
  | "notice"
  | "notification"
  | "time"
  | "eye"
  | "eye-off"
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
  // 闯关旗帜（TabBar / 品牌图标）
  flag: (c) => `
    <path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z" stroke="${c}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M4 22V15" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
  `,

  // 课堂播放圆环
  "circle-play": (c) => `
    <circle cx="12" cy="12" r="9" stroke="${c}" stroke-width="1.9"/>
    <polygon points="10 8.5 16 12 10 15.5" stroke="${c}" stroke-width="1.75" stroke-linejoin="round"/>
  `,

  // 错题笔记
  "notebook-pen": (c) => `
    <path d="M13.4 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-7.4" stroke="${c}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M2 6h4M2 10h4M2 14h4M2 18h4" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
    <path d="M21.38 3.62a1.7 1.7 0 0 0-2.4 0L11 11.6l-.9 3.3 3.3-.9 7.98-7.98a1.7 1.7 0 0 0 0-2.4z" stroke="${c}" stroke-width="1.8" stroke-linejoin="round"/>
  `,

  // 我的（简洁人形）
  user: (c) => `
    <circle cx="12" cy="8" r="4" stroke="${c}" stroke-width="1.9"/>
    <path d="M5 20a7 7 0 0 1 14 0" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
  `,

  // 境界层级
  layers: (c) => `
    <path d="M12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 3.91a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.84z" stroke="${c}" stroke-width="1.9" stroke-linejoin="round"/>
    <path d="m2 12 8.58 3.91a2 2 0 0 0 1.66 0L22 12" stroke="${c}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="m2 17 8.58 3.91a2 2 0 0 0 1.66 0L22 17" stroke="${c}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
  `,

  // 解答记录钢笔
  "pen-line": (c) => `
    <path d="M12 20h9" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
    <path d="M16.38 3.62a1.7 1.7 0 0 1 2.4 2.4L6.7 18.1 3 19l.9-3.7Z" stroke="${c}" stroke-width="1.9" stroke-linejoin="round"/>
  `,

  // 进阶考学士帽
  "graduation-cap": (c) => `
    <path d="M21.42 10.92a1 1 0 0 0-.02-1.84L12.83 5.18a2 2 0 0 0-1.66 0L2.6 9.08a1 1 0 0 0 0 1.84l8.58 3.91a2 2 0 0 0 1.66 0z" stroke="${c}" stroke-width="1.9" stroke-linejoin="round"/>
    <path d="M22 10v6" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
    <path d="M6 12.5V16a6 3 0 0 0 12 0v-3.5" stroke="${c}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
  `,

  // 学习周报柱状图
  "chart-column": (c) => `
    <path d="M3 3v16a2 2 0 0 0 2 2h16" stroke="${c}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M18 17V9M13 17V5M8 17v-3" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
  `,

  // 错误感叹圆圈
  "alert-circle": (c) => `
    <circle cx="12" cy="12" r="9" stroke="${c}" stroke-width="1.9"/>
    <path d="M12 8v5" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
    <circle cx="12" cy="16" r="1" fill="${c}"/>
  `,

  // 密码可见
  eye: (c) => `
    <path d="M2.5 12s3.5-6.5 9.5-6.5S21.5 12 21.5 12s-3.5 6.5-9.5 6.5S2.5 12 2.5 12Z" stroke="${c}" stroke-width="1.9" stroke-linejoin="round"/>
    <circle cx="12" cy="12" r="2.8" stroke="${c}" stroke-width="1.9"/>
  `,

  // 密码隐藏
  "eye-off": (c) => `
    <path d="M9.9 5.3A9.7 9.7 0 0 1 12 5.5c6 0 9.5 6.5 9.5 6.5a16.8 16.8 0 0 1-3.2 4.1" stroke="${c}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M6.2 6.8C4 8.4 2.5 12 2.5 12s3.5 6.5 9.5 6.5c1.7 0 3.2-.4 4.5-1.1" stroke="${c}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M3 3l18 18" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
  `,

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

  hand: (c) => `
    <path d="M9 11.5V6.2C9 5.54 9.54 5 10.2 5C10.86 5 11.4 5.54 11.4 6.2V10.5M11.4 10.5V4.8C11.4 4.14 11.94 3.6 12.6 3.6C13.26 3.6 13.8 4.14 13.8 4.8V10.5M13.8 10.5V5.7C13.8 5.04 14.34 4.5 15 4.5C15.66 4.5 16.2 5.04 16.2 5.7V11M16.2 11V7.6C16.2 6.94 16.74 6.4 17.4 6.4C18.06 6.4 18.6 6.94 18.6 7.6V14.2C18.6 17.6 16.1 20 12.8 20C10.3 20 8.5 18.7 7.1 16.6L5.1 13.4C4.74 12.84 4.92 12.09 5.48 11.74C6.02 11.4 6.72 11.54 7.1 12.04L9 14.3V11.5Z" stroke="${c}" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"/>
  `,

  "zoom-in": (c) => `
    <circle cx="11" cy="11" r="6.5" stroke="${c}" stroke-width="1.9"/>
    <path d="M16 16L20 20M8.5 11H13.5M11 8.5V13.5" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
  `,

  "zoom-out": (c) => `
    <circle cx="11" cy="11" r="6.5" stroke="${c}" stroke-width="1.9"/>
    <path d="M16 16L20 20M8.5 11H13.5" stroke="${c}" stroke-width="1.9" stroke-linecap="round"/>
  `,

  expand: (c) => `
    <path d="M15 4.5H19.5V9M9 19.5H4.5V15M19.5 4.5L13.8 10.2M4.5 19.5L10.2 13.8" stroke="${c}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
  `,
};

// 兼容旧名称映射，统一收口到专属图标库
const ALIAS_MAP: Record<string, string> = {
  home: "flag",
  edit: "brush",
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

export function buildGglIconSvg(name: string, color = "#0284C7"): string {
  const body = resolveGlyphSvgBody(name, color).replace(/\s+/g, " ").trim();
  return `<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none">${body}</svg>`;
}

export function buildGglIconDataUri(name: string, color = "#0284C7"): string {
  return `data:image/svg+xml;utf8,${encodeURIComponent(buildGglIconSvg(name, color))}`;
}
