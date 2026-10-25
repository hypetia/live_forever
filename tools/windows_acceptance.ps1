param(
    [ValidateRange(1,120)][int]$Minutes = 30,
    [string]$OutputDirectory = ""
)
$ErrorActionPreference = "Stop"
$executable = Join-Path $PSScriptRoot "LiveForever.exe"
$acceptanceExecutable = Join-Path $PSScriptRoot "LiveForeverAcceptance.exe"
if (!(Test-Path $executable) -or !(Test-Path $acceptanceExecutable)) { throw "Keep this script beside LiveForever.exe and LiveForeverAcceptance.exe." }
if (!$OutputDirectory) { $OutputDirectory = Join-Path $PSScriptRoot ("AcceptanceResults-" + (Get-Date -Format "yyyyMMdd-HHmmss")) }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
if (Test-Path (Join-Path $OutputDirectory "session.json")) { throw "Use a fresh results directory." }
$slot = Join-Path $OutputDirectory "session.json"
$reportPath = Join-Path $OutputDirectory "desktop-report.json"
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$env:APPDATA = Join-Path $OutputDirectory "profile\Roaming"
$env:LOCALAPPDATA = Join-Path $OutputDirectory "profile\Local"
New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA -Force | Out-Null
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class DesktopInput {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint key, uint mapType);
    [DllImport("user32.dll")] public static extern void keybd_event(byte key, byte scan, uint flags, UIntPtr extra);
    public static void SaveKey() { byte scan=(byte)MapVirtualKey(0x75,0); keybd_event(0x75, scan, 0, UIntPtr.Zero); System.Threading.Thread.Sleep(80); keybd_event(0x75, scan, 2, UIntPtr.Zero); }
}
'@
function Read-ValidatedSave([string]$Path) {
    $envelope = Get-Content -Raw -Encoding UTF8 $Path | ConvertFrom-Json
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $actual = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($envelope.data_json)))).Replace("-", "").ToLowerInvariant() }
    finally { $sha.Dispose() }
    if ($actual -ne $envelope.sha256) { throw "Save checksum failed." }
    return ($envelope.data_json | ConvertFrom-Json)
}
function Close-OwnedGame($Process) {
    $Process.Refresh()
    if (!$Process.CloseMainWindow()) { throw "No native game window accepted WM_CLOSE." }
    if (!$Process.WaitForExit(15000)) { throw "Normal window close exceeded 15 seconds; keep the logs for diagnosis." }
    if ($Process.ExitCode -ne 0) { throw "Game exited with code $($Process.ExitCode)." }
}
$process = $null
try {
    $arguments = '--resolution 1440x900 -- --output "' + $OutputDirectory + '" --minutes ' + $Minutes + ' --trace-exit'
    $process = Start-Process -FilePath $acceptanceExecutable -ArgumentList $arguments -PassThru -RedirectStandardOutput (Join-Path $OutputDirectory "continuous.log") -RedirectStandardError (Join-Path $OutputDirectory "continuous.err.log")
    Write-Host "Checking real Windows display modes and $Minutes minutes of continuous gameplay. Keep this desktop session active."
    $deadline = (Get-Date).AddMinutes($Minutes).AddSeconds(180)
    $report = $null
    $memorySamples = New-Object Collections.ArrayList
    $nextMemorySample = Get-Date
    while ((Get-Date) -lt $deadline) {
        $process.Refresh()
        if ($process.HasExited) { throw "Game exited before acceptance completed." }
        if ((Get-Date) -ge $nextMemorySample) {
            [void]$memorySamples.Add([ordered]@{ timestamp=(Get-Date).ToString("o"); working_set_bytes=$process.WorkingSet64; private_bytes=$process.PrivateMemorySize64 })
            $nextMemorySample = (Get-Date).AddSeconds(10)
        }
        if (Test-Path $reportPath) {
            $report = Get-Content -Raw -Encoding UTF8 $reportPath | ConvertFrom-Json
            if ($report.status -in @("ready_to_close", "failed")) { break }
        }
        Start-Sleep -Seconds 1
    }
    if (!$report -or $report.status -ne "ready_to_close") { throw "Desktop acceptance failed or timed out; inspect desktop-report.json." }
    $before = Read-ValidatedSave $slot
    Close-OwnedGame $process
    $arguments = '--resolution 1440x900 -- --qa-slot="' + $slot + '" --trace-exit'
    $process = Start-Process -FilePath $executable -ArgumentList $arguments -PassThru -RedirectStandardOutput (Join-Path $OutputDirectory "restart.log") -RedirectStandardError (Join-Path $OutputDirectory "restart.err.log")
    for ($index=0; $index -lt 120; $index++) {
        $process.Refresh()
        if ($process.HasExited) { throw "Game exited during restart." }
        if ($process.MainWindowHandle -ne [IntPtr]::Zero) { break }
        Start-Sleep -Milliseconds 500
    }
    if ($process.MainWindowHandle -eq [IntPtr]::Zero) { throw "No restored game window." }
    [DesktopInput]::SetForegroundWindow($process.MainWindowHandle) | Out-Null
    Start-Sleep -Seconds 2
    $previousWrite = (Get-Item $slot).LastWriteTimeUtc.Ticks
    [DesktopInput]::SaveKey()
    Start-Sleep -Seconds 1
    if ((Get-Item $slot).LastWriteTimeUtc.Ticks -le $previousWrite) { throw "Actual F6 did not write a new save; input/focus verification failed." }
    $after = Read-ValidatedSave $slot
    if (!$after.paused -or [Math]::Abs($after.simulation_time - $before.simulation_time) -gt 0.000001) { throw "Restart did not preserve paused simulation time." }
    foreach ($field in @("stock", "goals", "story")) {
        if (($before.$field | ConvertTo-Json -Depth 30 -Compress) -ne ($after.$field | ConvertTo-Json -Depth 30 -Compress)) { throw "Restart changed $field or repeated a reward." }
    }
    Close-OwnedGame $process
    foreach ($name in @("continuous.log", "continuous.err.log", "restart.log", "restart.err.log")) {
        if ((Get-Content -Raw -Encoding UTF8 (Join-Path $OutputDirectory $name)) -match 'SCRIPT ERROR:|ERROR:|instances leaked') { throw "Runtime errors in $name." }
    }
    $operatingSystemInfo = [Environment]::OSVersion.VersionString
    $graphicsInfo = @()
    try { $operatingSystemInfo = Get-CimInstance Win32_OperatingSystem | Select-Object -Property @("Caption", "Version", "OSArchitecture") } catch { $operatingSystemInfo = "WMI unavailable: " + $operatingSystemInfo }
    try { $graphicsInfo = @(Get-CimInstance Win32_VideoController | Select-Object -Property @("Name", "DriverVersion")) } catch { $graphicsInfo = @("Driver metadata unavailable") }
    $result = [ordered]@{
        platform = "Windows"; tested_on = (Get-Date).ToString("o"); requested_minutes = $Minutes;
        elapsed_seconds = $report.elapsed_seconds; checks = $report.checks; resolutions = $report.resolutions;
        native_close_and_restart = "passed"; continuous_30_minutes_complete = ($report.elapsed_seconds -ge 1800);
        executable_sha256 = (Get-FileHash -Algorithm SHA256 $executable).Hash.ToLowerInvariant();
        acceptance_binary_sha256 = (Get-FileHash -Algorithm SHA256 $acceptanceExecutable).Hash.ToLowerInvariant();
        operating_system = $operatingSystemInfo;
        graphics = $graphicsInfo;
        process_memory_samples = @($memorySamples);
        sound = "Default Windows audio driver used; audibility requires the manual checklist."
    }
    $result | ConvertTo-Json -Depth 30 | Set-Content -Encoding UTF8 (Join-Path $OutputDirectory "acceptance-result.json")
    Write-Host "PASS. Results: $OutputDirectory"
    Write-Host "Complete the short visual/audio checklist in WINDOWS_ACCEPTANCE.md before marking manual acceptance complete."
} finally {
    if ($process) { $process.Refresh(); if (!$process.HasExited) { $process.Kill(); $process.WaitForExit() } }
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
