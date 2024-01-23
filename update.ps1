# ps_windows_update
# Jonas Sauge - Async IT Sàrl - 2024

# Update Windows using powershell

# Version 1.0
# Version 1.1 - disable quickedit
# Version 1.2 - Automatic update :)
# Version 1.3 - Removed confusing informations
# Version 1.4 - fixed loop

$version = 1.4

# Ressources --------------------------
$updateexedownloadurl = "https://api.github.com/repos/async-it/ps_windows_update/releases/latest"
# --------------------------------------

write-host "   __      __.__            .___                     ____ ___            .___       __                "
write-host "  /  \    /  \__| ____    __| _/______  _  ________ |    |   \______   __| _/____ _/  |_  ___________ "
write-host "  \   \/\/   /  |/    \  / __ |/  _ \ \/ \/ /  ___/ |    |   /\____ \ / __ |\__  \\   __\/ __ \_  __ \"
write-host "   \        /|  |   |  \/ /_/ (  <_> )     /\___ \  |    |  / |  |_> > /_/ | / __ \|  | \  ___/|  | \/"
write-host "    \__/\  / |__|___|  /\____ |\____/ \/\_//____  > |______/  |   __/\____ |(____  /__|  \___  >__|   "
write-host "         \/          \/      \/                 \/            |__|        \/     \/          \/       "
write-host "---------------------- Jonas Sauge - Async IT Sàrl - 2024 - version $version -----------------------------"
write-host "- Updating Windows"

# Check if admin rights are correctly acquired
	if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "- This script requires administrative privileges."
	Read-Host -Prompt "- Press Enter to continue..."
    exit
}

$currentLocation = Get-Location
# Disable quick edit to ensure commands cannot be interrupted by mistake
$value = (Get-ItemProperty -Path "HKCU:\Console" -Name "QuickEdit").QuickEdit
	if($value -eq 1) {
		Set-ItemProperty -Path "HKCU:\Console" -Name "QuickEdit" -Value 0
		Start-Process $currentLocation\update.exe
		exit
		} else {
		Set-ItemProperty -Path "HKCU:\Console" -Name "QuickEdit" -Value 1
		}
		
function selfupdate {
# Check if the latest asset has the same version as actual, if not, an update is needed.
$actualversion = (Invoke-WebRequest $updateexedownloadurl | ConvertFrom-Json).assets | Where-Object browser_download_url -like *$version*
if ($actualversion -eq $null) {
    # Install update and restart process
    Write-Host "- An update is available, installing"
	$asset = (Invoke-WebRequest $updateexedownloadurl | ConvertFrom-Json).assets | Where-Object name -like update.exe
	$downloadUri = $asset.browser_download_url
	$extractDirectory = "C:\Windows\System32\"
	$extractPath = [System.IO.Path]::Combine($extractDirectory, $asset.name)
	Invoke-WebRequest -Uri $downloadUri -OutFile $extractPath
	Start-Process C:\Windows\System32\update.exe
	exit	
}
}

function installmoduleifmissing {
$moduleInstalled = Get-Module -ListAvailable | Where-Object { $_.Name -eq 'PSWindowsUpdate' }
if ($moduleInstalled -eq $null) {
    # Install module if missing
    Write-Host "- Installing PSWindowsUpdate"
	set-executionpolicy remotesigned
	Install-packageprovider -Name nuget -Force
	Install-Module -Name PSWindowsUpdate -Force
	import-Module -Name PSWindowsUpdate
    Write-Host "- PSWindowsUpdate installed"
} else {
    # Module already installed
   Write-Host "- PSWindowsUpdate is already installed"
}
}

selfupdate
installmoduleifmissing
Get-Wuinstall -Acceptall -Verbose -install
exit
