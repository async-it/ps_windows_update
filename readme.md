# PS Windows Update
Update windows with a simple command

![image](https://github.com/async-it/ps_windows_update/assets/70369976/adea5795-d4a4-43ca-8213-a360de5636be)

# Installation:
Download and put this in C:/windows/system32

## Usage:
- run from cmd, powershell or explorer
```ssh
update
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
