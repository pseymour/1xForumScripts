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
    [string]$kernelReportsFolderPath = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)) 'LiveKernelReports'
    if (-not (Test-Path -Path $kernelReportsFolderPath))
    {
        Write-Warning "`"$($kernelReportsFolderPath)`" does not exist."
    }
    else
    {
        if (0 -ge @(Get-ChildItem -Path $kernelReportsFolderPath -Filter '*.dmp' -File -Recurse -Force -ErrorAction SilentlyContinue).Count)
        {
            Write-Information "`"$($kernelReportsFolderPath)`" contains no .dmp files."
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

            # NOTE: The original batch script removed old "LiveKernel Reports*.zip" files from the user's desktop.
            # We're not doing that here, in order to let the user decide if and when they want those files deleted.

            [string]$logFilePath = Join-Path -Path $temporaryFolderPath -ChildPath "dump_file_log.txt"
            if (Test-Path -Path $logFilePath) { Remove-Item -Path $logFilePath -ErrorAction SilentlyContinue }

            # Display all of the .dmp files on the screen, and log them to the log file.
            Get-ChildItem -Path $kernelReportsFolderPath -Recurse -Force -Filter '*.dmp' -File |
            Format-Table -AutoSize -Property @(@{Name = 'Relative Path'; Expr = {($_.FullName.ToLowerInvariant() -split '\\' | Select-Object -Skip 3) -join '\'}}, @{ Name = 'Size (MB)'; Expression = {[Math]::Round(($_.Length/1MB),2)} }, @{Name = 'Creation Time'; Expression = {$_.CreationTime}; Format = 'u'}, @{Name = 'Age'; Expr = {(Get-Date).Subtract($_.CreationTime).TotalDays}; Format = 'N2'}) |
            Out-String |
            Tee-Object -FilePath $logFilePath

            [bool]$dumpFilesFound = $false
            for ([int]$maxAge = 30; ($maxAge -le 90) -and (-not $dumpFilesFound); $maxAge += 30)
            { # Keep looking for dump files younger than $maxAge. When you find some, break out.

                ## TODO: Remove this line for production.
                Write-Host "$($maxAge) days." -ForegroundColor Cyan

                Get-ChildItem -Path $kernelReportsFolderPath -Recurse -Force -Filter '*.dmp' -File |
                Where-Object { ((Get-Date).Subtract($_.CreationTime).TotalDays -le $maxAge) -and ($_.Length -le (1.5 * 1GB)) } |
                ForEach-Object {
                    $dumpFilesFound = $true
                    [string]$sourcePath = $_.FullName
                    [string]$destinationPath = Join-Path $temporaryFolderPath ($sourcePath.Substring([IO.Path]::GetPathRoot($sourcePath).Length))
                    $destinationPathParent = Split-Path -Path $destinationPath -Parent
                    if (-not (Test-Path -Path $destinationPathParent)) { New-Item -Path $destinationPathParent -ItemType 'Directory' | Out-Null }
                    Copy-Item -Path $sourcePath -Destination $destinationPath -Force -Recurse
                }
            }

            # If there are .dmp files in the temporary folder, create a .zip archive of those files.
            if (0 -lt @(Get-ChildItem -Path $temporaryFolderPath -Recurse -Force -Filter '*.dmp' -File).Count)
            {
                [string]$zipFilePath = "live_kernel_reports_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').zip"
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

                Write-Information "The .dmp files have been gathered into a .zip file on your desktop,"
                Write-Information "$($zipFilePath)."
                Write-Information "Please upload the file as an attachment to your post on the forum."
            }

            Remove-Item -Path $temporaryFolderPath -Recurse -Force
        }
    }
}

pause