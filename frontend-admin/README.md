# frontend-admin — Web 管理后台

基于开源框架 **`pure-admin-thin` (v6.2.0 · Vue 3 + Vite + TypeScript + Element Plus + Pinia + Tailwind CSS)** 改造实现。

## 已改造模块
- **数据总览** (`src/views/welcome/index.vue`)：核心指标卡、ECharts 年级题量与学生分布图、高频错题章节、段位分布
- **学生用户管理** (`src/views/user/index.vue`)：分页检索、新增/编辑、启停控制、战绩详情抽屉（过关数、段位、各章星级、错题本、答题历史）
- **年级章节与关卡配置** (`src/views/bank/chapter/index.vue`)：年级启停、章节 CRUD（自动初始化 4 关）、关卡规则配置抽屉
- **题目与模板管理** (`src/views/bank/question/index.vue`)：静态/动态模板与多题型支持、手机端实时预览、动态试生成、JSON 导入导出
- **段位与全局参数 / 操作审计日志** (`src/views/system/`)

## 本地开发命令
```powershell
cd frontend-admin
pnpm install
pnpm run dev        # 默认端口 8848，/api 代理至 http://localhost:8080
pnpm run typecheck  # TypeScript 类型检查
pnpm run build      # 生产构建
```
