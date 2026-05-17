$LogPath = "C:\Windows\Temp\Debloat.log"
"$(Get-Date) - Debloat starting" | Out-File -FilePath $LogPath -Encoding ascii -Append

try {
    $debloatScript = "$env:TEMP\Win11Debloat.ps1"
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Raphire/Win11Debloat/master/Win11Debloat.ps1' `
                      -OutFile $debloatScript -UseBasicParsing
    "$(Get-Date) - Downloaded Win11Debloat" | Out-File -FilePath $LogPath -Encoding ascii -Append

    $flags = @(
        '-Silent',
        '-RemoveApps',
        '-RemoveCommApps',
        '-RemoveGamingApps',
        '-RemoveW11Outlook',
        '-RemoveDevApps',
        '-DisableTelemetry',
        '-DisableBing',
        '-DisableSuggestions',
        '-DisableLockscreenTips',
        '-DisableSettings365Ads',
        '-DisableCopilot',
        '-DisableRecall',
        '-DisableClickToDo',
        '-DisableAIDataAnalysis',
        '-DisableEdgeAI',
        '-DisablePaintAI',
        '-DisableNotepadAI',
        '-DisableMouseAcceleration',
        '-DisableStickyKeys',
        '-DisableStorageSense',
        '-DisableFastStartup',
        '-DisableBitlockerAutoDeviceEncryption',
        '-DisableDeliveryOptimization',
        '-ClearStart',
        '-DisableWidgets',
        '-HideWidgets',
        '-DisableChat',
        '-HideChat',
        '-HideSearchTb',
        '-HideTaskview',
        '-ShowHiddenFolders',
        '-ShowKnownFileExt',
        '-HideOnedrive',
        '-DisableOnedrive',
        '-DisableCortana',
        '-DisableWindowsRecall'
    ) -join ' '

    $cmd = "& `"$debloatScript`" $flags"
    "$(Get-Date) - Running: $cmd" | Out-File -FilePath $LogPath -Encoding ascii -Append

    powershell.exe -ExecutionPolicy Bypass -NoProfile -Command $cmd 2>&1 | Out-File -FilePath $LogPath -Encoding ascii -Append

    "$(Get-Date) - Debloat finished" | Out-File -FilePath $LogPath -Encoding ascii -Append
} catch {
    "$(Get-Date) - Debloat error: $_" | Out-File -FilePath $LogPath -Encoding ascii -Append
}
