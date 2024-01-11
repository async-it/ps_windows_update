# PS Windows Update
Update windows with a simple command

![image](https://github.com/async-it/ps_windows_update/assets/70369976/9fb774b5-c826-46aa-9dfa-7976e00a55c1)

# One liner installation: run in elevated powershell prompt
```shell
Invoke-WebRequest -Uri "https://github.com/async-it/ps_windows_update/files/13905101/update.zip" -OutFile "$env:SystemRoot\System32\update.zip" ; Expand-Archive -Path "$env:SystemRoot\System32\update.zip" -DestinationPath "$env:SystemRoot\System32\" -Force ; Remove-Item -Path "$env:SystemRoot\System32\update.zip" -Force
```

# Compile yourself

Install ps2exe:
```shell
Install-Module -Name ps2exe
```

Download the repository content, open a command shell and convert it to .exe using ps2exe:

```shell
ps2exe "update.ps1" -requireadmin -version $version -company "Async IT Sàrl" -iconfile "default_icon.ico" -title  "Async Windows Updater" -copyright "Async IT Sarl - Jonas Sauge"  update.exe
```
put this in C:\Windows\System32 then just run
```shell
update
```
