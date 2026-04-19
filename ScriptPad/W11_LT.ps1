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
# [PostOS] Staging Rename + JumpCloud scripts for SetupComplete
#==================================================================
Write-Host -ForegroundColor Green "Staging SetupComplete scripts"

$SetupScriptsPath = "C:\Windows\Setup\Scripts"
if (!(Test-Path $SetupScriptsPath)) {
    New-Item $SetupScriptsPath -ItemType Directory -Force | Out-Null
}

# ----- Rename script (hostname: O-LT-<serial>, max 15 chars NetBIOS) -----
$RenameScriptContent = @'
#Requires -RunAsAdministrator
try {
    $serial = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber.Trim()
    # NetBIOS cap is 15 chars. "O-LT-" = 5, leaves 10 for serial.
    if ($serial.Length -gt 10) { $serial = $serial.Substring(0, 10) }
    if (-not [string]::IsNullOrWhiteSpace($serial)) {
        $newHostname = "O-LT-$serial"
        Rename-Computer -NewName $newHostname -Force -ErrorAction Stop
    }
} catch {
    "$_" | Out-File -FilePath C:\Windows\Temp\Rename-Computer-Error.log -Encoding utf8 -Append
}
'@
$RenameScriptContent | Out-File -FilePath "$SetupScriptsPath\RenamePC.ps1" -Encoding utf8 -Force

# ----- JumpCloud agent install -----
$JumpCloudScriptContent = @'
#Requires -RunAsAdministrator
$LogPath = "C:\Windows\Temp\JumpCloud-Install.log"
try {
    "$(Get-Date) - Downloading JumpCloud installer" | Out-File -FilePath $LogPath -Encoding ascii -Append
    $installer = 'C:\Windows\Temp\JumpCloudInstaller.exe'
    Invoke-WebRequest -Uri 'https://cdn02.jumpcloud.com/production/JumpCloudInstaller.exe' `
                      -OutFile $installer -UseBasicParsing

    $ConnectKey = 'jcc_eyJwdWJsaWNLaWNrc3RhcnRVcmwiOiJodHRwczovL2tpY2tzdGFydC5qdW1wY2xvdWQuY29tIiwicHJpdmF0ZUtpY2tzdGFydFVybCI6Imh0dHBzOi8vcHJpdmF0ZS1raWNrc3RhcnQuanVtcGNsb3VkLmNvbSIsImNvbm5lY3RLZXkiOiI4ZTlmNmY1OWQ4ZjEzZDQyMDc2OTZlYTI3Njk0YWUyMGY1ODkzMDBlIn0g'

    Start-Process -FilePath $installer `
        -ArgumentList "-k $ConnectKey /VERYSILENT /NORESTART /SUPPRESSMSGBOXES /NOCLOSEAPPLICATIONS" `
        -Wait -NoNewWindow
    "$(Get-Date) - JumpCloud installer finished" | Out-File -FilePath $LogPath -Encoding ascii -Append
} catch {
    "$(Get-Date) - JumpCloud install error: $_" | Out-File -FilePath $LogPath -Encoding ascii -Append
}
'@
$JumpCloudScriptContent | Out-File -FilePath "$SetupScriptsPath\Install-JumpCloud.ps1" -Encoding utf8 -Force

# ----- SetupComplete.cmd - runs both scripts at end of Specialize -----
$SetupCompleteCmdContent = @'
@echo off
powershell.exe -ExecutionPolicy Bypass -NoProfile -File C:\Windows\Setup\Scripts\RenamePC.ps1
powershell.exe -ExecutionPolicy Bypass -NoProfile -File C:\Windows\Setup\Scripts\Install-JumpCloud.ps1
'@
$SetupCompleteCmdContent | Out-File -FilePath "$SetupScriptsPath\SetupComplete.cmd" -Encoding ascii -Force

Write-Host "RenamePC.ps1, Install-JumpCloud.ps1, SetupComplete.cmd staged." -ForegroundColor Green

#================================================
# [PostOS] OOBE CMD Command Line
#================================================
Write-Host -ForegroundColor Green "Staging OOBE-phase global settings"
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
