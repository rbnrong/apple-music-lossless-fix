[CmdletBinding()]
param([string]$ProjectRoot=(Split-Path $PSScriptRoot -Parent))
# One-time persisted-configuration repair, verified on the recorded version.
# This is deliberately limited
# to a missing final plist. It never overwrites an existing preference file.
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$pkg=Get-AppxPackage -Name AppleInc.AppleMusicWin
if(-not $pkg -or $pkg.Version.ToString() -ne '1.1540.23042.0'){throw 'This repair has only been verified on Apple Music 1.1540.23042.0'}
$running=@(Get-Process -Name AppleMusic,AMPLibraryAgent,SharedHelper,appdefaults -ErrorAction SilentlyContinue)
if($running.Count){throw 'Close Apple Music normally and wait for its package processes to exit before applying this candidate'}
$directory=Join-Path $env:LOCALAPPDATA ('Packages\'+$pkg.PackageFamilyName+'\LocalCache\Roaming\Apple Computer\Preferences')
$target=Join-Path $directory 'AMPLibraryAgent.exe.plist'
if(-not(Test-Path -LiteralPath $directory -PathType Container)){throw 'The traced preference directory no longer exists'}
if(Test-Path -LiteralPath $target){throw 'Final plist already exists; inspect and back it up before any further action. This repair will not overwrite it.'}
$timestamp=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
$backup=Join-Path $ProjectRoot ('backups\playback-candidate-'+$timestamp)
$null=New-Item -ItemType Directory -Path $backup
$state=[pscustomobject]@{
    TimeUtc=[DateTime]::UtcNow.ToString('o');PackageFullName=$pkg.PackageFullName;
    Target=$target;Existed=$false;OriginalSHA256=$null;AppliedSHA256=$null;Status='BackedUp';
    Entries=@(
        [pscustomobject]@{Name='optimizeSongVolume';Value=$false;OriginalPresent=$false},
        [pscustomobject]@{Name='losslessEnabled';Value=$true;OriginalPresent=$false},
        [pscustomobject]@{Name='preferredStreamPlaybackAudioQuality';Value=15;OriginalPresent=$false}
    )
}
$stateFile=Join-Path $backup 'state.json'
$state|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $stateFile -Encoding UTF8
# Standard XML property list, containing only the three observed audio fields.
# Quality 15 preserves the desired session's observed streaming choice.
$xml=@'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>optimizeSongVolume</key><false/>
<key>losslessEnabled</key><true/>
<key>preferredStreamPlaybackAudioQuality</key><integer>15</integer>
</dict></plist>
'@
$bytes=[Text.UTF8Encoding]::new($false).GetBytes($xml)
$sha=[Security.Cryptography.SHA256]::Create()
try{$expected=[BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','')}finally{$sha.Dispose()}
$state.AppliedSHA256=$expected
$state|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $stateFile -Encoding UTF8
# CreateNew makes the absence precondition atomic. The live directory retains
# its original NTFS attributes, including encryption; no ACL is changed.
$stream=[IO.FileStream]::new($target,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
if((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $expected){throw 'Preference write did not verify; retain backup and inspect before continuing'}
$state.Status='AppliedAwaitingUIVerification'
$state|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $stateFile -Encoding UTF8
[pscustomobject]@{Status=$state.Status;Target=$target;Backup=$backup;SHA256=$expected}|ConvertTo-Json
