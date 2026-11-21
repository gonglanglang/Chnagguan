/**
 * 控制移动端屏幕方向（仅 App 端调用 HTML5+ API，H5/小程序安全空转）
 */
export function lockLandscapeOrientation(): void {
  // #ifdef APP-PLUS
  try {
    if (typeof plus !== "undefined" && plus.screen?.lockOrientation) {
      plus.screen.lockOrientation("landscape-primary");
    }
  } catch {
    // 忽略宿主不支持屏幕锁定时的异常
  }
  // #endif
}

/**
 * 恢复竖屏显示（仅 App 端调用 HTML5+ API）
 */
export function lockPortraitOrientation(): void {
  // #ifdef APP-PLUS
  try {
    if (typeof plus !== "undefined" && plus.screen?.lockOrientation) {
      plus.screen.lockOrientation("portrait-primary");
    }
  } catch {
    // 忽略宿主不支持屏幕锁定时的异常
  }
  // #endif
}
