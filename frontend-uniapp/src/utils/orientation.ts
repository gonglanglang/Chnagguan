const LANDSCAPE_DRAW_ROUTE = "subPages/draw-answer/index";
let orientationTimers: Array<ReturnType<typeof setTimeout>> = [];

function clearOrientationTimers(): void {
  orientationTimers.forEach((t) => clearTimeout(t));
  orientationTimers = [];
}

function getCurrentRoutePath(): string {
  try {
    const pages = getCurrentPages();
    const top = pages[pages.length - 1];
    return (top?.route as string) || "";
  } catch {
    return "";
  }
}

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

/**
 * 根据当前栈顶路由同步锁定屏幕方向（除横屏手写板外其余页面一律锁定竖屏，防止平板重力感应乱旋转）
 */
export function syncOrientationForCurrentPage(): void {
  // #ifdef APP-PLUS
  const route = getCurrentRoutePath();
  if (route === LANDSCAPE_DRAW_ROUTE) {
    lockLandscapeOrientation();
  } else {
    lockPortraitOrientation();
  }
  // #endif
}

/**
 * 在冷启动、后台切回、视频退出全屏等时序下多次重申方向锁定，避免平板硬件默认横屏或延迟就绪失效
 */
export function enforceOrientationRepeatedly(): void {
  // #ifdef APP-PLUS
  clearOrientationTimers();
  syncOrientationForCurrentPage();
  orientationTimers.push(setTimeout(syncOrientationForCurrentPage, 80));
  orientationTimers.push(setTimeout(syncOrientationForCurrentPage, 280));
  orientationTimers.push(setTimeout(syncOrientationForCurrentPage, 650));
  // #endif
}

/**
 * 注册全局路由拦截器，在页面跳转/返回完成后自动校正直横屏锁定状态
 */
export function setupOrientationGuard(): void {
  // #ifdef APP-PLUS
  const methods = ["navigateTo", "redirectTo", "switchTab", "reLaunch", "navigateBack"] as const;
  for (const method of methods) {
    try {
      uni.addInterceptor(method, {
        complete: () => {
          setTimeout(syncOrientationForCurrentPage, 60);
          setTimeout(syncOrientationForCurrentPage, 260);
        },
      });
    } catch {
      // 忽略拦截器注册异常
    }
  }
  // #endif
}
