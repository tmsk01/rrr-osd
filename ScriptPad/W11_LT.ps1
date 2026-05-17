#================================================
# [PreOS] Update Module
#================================================
if ((Get-MyComputerModel) -match 'Virtual') {
    Write-Host -ForegroundColor Green "Setting Display Resolution to 1600x"
    Set-DisRes 1600
}
Write-Host -ForegroundColor Green "Updating OSD PowerShell Module"
Install-Module OSD -Force
Write-Host -ForegroundColor Green "Importing OSD PowerShell Module"
Import-Module OSD -Force

#================================================
# [OS] Params and Start-OSDCloud
#================================================
$Params = @{
    OSVersion  = "Windows 11"
    OSBuild    = "24H2"
    OSEdition  = "Pro"
    OSLanguage = "en-us"
    OSLicense  = "Retail"
    ZTI        = $true
    Firmware   = $true
}
Start-OSDCloud @Params

#================================================
# [PostOS] OOBEDeploy Configuration
#================================================
Write-Host -ForegroundColor Green "Creating OOBEDeploy JSON config"
$OOBEDeployJson = @'
{
    "AddNetFX3": { "IsPresent": true },
    "Autopilot": { "IsPresent": false },
    "RemoveAppx": [
        "MicrosoftTeams", "Microsoft.BingWeather", "Microsoft.BingNews", "Microsoft.GamingApp",
        "Microsoft.GetHelp", "Microsoft.Getstarted", "Microsoft.Messaging", "Microsoft.MicrosoftOfficeHub",
        "Microsoft.MicrosoftSolitaireCollection", "Microsoft.MicrosoftStickyNotes", "Microsoft.MSPaint",
        "Microsoft.People", "Microsoft.PowerAutomateDesktop", "Microsoft.StorePurchaseApp", "Microsoft.Todos",
        "microsoft.windowscommunicationsapps", "Microsoft.WindowsFeedbackHub", "Microsoft.WindowsMaps",
        "Microsoft.WindowsSoundRecorder", "Microsoft.Xbox.TCUI", "Microsoft.XboxGameOverlay",
        "Microsoft.XboxGamingOverlay", "Microsoft.XboxIdentityProvider", "Microsoft.XboxSpeechToTextOverlay",
        "Microsoft.YourPhone", "Microsoft.ZuneMusic", "Microsoft.ZuneVideo"
    ],
    "UpdateDrivers": { "IsPresent": true },
    "UpdateWindows": { "IsPresent": true }
}
'@
If (!(Test-Path "C:\ProgramData\OSDeploy")) {
    New-Item "C:\ProgramData\OSDeploy" -ItemType Directory -Force | Out-Null
}
$OOBEDeployJson | Out-File -FilePath "C:\ProgramData\OSDeploy\OSDeploy.OOBEDeploy.json" -Encoding utf8 -Force

#==================================================================
# [PostOS] Stage SetupComplete: rename + JumpCloud RunOnce + Debloat RunOnce
#==================================================================
Write-Host -ForegroundColor Green "Staging SetupComplete scripts"

$SetupScriptsPath = "C:\Windows\Setup\Scripts"
if (!(Test-Path $SetupScriptsPath)) {
    New-Item $SetupScriptsPath -ItemType Directory -Force | Out-Null
}

$SetupCompleteScript = @'
#Requires -RunAsAdministrator
$LogPath = "C:\Windows\Temp\SetupComplete.log"
"$(Get-Date) - SetupComplete script starting" | Out-File -FilePath $LogPath -Encoding ascii -Append

try {
    $serial = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber.Trim().ToUpper()
    if ($serial.Length -gt 10) { $serial = $serial.Substring(0, 10) }
    if (-not [string]::IsNullOrWhiteSpace($serial)) {
        $newHostname = "O-LT-$serial"
        Rename-Computer -NewName $newHostname -Force -ErrorAction Stop
        "$(Get-Date) - Renamed to $newHostname" | Out-File -FilePath $LogPath -Encoding ascii -Append
    }
} catch {
    "$(Get-Date) - Rename error: $_" | Out-File -FilePath $LogPath -Encoding ascii -Append
}

try {
    $RunOnce = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
    if (!(Test-Path $RunOnce)) { New-Item -Path $RunOnce -Force | Out-Null }
    $JCCmd = 'powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File "C:\Windows\Setup\Scripts\Install-JumpCloud.ps1"'
    Set-ItemProperty -Path $RunOnce -Name '!1InstallJumpCloud' -Value $JCCmd -Type String -Force
    "$(Get-Date) - RunOnce staged for JumpCloud install" | Out-File -FilePath $LogPath -Encoding ascii -Append

    $DebloatCmd = 'powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File "C:\Windows\Setup\Scripts\Run-Debloat.ps1"'
    Set-ItemProperty -Path $RunOnce -Name '!2RunDebloat' -Value $DebloatCmd -Type String -Force
    "$(Get-Date) - RunOnce staged for Debloat" | Out-File -FilePath $LogPath -Encoding ascii -Append
} catch {
    "$(Get-Date) - RunOnce setup error: $_" | Out-File -FilePath $LogPath -Encoding ascii -Append
}

"$(Get-Date) - SetupComplete finished" | Out-File -FilePath $LogPath -Encoding ascii -Append
'@
$SetupCompleteScript | Out-File -FilePath "$SetupScriptsPath\SetupComplete-Custom.ps1" -Encoding ascii -Force

$JumpCloudScript = @'
#Requires -RunAsAdministrator
$LogPath = "C:\Windows\Temp\JumpCloud-Install.log"
"$(Get-Date) - JumpCloud install starting" | Out-File -FilePath $LogPath -Encoding ascii -Append
try {
    cd $env:temp
    Invoke-RestMethod -Method Get `
        -URI https://raw.githubusercontent.com/TheJumpCloud/support/master/scripts/windows/InstallWindowsAgent.ps1 `
        -OutFile InstallWindowsAgent.ps1
    ./InstallWindowsAgent.ps1 -JumpCloudConnectKey "jcc_eyJwdWJsaWNLaWNrc3RhcnRVcmwiOiJodHRwczovL2tpY2tzdGFydC5qdW1wY2xvdWQuY29tIiwicHJpdmF0ZUtpY2tzdGFydFVybCI6Imh0dHBzOi8vcHJpdmF0ZS1raWNrc3RhcnQuanVtcGNsb3VkLmNvbSIsImNvbm5lY3RLZXkiOiI4ZTlmNmY1OWQ4ZjEzZDQyMDc2OTZlYTI3Njk0YWUyMGY1ODkzMDBlIn0g" 2>&1 | Out-File -FilePath $LogPath -Encoding ascii -Append
    "$(Get-Date) - JumpCloud install finished" | Out-File -FilePath $LogPath -Encoding ascii -Append
} catch {
    "$(Get-Date) - JumpCloud install error: $_" | Out-File -FilePath $LogPath -Encoding ascii -Append
}
'@
$JumpCloudScript | Out-File -FilePath "$SetupScriptsPath\Install-JumpCloud.ps1" -Encoding ascii -Force

$RunDebloatScript = @'
#Requires -RunAsAdministrator
$LogPath = "C:\Windows\Temp\Run-Debloat.log"
"$(Get-Date) - Run-Debloat wrapper starting" | Out-File -FilePath $LogPath -Encoding ascii -Append
try {
    $debloat = "$env:TEMP\Debloat.ps1"
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/tmsk01/rrr-osd/main/Debloat.ps1' `
                      -OutFile $debloat -UseBasicParsing
    & powershell.exe -ExecutionPolicy Bypass -NoProfile -File $debloat 2>&1 | Out-File -FilePath $LogPath -Encoding ascii -Append
    "$(Get-Date) - Debloat finished" | Out-File -FilePath $LogPath -Encoding ascii -Append
} catch {
    "$(Get-Date) - Wrapper error: $_" | Out-File -FilePath $LogPath -Encoding ascii -Append
}
'@
$RunDebloatScript | Out-File -FilePath "$SetupScriptsPath\Run-Debloat.ps1" -Encoding ascii -Force

$SetupCompleteCmd = @'
@echo off
powershell.exe -ExecutionPolicy Bypass -NoProfile -File C:\Windows\Setup\Scripts\SetupComplete-Custom.ps1
'@
$SetupCompleteCmd | Out-File -FilePath "$SetupScriptsPath\SetupComplete.cmd" -Encoding ascii -Force

Write-Host -ForegroundColor Green "SetupComplete scripts staged."

#================================================
# [PostOS] OOBE CMD Command Line (language only - debloat moved to RunOnce)
#================================================
Write-Host -ForegroundColor Green "Staging OOBE-phase scripts"
Invoke-RestMethod https://raw.githubusercontent.com/tmsk01/rrr-osd/main/Set-GlobalSettings.ps1 | Out-File -FilePath 'C:\Windows\Setup\scripts\global.ps1' -Encoding ascii -Force

$OOBECMD = @'
@echo off
start /wait powershell.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\global.ps1
exit
'@
$OOBECMD | Out-File -FilePath 'C:\Windows\Setup\scripts\oobe.cmd' -Encoding ascii -Force

#================================================
# Restart-Computer
#================================================
Write-Host -ForegroundColor Green "Restarting in 10 seconds!"
Start-Sleep -Seconds 10
wpeutil reboot
