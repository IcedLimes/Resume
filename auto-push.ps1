$repo = $PSScriptRoot
$debounceSeconds = 5
$logFile = Join-Path $repo 'auto-push.log'

Set-Location $repo

function Write-Log($msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

Write-Log "Watching $repo for changes (debounce: ${debounceSeconds}s). Ctrl+C to stop."

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $repo
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true
$watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor `
                       [System.IO.NotifyFilters]::FileName -bor `
                       [System.IO.NotifyFilters]::DirectoryName

$script:lastChange = $null
$action = {
    $path = $Event.SourceEventArgs.FullPath
    if ($path -match '\\\.git\\' -or $path -match '\\auto-push\.log$') { return }
    $script:lastChange = Get-Date
}

Register-ObjectEvent $watcher Changed -Action $action | Out-Null
Register-ObjectEvent $watcher Created -Action $action | Out-Null
Register-ObjectEvent $watcher Deleted -Action $action | Out-Null
Register-ObjectEvent $watcher Renamed -Action $action | Out-Null

try {
    while ($true) {
        Start-Sleep -Seconds 1
        if ($null -ne $script:lastChange) {
            $idle = (Get-Date) - $script:lastChange
            if ($idle.TotalSeconds -ge $debounceSeconds) {
                $script:lastChange = $null
                $status = git status --porcelain
                if ([string]::IsNullOrWhiteSpace($status)) { continue }

                Write-Log "Changes detected, committing..."
                git add -A
                $msg = "auto: {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
                git commit -m $msg | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-Log "Commit failed (exit $LASTEXITCODE). Skipping push."
                    continue
                }
                Write-Log "Pushing to origin..."
                git push origin HEAD 2>&1 | ForEach-Object { Write-Log "  $_" }
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Push complete."
                } else {
                    Write-Log "Push failed (exit $LASTEXITCODE)."
                }
            }
        }
    }
} finally {
    Get-EventSubscriber | Unregister-Event
    $watcher.Dispose()
    Write-Log "Watcher stopped."
}
