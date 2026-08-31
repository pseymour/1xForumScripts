<# : batch script
@echo off
PowerShell.exe -NoProfile Invoke-Expression ([System.IO.File]::ReadAllText('%0'))
goto :eof
#>

Set-StrictMode -Version 'latest'

$InformationPreference = [Management.Automation.ActionPreference]::Continue

[string]$outputFilePath = (Join-Path ([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::DesktopDirectory)) "ChkDisk report $(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt")

[string]$filterXml = @"
<QueryList>
  <Query Id="0" Path="Application">
    <Select Path="Application">*[System[Provider[@Name='Microsoft-Windows-Wininit']]]</Select>
    <Select Path="Application">*[System[Provider[@Name='Chkdsk']]]</Select>
  </Query>
</QueryList>
"@

Get-WinEvent -FilterXml $filterXml | Sort-Object -Property @('TimeCreated') |
Format-List -Property @('ProviderName', 'TimeCreated', 'Message') |
Out-File -Width 400 -FilePath $outputFilePath

1..5 | ForEach-Object { Write-Information ([string]::Empty) }
Write-Information "The ChkDsk events have been gathered into a .txt file on your desktop,"
Write-Information "$($outputFilePath)."
Write-Information "Please upload the file as an attachment to your post on the forum."

pause