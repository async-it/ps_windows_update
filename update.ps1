<#
    ps_windows_update
    Jonas Sauge - Async IT Sarl - 2026

    Updates Windows, Chocolatey packages and the Async AnyDesk support client.

    Version history
    ---------------
    1.0        Initial release
    1.1        Disable quickedit
    1.2        Automatic update
    1.3        Removed confusing information
    1.4        Fixed loop & correct file replacement
    1.5        Correct file update
    1.6        Show version of Windows
    1.7        Update chocolatey apps and update AnyDesk client
    1.8        Only use functions, reorder for faster start
    2.0        Resilience, --noprogress for choco, path agnostic, error checks
    2.2        Window title, new ASCII header
    2.3        Updated AnyDesk url and download method
    2.4        Fixed ASCII art
    2.5        Enhanced AnyDesk download
    2.6        Prevent script block using basic parsing web request
    2.7        Download AnyDesk from Async website
    2.8        Set shortcut to AnyDesk if it gets updated
    2.9        Remove old AnyDesk installation, reinstall on shortcut-matching path
    3.0        Fixed AnyDesk version detection
    3.1        New AnyDesk download URL
    4.0        Rewrite:
                 - QuickEdit is now disabled on the live console through the
                   Win32 SetConsoleMode API. No registry write, no relaunch,
                   original console mode restored on exit.
                 - Self-update uses real version comparison ([version] instead
                   of string), resolves its own executable path instead of the
                   current working directory, validates the downloaded binary
                   and swaps it through an encoded helper (quoting-proof).
                 - Header info read from CIM/registry instead of
                   Get-ComputerInfo (seconds faster to first paint).
                 - Structured error handling (try/catch) replaces the
                   unreliable "$?" checks.
                 - Execution policy scoped to the process instead of the machine.
                 - AnyDesk: installer validated by PE header, version compare
                   hardened, temp file cleaned up, scoping bug fixed.
                 - Output unified in English, pure ASCII (safe in ps2exe consoles).
                 - TLS 1.2 forced, progress bars suppressed for speed.
    4.1        Reworked console presentation:
                 - Machine information banner (host, system, start time).
                 - Numbered sections separated by rules, aligned
                   [ OK ] / [WARN] / [FAIL] / [SKIP] status column.
                 - Raw tool output (choco, Windows Update) delimited so it
                   reads as a nested block instead of bleeding into the layout.
                 - End-of-run summary with per-task outcome and total duration.
                 - The window closes on its own when nothing failed, and waits
                   for a keypress when it did. The countdown is cancellable.

    Build
    -----
    ps2exe "update.ps1" -requireadmin -version 4.1.0.0 -company "Async IT Sarl" `
           -iconfile "default_icon.ico" -title "Async Windows Updater" `
           -copyright "Async IT Sarl - Jonas Sauge" update.exe
#>

[CmdletBinding()]
param()

# ==========================================================================
#  Configuration
# ==========================================================================

$script:Version = [version]'4.1'

# Presentation
$script:Width      = 70
$script:TotalSteps = 4
$script:StepIndex  = 0

# Auto-close behaviour (seconds). A keypress always cancels the countdown.
$script:CloseDelayClean    = 8
$script:CloseDelayWarnings = 20

# Self-update
$script:ReleaseApiUrl = 'https://api.github.com/repos/async-it/ps_windows_update/releases/latest'

# AnyDesk (Async support client)
$script:AnyDeskUrl           = 'https://raw.githubusercontent.com/async-it/public/refs/heads/main/Async_support_client.exe'
$script:AnyDeskInstallerPath = Join-Path $env:TEMP 'anydesk_support_client.exe'
$script:AnyDeskInstalledPath = Join-Path $env:ProgramFiles 'AnyDesk\AnyDesk-b45a3617.exe'
$script:AnyDeskShortcutPath  = Join-Path $env:PUBLIC 'Desktop\AnyDesk Async IT Support.lnk'
$script:AnyDeskDownloadTries = 3

# Legacy AnyDesk locations that must be removed before reinstalling
$script:AnyDeskLegacyPaths = @(
    (Join-Path ${env:ProgramFiles(x86)} 'AnyDesk-*\AnyDesk-*.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'AnyDesk\AnyDesk-*.exe')
)

# Desktop shortcut (CTRL + ALT + H hotkey), stored as a base64 .lnk blob
$script:AnyDeskShortcutB64 = 'TAAAAAEUAgAAAAAAwAAAAAAAAEbPAAAAIAAAAKiqO79yztwBJR1Bv3LO3AGAd26+cs7cAaATVgAAAAAAAQAAAEgGAAAAAAAAAAAAAIcBFAAfUOBP0CDqOmkQotgIACswMJ0ZAC9DOlwAAAAAAAAAAAAAAAAAAAAAAAAAjAAxAAAAAACRXCxwEQBQUk9HUkF+MQAAdAAJAAQA776BWEQ7kVwscC4AAABgkwYAAAABAAAAAAAAAAAASgAAAAAASnEAAVAAcgBvAGcAcgBhAG0AIABGAGkAbABlAHMAAABAAHMAaABlAGwAbAAzADIALgBkAGwAbAAsAC0AMgAxADcAOAAxAAAAGABWADEAAAAAAJFcPHAQAEFueURlc2sAQAAJAAQA776RXDxwkVw8cC4AAAA6VwAAAAAHAAAAAAAAAAAAAAAAAAAAWLfwAEEAbgB5AEQAZQBzAGsAAAAWAHYAMgCgE1YAkVw7cCAAQU5ZREVTfjEuRVhFAABaAAkABADvvpFcPHCRXDxwLgAAAEFXAAAAAAgAAAAAAAAAAAAAAAAAAACAvYwAQQBuAHkARABlAHMAawAtAGIANAA1AGEAMwA2ADEANwAuAGUAeABlAAAAHAAAAFwAAAAcAAAAAQAAABwAAAAtAAAAAAAAAFsAAAARAAAAAwAAAFwwYJwQAAAAAEM6XFByb2dyYW0gRmlsZXNcQW55RGVza1xBbnlEZXNrLWI0NWEzNjE3LmV4ZQAAGABBAG4AeQBEAGUAcwBrACAAQQBzAHkAbgBjACAASQBUACAAUwB1AHAAcABvAHIAdAAzAC4ALgBcAC4ALgBcAC4ALgBcAFAAcgBvAGcAcgBhAG0AIABGAGkAbABlAHMAXABBAG4AeQBEAGUAcwBrAFwAQQBuAHkARABlAHMAawAtAGIANAA1AGEAMwA2ADEANwAuAGUAeABlADgAJQBTAHkAcwB0AGUAbQBEAHIAaQB2AGUAJQBcAFAAcgBvAGcAcgBhAG0AIABGAGkAbABlAHMAXABBAG4AeQBEAGUAcwBrAFwAQQBuAHkARABlAHMAawAtAGIANAA1AGEAMwA2ADEANwAuAGUAeABlAGAAAAADAACgWAAAAAAAAAB3aW4xMS10ZXN0AAAAAAAAcspyfS+JKEm2u4k2JMrQCsdDPQllOvERi0lWiSvR6R9yynJ9L4koSba7iTYkytAKx0M9CWU68RGLSVaJK9HpHxAAAAAFAACgJgAAALkAAAAcAAAACwAAoLZjXpC/wU5JspxltzLT0hq5AAAAJwEAAAkAAKCJAAAAMVNQU+KKWEa8TDhDu/wTkyaYbc5tAAAABAAAAAAfAAAALgAAAFMALQAxAC0ANQAtADIAMQAtADUAOQA2ADQAMAA0ADUANgA2AC0AMQA1ADEAOAA2ADQAMAAwADMAMAAtADIAOAA3ADgANQAyADIAOQAzADQALQAxADAAMAAxAAAAAAAAAFkAAAAxU1BTVShMn3mfOUuo0OHULeHV8z0AAAAFAAAAAB8AAAAVAAAAcAByAG8AawB6AHUAbAB0ACAAYQBkAF8AYgA0ADUAYQAzADYAMQA3AAAAAAAAAAAAOQAAADFTUFOxFm1ErY1wSKdIQC6kPXiMHQAAAGgAAAAASAAAALL8yGu8QKdJnv0M9Sk7Uw4AAAAAAAAAAAAAAAA='

# Runtime preferences: no progress bars (much faster web requests on PS 5.1),
# and modern TLS for GitHub.
$ProgressPreference = 'SilentlyContinue'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch { }

$Host.UI.RawUI.WindowTitle = 'Async Windows Updater'

$script:StartedAt = Get-Date
$script:Results   = New-Object System.Collections.ArrayList

# ==========================================================================
#  Presentation layer
#  --------------------------------------------------------------------
#  Everything printed to the console goes through these helpers, so the
#  layout stays consistent and the whole look can be retuned in one place.
#  Only ASCII is emitted: accented characters, box-drawing glyphs and emoji
#  render as garbage in the OEM code page a ps2exe console inherits.
# ==========================================================================

$script:StatusStyles = @{
    'OK'   = @{ Tag = '[ OK ]'; Color = 'Green'    }
    'WORK' = @{ Tag = '[ .. ]'; Color = 'Cyan'     }
    'INFO' = @{ Tag = '[INFO]'; Color = 'Gray'     }
    'WARN' = @{ Tag = '[WARN]'; Color = 'Yellow'   }
    'FAIL' = @{ Tag = '[FAIL]'; Color = 'Red'      }
    'SKIP' = @{ Tag = '[SKIP]'; Color = 'DarkGray' }
}

function Write-Rule {
    param([char]$Character = '=', [string]$Color = 'DarkGray')
    Write-Host ([string]$Character * $script:Width) -ForegroundColor $Color
}

function Write-Status {
    param(
        [Parameter(Mandatory)][ValidateSet('OK', 'WORK', 'INFO', 'WARN', 'FAIL', 'SKIP')][string]$Level,
        [Parameter(Mandatory)][string]$Message
    )
    $style = $script:StatusStyles[$Level]
    Write-Host '  ' -NoNewline
    Write-Host $style.Tag -ForegroundColor $style.Color -NoNewline
    Write-Host "  $Message"
}

function Write-Section {
    param([Parameter(Mandatory)][string]$Title)
    $script:StepIndex++
    Write-Host ''
    Write-Rule
    Write-Host '  ' -NoNewline
    Write-Host "[$($script:StepIndex)/$($script:TotalSteps)]" -ForegroundColor DarkGray -NoNewline
    Write-Host "  $($Title.ToUpperInvariant())" -ForegroundColor White
    Write-Rule
}

function Enter-RawOutput {
    <#  Native tools (choco, Windows Update) write unindented, unstyled text.
        Fencing it keeps the surrounding layout readable instead of letting
        hundreds of raw lines dissolve the structure. #>
    Write-Host ''
    Write-Rule -Character '.' -Color 'DarkGray'
}

function Exit-RawOutput {
    Write-Rule -Character '.' -Color 'DarkGray'
    Write-Host ''
}

function Register-Result {
    param(
        [Parameter(Mandatory)][string]$Task,
        [Parameter(Mandatory)][ValidateSet('OK', 'WARN', 'FAIL', 'SKIP')][string]$Level,
        [string]$Detail = ''
    )
    [void]$script:Results.Add([pscustomobject]@{ Task = $Task; Level = $Level; Detail = $Detail })
}

function Format-Duration {
    param([TimeSpan]$Span)
    return '{0:00}:{1:00}:{2:00}' -f [int]$Span.TotalHours, $Span.Minutes, $Span.Seconds
}

function Show-Header {
    $art = @'

 __      ___         _
 \ \    / (_)_ _  __| |_____ __ _____  _  _ _ __ __| |__ _| |_ ___ _ _
  \ \/\/ /| | ' \/ _` / _ \ V  V (_-< | || | '_ / _` / _` |  _/ -_| '_|
   \_/\_/ |_|_||_\__,_\___/\_/\_//__/  \_,_| .__\__,_\__,_|\__\___|_|
                                           |_|
'@
    Write-Host $art -ForegroundColor Cyan

    $left  = '  Async IT Sarl - Jonas Sauge'
    $right = "Updater v$($script:Version)"
    $pad   = [Math]::Max(1, $script:Width - $left.Length - $right.Length)
    Write-Host ($left + (' ' * $pad)) -ForegroundColor DarkGray -NoNewline
    Write-Host $right -ForegroundColor DarkGray

    Write-Host ''
    Write-Field 'Host'    $env:COMPUTERNAME
    Write-Field 'System'  (Get-OperatingSystemLabel)
    Write-Field 'Started' ($script:StartedAt.ToString('dd.MM.yyyy HH:mm:ss'))
}

function Write-Field {
    param([string]$Label, [string]$Value)
    Write-Host ('  ' + $Label.PadRight(10)) -ForegroundColor DarkGray -NoNewline
    Write-Host $Value
}

function Show-Summary {
    Write-Host ''
    Write-Rule
    Write-Host '  SUMMARY' -ForegroundColor White
    Write-Rule

    if ($script:Results.Count -eq 0) {
        Write-Status -Level 'INFO' -Message 'Nothing to report'
    }

    $width = 0
    foreach ($result in $script:Results) {
        if ($result.Task.Length -gt $width) { $width = $result.Task.Length }
    }

    foreach ($result in $script:Results) {
        $line = $result.Task.PadRight($width + 2)
        if ($result.Detail) { $line += $result.Detail }
        Write-Status -Level $result.Level -Message $line
    }

    Write-Host ''
    Write-Field 'Duration' (Format-Duration ((Get-Date) - $script:StartedAt))
    Write-Host ''
}

function Wait-BeforeExit {
    <#  Blocks until a key is pressed, but only when a human is actually
        looking at the window, so unattended / RMM runs never hang. #>
    if (-not (Test-Interactive)) { return }
    Write-Host '  Press any key to close this window...' -ForegroundColor DarkGray
    try { [void]$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } catch { Start-Sleep -Seconds 5 }
}

function Test-Interactive {
    if (-not [Environment]::UserInteractive) { return $false }
    try { return -not [Console]::IsInputRedirected } catch { return $true }
}

function Start-CloseCountdown {
    param([int]$Seconds)

    if (-not (Test-Interactive)) { return }

    # Drain anything the user typed while the updates were running, otherwise
    # a stray keystroke from ten minutes ago would cancel the countdown.
    try { while ([Console]::KeyAvailable) { [void][Console]::ReadKey($true) } } catch { }

    for ($remaining = $Seconds; $remaining -gt 0; $remaining--) {
        $message = "  Closing in {0,2}s - press any key to keep this window open " -f $remaining
        Write-Host "`r$message" -ForegroundColor DarkGray -NoNewline
        for ($tick = 0; $tick -lt 10; $tick++) {
            try {
                if ([Console]::KeyAvailable) {
                    [void][Console]::ReadKey($true)
                    Write-Host "`r$(' ' * $message.Length)`r" -NoNewline
                    Wait-BeforeExit
                    return
                }
            } catch { }
            Start-Sleep -Milliseconds 100
        }
    }
    Write-Host "`r$(' ' * 70)`r" -NoNewline
}

function Complete-Run {
    Show-Summary

    $failed  = @($script:Results | Where-Object { $_.Level -eq 'FAIL' }).Count
    $warned  = @($script:Results | Where-Object { $_.Level -eq 'WARN' }).Count

    Restore-ConsoleMode

    if ($failed -gt 0) {
        Write-Status -Level 'FAIL' -Message "$failed task(s) failed - review the output above"
        Write-Host ''
        Wait-BeforeExit
        exit 1
    }

    Start-CloseCountdown -Seconds $(if ($warned -gt 0) { $script:CloseDelayWarnings } else { $script:CloseDelayClean })
    exit 0
}

function Stop-Script {
    param([string]$Message, [int]$Code = 1)
    if ($Message) { Write-Status -Level 'FAIL' -Message $Message }
    Restore-ConsoleMode
    Write-Host ''
    Wait-BeforeExit
    exit $Code
}

# ==========================================================================
#  QuickEdit
#  --------------------------------------------------------------------
#  QuickEdit lets a stray click inside the console window enter selection
#  mode, which freezes every child process until the user presses a key.
#  Previous versions worked around this by flipping HKCU:\Console\QuickEdit
#  and relaunching the executable so the new conhost would pick the value up.
#  That mutated the user's profile and silently misbehaved when QuickEdit
#  was already disabled. We now clear the flag directly on the console we
#  are attached to, and put the original mode back when we are done.
# ==========================================================================

$script:OriginalConsoleMode = $null

function Initialize-ConsoleInterop {
    if ('AsyncIT.ConsoleInterop' -as [type]) { return $true }
    $signature = @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern IntPtr GetStdHandle(int nStdHandle);

[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);

[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
'@
    try {
        Add-Type -MemberDefinition $signature -Namespace 'AsyncIT' -Name 'ConsoleInterop' -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Disable-QuickEdit {
    $STD_INPUT_HANDLE      = -10
    $INVALID_HANDLE_VALUE  = [IntPtr]::new(-1)
    $ENABLE_QUICK_EDIT     = 0x0040
    $ENABLE_EXTENDED_FLAGS = 0x0080

    if (-not (Initialize-ConsoleInterop)) {
        Write-Status -Level 'WARN' -Message 'QuickEdit could not be disabled - avoid clicking in this window'
        return
    }

    try {
        $handle = [AsyncIT.ConsoleInterop]::GetStdHandle($STD_INPUT_HANDLE)
        if ($handle -eq [IntPtr]::Zero -or $handle -eq $INVALID_HANDLE_VALUE) { return }

        $mode = 0
        if (-not [AsyncIT.ConsoleInterop]::GetConsoleMode($handle, [ref]$mode)) { return }

        $script:OriginalConsoleMode = $mode

        # ENABLE_EXTENDED_FLAGS must be set for the QuickEdit bit to be honoured.
        $newMode = ($mode -band -bnot $ENABLE_QUICK_EDIT) -bor $ENABLE_EXTENDED_FLAGS
        if (-not [AsyncIT.ConsoleInterop]::SetConsoleMode($handle, $newMode)) {
            Write-Status -Level 'WARN' -Message 'QuickEdit could not be disabled - avoid clicking in this window'
            $script:OriginalConsoleMode = $null
        }
    } catch {
        Write-Status -Level 'WARN' -Message "QuickEdit could not be disabled: $($_.Exception.Message)"
        $script:OriginalConsoleMode = $null
    }
}

function Restore-ConsoleMode {
    if ($null -eq $script:OriginalConsoleMode) { return }
    try {
        $handle = [AsyncIT.ConsoleInterop]::GetStdHandle(-10)
        [void][AsyncIT.ConsoleInterop]::SetConsoleMode($handle, $script:OriginalConsoleMode)
    } catch { }
    $script:OriginalConsoleMode = $null
}

# ==========================================================================
#  Environment
# ==========================================================================

function Test-Administrator {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-Administrator {
    if (-not (Test-Administrator)) {
        Stop-Script 'This application requires administrative privileges. Exiting.'
    }
}

function Get-HostExecutablePath {
    <#  Returns the full path of the running host process.
        When compiled with ps2exe this is ...\update.exe; when the .ps1 is run
        directly it is powershell.exe. Previous versions used Get-Location,
        which pointed at the *working directory* and therefore dropped updated
        binaries next to wherever the user happened to be. #>
    try {
        return [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    } catch {
        return $null
    }
}

function Test-CompiledHost {
    $exe = Get-HostExecutablePath
    if (-not $exe) { return $false }
    $name = [System.IO.Path]::GetFileName($exe)
    return ($name -notmatch '^(powershell|pwsh|powershell_ise)\.exe$')
}

function Get-OperatingSystemLabel {
    # Deliberately avoids Get-ComputerInfo, which enumerates the whole machine
    # and costs several seconds before the first line is ever printed.
    $name  = 'Windows'
    $build = ''
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $name = ($os.Caption -replace 'Microsoft\s*', '').Trim()
    } catch { }
    try {
        $key = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        $display = $key.DisplayVersion
        if (-not $display) { $display = $key.ReleaseId }
        $build = (@($display, "(build $($key.CurrentBuild).$($key.UBR))") | Where-Object { $_ }) -join ' '
    } catch { }
    return (@($name, $build) | Where-Object { $_ }) -join ' '
}

# ==========================================================================
#  Binary validation
# ==========================================================================

function Test-WindowsExecutable {
    <#  A truncated download or an HTML error page is not a PE binary.
        Checking the "MZ" magic is cheaper and far more reliable than
        scanning the whole file for "<html>". #>
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $false }

    $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $item -or $item.Length -lt 4096) { return $false }

    $stream = $null
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        $header = [byte[]]::new(2)
        if ($stream.Read($header, 0, 2) -ne 2) { return $false }
        return ($header[0] -eq 0x4D -and $header[1] -eq 0x5A)   # 'M','Z'
    } catch {
        return $false
    } finally {
        if ($stream) { $stream.Dispose() }
    }
}

function Get-FileVersionOrNull {
    param([Parameter(Mandatory)][string]$Path)
    try {
        $raw = [System.Diagnostics.FileVersionInfo]::GetVersionInfo((Resolve-Path -LiteralPath $Path).Path).FileVersion
        if (-not $raw) { return $null }
        return [version]($raw.Trim() -replace '[^0-9\.].*$', '')
    } catch {
        return $null
    }
}

# ==========================================================================
#  Self-update
# ==========================================================================

function Invoke-SelfUpdate {
    if (-not (Test-CompiledHost)) {
        Write-Status -Level 'SKIP' -Message 'Running from source - self-update skipped'
        return
    }

    $exePath = Get-HostExecutablePath
    if (-not $exePath) {
        Write-Status -Level 'WARN' -Message 'Could not resolve own path - self-update skipped'
        return
    }

    try {
        $release = Invoke-WebRequest -Uri $script:ReleaseApiUrl -UseBasicParsing -TimeoutSec 20 `
                                     -Headers @{ 'User-Agent' = 'AsyncWindowsUpdater' } -ErrorAction Stop |
                   ConvertFrom-Json
    } catch {
        Write-Status -Level 'WARN' -Message "Update check unavailable ($($_.Exception.Message))"
        return
    }

    $asset = $release.assets | Where-Object { $_.browser_download_url -match '/update\.exe$' } | Select-Object -First 1
    if (-not $asset) {
        Write-Status -Level 'WARN' -Message 'No update.exe asset found in the latest release'
        return
    }

    $downloadUrl = $asset.browser_download_url
    # .../releases/download/<version>/update.exe
    $match = [regex]::Match($downloadUrl, '/download/([^/]+)/update\.exe$')
    if (-not $match.Success) {
        Write-Status -Level 'WARN' -Message 'Could not parse the online version'
        return
    }

    $tag = $match.Groups[1].Value -replace '^[vV]', ''
    # String comparison used to be the rule here, which made "3.10" older
    # than "3.9". Compare as real versions instead.
    try {
        $onlineVersion = [version]$tag
    } catch {
        Write-Status -Level 'WARN' -Message "Unrecognised online version tag '$tag'"
        return
    }

    if ($onlineVersion -le $script:Version) {
        Write-Status -Level 'OK' -Message "Updater is up to date (v$($script:Version))"
        return
    }

    Write-Status -Level 'WORK' -Message "Updater v$onlineVersion available - downloading"

    $stagedPath = Join-Path $env:TEMP 'async_update_new.exe'
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $stagedPath -UseBasicParsing -TimeoutSec 300 -ErrorAction Stop
    } catch {
        Write-Status -Level 'WARN' -Message "Download failed ($($_.Exception.Message)) - keeping v$($script:Version)"
        Remove-Item -LiteralPath $stagedPath -Force -ErrorAction SilentlyContinue
        return
    }

    if (-not (Test-WindowsExecutable -Path $stagedPath)) {
        Write-Status -Level 'WARN' -Message "Downloaded file is not a valid executable - keeping v$($script:Version)"
        Remove-Item -LiteralPath $stagedPath -Force -ErrorAction SilentlyContinue
        return
    }

    Write-Status -Level 'OK' -Message 'Update downloaded - restarting'

    # A running executable cannot overwrite itself: hand the swap to a short
    # helper process. The command is passed base64-encoded so that spaces,
    # quotes or apostrophes in the paths can never break the argument line.
    $stagedLiteral = $stagedPath -replace "'", "''"
    $exeLiteral    = $exePath    -replace "'", "''"

    $helper = @"
for (`$i = 0; `$i -lt 40; `$i++) {
    try {
        Copy-Item -LiteralPath '$stagedLiteral' -Destination '$exeLiteral' -Force -ErrorAction Stop
        break
    } catch { Start-Sleep -Milliseconds 500 }
}
Remove-Item -LiteralPath '$stagedLiteral' -Force -ErrorAction SilentlyContinue
Start-Process -FilePath '$exeLiteral'
"@
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($helper))

    Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded
    )

    Restore-ConsoleMode
    exit 0
}

# ==========================================================================
#  Task 1 - PowerShell modules
# ==========================================================================

function Install-RequiredModule {
    Write-Section 'PowerShell modules'

    if (Get-Module -ListAvailable -Name 'PSWindowsUpdate') {
        Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue
        Write-Status -Level 'OK' -Message 'PSWindowsUpdate already available'
        Register-Result -Task 'PowerShell modules' -Level 'OK' -Detail 'PSWindowsUpdate already available'
        return
    }

    Write-Status -Level 'WORK' -Message 'Installing PSWindowsUpdate (first run on this machine)'
    try {
        # Process scope only: never change the machine-wide execution policy.
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue

        if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet -Force -Scope AllUsers -ErrorAction Stop | Out-Null
        }

        Install-Module -Name PSWindowsUpdate -Force -Confirm:$false -Scope AllUsers -AllowClobber -ErrorAction Stop
        Import-Module PSWindowsUpdate -ErrorAction Stop

        Write-Status -Level 'OK' -Message 'PSWindowsUpdate installed'
        Register-Result -Task 'PowerShell modules' -Level 'OK' -Detail 'PSWindowsUpdate installed'
    } catch {
        Register-Result -Task 'PowerShell modules' -Level 'FAIL' -Detail $_.Exception.Message
        Stop-Script "Could not install PSWindowsUpdate: $($_.Exception.Message)"
    }
}

# ==========================================================================
#  Task 2 - Chocolatey
# ==========================================================================

function Update-ChocolateyPackages {
    Write-Section 'Chocolatey packages'

    $choco = (Get-Command 'choco.exe' -ErrorAction SilentlyContinue).Source
    if (-not $choco) {
        $candidate = Join-Path $env:ProgramData 'chocolatey\bin\choco.exe'
        if (Test-Path -LiteralPath $candidate) { $choco = $candidate }
    }

    if (-not $choco) {
        Write-Status -Level 'SKIP' -Message 'Chocolatey is not installed on this machine'
        Register-Result -Task 'Chocolatey packages' -Level 'SKIP' -Detail 'not installed'
        return
    }

    Write-Status -Level 'WORK' -Message 'Upgrading all packages'

    try {
        Enter-RawOutput
        # Echoed line by line so the operator still sees choco live, while the
        # transcript is kept in memory to build the summary line afterwards.
        $chocoOutput = & $choco upgrade all --no-progress --yes 2>&1 |
                       ForEach-Object { $text = [string]$_; Write-Host $text; $text }
        $code = $LASTEXITCODE
        Exit-RawOutput

        $upgraded = $chocoOutput | Select-String -Pattern 'Chocolatey upgraded (\d+)/' | Select-Object -First 1
        $detail = if ($upgraded) { "$($upgraded.Matches[0].Groups[1].Value) package(s) upgraded" } else { 'upgrade completed' }

        if ($code -in @(0, 1641, 3010)) {
            Write-Status -Level 'OK' -Message $detail
            Register-Result -Task 'Chocolatey packages' -Level 'OK' -Detail $detail
        } else {
            Write-Status -Level 'WARN' -Message "Chocolatey returned exit code $code"
            Register-Result -Task 'Chocolatey packages' -Level 'WARN' -Detail "exit code $code"
        }
    } catch {
        Exit-RawOutput
        Write-Status -Level 'WARN' -Message "Chocolatey update failed: $($_.Exception.Message)"
        Register-Result -Task 'Chocolatey packages' -Level 'WARN' -Detail $_.Exception.Message
    }
}

# ==========================================================================
#  Task 3 - AnyDesk (Async support client)
# ==========================================================================

function Get-AnyDeskInstaller {
    for ($attempt = 1; $attempt -le $script:AnyDeskDownloadTries; $attempt++) {
        Write-Status -Level 'WORK' -Message "Downloading Async support package (attempt $attempt/$($script:AnyDeskDownloadTries))"

        Remove-Item -LiteralPath $script:AnyDeskInstallerPath -Force -ErrorAction SilentlyContinue

        # curl.exe is used on purpose: Invoke-WebRequest is answered with a 403
        # by the CDN when the call originates from inside the compiled exe.
        & curl.exe -s -L --fail --max-time 300 `
            -A 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' `
            -o $script:AnyDeskInstallerPath $script:AnyDeskUrl 2>$null

        if (Test-WindowsExecutable -Path $script:AnyDeskInstallerPath) { return $true }

        Write-Status -Level 'WARN' -Message 'Invalid or incomplete download'
        Remove-Item -LiteralPath $script:AnyDeskInstallerPath -Force -ErrorAction SilentlyContinue
        if ($attempt -lt $script:AnyDeskDownloadTries) { Start-Sleep -Seconds 2 }
    }

    Write-Status -Level 'FAIL' -Message "Download failed after $($script:AnyDeskDownloadTries) attempts"
    return $false
}

function Remove-LegacyAnyDesk {
    $legacy = foreach ($path in $script:AnyDeskLegacyPaths) {
        Get-ChildItem -Path $path -ErrorAction SilentlyContinue
    }

    foreach ($file in $legacy) {
        Write-Status -Level 'WORK' -Message "Removing legacy installation: $($file.FullName)"
        try {
            Start-Process -FilePath $file.FullName -ArgumentList '--remove' -Wait -ErrorAction Stop
        } catch {
            Write-Status -Level 'WARN' -Message "Could not remove $($file.FullName): $($_.Exception.Message)"
        }
    }

    # Previous versions leaked the loop variable and treated it as "an old
    # install exists", which made the outcome depend on loop side effects.
    return [bool]$legacy
}

function Set-AnyDeskShortcut {
    try {
        [System.IO.File]::WriteAllBytes($script:AnyDeskShortcutPath,
                                        [Convert]::FromBase64String($script:AnyDeskShortcutB64))
        Write-Status -Level 'OK' -Message 'Desktop shortcut refreshed (CTRL + ALT + H)'
        return $true
    } catch {
        Write-Status -Level 'WARN' -Message "Could not write the desktop shortcut: $($_.Exception.Message)"
        return $false
    }
}

function Update-AnyDesk {
    Write-Section 'AnyDesk support client'

    $hadLegacy   = Remove-LegacyAnyDesk
    $isInstalled = Test-Path -LiteralPath $script:AnyDeskInstalledPath

    if (-not ($hadLegacy -or $isInstalled)) {
        Write-Status -Level 'SKIP' -Message 'Async support client is not installed on this machine'
        Register-Result -Task 'AnyDesk support client' -Level 'SKIP' -Detail 'not installed'
        return
    }

    try {
        if (-not (Get-AnyDeskInstaller)) {
            Register-Result -Task 'AnyDesk support client' -Level 'FAIL' -Detail 'download failed'
            return
        }

        $installedVersion = if ($isInstalled) { Get-FileVersionOrNull -Path $script:AnyDeskInstalledPath } else { $null }
        $availableVersion = Get-FileVersionOrNull -Path $script:AnyDeskInstallerPath

        if (-not $availableVersion) {
            Write-Status -Level 'WARN' -Message 'Could not read the downloaded version'
            Register-Result -Task 'AnyDesk support client' -Level 'WARN' -Detail 'version unreadable'
            return
        }

        $installedLabel = if ($installedVersion) { "$installedVersion" } else { 'none' }
        Write-Status -Level 'INFO' -Message "Installed: $installedLabel  -  Available: $availableVersion"

        if ($installedVersion -and $availableVersion -le $installedVersion) {
            Write-Status -Level 'OK' -Message 'Already up to date'
            Register-Result -Task 'AnyDesk support client' -Level 'OK' -Detail "up to date ($installedLabel)"
            return
        }

        Write-Status -Level 'WORK' -Message "Installing $availableVersion"
        $arguments = "--install `"$(Join-Path $env:ProgramFiles 'AnyDesk')`" --start-with-win --create-desktop-icon --remove-first"
        $process = Start-Process -FilePath $script:AnyDeskInstallerPath -ArgumentList $arguments -Wait -PassThru -ErrorAction Stop

        if ($process.ExitCode -ne 0) {
            Write-Status -Level 'WARN' -Message "Installer returned exit code $($process.ExitCode)"
            Register-Result -Task 'AnyDesk support client' -Level 'WARN' -Detail "installer exit code $($process.ExitCode)"
            return
        }

        [void](Set-AnyDeskShortcut)
        Write-Status -Level 'OK' -Message "Updated $installedLabel -> $availableVersion"
        Register-Result -Task 'AnyDesk support client' -Level 'OK' -Detail "$installedLabel -> $availableVersion"
    } catch {
        Write-Status -Level 'WARN' -Message "Update failed: $($_.Exception.Message)"
        Register-Result -Task 'AnyDesk support client' -Level 'WARN' -Detail $_.Exception.Message
    } finally {
        Remove-Item -LiteralPath $script:AnyDeskInstallerPath -Force -ErrorAction SilentlyContinue
    }
}

# ==========================================================================
#  Task 4 - Windows Update
# ==========================================================================

function Update-Windows {
    Write-Section 'Windows Update'
    Write-Status -Level 'WORK' -Message 'Searching for and installing available updates'

    $installed = @()
    try {
        Enter-RawOutput
        # The verbose stream keeps scrolling live during the download and
        # install; the result objects are captured so they can be rendered as
        # one aligned table at the end instead of dribbling out unformatted.
        if (Get-Command -Name 'Install-WindowsUpdate' -ErrorAction SilentlyContinue) {
            $installed = @(Install-WindowsUpdate -AcceptAll -Install -IgnoreReboot -Verbose -ErrorAction Stop)
        } else {
            $installed = @(Get-WUInstall -AcceptAll -Install -Verbose -ErrorAction Stop)
        }
        if ($installed.Count -gt 0) { $installed | Format-Table -AutoSize | Out-Host }
        Exit-RawOutput
    } catch {
        Exit-RawOutput
        Write-Status -Level 'FAIL' -Message "Windows Update failed: $($_.Exception.Message)"
        Register-Result -Task 'Windows Update' -Level 'FAIL' -Detail $_.Exception.Message
        return
    }

    $count  = $installed.Count
    $detail = if ($count -gt 0) { "$count update(s) installed" } else { 'no updates available' }
    Write-Status -Level 'OK' -Message $detail

    $rebootRequired = $false
    try { $rebootRequired = (Get-WURebootStatus -Silent -ErrorAction SilentlyContinue) -eq $true } catch { }

    if ($rebootRequired) {
        Write-Status -Level 'WARN' -Message 'A reboot is required to finish the installation'
        Register-Result -Task 'Windows Update' -Level 'WARN' -Detail "$detail, reboot required"
    } else {
        Register-Result -Task 'Windows Update' -Level 'OK' -Detail $detail
    }
}

# ==========================================================================
#  Main
# ==========================================================================

try {
    Assert-Administrator
    Disable-QuickEdit
    Show-Header
    Write-Host ''
    Invoke-SelfUpdate

    Install-RequiredModule
    Update-ChocolateyPackages
    Update-AnyDesk
    Update-Windows

    Complete-Run
} catch {
    Register-Result -Task 'Updater' -Level 'FAIL' -Detail $_.Exception.Message
    Stop-Script "Unexpected error: $($_.Exception.Message)"
} finally {
    Restore-ConsoleMode
}
