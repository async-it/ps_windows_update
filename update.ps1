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
# Version 2.0 - Small enhancements to make the start of process feel faster
# Version 2.2 - add title to window, changed the header asciiart
# Version 2.3 - Updated anydesk url and download method
# Version 2.4 - Fixed ASCII art
# Version 2.5 - Enhanced Anydesk Download
# Version 2.6 - Prevent script block using basic parsing web request

$version = "2.6"

# Ressources --------------------------
$updateexedownloadurl = "https://api.github.com/repos/async-it/ps_windows_update/releases/latest"
# Anydesk Download URL and path
$AnyDeskUrl = "https://my.anydesk.com/download/d0WzDK32/Async_support_client.msi"
$AnyDeskInstallerPath = "C:\Windows\Temp\anydesk_support_client.exe"
# Anydesk paths to check
$oldFilePath = "C:\Program Files\AnyDesk\AnyDesk-b45a3617.exe"
# Environement
$currentLocation = Get-Location
$filename = "update.exe"
$executableFilePath = Join-Path -Path $currentLocation -ChildPath $filename

# --------------------------------------

$Host.UI.RawUI.WindowTitle = 'Async Windows Updater'

function displayHeader {
write-host "
 __      ___         _                              _      _           
 \ \    / (_)_ _  __| |_____ __ _____  _  _ _ __ __| |__ _| |_ ___ _ _ 
  \ \/\/ /| | ' \/ _`` / _ \ V  V (_-< | || | '_ / _`` / _`` |  _/ -_| '_|
   \_/\_/ |_|_||_\__,_\___/\_/\_//__/  \_,_| .__\__,_\__,_|\__\___|_|  
                                           |_|                          
---------- Jonas Sauge - Async IT Sàrl - 2025 - version $version ----------
"
$computerinfo = Get-ComputerInfo
$computerinfoosname = $computerinfo | ForEach-Object { $_.osName -replace 'Microsoft ', '' }
$computerinfoversion = $computerinfo | select osdisplayversion -ExpandProperty osdisplayversion
write-host "- Updating $computerinfoosname $computerinfoversion"
}

function errorCheck {
    # Check if the last command was successful
    if (!$?) {
        Write-Host "- Error Happened, app will quit"
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
# Disable quick edit to ensure commands cannot be interrupted by mistake
$value = (Get-ItemProperty -Path "HKCU:\Console" -Name "QuickEdit").QuickEdit
	if($value -eq 1) {
		Set-ItemProperty -Path "HKCU:\Console" -Name "QuickEdit" -Value 0
		$currentLocation = Get-Location
		Start-Process $currentLocation\update.exe
		exit
		} else {
		Set-ItemProperty -Path "HKCU:\Console" -Name "QuickEdit" -Value 1
		}
}

function anydesk_download {
$maxAttempts = 3
$attempt = 1
$success = $false

while (-not $success -and $attempt -le $maxAttempts) {
    Write-Host "Tentative $attempt de téléchargement..." -ForegroundColor Yellow
    curl.exe -s -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -o $AnyDeskInstallerPath $AnyDeskUrl

    if (Test-Path $AnyDeskInstallerPath) {
        $content = Get-Content $AnyDeskInstallerPath -Raw -Encoding Byte
        $asText = [System.Text.Encoding]::ASCII.GetString($content)

        if ($asText -match "<html" -or $asText -match "<!DOCTYPE html") {
            Write-Host "- Erreur : fichier HTML détecté. Suppression du fichier..." -ForegroundColor Red
            Remove-Item $AnyDeskInstallerPath -ErrorAction SilentlyContinue
        } else {
            Write-Host "- Téléchargement réussi : $AnyDeskInstallerPath" -ForegroundColor Green
			$success = $true
        }
    } else {
        Write-Host "- Erreur : fichier non trouvé après téléchargement." -ForegroundColor Red
    }

    if (-not $success) {
        $attempt++
        Start-Sleep -Seconds 2
    }
}

if (-not $success) {
    Write-Host "❌ Échec du téléchargement après $maxAttempts tentatives." -ForegroundColor Red
}

}

function selfupdate {
# Check if the latest asset has the same version as actual, if not, an update is needed.

$versionwebrequest = (Invoke-WebRequest -UseBasicParsing $updateexedownloadurl | ConvertFrom-Json).assets
errorCheck
$onlineversionurl = ($versionwebrequest).browser_download_url
# Obtaining Online version
$indexStart = $onlineversionurl.IndexOf("download/") + 9
$indexEnd = $onlineversionurl.IndexOf("/update.exe", $indexStart)
$onlineVersionValue = $onlineversionurl.Substring($indexStart, $indexEnd - $indexStart)
if ($onlineVersionValue -gt $version) {
    # Install update and restart process
    Write-Host "- An update is available, installing"
	$extractPath = [System.IO.Path]::Combine($currentLocation, $filename)
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"Write-Host '- Updating update.exe!'; Start-Sleep -Seconds 3; Invoke-WebRequest -Uri $onlineversionurl -OutFile $extractPath; Start-Process $executableFilePath`""
	errorcheck
	exit
} else {
		if ($onlineVersionValue -lt $version) {
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
Write-Host "- Downloading Async Support package"
# 20250416 - Use curl instead of invoke-webrequest that throw error 403 when ran from inside this exe
# Invoke-WebRequest -Uri $AnyDeskUrl -OutFile $AnyDeskInstallerPath
anydesk_download
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
Write-Host "- Checking if Anydesk needs an update - Installed: $oldFileVersion - Available: $newFileVersion"
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

admincheck
selfupdate
setconsolesettings
displayHeader
installmoduleifmissing
chocoappsupdate
anydeskupdate
windowsupdate
exit
