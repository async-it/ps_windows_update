# PS Windows Update
Update windows with a simple command

# Compile yourself
Download the repository content, open a command shell and convert it to .exe using ps2exe:

```shell
ps2exe "update.ps1" -requireadmin -version $version -company "Async IT Sàrl" -requireadmin -iconfile "default_icon.ico" -title  "Async Windows Updater" -copyright "Async IT Sarl - Jonas Sauge"  update.exe
```
put this in C:\Windows\System32 the just run
```shell
update
```
