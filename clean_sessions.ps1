# DSH 会话清理脚本
# 用法: 在 PowerShell 中运行 .\clean_sessions.ps1
# 功能: 列出所有会话，交互式选择要删除的，删除前自动备份

param(
    [string]$SessionsDir = "C:\Users\LENOVO\.dsh\sessions\--D-deepseek-~5DE5~4F5C~533A--",
    [string]$BackupDir = "D:\deepseek\sessions-backup"
)

Write-Host "=== DSH 会话清理工具 ===" -ForegroundColor Cyan
Write-Host "会话目录: $SessionsDir"
Write-Host ""

if (-not (Test-Path $SessionsDir)) {
    Write-Host "目录不存在: $SessionsDir" -ForegroundColor Red
    exit 1
}

# 列出会话
$sessions = Get-ChildItem $SessionsDir -Directory | Sort-Object LastWriteTime -Descending
if ($sessions.Count -eq 0) {
    Write-Host "没有找到会话文件夹。" -ForegroundColor Yellow
    exit 0
}

Write-Host "找到 $($sessions.Count) 个会话：" -ForegroundColor Green
Write-Host ""
$items = @()
for ($i = 0; $i -lt $sessions.Count; $i++) {
    $s = $sessions[$i]
    $size = (Get-ChildItem $s.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    $sizeMB = [math]::Round($size / 1MB, 2)
    $items += [PSCustomObject]@{
        Index = $i + 1
        Name = $s.Name
        SizeMB = $sizeMB
        LastWrite = $s.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
        Path = $s.FullName
    }
    Write-Host ("  [{0,2}] {1,-45} {2,8} MB  {3}" -f ($i+1), $s.Name, $sizeMB, $s.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))
}

Write-Host ""
Write-Host "请输入要删除的会话编号（多个用逗号分隔，如 1,3,5），输入 q 退出：" -ForegroundColor Yellow
$input = Read-Host

if ($input -eq 'q' -or $input -eq 'Q') {
    Write-Host "已取消。" -ForegroundColor Gray
    exit 0
}

$indices = $input -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
$toDelete = @()
foreach ($idx in $indices) {
    if ($idx -ge 1 -and $idx -le $items.Count) {
        $toDelete += $items[$idx - 1]
    } else {
        Write-Host "编号 $idx 无效，跳过。" -ForegroundColor Red
    }
}

if ($toDelete.Count -eq 0) {
    Write-Host "没有有效的删除目标。" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "即将删除以下会话：" -ForegroundColor Red
foreach ($d in $toDelete) {
    Write-Host "  - $($d.Name) ($($d.SizeMB) MB, $($d.LastWrite))" -ForegroundColor Red
}
$confirm = Read-Host "确认删除？(y/N)"
if ($confirm -ne 'y' -and $confirm -ne 'Y') {
    Write-Host "已取消。" -ForegroundColor Gray
    exit 0
}

# 备份
if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}
$backupSub = Join-Path $BackupDir ("backup-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $backupSub -Force | Out-Null

foreach ($d in $toDelete) {
    # 先备份
    $dest = Join-Path $backupSub $d.Name
    Copy-Item -Path $d.Path -Destination $dest -Recurse -Force
    Write-Host "已备份: $($d.Name)" -ForegroundColor Gray
    # 再删除
    Remove-Item -Path $d.Path -Recurse -Force
    Write-Host "已删除: $($d.Name)" -ForegroundColor Green
}

Write-Host ""
Write-Host "完成！备份保存在: $backupSub" -ForegroundColor Cyan
Write-Host "如需恢复，将备份文件夹复制回 sessions 目录即可。" -ForegroundColor Gray
