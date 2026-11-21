param(
    [string]$MySqlUser = "root",
    [string]$MySqlHost = "127.0.0.1",
    [int]$MySqlPort = 3306
)

$mysqlExe = "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
if (-not (Test-Path $mysqlExe)) {
    $mysqlExe = "mysql"
}

$secPwd = Read-Host "请输入 MySQL 用户 ($MySqlUser) 的密码" -AsSecureString
$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secPwd)
$plainPwd = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)

$sqlFile = Join-Path $PSScriptRoot "output\init-mysql-all.sql"
if (-not (Test-Path $sqlFile)) {
    Write-Error "未找到 SQL 文件: $sqlFile，请先运行 node scripts/extract_prototype_bank.mjs"
    exit 1
}

Write-Host "正在导入数据库 guoguanla ..." -ForegroundColor Cyan
$env:MYSQL_PWD = $plainPwd
Get-Content $sqlFile -Raw -Encoding UTF8 | & $mysqlExe --default-character-set=utf8mb4 -h $MySqlHost -P $MySqlPort -u $MySqlUser
$exitCode = $LASTEXITCODE
Remove-Item Env:\MYSQL_PWD -ErrorAction SilentlyContinue

if ($exitCode -eq 0) {
    Write-Host "✅ MySQL 数据库 guoguanla 建表与 51 章题库初始化成功！" -ForegroundColor Green
    $localYml = Join-Path $PSScriptRoot "..\backend\application-local.yml"
    $ymlContent = @"
spring:
  datasource:
    url: jdbc:mysql://${MySqlHost}:${MySqlPort}/guoguanla?createDatabaseIfNotExist=true&useUnicode=true&characterEncoding=UTF-8&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true&useSSL=false
    username: ${MySqlUser}
    password: ${plainPwd}
"@
    Set-Content -Path $localYml -Value $ymlContent -Encoding UTF8
    Write-Host "✅ 已生成本地配置 backend/application-local.yml（已加入 .gitignore）" -ForegroundColor Green
} else {
    Write-Error "❌ MySQL 导入失败，请检查密码或 MySQL80 服务状态。"
    exit $exitCode
}
