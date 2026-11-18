# Apple Music for Windows — keep Lossless Audio enabled

A one-time PowerShell workaround for the Microsoft Store version of Apple Music when **Lossless Audio turns off again after you quit and reopen the app**. Tested on one Windows installation with Apple Music **1.1540.23042.0** and Windows PowerShell 5.1. [中文说明](#中文说明)

**Upgrade check (19 November 2026).** On the same PC, after Apple Music updated to **1.1792.39942.0**, the playback preferences file still matched the file verified in September byte for byte (SHA-256). The saved Lossless setting survived the update. Playback settings in the new build’s UI and a fresh repair on that build have yet to be tested.

## When it applies

On the tested installation, the library agent wrote the selected settings to a temporary plist, then deleted it. Its final preferences file was missing. With Apple Music closed, the repair creates this file in the current user's package data:

```text
%LOCALAPPDATA%\Packages\AppleInc.AppleMusicWin_nzyj5cx40ttqa\LocalCache\Roaming\Apple Computer\Preferences\AMPLibraryAgent.exe.plist
```

The file contains three values observed in the app's own temporary preferences:

| Playback setting | Plist entry | Result in the tested app |
| --- | --- | --- |
| Lossless Audio | `losslessEnabled = true` | On |
| Streaming quality | `preferredStreamPlaybackAudioQuality = 15` | Lossless ALAC, up to 24-bit/48 kHz |
| Sound Check | `optimizeSongVolume = false` | Off |

Download quality has no entry in the repair. On the tested installation it stayed at AAC 256 kbps. The script stops if the installed version differs, if an app process is running, if the preferences directory is missing, or if the final plist already exists.

## Apply and verify

1. Download and extract this repository to a writable folder. Keep the folder for rollback.
2. Quit Apple Music normally. Open **Windows PowerShell** as your regular user in the extracted folder, alongside this README.
3. Run the following command once. Keep the directory printed in the `Backup` field.

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\repair_playback_preferences.ps1
```

4. Open Apple Music from the Start menu. In **Settings → Playback**, check Lossless Audio, streaming quality and Sound Check against the table. Quit normally, reopen and check again.

The invocation sets RemoteSigned for that PowerShell process only. If PowerShell reports that the downloaded scripts are blocked, review the two files first. On a system using RemoteSigned, you can unblock just those files with `Unblock-File -LiteralPath .\scripts\repair_playback_preferences.ps1` and `Unblock-File -LiteralPath .\scripts\restore_original_state.ps1`.

## Undo

Quit Apple Music. Substitute the backup directory from the repair output for the example path below. The directory contains a `state.json` recording that the file was originally absent.

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\restore_original_state.ps1 -BackupPath '.\backups\playback-candidate-<timestamp>'
```

Rollback archives the created plist in that backup directory and removes the live copy after verifying its hash. If Apple Music or the user has since changed the file, rollback stops so those settings are preserved.

## What was verified

On 14 September 2026, the settings reverted after a normal quit and relaunch before the repair. After a single repair, two normal launches showed Lossless Audio on, streaming at up to 24-bit/48 kHz and Sound Check off. The plist hash stayed the same. These checks cover the visible playback preferences on the tested build. The underlying reason the temporary file disappeared is unknown.

## 中文说明

适用于 Windows 商店版 Apple Music **1.1540.23042.0**。如果在设置中打开无损，正常退出再打开却又变成关闭，并且缺少上文列出的正式 plist，可使用此脚本。脚本会同时开启无损、把流播放设为最高 24 位/48 kHz，并关闭音量平衡。下载音质沿用原值。

**升级验证（2026 年 11 月 19 日）**：同一台电脑升级到 **1.1792.39942.0** 后，播放偏好文件的 SHA-256 仍与 9 月最终验证时一致，已写入的无损设置保留了下来。新版界面的重启验证，以及在新版上首次运行修复的效果，仍待实测。

1. 解压仓库到可写目录，正常退出 Apple Music。在 README 所在目录打开普通用户的 **Windows PowerShell**。
2. 运行 `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\repair_playback_preferences.ps1` 一次，记下输出中的 `Backup` 目录。版本不符或已有正式文件时，脚本会停止。
3. 从开始菜单打开 Apple Music，在「设置 → 播放」中核对无损、流播放音质和音量平衡。正常退出后再打开一次，确认设置仍然保留。
4. 如需撤销，退出应用，运行 `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\restore_original_state.ps1 -BackupPath '本次 Backup 目录'`。如果文件已有后续修改，回滚会停止并保留文件。
