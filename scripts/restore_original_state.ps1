[CmdletBinding()]
param([string]$ProjectRoot=(Split-Path $PSScriptRoot -Parent),[Parameter(Mandatory=$true)][string]$BackupPath)
# Conservative rollback for the missing-file candidate. Refuse to discard
# subsequent app/user changes; inspect and merge those separately if present.
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
if(Get-Process -Name AppleMusic,AMPLibraryAgent,SharedHelper,appdefaults -ErrorAction SilentlyContinue){throw 'Close Apple Music normally before restoring'}
$state=Get-Content -LiteralPath (Join-Path $BackupPath 'state.json') -Raw|ConvertFrom-Json
$pkg=Get-AppxPackage -Name AppleInc.AppleMusicWin
$expected=Join-Path $env:LOCALAPPDATA ('Packages\'+$pkg.PackageFamilyName+'\LocalCache\Roaming\Apple Computer\Preferences\AMPLibraryAgent.exe.plist')
if($state.Target -ne $expected -or $state.Existed -ne $false -or -not $state.AppliedSHA256){throw 'Backup does not describe this candidate'}
if(-not(Test-Path -LiteralPath $expected)){Write-Output 'Already restored: target is absent';return}
if((Get-FileHash -LiteralPath $expected -Algorithm SHA256).Hash -ne $state.AppliedSHA256){throw 'The app or user changed the plist after the candidate was applied. Refusing to delete those later changes; use a reviewed per-key merge.'}
$archive=Join-Path $BackupPath ('before-rollback-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')+'.plist')
$bytes=[IO.File]::ReadAllBytes($expected)
[IO.File]::WriteAllBytes($archive,$bytes)
if((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $state.AppliedSHA256){throw 'Rollback archive verification failed'}
[IO.File]::Delete($expected)
Write-Output 'Restored the original missing-file state; candidate bytes retained in the backup.'
