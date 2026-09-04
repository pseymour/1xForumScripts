<# : batch script
@echo off
PowerShell.exe -NoProfile Invoke-Expression ([System.IO.File]::ReadAllText('%0'))
goto :eof
#>

[CmdletBinding(SupportsShouldProcess=$false)]
Param()

Set-StrictMode -Version 'latest'

function Test-RunningAsAdmin
{
    [System.Security.Principal.WindowsIdentity]$currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    [System.Security.Principal.WindowsPrincipal]$currentPrincipal = [System.Security.Principal.WindowsPrincipal]::new($currentIdentity)

    Write-Output ($currentPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator))
}

$InformationPreference = [Management.Automation.ActionPreference]::Continue

if (-not (Test-RunningAsAdmin))
{
    Write-Warning 'This script requires administrator privileges! Please restart it by running it as an administrator.'
}
else
{
    [string]$temporaryFolderPath = [string]::Empty

    do
    {
        $temporaryFolderPath = [IO.Path]::GetTempFileName()
        if (Test-Path $temporaryFolderPath) { Remove-Item -Path $temporaryFolderPath -Recurse -Force }
    } while ((-not ([string]::IsNullOrEmpty($temporaryFolderPath))) -and (Test-Path -Path $temporaryFolderPath))

    # Create the temporary folder if it does not exist.
    if (-not (Test-Path -Path $temporaryFolderPath)) { New-Item -Path $temporaryFolderPath -ItemType 'Directory' | Out-Null }

    # Clear any existing contents of the temporary folder.
    Get-ChildItem -Path $temporaryFolderPath -Force | Remove-Item -Recurse -Force

    [string]$logFilePath = Join-Path -Path $temporaryFolderPath -ChildPath 'powercfg-info.txt'
    if (Test-Path -Path $logFilePath) { Remove-Item -Path $logFilePath -ErrorAction SilentlyContinue }

    [string]$powercfgPath = Join-Path ([System.Environment]::SystemDirectory) 'powercfg.exe'

    [System.Diagnostics.ProcessStartInfo]$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $powercfgPath
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    if (Test-Path -Path $powercfgPath)
    {
        [string]$energyReportPath = Join-Path -Path $temporaryFolderPath -ChildPath 'energy-report.html'
        [string]$batteryReportPath = Join-Path -Path $temporaryFolderPath -ChildPath 'battery-report.html'
        [string]$sleepStudyReportPath = Join-Path -Path $temporaryFolderPath -ChildPath 'sleepstudy-report.html'
        ## [string]$sleepDiagnosticsReportPath = Join-Path -Path $temporaryFolderPath -ChildPath 'sleep-diagnostics-report.html'
        ## [string]$systemPowerReportPath = Join-Path -Path $temporaryFolderPath -ChildPath 'system-power-report.html'

        @('/list',
          '/availablesleepstates',
          '/lastwake',
          '/devicequery wake_armed',
          '/waketimers',
          '/requests',
          "/energy /output `"$($energyReportPath)`" /duration 10",
          "/batteryreport /output `"$($batteryReportPath)`"",
          "/sleepstudy /output `"$($sleepStudyReportPath)`""
          ## "/systemsleepdiagnostics /output `"$($sleepDiagnosticsReportPath)`"", # Command is deprecated.
          ## "/systempowerreport /output `"$($systemPowerReportPath)`"" # Generates the same report as /sleepstudy.
         ) |
        ForEach-Object {
            Write-Output "Running PowerCfg $($_)" | Tee-Object -FilePath $logFilePath -Append

            $startInfo.Arguments = @($_)

            [System.Diagnostics.Process]$dsRegCmdProcess = [System.Diagnostics.Process]::new()
            $dsRegCmdProcess.StartInfo = $startInfo
            $dsRegCmdProcess.Start() | Out-Null

            Write-Output $dsRegCmdProcess.StandardOutput.ReadToEnd() | Out-String | Tee-Object -FilePath $logFilePath -Append
        }
    }
    else
    {
        Write-Warning "$($powercfgPath) does not exist!"
    }

    [string]$zipFilePath = "powercfg_info_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').zip"
    [System.IO.Path]::GetInvalidFileNameChars() | ForEach-Object { $zipFilePath = $zipFilePath -replace "\$($_)", [string]::Empty }
    $zipFilePath = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)) $zipFilePath

    1..2 | ForEach-Object { Write-Information ([string]::Empty) } # Write some empty lines, just for spacing.
    Write-Information "Compressing gathered files into a .zip archive..."
    Get-ChildItem -Path $temporaryFolderPath |
    ForEach-Object {
        Compress-Archive -Path ($_.FullName) -Update -DestinationPath $zipFilePath
        Start-Sleep -Seconds 1
        Remove-Item -Path $_.FullName -Recurse -Force
    }

    1..5 | ForEach-Object { Write-Information ([string]::Empty) } # Write some empty lines, just for spacing.
    Write-Information "The PowerCfg report files have been gathered into a .zip file on your desktop,"
    Write-Information "$($zipFilePath)."
    Write-Information "Please upload the file as an attachment to your post on the forum."

    Remove-Item -Path $temporaryFolderPath -Recurse -Force
}

pause