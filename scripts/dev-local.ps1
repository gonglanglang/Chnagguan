param(
  [ValidateSet("start", "stop", "status")]
  [string]$Action = "start",
  [ValidateSet("all", "backend", "admin", "uniapp")]
  [string]$Target = "all"
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$StateDir = Join-Path $env:TEMP "guoguanla-dev"
$PidFile = Join-Path $StateDir "pids.json"

$Services = @(
  @{
    Key = "backend"
    Name = "Java 后端 (Spring Boot)"
    Port = 8080
    Url = "http://127.0.0.1:8080/api/app/home/summary"
    WorkDir = Join-Path $RepoRoot "backend"
    Cmd = "mvnw.cmd"
    Args = @("spring-boot:run", "-Dspring-boot.run.profiles=dev")
  },
  @{
    Key = "admin"
    Name = "管理后台 (Vite)"
    Port = 8848
    Url = "http://127.0.0.1:8848/"
    WorkDir = Join-Path $RepoRoot "frontend-admin"
    Cmd = "pnpm.cmd"
    Args = @("dev")
  },
  @{
    Key = "uniapp"
    Name = "学生端 H5 (UniApp Vite)"
    Port = 5174
    Url = "http://127.0.0.1:5174/"
    WorkDir = Join-Path $RepoRoot "frontend-uniapp"
    Cmd = "pnpm.cmd"
    Args = @("dev:h5")
  }
)

function Get-ListeningPid([int]$Port) {
  $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($conn) { return [int]$conn.OwningProcess }
  return $null
}

function Load-SavedPids() {
  if (-not (Test-Path $PidFile)) { return @{} }
  try {
    $raw = Get-Content -Path $PidFile -Raw -Encoding UTF8
    if (-not $raw) { return @{} }
    $obj = $raw | ConvertFrom-Json
    $map = @{}
    foreach ($p in $obj.PSObject.Properties) {
      $map[$p.Name] = [int]$p.Value
    }
    return $map
  } catch {
    return @{}
  }
}

function Save-Pids([hashtable]$Map) {
  New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
  ($Map | ConvertTo-Json) | Set-Content -Path $PidFile -Encoding UTF8
}

function Stop-ProcessTree([int]$ProcessId) {
  try {
    & cmd.exe /c "taskkill /PID $ProcessId /T /F" *> $null
  } catch {
    # ignore already stopped
  }
}

function Show-Status() {
  foreach ($svc in $Services) {
    $listening = Get-ListeningPid $svc.Port
    if ($listening) {
      Write-Host ("[RUNNING] {0} -> 端口 {1} (PID={2}) | {3}" -f $svc.Name, $svc.Port, $listening, $svc.Url)
    } else {
      Write-Host ("[STOPPED] {0} -> 端口 {1}" -f $svc.Name, $svc.Port)
    }
  }
}

function Ensure-JavaHome() {
  $jdk21 = "C:\Program Files\Java\jdk-21"
  if (Test-Path (Join-Path $jdk21 "bin\java.exe")) {
    $env:JAVA_HOME = $jdk21
    $env:Path = (Join-Path $jdk21 "bin") + ";" + $env:Path
  }
}

$Selected = if ($Target -eq "all") { $Services } else { $Services | Where-Object { $_.Key -eq $Target } }

if ($Action -eq "status") {
  Show-Status
  exit 0
}

if ($Action -eq "stop") {
  $saved = Load-SavedPids
  foreach ($svc in $Selected) {
    $stopped = $false
    $listening = Get-ListeningPid $svc.Port
    if ($listening) {
      Stop-ProcessTree $listening
      $stopped = $true
    }
    if ($saved.ContainsKey($svc.Key) -and $saved[$svc.Key]) {
      Stop-ProcessTree $saved[$svc.Key]
      $saved.Remove($svc.Key)
      $stopped = $true
    }
    Write-Host ($(if ($stopped) { "已停止" } else { "未在运行" }) + ": " + $svc.Name)
  }
  Save-Pids $saved
  exit 0
}

# Action = start
Ensure-JavaHome
New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
$savedPids = Load-SavedPids

foreach ($svc in $Selected) {
  if ($svc.Key -eq "backend") {
    $localCfg = Join-Path $svc.WorkDir "application-local.yml"
    if (-not (Test-Path $localCfg)) {
      Write-Warning "缺少 $localCfg，若本机 MySQL 有密码请从 src\main\resources\application-local.yml.example 复制配置。"
    }
  }

  $existing = Get-ListeningPid $svc.Port
  if ($existing) {
    Write-Host ("[SKIP] {0} 已在运行（端口 {1}, PID={2}）" -f $svc.Name, $svc.Port, $existing)
    continue
  }

  $stdoutLog = Join-Path $StateDir ($svc.Key + ".out.log")
  $stderrLog = Join-Path $StateDir ($svc.Key + ".err.log")
  Remove-Item $stdoutLog, $stderrLog -Force -ErrorAction SilentlyContinue

  $cmdPath = if ($svc.Cmd -eq "mvnw.cmd") { Join-Path $svc.WorkDir "mvnw.cmd" } else { $svc.Cmd }
  $argLine = ($svc.Args -join " ")
  $proc = Start-Process -FilePath "cmd.exe" `
    -ArgumentList @("/c", "`"$cmdPath`" $argLine") `
    -WorkingDirectory $svc.WorkDir `
    -RedirectStandardOutput $stdoutLog `
    -RedirectStandardError $stderrLog `
    -WindowStyle Hidden `
    -PassThru

  $savedPids[$svc.Key] = $proc.Id
  Write-Host ("[STARTING] {0} (PID={1})，等待端口 {2} 就绪..." -f $svc.Name, $proc.Id, $svc.Port)
}

Save-Pids $savedPids

# Wait for HTTP / TCP readiness
$deadline = (Get-Date).AddSeconds(90)
$pending = [System.Collections.Generic.HashSet[string]]::new()
foreach ($svc in $Selected) { [void]$pending.Add($svc.Key) }

while ($pending.Count -gt 0 -and (Get-Date) -lt $deadline) {
  foreach ($svc in $Selected) {
    if (-not $pending.Contains($svc.Key)) { continue }
    $listening = Get-ListeningPid $svc.Port
    if ($listening) {
      if ($svc.Key -eq "backend") {
        try {
          $r = Invoke-WebRequest -Uri $svc.Url -UseBasicParsing -TimeoutSec 2
          if ($r.StatusCode -eq 200) { [void]$pending.Remove($svc.Key) }
        } catch {
          # wait until servlet ready
        }
      } else {
        [void]$pending.Remove($svc.Key)
      }
    }
  }
  if ($pending.Count -gt 0) {
    Start-Sleep -Milliseconds 1200
  }
}

Write-Host "--- 本地服务状态 ---"
Show-Status
if ($pending.Count -gt 0) {
  Write-Warning ("以下服务尚未在超时时间内就绪: " + ($pending -join ", ") + "。请检查日志目录: $StateDir")
  exit 1
}
