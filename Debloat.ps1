$LogPath = "C:\Windows\Temp\RRR-Debloat.log"
function Log($msg) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg" | Out-File -FilePath $LogPath -Encoding ascii -Append
}

function Set-Reg {
    param($Path, $Name, $Value, $Type = 'DWord')
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force -ErrorAction Stop | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
        Log "  OK: $Path\$Name = $Value"
    } catch {
        Log "  FAIL: $Path\$Name : $_"
    }
}

Log "=========================================="
Log "Brute-Force Debloat starting"
Log "Machine: $env:COMPUTERNAME | Running as: $env:USERNAME"
Log "=========================================="

Log "=== HKLM: Copilot, Recall, AI ==="
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'AllowRecallEnablement' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableClickToDo' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'AllowImageCreator' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'AllowCocreator' 0

Log "=== HKLM: Widgets ==="
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0

Log "=== HKLM: Telemetry ==="
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'MaxTelemetryAllowed' 1
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy' 1

Log "=== HKLM: Cortana / Bing Web Search ==="
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCortana' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'DisableWebSearch' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'ConnectedSearchUseWeb' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowSearchToUseLocation' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'EnableDynamicContentInWSB' 0

Log "=== HKLM: Edge AI ==="
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'HubsSidebarEnabled' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'CopilotPageContext' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'EdgeShoppingAssistantEnabled' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'ShowRecommendationsEnabled' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'PersonalizationReportingEnabled' 0

Log "=== HKLM: Consumer Features ==="
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableConsumerAccountStateContent' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableCloudOptimizedContent' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableSoftLanding' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsSpotlightFeatures' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsSpotlightOnActionCenter' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsSpotlightWindowsWelcomeExperience' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableThirdPartySuggestions' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableTailoredExperiencesWithDiagnosticData' 1

Log "=== HKLM: Delivery Optimization ==="
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 0

Log "=== HKLM: Fast Startup ==="
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 0

Log "=== Removing Appx packages ==="
$appsToKill = @(
    'MicrosoftTeams','Microsoft.BingWeather','Microsoft.BingNews','Microsoft.BingSearch',
    'Microsoft.GamingApp','Microsoft.GetHelp','Microsoft.Getstarted','Microsoft.Messaging',
    'Microsoft.MicrosoftOfficeHub','Microsoft.MicrosoftSolitaireCollection','Microsoft.MicrosoftStickyNotes',
    'Microsoft.MSPaint','Microsoft.Paint','Microsoft.People','Microsoft.PowerAutomateDesktop',
    'Microsoft.Todos','microsoft.windowscommunicationsapps','Microsoft.WindowsFeedbackHub',
    'Microsoft.WindowsMaps','Microsoft.WindowsSoundRecorder','Microsoft.Xbox.TCUI',
    'Microsoft.XboxGameOverlay','Microsoft.XboxGamingOverlay','Microsoft.XboxIdentityProvider',
    'Microsoft.XboxSpeechToTextOverlay','Microsoft.YourPhone','Microsoft.ZuneMusic',
    'Microsoft.ZuneVideo','Microsoft.Copilot','Microsoft.OutlookForWindows',
    'Microsoft.WindowsAlarms','Microsoft.WindowsCamera','Microsoft.MixedReality.Portal',
    'Microsoft.SkypeApp','MicrosoftCorporationII.QuickAssist','Clipchamp.Clipchamp',
    'SpotifyAB.SpotifyMusic','Disney.37853FC22B2CE','Microsoft.549981C3F5F10'
)

foreach ($app in $appsToKill) {
    try {
        $found = Get-AppxPackage -AllUsers -Name $app -ErrorAction SilentlyContinue
        if ($found) {
            $found | ForEach-Object {
                Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue
                Log "  Removed AppxPackage: $($_.Name)"
            }
        }
    } catch { Log "  Failed AppxPackage $app : $_" }

    try {
        $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object DisplayName -eq $app
        if ($prov) {
            $prov | ForEach-Object {
                Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
                Log "  Removed ProvisionedPackage: $($_.DisplayName)"
            }
        }
    } catch { Log "  Failed Provisioned $app : $_" }
}

Log "=== HKCU changes ==="
$userHiveChanges = @(
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'SearchboxTaskbarMode'; Value = 0 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'BingSearchEnabled'; Value = 0 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'CortanaConsent'; Value = 0 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'IsDynamicSearchBoxEnabled'; Value = 0 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarDa'; Value = 0 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarMn'; Value = 0 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowTaskViewButton'; Value = 0 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Hidden'; Value = 1 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'HideFileExt'; Value = 0 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowSuperHidden'; Value = 1 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_IrisRecommendations'; Value = 0 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_AccountNotifications'; Value = 0 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_Layout'; Value = 1 },
    @{ Path = 'Software\Policies\Microsoft\Windows\Explorer'; Name = 'HideRecommendedSection'; Value = 1 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338388Enabled'; Value = 0 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338389Enabled'; Value = 0 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338393Enabled'; Value = 0 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-353694Enabled'; Value = 0 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-353696Enabled'; Value = 0 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-310093Enabled'; Value = 0 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-314559Enabled'; Value = 0 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338387Enabled'; Value = 0 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SystemPaneSuggestionsEnabled'; Value = 0 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SilentInstalledAppsEnabled'; Value = 0 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'PreInstalledAppsEnabled'; Value = 0 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'PreInstalledAppsEverEnabled'; Value = 0 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'OemPreInstalledAppsEnabled'; Value = 0 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'RotatingLockScreenEnabled'; Value = 0 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'RotatingLockScreenOverlayEnabled'; Value = 0 },
    @{ Path = 'Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Name = 'Enabled'; Value = 0 }
)

$loadedHives = Get-ChildItem 'Registry::HKEY_USERS' | Where-Object {
    $_.Name -match 'S-1-5-21-' -and $_.Name -notmatch '_Classes$'
}
Log "Found $($loadedHives.Count) loaded user hive(s)"

foreach ($hive in $loadedHives) {
    $sid = $hive.PSChildName
    Log "  -- Processing SID: $sid --"
    foreach ($change in $userHiveChanges) {
        Set-Reg "Registry::HKEY_USERS\$sid\$($change.Path)" $change.Name $change.Value
    }
}

Log "=== Default profile ==="
$defaultHive = "$env:SystemDrive\Users\Default\NTUSER.DAT"
$tempKey = 'HKEY_USERS\TempDefault_Debloat'
if (Test-Path $defaultHive) {
    & reg.exe load $tempKey $defaultHive 2>&1 | ForEach-Object { Log "  REG LOAD: $_" }
    Start-Sleep -Seconds 1
    foreach ($change in $userHiveChanges) {
        Set-Reg "Registry::$tempKey\$($change.Path)" $change.Name $change.Value
    }
    [GC]::Collect()
    Start-Sleep -Seconds 1
    & reg.exe unload $tempKey 2>&1 | ForEach-Object { Log "  REG UNLOAD: $_" }
} else {
    Log "  Default NTUSER.DAT not found - skipping"
}

Log "=== Restarting explorer ==="
Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

Log "Brute-Force Debloat DONE"
