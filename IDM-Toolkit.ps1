#Requires -Version 5.1
<#
  IDM Toolkit - Internet Download Manager Management Utility
  Version 3.6 | PowerShell Edition

.SYNOPSIS
    All-in-one management utility for Internet Download Manager.
    Supports license activation, trial freeze, clean reset, backup/restore settings, and WPF GUI.

.PARAMETER Mode
    Headless mode: 'license', 'trial', 'wipe', 'backup', or 'restore'

.PARAMETER Gui
    Launch the modern WPF Graphical User Interface.

.PARAMETER LogPath
    Custom path for log file.

.PARAMETER BackupPath
    Custom path for backup JSON file (used with -Mode backup or -Mode restore).

.EXAMPLE
    .\IDM-Toolkit.ps1                    # Interactive CLI menu
    .\IDM-Toolkit.ps1 -Gui               # Modern WPF Graphical Interface
    .\IDM-Toolkit.ps1 -Mode trial        # Headless freeze
    .\IDM-Toolkit.ps1 -Mode backup       # Backup IDM settings
#>

[CmdletBinding()]
param(
    [ValidateSet('license', 'trial', 'wipe', 'backup', 'restore', 'gui')]
    [string]$Mode,

    [switch]$Gui,

    [string]$LogPath,

    [string]$BackupPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─────────────────────────────────────────────────────────────
#  Constants & Paths
# ─────────────────────────────────────────────────────────────

$APP_VERSION     = '3.6'
$APP_TITLE       = 'IDM Toolkit'
$IDM_DOMAIN      = 'internetdownloadmanager.com'
$IDM_DOWNLOAD    = "https://www.$IDM_DOMAIN/download.html"
$IDM_HELP        = 'https://github.com/AvenalJ/IDM-Activator#readme'
$HEADLESS        = [bool]$Mode

if (-not $LogPath) {
    $LogPath = Join-Path $PSScriptRoot 'IDM-Toolkit.log'
}
$script:LOG_FILE = $LogPath

# ─────────────────────────────────────────────────────────────
#  Feature 1: Structured Logging Engine
# ─────────────────────────────────────────────────────────────

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Level = 'INFO'
    )
    try {
        # Strip ANSI sequences for clean log text
        $cleanMsg = $Message -replace '\x1B\[[0-9;]*[a-zA-Z]', ''
        $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        $logLine = "[$timestamp] [$($Level.ToUpper().PadRight(7))] $cleanMsg"
        Add-Content -Path $script:LOG_FILE -Value $logLine -Encoding UTF8 -EA SilentlyContinue
    } catch {}
}

function Invoke-LogRotation {
    try {
        if (Test-Path $script:LOG_FILE) {
            $item = Get-Item $script:LOG_FILE -EA SilentlyContinue
            if ($item -and $item.Length -gt 2MB) {
                $bakPath = "$script:LOG_FILE.bak"
                Copy-Item $script:LOG_FILE $bakPath -Force -EA SilentlyContinue
                Clear-Content $script:LOG_FILE -EA SilentlyContinue
                Write-Log "Log file exceeded 2MB limit. Rotated previous log to $bakPath" 'INFO'
            }
        }
    } catch {}
}

# Run log rotation check on startup
Invoke-LogRotation
Write-Log "=== IDM Toolkit v$APP_VERSION Initialized ===" 'INFO'

# ─────────────────────────────────────────────────────────────
#  Theme Engine - ANSI color helpers
# ─────────────────────────────────────────────────────────────

# Build the ESC char once
$script:E = [char]27

# Color codes - purple/teal dark theme
$C = @{
    Pri   = '38;5;141'     # Soft purple
    Sec   = '38;5;80'      # Teal
    Acc   = '38;5;215'     # Warm amber
    Ok    = '38;5;114'     # Muted green
    Err   = '38;5;204'     # Soft red/pink
    Wrn   = '38;5;221'     # Gold
    Dim   = '38;5;245'     # Gray
    Bld   = '1;97'         # Bright white bold
    Frm   = '38;5;60'      # Dark lavender borders
    BgOk  = '48;5;28;97'   # Green bg white text
    BgErr = '48;5;160;97'  # Red bg white text
    BgWrn = '48;5;136;30'  # Gold bg dark text
    Wht   = '97'            # Bright white
    Rst   = '0'             # Reset
}

function _c([string]$code, [string]$text) {
    return "$script:E[$($code)m$text$script:E[0m"
}

function Out-Styled([string]$Text, [string]$Style, [switch]$NoNewline) {
    $rendered = _c $Style $Text
    if ($NoNewline) { Write-Host $rendered -NoNewline } else { Write-Host $rendered }
}

function Out-Badge([string]$Label, [string]$Msg, [string]$BStyle, [string]$MStyle) {
    Write-Host "   $(_c $BStyle " $Label ") $(_c $MStyle $Msg)"
    Write-Log "[$Label] $Msg" $(if ($Label -match 'ERR|FATAL') { 'ERROR' } elseif ($Label -match 'WARN') { 'WARN' } else { 'INFO' })
}

function Out-Step([string]$Sym, [string]$Text, [string]$Color) {
    if (-not $Color) { $Color = $C.Sec }
    Write-Host "   $(_c $C.Pri $Sym) $(_c $Color $Text)"
    Write-Log "$Sym $Text" 'INFO'
}

function Out-Result([string]$Tag, [string]$Detail, [bool]$OK = $true) {
    $clr = if ($OK) { $C.Ok } else { $C.Err }
    Write-Host "     $(_c $clr $Tag.PadRight(8)) $(_c $C.Dim $Detail)"
    $lvl = if ($OK) { 'INFO' } else { 'ERROR' }
    Write-Log "$Tag - $Detail" $lvl
}

function Out-Rule {
    Out-Styled ('   ' + ([string]::new([char]0x2500, 58))) $C.Frm
}

# ─────────────────────────────────────────────────────────────
#  Splash Screen and Menu
# ─────────────────────────────────────────────────────────────

function Show-Splash {
    Write-Host ''
    Out-Styled '   +======================================================+' $C.Frm
    Out-Styled '   ||                                                      ||' $C.Frm

    $art = @(
        '    ## ######  ##   ##    ########  ##   ## ## ######## '
        '    ## ##   ## ### ###       ##     ##  ##  ##    ##    '
        '    ## ##   ## ## # ##       ##     #####   ##    ##    '
        '    ## ##   ## ##   ##       ##     ##  ##  ##    ##    '
        '    ## ######  ##   ##       ##     ##   ## ##    ##    '
    )
    for ($i = 0; $i -lt $art.Count; $i++) {
        $ac = if ($i -lt 2) { $C.Bld } else { $C.Pri }
        $border = _c $C.Frm '||'
        $body = _c $ac $art[$i]
        Write-Host "   $border $body$border"
    }

    Out-Styled '   ||                                                      ||' $C.Frm
    $border = _c $C.Frm '||'
    $info = _c $C.Dim "Management Toolkit v$APP_VERSION                           "
    Write-Host "   $border   $info$border"
    Out-Styled '   +======================================================+' $C.Frm
    Write-Host ''
}

function Show-Menu {
    $bdr = $C.Frm
    Out-Styled '   .--------------------------------------------------.' $bdr
    Out-Styled '   |                                                  |' $bdr

    $lb = _c $bdr '|'
    $arrow = _c $C.Sec '>'

    $line1 = "   $lb    $arrow $(_c $C.Wht '1')  $(_c $C.Wht 'Activate License')                       $lb"
    $line2 = "   $lb    $arrow $(_c $C.Wht '2')  $(_c $C.Wht 'Freeze Trial Period')  $(_c $C.Acc '* recommended')    $lb"
    $line3 = "   $lb    $arrow $(_c $C.Wht '3')  $(_c $C.Wht 'Wipe and Reset Everything')                $lb"
    $sep1  = "   $lb    $(_c $C.Dim '..........................................')    $lb"
    $line4 = "   $lb    $arrow $(_c $C.Pri '4')  $(_c $C.Pri 'Backup IDM Settings (JSON)')               $lb"
    $line5 = "   $lb    $arrow $(_c $C.Pri '5')  $(_c $C.Pri 'Restore IDM Settings (JSON)')              $lb"
    $line6 = "   $lb    $arrow $(_c $C.Sec '6')  $(_c $C.Sec 'Launch WPF GUI Window')                    $lb"
    $sep2  = "   $lb    $(_c $C.Dim '..........................................')    $lb"
    $line7 = "   $lb    $(_c $C.Dim '+') $(_c $C.Dim '7')  $(_c $C.Dim 'View Log File')                          $lb"
    $line8 = "   $lb    $(_c $C.Dim '+') $(_c $C.Dim '8')  $(_c $C.Dim 'Get IDM Installer')                      $lb"
    $line9 = "   $lb    $(_c $C.Dim '+') $(_c $C.Dim '9')  $(_c $C.Dim 'Online Help')                             $lb"
    $line0 = "   $lb    $(_c $C.Err 'x') $(_c $C.Err '0')  $(_c $C.Err 'Quit')                                    $lb"

    Write-Host $line1
    Write-Host $line2
    Write-Host $line3
    Write-Host $sep1
    Write-Host $line4
    Write-Host $line5
    Write-Host $line6
    Write-Host $sep2
    Write-Host $line7
    Write-Host $line8
    Write-Host $line9
    Write-Host $line0

    Out-Styled '   |                                                  |' $bdr
    Out-Styled "   '--------------------------------------------------'" $bdr
}

function Read-MenuChoice {
    Write-Host ''
    Out-Styled '    > ' $C.Acc -NoNewline
    return $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character
}

function Wait-ForUser {
    Write-Host ''
    Out-Rule
    Write-Host ''
    if ($HEADLESS) { Start-Sleep -Seconds 2; return }
    Out-Styled '   Press any key to continue...' $C.Acc
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

function Wait-ForExit {
    if ($HEADLESS) { Start-Sleep -Seconds 2; return }
    Write-Host ''
    Out-Styled '   Press any key to exit...' $C.Acc
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

function Show-LogViewer {
    Clear-Host
    $Host.UI.RawUI.WindowTitle = "$APP_TITLE - Log Viewer"
    Write-Host ''
    Out-Badge 'LOGS' "Log File: $script:LOG_FILE" $C.BgOk $C.Ok
    Write-Host ''
    if (Test-Path $script:LOG_FILE) {
        $logs = Get-Content $script:LOG_FILE -Tail 40
        foreach ($line in $logs) {
            $clr = $C.Dim
            if ($line -match '\[ERROR\s*\]') { $clr = $C.Err }
            elseif ($line -match '\[WARN\s*\]') { $clr = $C.Wrn }
            elseif ($line -match '\[SUCCESS\]') { $clr = $C.Ok }
            Write-Host "   $(_c $clr $line)"
        }
    } else {
        Out-Badge 'INFO' 'No log file found yet.' $C.BgWrn $C.Wrn
    }
    Wait-ForUser
}

# ─────────────────────────────────────────────────────────────
#  Environment Probe - discover system/IDM state
# ─────────────────────────────────────────────────────────────

function New-EnvironmentProbe {
    Write-Log "Running environment probe..." 'INFO'
    $ctx = @{
        BuildNumber      = 0
        OSEdition        = ''
        CpuArch          = ''
        AccountSID       = ''
        RegistryMirrored = $false
        IdmExePath       = $null
        IdmVersion       = $null
        ClsidHKCU        = ''
        ClsidHKU         = ''
        IdmHKLM          = ''
    }

    $ctx.BuildNumber = [Environment]::OSVersion.Version.Build
    if ($ctx.BuildNumber -lt 7600) {
        throw "Unsupported Windows build $($ctx.BuildNumber). Need 7600+ (Win 7 or later)."
    }

    $osRaw = try {
        (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -EA Stop).ProductName
    } catch { 'Windows' }

    $ctx.OSEdition = if ($ctx.BuildNumber -ge 22000 -and $osRaw -match 'Windows 10') {
        $osRaw -replace 'Windows 10', 'Windows 11'
    } else {
        $osRaw
    }

    $archRaw = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -EA Stop).PROCESSOR_ARCHITECTURE
    $ctx.CpuArch = if ($archRaw -eq 'AMD64' -or $archRaw -eq 'IA64') { 'x64' } else { $archRaw }

    $ctx.AccountSID = Resolve-UserSID
    $hkuSoftware = "Registry::HKEY_USERS\$($ctx.AccountSID)\Software"
    if (-not (Test-Path $hkuSoftware)) {
        throw "SID $($ctx.AccountSID) is not loadable in HKU."
    }

    $ctx.RegistryMirrored = Test-RegistryMirror -SID $ctx.AccountSID

    if ($ctx.CpuArch -eq 'x86') {
        $ctx.ClsidHKCU = 'HKCU:\Software\Classes\CLSID'
        $ctx.ClsidHKU  = "Registry::HKEY_USERS\$($ctx.AccountSID)\Software\Classes\CLSID"
        $ctx.IdmHKLM   = 'HKLM:\Software\Internet Download Manager'
    } else {
        $ctx.ClsidHKCU = 'HKCU:\Software\Classes\Wow6432Node\CLSID'
        $ctx.ClsidHKU  = "Registry::HKEY_USERS\$($ctx.AccountSID)\Software\Classes\Wow6432Node\CLSID"
        $ctx.IdmHKLM   = 'HKLM:\SOFTWARE\Wow6432Node\Internet Download Manager'
    }

    $ctx.IdmExePath = Resolve-IdmExecutable -SID $ctx.AccountSID -Arch $ctx.CpuArch
    $ctx.IdmVersion = Resolve-IdmVersion -SID $ctx.AccountSID

    Assert-ClsidAccess -Path $ctx.ClsidHKU

    Write-Log "Environment probe complete. OS=$($ctx.OSEdition), Arch=$($ctx.CpuArch), IDM Vers=$($ctx.IdmVersion)" 'INFO'
    return $ctx
}

function Resolve-UserSID {
    try {
        $user = (Get-CimInstance Win32_ComputerSystem -EA Stop).UserName
        $acct = [System.Security.Principal.NTAccount]::new($user)
        return $acct.Translate([System.Security.Principal.SecurityIdentifier]).Value
    } catch {}

    try {
        $sess = (Get-Process -Id $PID).SessionId
        $exp  = Get-Process explorer -EA Stop | Where-Object { $_.SessionId -eq $sess } | Select-Object -First 1
        $wmi  = Get-CimInstance Win32_Process -Filter "ProcessID=$($exp.Id)" -EA Stop
        return (Invoke-CimMethod -InputObject $wmi -MethodName GetOwnerSid -EA Stop).Sid
    } catch {}

    throw 'Unable to determine current user SID.'
}

function Test-RegistryMirror([string]$SID) {
    $sentinel = 'HKCU:\__IDMToolkit_SyncTest__'
    $mirror   = "Registry::HKEY_USERS\${SID}\__IDMToolkit_SyncTest__"
    try {
        New-Item $sentinel -Force -EA Stop | Out-Null
        $synced = Test-Path $mirror
        Remove-Item $sentinel -Force -EA SilentlyContinue
        Remove-Item $mirror   -Force -EA SilentlyContinue
        return $synced
    }
    catch {
        Remove-Item $sentinel -Force -EA SilentlyContinue
        return $false
    }
}

function Resolve-IdmExecutable([string]$SID, [string]$Arch) {
    $dmKey = "Registry::HKEY_USERS\${SID}\Software\DownloadManager"
    if (Test-Path $dmKey) {
        $custom = (Get-ItemProperty $dmKey -EA SilentlyContinue).ExePath
        if ($custom -and (Test-Path $custom)) { return $custom }
    }
    $default = if ($Arch -eq 'x64') {
        "${env:ProgramFiles(x86)}\Internet Download Manager\IDMan.exe"
    } else {
        "$env:ProgramFiles\Internet Download Manager\IDMan.exe"
    }
    if (Test-Path $default) { return $default }
    return $null
}

function Resolve-IdmVersion([string]$SID) {
    try {
        $dmKey = "Registry::HKEY_USERS\${SID}\Software\DownloadManager"
        $raw = (Get-ItemProperty $dmKey -EA Stop).idmvers
        if ($raw) { return $raw.TrimStart('v', 'V') }
        return $null
    } catch { return $null }
}

function Assert-ClsidAccess([string]$Path) {
    $probe = Join-Path $Path '__IDMToolkit_AccessTest__'
    try {
        New-Item $probe -Force -EA Stop | Out-Null
        Remove-Item $probe -Force -EA SilentlyContinue
    }
    catch {
        throw "Cannot write to CLSID path: $Path"
    }
}

# ─────────────────────────────────────────────────────────────
#  Admin Elevation
# ─────────────────────────────────────────────────────────────

function Request-Admin {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        try {
            $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
            if ($Mode) { $argList += " -Mode $Mode" }
            if ($Gui)  { $argList += " -Gui" }
            Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
            exit
        }
        catch {
            Write-Host ''
            Out-Badge 'ERROR' 'This script requires administrator privileges.' $C.BgErr $C.Err
            Write-Host '   Right-click and select "Run as administrator".'
            Wait-ForExit
            exit 1
        }
    }
}

# ─────────────────────────────────────────────────────────────
#  Feature 2: Backup & Restore IDM Settings Engine
# ─────────────────────────────────────────────────────────────

function Export-IDMBackup {
    param(
        [hashtable]$Ctx,
        [string]$TargetFile
    )

    if (-not $TargetFile) {
        $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
        $TargetFile = Join-Path $PSScriptRoot "IDM_Backup_$ts.json"
    }

    Out-Step '+' "Exporting IDM configuration to $TargetFile..."

    $dmKey = "Registry::HKEY_USERS\$($Ctx.AccountSID)\Software\DownloadManager"
    if (-not (Test-Path $dmKey)) {
        Out-Badge 'ERROR' "IDM registry key not found at $dmKey" $C.BgErr $C.Err
        return $null
    }

    function Get-RegistryTreeData([string]$Path) {
        $tree = @{
            Values  = @{}
            SubKeys = @{}
        }
        if (-not (Test-Path $Path)) { return $tree }

        $item = Get-Item -LiteralPath $Path -EA Stop
        foreach ($vName in $item.GetValueNames()) {
            try {
                $vKind = $item.GetValueKind($vName).ToString()
                $vRaw  = $item.GetValue($vName, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                $tree.Values[$vName] = @{
                    Kind  = $vKind
                    Value = $vRaw
                }
            } catch {}
        }
        foreach ($sName in $item.GetSubKeyNames()) {
            $subPath = Join-Path $Path $sName
            $tree.SubKeys[$sName] = Get-RegistryTreeData -Path $subPath
        }
        return $tree
    }

    $backupObj = [ordered]@{
        FormatVersion = '1.0'
        CreatedDate   = (Get-Date).ToString('o')
        IdmVersion    = $Ctx.IdmVersion
        AccountSID    = $Ctx.AccountSID
        RegistryData  = Get-RegistryTreeData -Path $dmKey
    }

    $json = ConvertTo-Json $backupObj -Depth 12
    Set-Content -Path $TargetFile -Value $json -Encoding UTF8 -Force
    Out-Result 'Exported' $TargetFile $true
    Write-Log "IDM Settings successfully exported to $TargetFile" 'SUCCESS'
    return $TargetFile
}

function Import-IDMBackup {
    param(
        [hashtable]$Ctx,
        [string]$SourceFile
    )

    if (-not $SourceFile -or -not (Test-Path $SourceFile)) {
        Out-Badge 'ERROR' "Backup file not found: $SourceFile" $C.BgErr $C.Err
        return $false
    }

    Out-Step '+' "Restoring IDM configuration from $SourceFile..."

    try {
        $rawJson = Get-Content -Path $SourceFile -Raw -Encoding UTF8
        $backupObj = ConvertFrom-Json $rawJson

        if (-not $backupObj.RegistryData) {
            Out-Badge 'ERROR' 'Invalid backup file structure (missing RegistryData).' $C.BgErr $C.Err
            return $false
        }

        $dmKey = "Registry::HKEY_USERS\$($Ctx.AccountSID)\Software\DownloadManager"

        function Restore-RegistryTreeData([string]$Path, $node) {
            if (-not (Test-Path $Path)) {
                New-Item -Path $Path -Force -EA Stop | Out-Null
            }
            if ($node.Values) {
                foreach ($prop in $node.Values.PSObject.Properties) {
                    $valName = $prop.Name
                    $valMeta = $prop.Value
                    $kind    = if ($valMeta.Kind) { $valMeta.Kind } else { 'String' }
                    $val     = $valMeta.Value
                    Set-ItemProperty -Path $Path -Name $valName -Value $val -Type $kind -Force -EA SilentlyContinue
                }
            }
            if ($node.SubKeys) {
                foreach ($subProp in $node.SubKeys.PSObject.Properties) {
                    $subName = $subProp.Name
                    $subNode = $subProp.Value
                    $subPath = Join-Path $Path $subName
                    Restore-RegistryTreeData -Path $subPath -node $subNode
                }
            }
        }

        Restore-RegistryTreeData -Path $dmKey -node $backupObj.RegistryData
        Out-Result 'Restored' "IDM Settings imported from $SourceFile" $true
        Write-Log "IDM Settings successfully restored from $SourceFile" 'SUCCESS'
        return $true
    }
    catch {
        Out-Badge 'ERROR' "Failed to restore backup: $($_.Exception.Message)" $C.BgErr $C.Err
        Write-Log "Failed to restore backup: $($_.Exception.Message)" 'ERROR'
        return $false
    }
}

function Invoke-BackupUI {
    param([hashtable]$Ctx)
    Clear-Host
    $Host.UI.RawUI.WindowTitle = "$APP_TITLE - Backup Settings"
    Write-Host ''
    Out-Badge 'BACKUP' 'Exporting IDM settings to JSON...' $C.BgOk $C.Ok
    Write-Host ''
    $path = Export-IDMBackup -Ctx $Ctx -TargetFile $BackupPath
    if ($path) {
        Write-Host ''
        Out-Badge 'DONE' "Backup saved to: $path" $C.BgOk $C.Ok
    }
    Wait-ForUser
}

function Invoke-RestoreUI {
    param([hashtable]$Ctx)
    Clear-Host
    $Host.UI.RawUI.WindowTitle = "$APP_TITLE - Restore Settings"
    Write-Host ''
    Out-Badge 'RESTORE' 'Restoring IDM settings from JSON...' $C.BgOk $C.Ok
    Write-Host ''
    $fileToRestore = $BackupPath
    if (-not $fileToRestore) {
        $backups = Get-ChildItem -Path $PSScriptRoot -Filter 'IDM_Backup_*.json' | Sort-Object LastWriteTime -Descending
        if ($backups) {
            $fileToRestore = $backups[0].FullName
            Out-Step '*' "Found recent backup: $($backups[0].Name)"
        } else {
            Out-Badge 'ERROR' 'No backup JSON files found in script folder.' $C.BgErr $C.Err
            Wait-ForUser; return
        }
    }
    $ok = Import-IDMBackup -Ctx $Ctx -SourceFile $fileToRestore
    Wait-ForUser
}

# ─────────────────────────────────────────────────────────────
#  Registry Operations
# ─────────────────────────────────────────────────────────────

function Export-RegistrySnapshot {
    param([hashtable]$Ctx)

    Out-Step '+' 'Saving registry snapshot...'

    $ts   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $dest = Join-Path $env:SystemRoot 'Temp'
    if (-not (Test-Path $dest)) { New-Item $dest -ItemType Directory -Force | Out-Null }

    $hkcuFlat = $Ctx.ClsidHKCU -replace '^HKCU:\\?', 'HKCU\'
    $file1 = Join-Path $dest "IDMToolkit_HKCU_CLSID_$ts.reg"
    & reg.exe export $hkcuFlat $file1 /y 2>$null | Out-Null
    Out-Result 'Saved' $file1

    if (-not $Ctx.RegistryMirrored) {
        $hkuFlat = ($Ctx.ClsidHKU -replace '^Registry::HKEY_USERS', 'HKU') -replace '\\\\', '\'
        $file2 = Join-Path $dest "IDMToolkit_HKU_CLSID_$ts.reg"
        & reg.exe export $hkuFlat $file2 /y 2>$null | Out-Null
        Out-Result 'Saved' $file2
    }
}

function Clear-IdmUserData {
    param([hashtable]$Ctx)

    Write-Host ''
    Out-Step 'x' 'Purging IDM user data...'
    Write-Host ''

    $props = @('FName','LName','Email','Serial','scansk','tvfrdt',
               'radxcnt','LstCheck','ptrk_scdt','LastCheckQU')

    $paths = @('HKCU:\Software\DownloadManager')
    if (-not $Ctx.RegistryMirrored) {
        $paths += "Registry::HKEY_USERS\$($Ctx.AccountSID)\Software\DownloadManager"
    }

    foreach ($regPath in $paths) {
        if (-not (Test-Path $regPath)) { continue }
        foreach ($name in $props) {
            $exists = Get-ItemProperty $regPath -Name $name -EA SilentlyContinue
            if (-not $exists) { continue }
            try {
                Remove-ItemProperty $regPath -Name $name -Force -EA Stop
                Out-Result 'Removed' "$regPath > $name"
            }
            catch {
                Out-Result 'FAILED' "$regPath > $name" -OK $false
            }
        }
    }

    if (Test-Path $Ctx.IdmHKLM) {
        try {
            Remove-Item $Ctx.IdmHKLM -Recurse -Force -EA Stop
            Out-Result 'Removed' ($Ctx.IdmHKLM -replace '^HKLM:\\?', 'HKLM\')
        }
        catch {
            Out-Result 'FAILED' ($Ctx.IdmHKLM -replace '^HKLM:\\?', 'HKLM\') -OK $false
        }
    }
}

function Set-DriverFlag {
    param([hashtable]$Ctx)

    Write-Host ''
    Out-Step '+' 'Setting driver integration flag...'
    Write-Host ''

    try {
        if (-not (Test-Path $Ctx.IdmHKLM)) {
            New-Item $Ctx.IdmHKLM -Force -EA Stop | Out-Null
        }
        Set-ItemProperty $Ctx.IdmHKLM -Name 'AdvIntDriverEnabled2' -Value 1 -Type DWord -Force -EA Stop
        $display = ($Ctx.IdmHKLM -replace '^HKLM:\\?','HKLM\') + '\AdvIntDriverEnabled2 = 1'
        Out-Result 'Set' $display
    }
    catch {
        Out-Result 'FAILED' "$($Ctx.IdmHKLM)\AdvIntDriverEnabled2" -OK $false
    }
}

function Write-FakeRegistration {
    param([hashtable]$Ctx)

    Write-Host ''
    Out-Step '*' 'Generating registration data...'
    Write-Host ''

    $fn = Get-Random -Minimum 1000 -Maximum 9999
    $ln = Get-Random -Minimum 1000 -Maximum 9999
    $em = "$fn.$ln@tonec.com"

    $pool = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    $raw  = -join (1..20 | ForEach-Object { $pool[(Get-Random -Maximum $pool.Length)] })
    $sn   = '{0}-{1}-{2}-{3}' -f $raw.Substring(0,5), $raw.Substring(5,5), $raw.Substring(10,5), $raw.Substring(15,5)

    $payload = [ordered]@{
        FName  = "$fn"
        LName  = "$ln"
        Email  = $em
        Serial = $sn
    }

    $targets = @('HKCU:\SOFTWARE\DownloadManager')
    if (-not $Ctx.RegistryMirrored) {
        $targets += "Registry::HKEY_USERS\$($Ctx.AccountSID)\SOFTWARE\DownloadManager"
    }

    foreach ($t in $targets) {
        if (-not (Test-Path $t)) { New-Item $t -Force | Out-Null }
        foreach ($kv in $payload.GetEnumerator()) {
            try {
                Set-ItemProperty $t -Name $kv.Key -Value $kv.Value -Type String -Force -EA Stop
                Out-Result 'Written' "$($kv.Key) = $($kv.Value)"
            }
            catch {
                Out-Result 'FAILED' "$t > $($kv.Key)" -OK $false
            }
        }
    }
}

# ─────────────────────────────────────────────────────────────
#  CLSID Key Analysis and Locking Engine
# ─────────────────────────────────────────────────────────────

function Get-SuspiciousGuids {
    param([hashtable]$Ctx)

    Out-Step '*' 'Scanning registry for suspicious CLSIDs...'

    $targets = @(
        @{ Scope = 'HKCU'; Path = $Ctx.ClsidHKCU }
    )
    if (-not $Ctx.RegistryMirrored) {
        $targets += @{ Scope = 'HKU'; Path = $Ctx.ClsidHKU }
    }

    $guidMap = @{}

    foreach ($t in $targets) {
        if (-not (Test-Path $t.Path)) { continue }
        $keys = Get-ChildItem $t.Path -EA SilentlyContinue
        foreach ($k in $keys) {
            $g = $k.PSChildName
            if ($g -notmatch '^\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}$') { continue }

            $subItems = @(Get-ChildItem $k.PSPath -EA SilentlyContinue)
            if ($subItems.Count -ne 0) { continue }

            $item   = Get-ItemProperty $k.PSPath -EA SilentlyContinue
            if (-not $item) { continue }
            $pNames = @($item.psobject.Properties.Name | Where-Object { $_ -notmatch '^PS' })
            if ($pNames.Count -ne 1 -or $pNames[0] -ne '(default)') { continue }

            $val = $item.'(default)'
            if ($val -is [byte[]] -and ($val.Length -eq 12 -or $val.Length -eq 0)) {
                $guidMap[$g] = $true
            }
        }
    }

    $found = @($guidMap.Keys)
    Out-Result 'Scanned' "$($found.Length) suspicious GUID(s) matched"
    return [string[]]$found
}

function Invoke-GuidOperation {
    param(
        [hashtable]$Ctx,
        [AllowNull()][AllowEmptyCollection()][string[]]$Guids,
        [ValidateSet('Lock', 'Delete')][string]$Op,
        [bool]$AutoSwitch = $false
    )

    if (-not $Guids -or $Guids.Length -eq 0) { return }
    $gList = @($Guids)

    Write-Host ''
    Out-Step '*' "Executing $Op on $($gList.Length) GUID(s)..."
    Write-Host ''

    $paths = @($Ctx.ClsidHKCU)
    if (-not $Ctx.RegistryMirrored) { $paths += $Ctx.ClsidHKU }

    foreach ($g in $gList) {
        foreach ($base in $paths) {
            $full = Join-Path $base $g
            if (-not (Test-Path $full)) {
                if ($Op -eq 'Lock') {
                    try { New-Item $full -Force -EA Stop | Out-Null } catch { continue }
                } else { continue }
            }

            if ($Op -eq 'Lock') {
                $ok = Set-RegistryAccess -Path $full -Deny
                if (-not $ok -and $AutoSwitch) {
                    Out-Result 'Switch' "Access denied on $g -> switching to Delete" -OK $false
                    Remove-Item $full -Recurse -Force -EA SilentlyContinue
                    Out-Result 'Deleted' $g
                } else {
                    Out-Result 'Locked' $g
                }
            } else {
                Set-RegistryAccess -Path $full -Grant
                Remove-Item $full -Recurse -Force -EA SilentlyContinue
                Out-Result 'Deleted' $g
            }
        }
    }
}

function Set-RegistryAccess {
    param(
        [string]$Path,
        [switch]$Deny,
        [switch]$Grant
    )
    try {
        $acl  = Get-Acl $Path -EA Stop
        $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $rule = [System.Security.AccessControl.RegistryAccessRule]::new(
            $user,
            [System.Security.AccessControl.RegistryRights]::FullControl,
            [System.Security.AccessControl.AccessControlType]::Deny
        )

        if ($Deny) {
            $acl.SetAccessRule($rule)
        } else {
            $acl.RemoveAccessRule($rule) | Out-Null
        }

        Set-Acl $Path $acl -EA Stop
        return $true
    }
    catch {
        return $false
    }
}

# ─────────────────────────────────────────────────────────────
#  Network Connectivity & File Probe
# ─────────────────────────────────────────────────────────────

function Test-IdmConnectivity {
    Out-Step '*' "Checking network reachability to $IDM_DOMAIN..."
    try {
        $res = Test-Connection -ComputerName $IDM_DOMAIN -Count 1 -Quiet -EA Stop
        if ($res) {
            Out-Result 'Online' "$IDM_DOMAIN is reachable"
            return $true
        }
    } catch {}

    try {
        $req = [System.Net.WebRequest]::Create("https://$IDM_DOMAIN")
        $req.Timeout = 5000
        $resp = $req.GetResponse()
        $resp.Close()
        Out-Result 'Online' "$IDM_DOMAIN (HTTP) reachable"
        return $true
    } catch {}

    Out-Result 'Offline' "Cannot reach $IDM_DOMAIN" -OK $false
    return $false
}

function Invoke-IdmFileProbe {
    param([hashtable]$Ctx)

    Write-Host ''
    Out-Step '*' 'Triggering IDM file probe for CLSID generation...'
    Write-Host ''

    $probeUrls = @(
        'https://www.internetdownloadmanager.com/images/idm_box_min.png'
        'https://www.internetdownloadmanager.com/register/new_faq/pictures/idm_options_downloads.png'
    )

    $tempFiles = @()
    $tempDir   = $env:TEMP

    foreach ($u in $probeUrls) {
        $fileName = "IDMProbe_" + [Guid]::NewGuid().ToString('N') + '.png'
        $fullPath = Join-Path $tempDir $fileName
        $tempFiles += $fullPath

        Out-Result 'Probe' "Requesting download: $(Split-Path $u -Leaf)"
        & $Ctx.IdmExePath /d $u /p $tempDir /f $fileName /q /n | Out-Null
        Start-Sleep -Milliseconds 600
    }

    Start-Sleep -Seconds 2
    Stop-Process -Name IDMan -Force -EA SilentlyContinue

    foreach ($tf in $tempFiles) {
        Remove-Item $tf -Force -EA SilentlyContinue
    }

    return $true
}

# ─────────────────────────────────────────────────────────────
#  Workflows: License, Trial Freeze, Wipe
# ─────────────────────────────────────────────────────────────

function Invoke-License {
    param([hashtable]$Ctx)

    Clear-Host
    $Host.UI.RawUI.WindowTitle = "$APP_TITLE - License Activation"
    Write-Host ''
    Out-Badge 'LICENSE' 'Starting registration process...' $C.BgOk $C.Ok
    Write-Host ''

    if (-not $Ctx.IdmExePath -or -not (Test-Path $Ctx.IdmExePath)) {
        Out-Badge 'ERROR' 'IDM is not installed.' $C.BgErr $C.Err
        Write-Host "   $(_c $C.Dim "Download: $IDM_DOWNLOAD")"
        Wait-ForUser; return
    }

    if (-not (Test-IdmConnectivity)) {
        Out-Badge 'ERROR' "Cannot reach $IDM_DOMAIN" $C.BgErr $C.Err
        Wait-ForUser; return
    }

    Write-Host "   $(_c $C.Dim "$($Ctx.OSEdition) | Build $($Ctx.BuildNumber) | $($Ctx.CpuArch) | IDM $($Ctx.IdmVersion)")"
    Write-Host ''

    Stop-Process -Name IDMan -Force -EA SilentlyContinue
    Export-RegistrySnapshot -Ctx $Ctx
    Clear-IdmUserData       -Ctx $Ctx
    Set-DriverFlag          -Ctx $Ctx
    Write-FakeRegistration  -Ctx $Ctx

    $probeOK = Invoke-IdmFileProbe -Ctx $Ctx
    if (-not $probeOK) {
        Out-Badge 'ERROR' 'File probe failed. IDM did not download test files.' $C.BgErr $C.Err
        Write-Host "   $(_c $C.Dim "Help: $IDM_HELP")"
        Wait-ForUser; return
    }

    $guids = Get-SuspiciousGuids -Ctx $Ctx
    Invoke-GuidOperation -Ctx $Ctx -Guids $guids -Op Lock

    Write-Host ''
    Out-Badge 'DONE' 'License activation completed.' $C.BgOk $C.Ok
    Write-Host "   $(_c $C.Dim 'If a fake serial screen appears, try Freeze Trial instead.')"
    Wait-ForUser
}

function Invoke-TrialFreeze {
    param([hashtable]$Ctx)

    Clear-Host
    $Host.UI.RawUI.WindowTitle = "$APP_TITLE - Trial Freeze"
    Write-Host ''
    Out-Badge 'FREEZE' 'Starting trial freeze...' $C.BgOk $C.Ok
    Write-Host ''

    if (-not $Ctx.IdmExePath -or -not (Test-Path $Ctx.IdmExePath)) {
        Out-Badge 'ERROR' 'IDM is not installed.' $C.BgErr $C.Err
        Write-Host "   $(_c $C.Dim "Download: $IDM_DOWNLOAD")"
        Wait-ForUser; return
    }

    if (-not (Test-IdmConnectivity)) {
        Out-Badge 'ERROR' "Cannot reach $IDM_DOMAIN" $C.BgErr $C.Err
        Wait-ForUser; return
    }

    Write-Host "   $(_c $C.Dim "$($Ctx.OSEdition) | Build $($Ctx.BuildNumber) | $($Ctx.CpuArch) | IDM $($Ctx.IdmVersion)")"
    Write-Host ''

    Stop-Process -Name IDMan -Force -EA SilentlyContinue
    Export-RegistrySnapshot -Ctx $Ctx
    Clear-IdmUserData       -Ctx $Ctx
    Set-DriverFlag          -Ctx $Ctx

    $g1 = Get-SuspiciousGuids -Ctx $Ctx
    Invoke-GuidOperation -Ctx $Ctx -Guids $g1 -Op Lock -AutoSwitch $true

    $probeOK = Invoke-IdmFileProbe -Ctx $Ctx
    if (-not $probeOK) {
        Out-Badge 'ERROR' 'File probe failed. IDM did not download test files.' $C.BgErr $C.Err
        Write-Host "   $(_c $C.Dim "Help: $IDM_HELP")"
        Wait-ForUser; return
    }

    $g2 = Get-SuspiciousGuids -Ctx $Ctx
    Invoke-GuidOperation -Ctx $Ctx -Guids $g2 -Op Lock

    Write-Host ''
    Out-Badge 'DONE' 'Trial period frozen for lifetime.' $C.BgOk $C.Ok
    Write-Host "   $(_c $C.Dim 'If IDM shows a registration popup, reinstall IDM first.')"
    Wait-ForUser
}

function Invoke-Wipe {
    param([hashtable]$Ctx)

    Clear-Host
    $Host.UI.RawUI.WindowTitle = "$APP_TITLE - Reset Everything"
    Write-Host ''
    Out-Badge 'RESET' 'Starting clean reset...' $C.BgWrn $C.Wrn
    Write-Host ''

    Stop-Process -Name IDMan -Force -EA SilentlyContinue
    Export-RegistrySnapshot -Ctx $Ctx

    $guids = Get-SuspiciousGuids -Ctx $Ctx
    Invoke-GuidOperation -Ctx $Ctx -Guids $guids -Op Delete

    Clear-IdmUserData -Ctx $Ctx

    Write-Host ''
    Out-Badge 'DONE' 'All registration entries and trial locks wiped.' $C.BgOk $C.Ok
    Write-Host "   $(_c $C.Dim 'You now have a fresh 30-day trial.')"
    Wait-ForUser
}

function Show-WpfGui {
    $guiScript = Join-Path $PSScriptRoot 'IDM-Toolkit-GUI.ps1'
    if (Test-Path $guiScript) {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-STA -NoProfile -ExecutionPolicy Bypass -File `"$guiScript`""
    } else {
        Out-Badge 'ERROR' "GUI script not found at $guiScript" $C.BgErr $C.Err
        Wait-ForUser
    }
}

# ─────────────────────────────────────────────────────────────
#  Entry Point
# ─────────────────────────────────────────────────────────────

try {
    Request-Admin

    if ($Gui) {
        Show-WpfGui
        exit 0
    }

    try {
        $ui = $Host.UI.RawUI
        $bs = $ui.BufferSize; $ws = $ui.WindowSize
        $bs.Width  = [Math]::Max($bs.Width, 76)
        $bs.Height = [Math]::Max($bs.Height, 300)
        $ws.Width  = [Math]::Max($ws.Width, 76)
        $ws.Height = [Math]::Max($ws.Height, 32)
        $ui.BufferSize = $bs; $ui.WindowSize = $ws
    } catch {}

    Clear-Host
    $Host.UI.RawUI.WindowTitle = "$APP_TITLE v$APP_VERSION"

    Write-Host ''
    Out-Step '*' 'Initialising environment probe...'
    Write-Host ''

    $env_ctx = New-EnvironmentProbe

    if (-not $Mode) {
        Show-WpfGui
        exit 0
    }

    if ($Mode) {
        switch ($Mode) {
            'license' { Invoke-License     -Ctx $env_ctx }
            'trial'   { Invoke-TrialFreeze -Ctx $env_ctx }
            'wipe'    { Invoke-Wipe        -Ctx $env_ctx }
            'backup'  { Invoke-BackupUI    -Ctx $env_ctx }
            'restore' { Invoke-RestoreUI   -Ctx $env_ctx }
            'gui'     { Show-WpfGui }
        }
        exit 0
    }

    while ($true) {
        Clear-Host
        $Host.UI.RawUI.WindowTitle = "$APP_TITLE v$APP_VERSION"
        Show-Splash
        Show-Menu
        $key = Read-MenuChoice

        switch ($key) {
            '1' { Invoke-License     -Ctx $env_ctx }
            '2' { Invoke-TrialFreeze -Ctx $env_ctx }
            '3' { Invoke-Wipe        -Ctx $env_ctx }
            '4' { Invoke-BackupUI    -Ctx $env_ctx }
            '5' { Invoke-RestoreUI   -Ctx $env_ctx }
            '6' { Show-WpfGui }
            '7' { Show-LogViewer }
            '8' { Start-Process $IDM_DOWNLOAD }
            '9' { Start-Process $IDM_HELP }
            '0' { exit 0 }
        }
    }
}
catch {
    Write-Host ''
    Out-Badge 'FATAL' $_.Exception.Message $C.BgErr $C.Err
    Write-Host ''
    Write-Host "   $(_c $C.Dim $_.ScriptStackTrace)"
    Wait-ForExit
    exit 1
}
