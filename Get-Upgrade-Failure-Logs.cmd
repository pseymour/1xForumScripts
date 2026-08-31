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

    # Gather specific files and folders into the temporary logging folder.
    @(
    (Join-Path ($env:SystemDrive) '$Windows.~BT\Sources\Rollback'),
    (Join-Path ($env:SystemDrive) '$Windows.~BT\Sources\Panther'),
    (Join-Path ($env:SystemDrive) '$Windows.~WS\Sources\Panther\setupact.log'),
    (Join-Path ($env:SystemDrive) '$Windows.~WS\Sources\Panther\setuperr.log'),
    (Join-Path ($env:SystemRoot) 'Logs\MoSetup'),
    (Join-Path ($env:SystemRoot) 'Panther\UnattendGC'),
    (Join-Path ($env:SystemRoot) 'Panther\NewOS'),
    (Join-Path ($env:SystemRoot) 'Panther\setupact.log'),
    (Join-Path ($env:SystemRoot) 'Panther\setuperr.log'),
    (Join-Path ($env:SystemRoot) 'setupapi.log'),
    (Join-Path ($env:SystemRoot) 'inf\setupapi.dev.log')
    ) |
    ForEach-Object {
        [string]$sourcePath = $_
        if (Test-Path -Path $sourcePath)
        {
            Write-Information "Gathering $($sourcePath)..."
            [string]$destinationPath = Join-Path $temporaryFolderPath ($sourcePath.Substring([IO.Path]::GetPathRoot($sourcePath).Length))
            $destinationPathParent = Split-Path -Path $destinationPath -Parent
            if (-not (Test-Path -Path $destinationPathParent)) { New-Item -Path $destinationPathParent -ItemType 'Directory' | Out-Null }
            Copy-Item -Path $sourcePath -Destination $destinationPath -Force -Recurse
        }
        else
        {
            Write-Information "`"$($sourcePath)`" does not exist."
        }
    }

    [string]$zipFilePath = "upgrade_failure_logs_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').zip"
    [System.IO.Path]::GetInvalidFileNameChars() | ForEach-Object { $zipFilePath = $zipFilePath -replace "\$($_)", [string]::Empty }
    $zipFilePath = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)) $zipFilePath

    1..2 | ForEach-Object { Write-Information ([string]::Empty) } # Write some empty lines, just for spacing.
    Write-Information "Compressing gathered files into a .zip archive..."
    Get-ChildItem -Path $temporaryFolderPath -Directory |
    ForEach-Object {
        Compress-Archive -Path ($_.FullName) -Update -DestinationPath $zipFilePath
        Start-Sleep -Seconds 1
        Remove-Item -Path $_.FullName -Recurse -Force
    }

    1..5 | ForEach-Object { Write-Information ([string]::Empty) } # Write some empty lines, just for spacing.
    Write-Information "The log files have been gathered into a .zip file on your desktop,"
    Write-Information "$($zipFilePath)."
    Write-Information "Please upload the file as an attachment to your post on the forum."

    Remove-Item -Path $temporaryFolderPath -Recurse -Force
}

pause