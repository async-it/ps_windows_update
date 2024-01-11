# ps_windows_update
# Jonas Sauge - Async IT Sàrl - 2024

# Update Windows using powershell

# Version 1.0

write-host "- Jonas Sauge - Async IT Sàrl - 2024"
write-host "- Updating Windows"

# Check if admin rights are correctly acquired
	if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script requires administrative privileges."
	Read-Host -Prompt "Press Enter to continue..."
    exit
}

function installmoduleifmissing {
$moduleInstalled = Get-Module -ListAvailable | Where-Object { $_.Name -eq 'PSWindowsUpdate' }
if ($moduleInstalled -eq $null) {
    # Install module if missing
    Write-Host "Le module PSWindowsUpdate n'est pas installé. Installation en cours..."
	set-executionpolicy remotesigned
	Install-packageprovider -Name nuget -Force
	Install-Module -Name PSWindowsUpdate -Force
	import-Module -Name PSWindowsUpdate
    Write-Host "Le module PSWindowsUpdate a été installé avec succès."
} else {
    # Mudule already installed
	write-host "$moduleInstalled"
    Write-Host "Le module PSWindowsUpdate est déjà installé."
}
}
installmoduleifmissing
Get-Wuinstall -Acceptall -Verbose -install
