# 过关啦 · 数学基础自测神器（全栈重构项目）

将原纯前端单页 PWA 原型升级为 **UniApp 学生端 + Vue3 管理后台 + Java Spring Boot 后端** 的完整项目。

## 目录结构

| 目录 / 文件 | 说明 |
|---|---|
| [AGENTS.md](./AGENTS.md) | **AI 会话开发总纲**（每次开启新对话优先读取） |
| [docs/01-产品原型文档.md](./docs/01-产品原型文档.md) | 完整产品原型文档（前台学生端 + 后台管理端 + 原版 51 章映射） |
| [docs/02-开发规范.md](./docs/02-开发规范.md) | 工程与编码规范（Java / UniApp / Admin / MySQL / Git） |
| [docs/03-数据库与接口规划.md](./docs/03-数据库与接口规划.md) | MySQL 表结构设计、API 契约与动态出题引擎方案 |
| [docs/04-UI框架选型对比.md](./docs/04-UI框架选型对比.md) | UniApp 与管理后台 UI 框架选型对比与最终确认记录 |
| `backend/` | Java 后端项目目录（Spring Boot 3 + MyBatis-Plus） |
| `frontend-uniapp/` | UniApp 学生端目录（`vue-uniapp-template` + `@wot-ui/ui` v2 + Vue 3 + TS） |
| `frontend-admin/` | Web 管理后台目录（`pure-admin-thin` + Vue 3 + TS + Element Plus） |
| `scripts/` | 题库迁移与运维辅助脚本目录 |

## 原型来源

- 原版源码路径：`C:\Users\LangLang\Downloads\过关啦-完整源码\过关啦-完整源码`
- 原版规模：人教版初一至高三 **6 个年级、51 个章节、204 个关卡**（68 个静态关 + 136 个随机生成关）、**10 个创意段位**、错题本、本地教师出题与 JSON 导入导出。

## 每次开启新对话的使用方式

1. 推荐在 **Antigravity / IDE** 中直接将本文件夹 `c:\Users\LangLang\Desktop\guoguanla` 作为工作区打开，`AGENTS.md` 会被自动加载。
2. 若从其他工作区发起新对话，请先提示 AI：  
   > 「请先读取 `c:\Users\LangLang\Desktop\guoguanla\AGENTS.md` 和 `docs/` 下的规范文档后再开始开发。」
