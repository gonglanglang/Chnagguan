# 过关啦 · 学生端 App（Flutter + WelkUI 重构版）

基于 **Flutter 3.50+ (Dart 3.14)** 与漫画手绘风组件库 **`welkui_flutter` (`^0.2.2`)** 全量重构的学生端跨端应用，完整对接「过关啦」Spring Boot 后端全部 `/api/app/**` 接口。

## 技术栈

- **框架**：Flutter `>=3.35.0` / Dart `^3.13.4`
- **UI 组件库**：`welkui_flutter: ^0.2.2`（`WelkTheme`、`WelkAppBar`、`WelkBottomNavBar`、`WelkButton`、`WelkIconButton`、`WelkInput`、`WelkBadge`、`WelkAvatar`、`WelkSwitch`、`WelkCheckBox`、`WelkDivider`、`WelkDialog`、`WelkDrawer`、`WelkSnackBar`、`WelkAccordion`）
- **状态管理**：`provider`（`UserProvider` / `ThemeProvider` / `UpdateProvider`）
- **网络与持久化**：`dio` + `shared_preferences`
- **多媒体与原生能力**：`video_player`、`image_picker`、`package_info_plus`、`path_provider`、`url_launcher`、`open_filex`

## 核心特性

- **四主 Tab + 11 二级页面（共 15 页）**：闯关首页、修炼课堂、错题本（带实时角标）、我的、登录注册（必填年级/无体验账号/游客记录合并）、章节闯关地图、答题判题与结算（防作弊后端判分、支持关卡/错题重做/进阶考核三模式）、横屏无限手写画板（纯 Canvas 双指缩放/边缘自动延申/高清 PNG 离屏导出上传）、视频课堂与课堂笔记、六大修仙境界体系、解答作答记录（含永久清空）、个人资料与头像上传、漫画主题与暗黑模式设置、网络检测、关于与版本更新。
- **Android 包标识对齐**：`applicationId = "com.guoguanla.app"`，版本号 `1.0.13+113`，内置应用内直下 APK 进度条与安装调起。

## 本地运行与构建

```bash
# 安装依赖
flutter pub get

# 静态分析与自动化测试
flutter analyze
flutter test

# 本地 Web 预览（默认连接 http://localhost:8080/api）
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5175 --dart-define=API_BASE_URL=http://localhost:8080/api

# 或使用仓库根目录一键脚本（需先启动后端 8080）
powershell -ExecutionPolicy Bypass -File ../scripts/dev-local.ps1 -Action start -Target flutter

# 构建生产 Android APK（需本机配置 Android SDK 与签名 keystore）
flutter build apk --release --dart-define=API_BASE_URL=http://47.107.94.90/api
```
