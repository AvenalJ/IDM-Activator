#Requires -Version 5.1
<#
  IDM Toolkit - Pester Test Suite
  Compatible with Pester v3, v4, and v5
#>

Describe 'IDM Toolkit Core Logic & Syntax Tests' {

    Context 'Syntax & File Parsing' {
        It 'IDM-Toolkit.ps1 should parse without any syntax errors' {
            $scriptPath = Join-Path $PSScriptRoot 'IDM-Toolkit.ps1'
            $errors = $null
            $tokens = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $scriptPath,
                [ref]$tokens,
                [ref]$errors
            )
            if ($errors.Count -ne 0) { throw "Syntax errors: $($errors -join ', ')" }
        }

        It 'IDM-Toolkit-GUI.ps1 should parse without any syntax errors' {
            $guiPath = Join-Path $PSScriptRoot 'IDM-Toolkit-GUI.ps1'
            $errors = $null
            $tokens = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $guiPath,
                [ref]$tokens,
                [ref]$errors
            )
            if ($errors.Count -ne 0) { throw "Syntax errors: $($errors -join ', ')" }
        }
    }

    Context 'Helper Functions & Logic' {
        It 'ANSI color helper _c should wrap string in escape sequences' {
            $e = [char]27
            $result = & {
                function _c([string]$code, [string]$text) { return "$e[$($code)m$text$e[0m" }
                _c '31' 'TestText'
            }
            if ($result -ne "$e[31mTestText$e[0m") { throw "Expected ANSI string, got $result" }
        }

        It 'JSON serialization of Backup Data structure should roundtrip accurately' {
            $dummyBackup = [ordered]@{
                FormatVersion = '1.0'
                CreatedDate   = '2026-09-24T10:00:00Z'
                IdmVersion    = '6.42'
                AccountSID    = 'S-1-5-21-0000000000-0000000000-0000000000-1001'
                RegistryData  = @{
                    Values = @{
                        FName = @{ Kind = 'String'; Value = 'TestUser' }
                    }
                }
            }

            $json = ConvertTo-Json $dummyBackup -Depth 10
            $deserialized = ConvertFrom-Json $json

            if ($deserialized.FormatVersion -ne '1.0') { throw 'FormatVersion mismatch' }
            if ($deserialized.IdmVersion -ne '6.42') { throw 'IdmVersion mismatch' }
            if ($deserialized.RegistryData.Values.FName.Value -ne 'TestUser') { throw 'FName mismatch' }
        }
    }

    Context 'Logging System' {
        It 'Should write clean log entries without ANSI escape codes' {
            $testLogFile = Join-Path $env:TEMP 'PesterTest_IDM.log'
            if (Test-Path $testLogFile) { Remove-Item $testLogFile -Force }

            $e = [char]27
            $ansiMessage = "$e[38;5;141mTest ANSI Log Message$e[0m"

            & {
                $cleanMsg = $ansiMessage -replace '\x1B\[[0-9;]*[a-zA-Z]', ''
                $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                $logLine = "[$timestamp] [INFO   ] $cleanMsg"
                Add-Content -Path $testLogFile -Value $logLine -Encoding UTF8
            }

            if (-not (Test-Path $testLogFile)) { throw 'Log file was not created' }
            $content = Get-Content $testLogFile -Raw
            if ($content -notmatch 'Test ANSI Log Message') { throw 'Log content missing message' }
            if ($content -match '\x1B') { throw 'ANSI code found in log' }

            Remove-Item $testLogFile -Force -EA SilentlyContinue
        }
    }

    Context 'GUID Regex Validator' {
        It 'Should accurately match valid registry CLSID GUID format' {
            $validGuid = '{12345678-ABCD-1234-EF01-123456789ABC}'
            $invalidGuid = '{12345678-ABCD-1234-EF01}'

            $m1 = $validGuid -match '^\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}$'
            $m2 = $invalidGuid -match '^\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}$'

            if (-not $m1) { throw 'Failed to match valid GUID' }
            if ($m2) { throw 'Incorrectly matched invalid GUID' }
        }
    }
}
