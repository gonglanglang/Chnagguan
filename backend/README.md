# backend — Java 服务端

基于 **Java 17+ (本机运行 JDK 21) + Spring Boot 3.3.5 + MyBatis-Plus 3.5.9 + Sa-Token 1.39 + MySQL 8.0 + Mozilla Rhino 沙箱引擎** 构建。

## 启动与验证方式

### 1. 配置本地 MySQL（二选一）
- **方式 A（推荐）**：在项目根目录运行交互式脚本：
  ```powershell
  .\scripts\init-mysql.ps1
  ```
  脚本会执行建表与 51 章题库初始化，并自动生成 `backend/application-local.yml`。
- **方式 B**：手动复制 `src/main/resources/application-local.yml.example` 为 `backend/application-local.yml` 并填入本地 MySQL 密码，程序启动时会自动建库建表并导入默认管理员、51 章题库及演示学生。

### 2. 运行测试与启动服务
```powershell
$env:JAVA_HOME = "C:\Program Files\Java\jdk-21"
cd backend
.\mvnw.cmd test             # H2 内存库集成测试 + 408 个动态题生成器全量验证
.\mvnw.cmd spring-boot:run  # 启动服务 (端口 8080，Swagger 文档: http://localhost:8080/doc.html)
```

默认管理员账号：`admin` / `admin123`（超管） ｜ `teacher` / `teacher123`（教研）。
