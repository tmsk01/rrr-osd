#Requires -RunAsAdministrator

param(
    [string]$WorkspacePath = 'C:\OSDCloud\MyWorkspace',
    [string]$IsoFileId     = '1zlk2RB9-edkhwQVX0BiI6iZrcJqOuot2',
    [string]$IsoLocalPath  = "$env:USERPROFILE\Downloads\RRR-OSDCloud.iso",
    [string]$AdkBootstrapUrl   = 'https://go.microsoft.com/fwlink/?linkid=2289980',
    [string]$WinPEBootstrapUrl = 'https://go.microsoft.com/fwlink/?linkid=2289981'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'

function Step($n, $msg) {
    Write-Host "`n[$n/5] $msg" -ForegroundColor Cyan
}

function Get-FileWithProgress {
    param($Url, $Destination, $Activity)

    Add-Type -AssemblyName System.Net.Http
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect = $true
    $client = [System.Net.Http.HttpClient]::new($handler)
    $client.Timeout = [System.TimeSpan]::FromHours(1)

    $response = $client.GetAsync($Url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
    $response.EnsureSuccessStatusCode() | Out-Null

    $totalBytes = $response.Content.Headers.ContentLength
    $stream     = $response.Content.ReadAsStreamAsync().Result
    $fileStream = [System.IO.File]::Create($Destination)

    $buffer = New-Object byte[] 1048576
    $totalRead = 0
    $startTime = Get-Date
    $lastUpdate = Get-Date

    try {
        while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $fileStream.Write($buffer, 0, $read)
            $totalRead += $read

            if (((Get-Date) - $lastUpdate).TotalMilliseconds -ge 250) {
                $elapsed = ((Get-Date) - $startTime).TotalSeconds
                $mbDone  = [math]::Round($totalRead / 1MB, 1)
                $speed   = if ($elapsed -gt 0) { [math]::Round($totalRead / 1MB / $elapsed, 2) } else { 0 }

                if ($totalBytes) {
                    $mbTotal  = [math]::Round($totalBytes / 1MB, 1)
                    $percent  = [math]::Round(($totalRead / $totalBytes) * 100, 1)
                    $remain   = if ($speed -gt 0) { [math]::Round((($totalBytes - $totalRead) / 1MB) / $speed, 0) } else { 0 }
                    Write-Progress -Activity $Activity `
                        -Status "$mbDone MB / $mbTotal MB - $speed MB/s - ~${remain}s remaining" `
                        -PercentComplete $percent
                } else {
                    Write-Progress -Activity $Activity -Status "$mbDone MB downloaded - $speed MB/s"
                }
                $lastUpdate = Get-Date
            }
        }
    }
    finally {
        $fileStream.Close()
        $stream.Close()
        $client.Dispose()
    }
    Write-Progress -Activity $Activity -Completed
}

function Get-RealPython {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe",
        "C:\Program Files\Python313\python.exe",
        "C:\Program Files\Python312\python.exe",
        "C:\Program Files\Python311\python.exe"
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }

    $found = Get-ChildItem "$env:LOCALAPPDATA\Programs\Python\" -Filter python.exe -Recurse -ErrorAction SilentlyContinue |
             Where-Object { $_.FullName -notmatch 'WindowsApps' } |
             Select-Object -First 1 -ExpandProperty FullName
    if ($found) { return $found }

    $found = Get-ChildItem "C:\Program Files\Python*\python.exe" -ErrorAction SilentlyContinue |
             Select-Object -First 1 -ExpandProperty FullName
    if ($found) { return $found }

    return $null
}

function Ensure-Python {
    $existing = Get-RealPython
    if ($existing) {
        $script:PythonExe = $existing
        return
    }

    Write-Host "Python not found - installing via winget..." -ForegroundColor Gray
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget is not available. Install Python manually from python.org and re-run."
    }
    winget install -e --id Python.Python.3.12 --silent --accept-source-agreements --accept-package-agreements | Out-Null

    $existing = Get-RealPython
    if (-not $existing) {
        throw "Python installed but cannot be located. Open a new admin PowerShell window and re-run the script."
    }
    $script:PythonExe = $existing
    Write-Host "Python installed at $existing" -ForegroundColor Green
}

function Get-GoogleDriveFile {
    param($FileId, $Destination)

    Ensure-Python

    Write-Progress -Activity 'Preparing gdown' -Status 'Installing/upgrading via pip...'
    & $script:PythonExe -m pip install --quiet --upgrade gdown 2>&1 | Out-Null
    Write-Progress -Activity 'Preparing gdown' -Completed

    Write-Host "Downloading ISO via gdown..." -ForegroundColor Gray
    & $script:PythonExe -m gdown "https://drive.google.com/uc?id=$FileId" -O $Destination
}

Write-Host "`n=== RRR OSDCloud Workspace Bootstrap ===" -ForegroundColor Magenta

Step 1 'Windows ADK + WinPE'
$winpePath = "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment"
if (Test-Path $winpePath) {
    Write-Host "Already installed" -ForegroundColor Green
} else {
    $tempDir = "$env:TEMP\adk-bootstrap"
    if (!(Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir -Force | Out-Null }

    $adkExe = Join-Path $tempDir 'adksetup.exe'
    Get-FileWithProgress -Url $AdkBootstrapUrl -Destination $adkExe -Activity 'Downloading ADK installer'

    Write-Progress -Activity 'Installing ADK' -Status 'Running silent installer (5-10 minutes)...'
    Start-Process -FilePath $adkExe -ArgumentList '/quiet','/norestart','/features','OptionId.DeploymentTools' -Wait -NoNewWindow
    Write-Progress -Activity 'Installing ADK' -Completed

    $winpeExe = Join-Path $tempDir 'adkwinpesetup.exe'
    Get-FileWithProgress -Url $WinPEBootstrapUrl -Destination $winpeExe -Activity 'Downloading WinPE add-on'

    Write-Progress -Activity 'Installing WinPE add-on' -Status 'Running silent installer (3-5 minutes)...'
    Start-Process -FilePath $winpeExe -ArgumentList '/quiet','/norestart','/features','OptionId.WindowsPreinstallationEnvironment' -Wait -NoNewWindow
    Write-Progress -Activity 'Installing WinPE add-on' -Completed

    if (-not (Test-Path $winpePath)) {
        Write-Error "ADK install completed but WinPE not found. Manual install: https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install"
        return
    }
    Write-Host "Installed" -ForegroundColor Green
}

Step 2 'OSD PowerShell module'
if (-not (Get-Module -ListAvailable -Name OSD)) {
    if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne 'Trusted') {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }
    Write-Progress -Activity 'Installing OSD module' -Status 'Downloading from PSGallery...'
    Install-Module OSD -Force -Scope CurrentUser
    Write-Progress -Activity 'Installing OSD module' -Completed
}
Import-Module OSD -Force
Write-Host "Loaded version $((Get-Module OSD).Version)" -ForegroundColor Green

Step 3 'Customized ISO'
if (Test-Path $IsoLocalPath) {
    $sizeMB = [math]::Round((Get-Item $IsoLocalPath).Length / 1MB, 1)
    Write-Host "Already exists at $IsoLocalPath ($sizeMB MB)" -ForegroundColor Green
} else {
    Get-GoogleDriveFile -FileId $IsoFileId -Destination $IsoLocalPath

    if (-not (Test-Path $IsoLocalPath)) {
        Write-Error "ISO download failed. Download manually from Google Drive to $IsoLocalPath, then re-run."
        return
    }

    $sizeMB = [math]::Round((Get-Item $IsoLocalPath).Length / 1MB, 1)
    if ($sizeMB -lt 100) {
        Remove-Item $IsoLocalPath -Force
        Write-Error "Downloaded file is only $sizeMB MB. Download manually to $IsoLocalPath, then re-run."
        return
    }
    Write-Host "Downloaded $sizeMB MB" -ForegroundColor Green
}

Step 4 'Workspace fork'
if (Test-Path $WorkspacePath) {
    Write-Host "Already exists at $WorkspacePath - delete folder manually for a clean rebuild" -ForegroundColor Yellow
} else {
    Write-Progress -Activity 'Creating workspace' -Status 'Mounting ISO and copying media...'
    New-OSDCloudWorkspace -WorkspacePath $WorkspacePath -fromIsoFile $IsoLocalPath
    Write-Progress -Activity 'Creating workspace' -Completed
    Write-Host "Created at $WorkspacePath" -ForegroundColor Green
}

Step 5 'Verify'
$bootWim = Join-Path $WorkspacePath 'Media\sources\boot.wim'
if (Test-Path $bootWim) {
    $sizeMB = [math]::Round((Get-Item $bootWim).Length / 1MB, 1)
    Write-Host "boot.wim found ($sizeMB MB)" -ForegroundColor Green
} else {
    Write-Error "Verification failed - boot.wim not found at expected path"
    return
}

Write-Host "`n=== Done ===" -ForegroundColor Green
Write-Host @"
Workspace: $WorkspacePath

Next:
  New-OSDCloudUSB -WorkspacePath '$WorkspacePath'
  New-OSDCloudISO -WorkspacePath '$WorkspacePath'
  Edit-OSDCloudWinPE -WorkspacePath '$WorkspacePath' -DriverPath 'path\to\drivers'

Repo: https://github.com/tmsk01/rrr-osd
"@ -ForegroundColor Cyan
