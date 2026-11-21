# 过关啦 · 学生端 UniApp（frontend-uniapp）

基于开源模板 **`vue-uniapp-template` (`youlai-app`)** + **`@wot-ui/ui` (Wot Design Uni v2)** + **Vue 3 + TypeScript + Pinia + UnoCSS** 改造重构。

## 架构特点

- **开箱即用框架底座**：沿用 `AppProvider`（全局 `wd-config-provider` / `wd-toast` / `wd-dialog` / `wd-notify` + 深色模式/主题色）、`AppNavbar`（适配微信小程序胶囊与状态栏安全区）、`tabbar` / `default` / `blank` 布局及 `@uni-helper/vite-plugin-uni-pages` 自动路由。
- **清爽极简视觉**：`#f7f8fa` 浅灰画布、纯白圆角卡片、`#16a34a` 克制主色与 `@wot-ui/ui` 矢量图标，无多余渐变、大边框或冗余装饰。
- **核心学生业务**：
  - `src/pages/index/index.vue`：年级 -> 章节 -> 4 关三层钻取，支持游客试玩及实时过关进度刷新
  - `src/pages/wrong/index.vue`：年级筛选、待巩固错题回顾、重做入口与手动掌握/清空
  - `src/pages/mine/index.vue`：学生档案卡片、章节战绩摘要、个人资料编辑、段位说明与主题/缓存/网络设置
  - `src/subPages/quiz/index.vue`：关卡答题与错题重做（后端动态出题、单题即时判题与解析、交卷自动晋升段位）
  - `src/subPages/login/index.vue` / `profile/index.vue` / `levels/index.vue`：登录注册（自动合并游客通关进度）、资料与年级修改、10 级段位体系展示

## 本地开发与构建

```bash
pnpm install

# H5 开发启动（默认端口 5174，/api 代理到 http://localhost:8080）
pnpm run dev:h5

# TypeScript 类型检查
pnpm run type-check

# H5 生产构建
pnpm run build:h5

# 微信小程序构建（输出 dist/build/mp-weixin）
pnpm run build:mp-weixin
```

> **提示**：`src/pages.json` 与 `src/types/{auto-imports,components,uni-pages}.d.ts` 由 `@uni-helper/vite-plugin-uni-pages`、`unplugin-auto-import` 和 `vite-plugin-uni-components` 自动生成，请勿手动修改 `src/pages.json`；路由及标题请改对应页面内的 `definePage(...)` 或根目录 `pages.config.ts`。
