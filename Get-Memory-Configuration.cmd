<# : batch script
@echo off
PowerShell.exe -NoProfile Invoke-Expression ([System.IO.File]::ReadAllText('%0'))
goto :eof
#>

[CmdletBinding(SupportsShouldProcess=$false)]
Param()

Set-StrictMode -Version 'latest'

$InformationPreference = [Management.Automation.ActionPreference]::Continue

[string]$outputFilePath = (Join-Path ([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::DesktopDirectory)) "memory configuration report $(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt")

Write-Output "Memory Modules:" | Out-File -FilePath $outputFilePath

$PhysicalMemory = @(Get-CimInstance -ClassName 'Win32_PhysicalMemory')
$PhysicalMemory |
Format-Table -AutoSize -Property @('Tag', 'BankLabel' , @{ Name = "Capacity (GB)"; Expression = { $_.Capacity / 1GB} }, 'Manufacturer', 'PartNumber', 'Speed') |
Out-File -FilePath $outputFilePath -Append

Write-Output "Total Memory: $(($PhysicalMemory | Measure-Object -Property 'Capacity' -Sum).Sum / 1GB) GB" |
Out-File -FilePath $outputFilePath -Append

[double]$totalMemorySlots = (Get-CimInstance -ClassName 'Win32_PhysicalMemoryArray' -Property @('MemoryDevices') | Measure-Object -Property @('MemoryDevices') -Sum).Sum

Write-Output ("Memory Slots: {0:N0} used of {1:N0} total" -f $PhysicalMemory.Count, $totalMemorySlots) |
Out-File -FilePath $outputFilePath -Append

if ($PhysicalMemory.Count -eq $totalMemorySlots)
{
    Write-Output "All memory slots have been filled. None is empty!" | Out-File -FilePath $outputFilePath -Append
}

1..5 | ForEach-Object { Write-Information ([string]::Empty) }
Write-Information "The memory configuration has been gathered into a .txt file on your desktop,"
Write-Information "$($outputFilePath)."
Write-Information "Please upload the file as an attachment to your post on the forum."

pause