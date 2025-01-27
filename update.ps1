# ps_windows_update
# Jonas Sauge - Async IT Sàrl - 2025

# Update Windows using powershell

# Version 1.0
# Version 1.1 - disable quickedit
# Version 1.2 - Automatic update :)
# Version 1.3 - Removed confusing informations
# Version 1.4 - fixed loop & correct file replacement
# Version 1.5 - Correct file update 
# Version 1.6 - Show version of windows
# Version 1.7 - Update chocolatey apps and update Anydeks client
# Version 1.8 - little enhancements, only use functions, reorder a bit in the hope to be a bit faster to start
# Version 2.0 - Make program more resilient, add --noprogress to choco update to ensure better readability, other improvements, makes it faster, make it path agnostic, add error checks

$version = 2.0

# Ressources --------------------------
$updateexedownloadurl = "https://api.github.com/repos/async-it/ps_windows_update/releases/latest"
# Anydesk Download URL and path
$AnyDeskUrl = "https://get.anydesk.com/d0WzDK32/Async_Support_Client.exe"
$AnyDeskInstallerPath = "C:\Windows\Temp\anydesk_support_client.exe"
# Anydesk paths to check
$oldFilePath = "C:\Program Files\AnyDesk\AnyDesk-b45a3617.exe"
# Environement
$currentLocation = Get-Location
$filename = "update.exe"
$executableFilePath = Join-Path -Path $currentLocation -ChildPath $filename

# --------------------------------------

function displayHeaderInitial {
write-host "   __      __.__            .___                     ____ ___            .___       __                "
write-host "  /  \    /  \__| ____    __| _/______  _  ________ |    |   \______   __| _/____ _/  |_  ___________ "
write-host "  \   \/\/   /  |/    \  / __ |/  _ \ \/ \/ /  ___/ |    |   /\____ \ / __ |\__  \\   __\/ __ \_  __ \"
write-host "   \        /|  |   |  \/ /_/ (  <_> )     /\___ \  |    |  / |  |_> > /_/ | / __ \|  | \  ___/|  | \/"
write-host "    \__/\  / |__|___|  /\____ |\____/ \/\_//____  > |______/  |   __/\____ |(____  /__|  \___  >__|   "
write-host "         \/          \/      \/                 \/            |__|        \/     \/          \/       "
write-host "---------------------- Jonas Sauge - Async IT Sàrl - 2024 - version $version -----------------------------"
}

function displayHeaderFull {
displayHeaderInitial
$computerinfo = Get-ComputerInfo
$computerinfoosname = $computerinfo | ForEach-Object { $_.osName -replace 'Microsoft ', '' }
$computerinfoversion = $computerinfo | select osdisplayversion -ExpandProperty osdisplayversion
}

function errorCheck {
if ($?) {
		Write-Output ""
	} else {
		Write-Output "- Error Happened, application will exit"
		pause
		exit
	}					
}


function admincheck {
# Check if admin rights are correctly acquired
	if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "- This script requires administrative privileges. Application will exit"
	pause
    exit
}
}

function setconsolesettings {
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
}

function selfupdate {
# Check if the latest asset has the same version as actual, if not, an update is needed.

$versionwebrequest = (Invoke-WebRequest $updateexedownloadurl | ConvertFrom-Json).assets
errorCheck
$onlineversionurl = ($versionwebrequest).browser_download_url
# Obtaining Online version
$indexStart = $onlineversionurl.IndexOf("download/") + 9
$indexEnd = $onlineversionurl.IndexOf("/update.exe", $indexStart)
$onlineVersionValue = $onlineversionurl.Substring($indexStart, $indexEnd - $indexStart)
Write-Host "- Online version is: $onlineVersionValue"

if ($onlineVersionValue -gt $version) {
    # Install update and restart process
    Write-Host "- An update is available, installing"
	$extractPath = [System.IO.Path]::Combine($currentLocation, $filename)
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"Write-Host '- Updating update.exe!'; Start-Sleep -Seconds 3; Invoke-WebRequest -Uri $onlineversionurl -OutFile $extractPath; Start-Process $executableFilePath`""
	errorcheck
	exit
} else {
		if ($onlineVersionValue -eq $version) {
			Write-Host "- Update.exe is already in the latest version, no update needed"
		} else {
			Write-Host "- Error: Your version seems to be above online version, please check"
			pause
			exit
		}
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
}
}

function anydeskupdate {
if (Test-Path $oldFilePath) {
Write-Host "- Checking if Anydesk needs an update"
Write-Host "- Downloading Async Support package"
Invoke-WebRequest -Uri $AnyDeskUrl -OutFile $AnyDeskInstallerPath
errorCheck
if (Test-Path $oldFilePath) {
}

# Fonction pour obtenir la version d'un fichier
function Get-FileVersion {
    param (
        [string]$filePath
    )
    $file = Get-Item -Path $filePath
    $fileVersionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($file.FullName)
    return $fileVersionInfo.FileVersion
}

# Comparing files versions
$oldFileVersion = Get-FileVersion -filePath $oldFilePath
$newFileVersion = Get-FileVersion -filePath $AnyDeskInstallerPath

# Displayinf versions 
Write-Host "- Installed:  $oldFileVersion - Available: $newFileVersion"
# Comparer les versions
if ($newFileVersion -gt $oldFileVersion) {
	Write-Host "Installing Async Support package"
	# Install anydesk using specified options
	$arguments = "--install `"${env:ProgramFiles}\AnyDesk`" --start-with-win --create-desktop-icon --remove-first"
	Start-Process -FilePath "$AnyDeskInstallerPath" -ArgumentList $arguments -Wait
} else {
    Write-Host "- Anydesk up to date"
}
} else {
 Write-Host "- Anydesk for customers not installed"
}

}

function chocoappsupdate {
# Check if Chocolatey is already installed
$chocoPath = Join-Path $env:SystemDrive "ProgramData\chocolatey\bin\choco.exe"
	if (Test-Path $chocoPath) {
		Write-Host "- Chocolatey is installed - updating apps"
  		choco upgrade all --no-progress -y
   	}
}

function windowsupdate {
Get-Wuinstall -Acceptall -Verbose -install
}

displayHeaderInitial
admincheck
selfupdate
setconsolesettings
displayHeaderFull
installmoduleifmissing
chocoappsupdate
anydeskupdate
windowsupdate
exit
