Write-Host -ForegroundColor Green "Starting OSDCloud ZTI"
   Start-Sleep -Seconds 5

   Write-Host -ForegroundColor Green "Updating OSD PowerShell Module"
   Install-Module OSD -Force

   Write-Host -ForegroundColor Green "Importing OSD PowerShell Module"
   Import-Module OSD -Force

   Write-Host -ForegroundColor Green "Starting OSDPad"
   Start-OSDPad -RepoOwner tmsk01 -RepoName rrr-osd -RepoFolder ScriptPad -Hide Script -BrandingTitle 'RRR Windows Deployment'
