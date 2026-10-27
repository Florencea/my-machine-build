# My Machine Build (macOS & Windows 11)

Unified cross-platform development environment, PowerShell 7 (`pwsh`) CLI suite, and Antigravity Plugin bundles for **macOS** and **Windows 11**.

## Automated Setup Scripts

### macOS (Zsh Bootstrap)

```sh
./scripts/install.sh
```

### Windows 11 (PowerShell 5.1 & PowerShell 7 Compatible)

```powershell
.\scripts\install.ps1
```

## Table of Contents

- [Automated Setup Scripts](#automated-setup-scripts)
- [Extension Configs](#extension-configs)
- [Cross-Platform Custom CLI Tools (`cli/*.ps1`)](#cross-platform-custom-cli-tools-clips1)
  - [`webread`](#webread)
  - [`ua`](#ua)
  - [`up`](#up)
  - [`unodev`](#unodev)
  - [`mkclp`](#mkclp)
  - [`mkgif`](#mkgif)
  - [`mdig`](#mdig)
  - [`clall` / `ebk` / `rea` / `mmb`](#clall--ebk--rea--mmb)
- [Antigravity Plugins (`plugins/`)](#antigravity-plugins-plugins)
- [Browser & DevTools Note (Cross-Platform)](#browser--devtools-note-cross-platform)
  - [Pagetual Rules](#pagetual-rules)
  - [Microsoft Edge for DevTools Device Profile](#microsoft-edge-for-devtools-device-profile)
- [Media & Encoding Note](#media--encoding-note)
  - [Hardware Accelerated Encoding on Apple Silicon](#hardware-accelerated-encoding-on-apple-silicon)
  - [Software Encoding Commands](#software-encoding-commands)
  - [Make GIF (Modern Pipeline)](#make-gif-modern-pipeline)
  - [Download Full Album from YTMusic](#download-full-album-from-ytmusic)
- [macOS Note](#macos-note)
  - [Disable macOS popup showing accented characters when holding down a key](#disable-macos-popup-showing-accented-characters-when-holding-down-a-key)
  - [Disable Window Animations](#disable-window-animations)
  - [Generate SSH Key](#generate-ssh-key)
  - [Use Touch ID for sudo Commands](#use-touch-id-for-sudo-commands)
  - [Remove Quarantine Attributes](#remove-quarantine-attributes)
  - [Set DNS Servers with CLI](#set-dns-servers-with-cli)
  - [Clear DNS Cache](#clear-dns-cache)
  - [CDN Alias](#cdn-alias)
- [Windows 11 Note](#windows-11-note)
  - [Dev Drive (ReFS)](#dev-drive-refs)
  - [Vite+ & Cache Relocation (`E:\vite-plus`)](#vite--cache-relocation-evite-plus)
  - [Modern CLI Tools & Desktop Apps (`winget`)](#modern-cli-tools--desktop-apps-winget)
  - [PowerShell 7 Profile & Terminal Defaults](#powershell-7-profile--terminal-defaults)
  - [Global Git Config (Windows)](#global-git-config-windows)
  - [Inspect & Prune User PATH](#inspect--prune-user-path)

## Extension Configs

- [UBoL Configs](https://github.com/Florencea/my-macos-build/raw/main/configs/ubol-config.json)
- [Stylus Configs](https://github.com/Florencea/my-macos-build/raw/main/configs/stylus.json)
- [Tampermonkey Configs](https://github.com/Florencea/my-macos-build/raw/main/configs/tampermonkey.json)
- [Immersive Translate](https://github.com/Florencea/my-macos-build/raw/main/configs/immersive-translate-config.json)
- [Ubo mv2 Configs](https://github.com/Florencea/my-macos-build/raw/main/configs/ubo-config.txt)

## Cross-Platform Custom CLI Tools (`cli/*.ps1`)

All 11 CLI utilities in `cli/*.ps1` are written in cross-platform **PowerShell 7 (`pwsh`)** and support both POSIX/GNU flags (`--llms`, `--quality`, `-h`, `--help`) and PowerShell parameters (`-Llms`, `-Quality`, `-Help`).

- **macOS**: Automatically symlinked without extension into `~/.local/bin/<cmd>` via `scripts/install.sh` (with Zsh completions in `configs/zsh/completions/`).
- **Windows 11**: `cli/` is registered directly in User `PATH` via `scripts/install.ps1`.

### `webread`

Fetch and extract clean, LLM-friendly Markdown or structured HTML from any webpage via Jina Reader (`r.jina.ai`), CSS selectors (`htmlq`), or direct `/llms.txt` probing.

```sh
# Extract clean Markdown via Jina Reader
webread https://react.dev/learn/you-might-not-need-an-effect

# Auto-probe /llms-full.txt or /llms.txt from site root
webread --llms https://viteplus.dev

# Extract specific DOM element via htmlq CSS selector
webread -s 'article' https://oxc.rs

# Fetch raw HTML and save to file
webread --raw https://example.com -o page.html
```

### `ua`

One-click upgrade for OS packages (`brew` on macOS / `winget` on Windows 11), Active LTS Node.js (via Vite+), and parallel Git repository synchronization across the workspace.

```sh
# Full upgrade & parallel Git pull across workspace
ua

# Skip OS package manager check
ua --skip-brew
ua --skip-winget
```

### `up`

Automated Node.js / Vite+ dependency updater with sandbox branch creation, `vp migrate`, `npm-check-updates`, `vp fmt`, `vp check`, typecheck/unit test verification gates, and automatic rollback on failure.

```sh
up
```

### `unodev`

Synchronize `engines.node` in `package.json` across all local workspace repositories in parallel to match the active Vite+ Node.js LTS version.

```sh
unodev
```

### `mkclp`

Rapid video clip maker supporting local video files and YouTube streaming (using `yt-dlp --download-sections` with automatic Chrome browser cookies and cookie-less fallback).

- **Stream Copy (`--copy` or compatible MP4)**: 0-second lossless cut with zero re-encoding.
- **macOS Hardware Encoding**: Uses `hevc_videotoolbox -tag:v hvc1` (default Quality: `50`).
- **Windows Universal Encoding**: Uses `libx264` + `AAC` (default CRF Quality: `23`).

```sh
# Fast cut from local video
mkclp 'input.mp4' 00:01:30 10.0

# 0-second lossless stream copy
mkclp 'input.mp4' 00:00:15 5.0 --copy

# Clip YouTube video directly using Chrome cookies
mkclp JoSY6AWKqHs 00:01:59 2 --quality 45
```

### `mkgif`

High-quality animated GIF maker from local video files or YouTube streaming (with Chrome cookie support), using `gifski` via `yuv4mpegpipe` or 256-color temporal diff palettes.

```sh
# Make GIF from local video
mkgif 'input.mp4' 00:01:13.5 3.2 -w 480 --fps 12

# Make GIF from YouTube stream
mkgif JoSY6AWKqHs 00:01:59 4 -w 720 --fps 10
```

### `mdig`

Parallel multi-resolver DNS checker querying A (IPv4) and AAAA (IPv6) records across Google, Cloudflare, Hinet, and System resolvers (uses `dig` on macOS and `Resolve-DnsName` on Windows).

```sh
mdig 'is1-ssl.mzstatic.com'
```

### `clall` / `ebk` / `rea` / `mmb`

- `clall <GITHUB_TOKEN>`: Clone all GitHub repositories for the authenticated user in parallel.
- `ebk`: Backup and format browser extension exports from `~/Downloads` into `configs/` and push.
- `rea <input_dir>`: Combine `.cht.ass` subtitle into `.mkv` as the default Traditional Chinese track and clean up directory.
- `mmb`: Open this repository in Visual Studio Code.

## Antigravity Plugins (`plugins/`)

Customizations (Rules and Skills) are organized into three modular plugins under `plugins/` and deployed to `~/.gemini/config/plugins/`:

| Plugin               | Target OS       | Bundled Rules & Skills                                                                                          |
| :------------------- | :-------------- | :-------------------------------------------------------------------------------------------------------------- |
| `macos-modern-tools` | macOS           | `macos-execution` (`rules/AGENTS.md`) + `macos-toolchain` skill                                                 |
| `win11-modern-tools` | Windows 11      | `win11-execution` (`rules/AGENTS.md`) + `win11-toolchain` skill                                                 |
| `modern-web-stack`   | macOS & Windows | Consolidated Node.js, TypeScript 5+, React 19, Tailwind v4, Testing & CI rules + 5 modern web/Node/React skills |

## Browser & DevTools Note (Cross-Platform)

### Pagetual Rules

#### `share.dmhy.org`

```json
{
  "name": "動漫花園",
  "author": "skofkyo",
  "example": "http://share.dmhy.org/topics/list/sort_id/2",
  "url": "^https?://(www|share|dmhy)?(\\.)?(dmhy|anoneko)\\.(org|com)",
  "action": 1,
  "nextLink": "//a[text()='下一頁']",
  "pageElement": "thead+tbody",
  "replaceElement": ".table.clear>.nav_title,script+.nav_title",
  "rate": 3,
  "pageBar": 0,
  "sideController": false
}
```

#### `E-Hentai / ExHentai (Gallery & List)`

```json
{
  "name": "E-Hentai / ExHentai (Gallery & List)",
  "author": "skofkyo",
  "example": "https://exhentai.org/g/*, https://exhentai.org/?f_search=*",
  "url": "^https?://(e-hentai|exhentai)\\.org/(?!s/).*",
  "nextLink": "//table[@class='ptt']//a[string()='>'] | id('next') | id('unext')",
  "pageElement": ".itg>div,.itg>tbody>tr:not(:first-of-type),.gl1t, #gdt>div:not(.c),#gdt>a:not(.c), #img",
  "replaceElement": ".ptt,.ptb,.sn,.searchnav",
  "css": "#img {max-width: 100% !important;height: auto !important;min-height: 400px;}",
  "pageInit": "let img=doc.getElementById('img');img&&img.setAttribute('onerror','setTimeout(()=>{this.src=this.src.replace(/(\\\\?time=.*)?$/,`?time=${Date.now()}`)},3000)');",
  "pageBar": 0,
  "sideController": false,
  "action": 0
}
```

#### `E-Hentai / ExHentai (Reader - Auto Preload)`

```json
{
  "name": "E-Hentai / ExHentai (Reader - Auto Preload)",
  "author": "skofkyo",
  "example": "https://exhentai.org/s/*",
  "url": "^https?://(e-hentai|exhentai)\\.org/s/.*",
  "nextLink": "//table[@class='ptt']//a[string()='>'] | id('next') | id('unext')",
  "pageElement": ".itg>div,.itg>tbody>tr:not(:first-of-type),.gl1t, #gdt>div:not(.c),#gdt>a:not(.c), #img",
  "replaceElement": ".ptt,.ptb,.sn,.searchnav",
  "css": "#img {max-width: 100% !important;height: auto !important;min-height: 400px;}",
  "pageInit": "let img=doc.getElementById('img');img&&img.setAttribute('onerror','setTimeout(()=>{this.src=this.src.replace(/(\\\\?time=.*)?$/,`?time=${Date.now()}`)},3000)');",
  "pageBar": 0,
  "sideController": false,
  "action": 1,
  "autoLoadNum": 9999
}
```

### Microsoft Edge for DevTools Device Profile

- Android Browser User Agent

```text
Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/VERSION.0.0.0 Mobile Safari/537.36 EdgA/VERSION.0.0.0
```

- Example

```text
Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Mobile Safari/537.36 EdgA/155.0.0.0
```

#### Google Pixel 10 pro XL

##### Full

- Screen: `448 x 998`
- DPR: `3`

##### High

- Screen: `444 x 987`
- DPR: `2.44`

## Media & Encoding Note

### Hardware Accelerated Encoding on Apple Silicon

- <https://git.ffmpeg.org/gitweb/ffmpeg.git/commit/efece4442f3f583f7d04f98ef5168dfd08eaca5c>
- <https://trac.ffmpeg.org/wiki/HWAccelIntro#VideoToolbox>
- **Primary Use Case**: Rapid clipping and sharing via messaging apps (e.g. `cli/mkclp.ps1` for LINE, Discord). LINE natively supports direct drag-and-drop upload, video preview, and in-app playback for HEVC (`-tag:v hvc1`), while AV1 is not yet supported for direct in-app playback.
- `-q:v` could be set 0 to 100, higher is better (larger file).
- `-movflags +faststart` ensures instant Quick Look preview on macOS and fast network streaming.
- Test on MacBook Pro 16" (M1 Pro, 2021), FFmpeg 9.0.1
  - Input: H.264 AVC 1280 x 720 from YouTube (Big Buck Bunny)
  - Encoder: `hevc_videotoolbox`

```bash
ffmpeg -y \
  -hide_banner \
  -loglevel error \
  -stats \
  -i <INPUT_FILE> \
  -map 0:v:0 \
  -map "0:a?" \
  -c:v hevc_videotoolbox \
  -q:v <QUALITY> \
  -tag:v hvc1 \
  -c:a copy \
  -movflags +faststart \
  <OUTPUT_FILE>
```

| Quality  | Speed | Size  | VMAF  | Description                                                               |
| :------- | :---- | :---- | :---- | :------------------------------------------------------------------------ |
| original | -     | 81MB  | 100.0 | Baseline reference.                                                       |
| `0`      | 13.1x | 17MB  | 13.7  | Poor. Heavy blocking and severe loss of fine details.                     |
| `15`     | 13.1x | 22MB  | 31.6  | Low. Motion frames exhibit noticeable compression artifacts.              |
| `25`     | 13.2x | 28MB  | 48.5  | Fair. Acceptable for low-bandwidth mobile playback.                       |
| `40`     | 13.1x | 41MB  | 67.7  | Good. Minor differences only visible in complex motion scenes.            |
| `45`     | 13.1x | 48MB  | 73.8  | **Visually consistent. (Sweet Spot: storage-optimized, ~41% reduction).** |
| `50`     | 13.1x | 58MB  | 79.1  | **Visually consistent. (Sweet Spot: quality-optimized, ~29% reduction).** |
| `60`     | 11.1x | 95MB  | 88.5  | Diminishing returns. (+64% size vs q50, exceeds baseline size).           |
| `75`     | 10.0x | 196MB | 95.7  | Severe bloat. (3.4x size of q50 for marginal perceptual improvement).     |
| `100`    | 13.8x | 1.9GB | 98.9  | Near-lossless. (~33x size of q50, impractical file inflation).            |

> [!TIP]
> **Why `-q:v 45–50` is the Sweet Spot Range:**
>
> - **`-q:v 45`**: Best for storage and fast sharing (saves ~41% disk space, stays well under 50MB).
> - **`-q:v 50`**: Best for visual fidelity (VMAF climbs to 79.1 with +5.3 gain, while still saving ~29% space).
> - **Above `50`**: Stepping to `60` balloons size to 95MB (exceeding original video size). `75` and `100` cause severe bloat (up to 1.9GB, ~33×) with negligible real-world benefit during normal playback.

### Software Encoding Commands

- **Primary Use Case**: Archival preservation and hard-burning subtitles (`-vf "subtitles=..."`) for anime and movies, where absolute visual quality (10-bit color, no color banding, VMAF 96+) takes priority over encoding speed.

#### H.264 (AVC) crf

| Metric             | Acceptable     | Streaming      | Visual Lossless |
| :----------------- | :------------- | :------------- | :-------------- |
| **CRF**            | 30             | 23             | 18              |
| **Speed (M1 Pro)** | ~3.0x (71 fps) | ~2.6x (64 fps) | ~2.3x (57 fps)  |

```bash
ffmpeg -y \
  -hide_banner \
  -loglevel error \
  -stats \
  -i <INPUT_FILE> \
  -map 0:v:0 \
  -map "0:a?" \
  -c:v libx264 \
  -crf <CRF> \
  -preset veryslow \
  -vf "subtitles=filename='<ASS_FILE>'" \
  -c:a copy \
  -movflags +faststart \
  <OUTPUT_FILE>
```

#### HEVC (H.265) crf

| Metric             | Acceptable       | Streaming        | Visual Lossless  |
| :----------------- | :--------------- | :--------------- | :--------------- |
| **CRF**            | 31               | 26               | 21               |
| **Speed (M1 Pro)** | ~0.27x (6.6 fps) | ~0.23x (5.6 fps) | ~0.19x (4.8 fps) |

```bash
ffmpeg -y \
  -hide_banner \
  -loglevel error \
  -stats \
  -i <INPUT_FILE> \
  -map 0:v:0 \
  -map "0:a?" \
  -c:v libx265 \
  -crf <CRF> \
  -preset veryslow \
  -pix_fmt yuv420p10le \
  -vf "subtitles=filename='<ASS_FILE>'" \
  -tag:v hvc1 \
  -c:a copy \
  -movflags +faststart \
  <OUTPUT_FILE>
```

#### AV1 crf

| Metric             | Acceptable      | Streaming       | Visual Lossless |
| :----------------- | :-------------- | :-------------- | :-------------- |
| **CRF**            | 40              | 31              | 24              |
| **Speed (M1 Pro)** | ~4.8x (115 fps) | ~4.7x (113 fps) | ~4.7x (115 fps) |

```bash
ffmpeg -y \
  -hide_banner \
  -loglevel error \
  -stats \
  -i <INPUT_FILE> \
  -map 0:v:0 \
  -map "0:a?" \
  -c:v libsvtav1 \
  -crf <CRF> \
  -preset 6 \
  -pix_fmt yuv420p10le \
  -svtav1-params tune=0 \
  -vf "subtitles=filename='<ASS_FILE>'" \
  -c:a copy \
  -movflags +faststart \
  <OUTPUT_FILE>
```

### Make GIF (Modern Pipeline)

_Highly recommended to use [gifski](https://github.com/ImageOptim/gifski) via `yuv4mpegpipe` for zero disk I/O and highest quality color quantization._

```bash
ffmpeg -y -hide_banner -loglevel error -stats \
  -ss <START> \
  -i <INPUT_FILE> \
  -t <DURATION> \
  -vf "fps=<FRAME_RATE>,scale=<WIDTH>:-2:flags=lanczos,format=yuv420p" \
  -f yuv4mpegpipe - | \
  gifski -q \
    -Q <QUALITY_1_TO_100> \
    -o <OUTPUT_GIF> -
```

### Download Full Album from YTMusic

```bash
yt-dlp \
  --no-warnings \
  --progress \
  -f bestaudio \
  --ppa "ThumbnailsConvertor+FFmpeg_o:-c:v mjpeg -vf crop=\"'if(gt(ih,iw),iw,ih)':'if(gt(iw,ih),ih,iw)'\"" \
  --extract-audio \
  --embed-thumbnail \
  --embed-metadata \
  --parse-metadata 'playlist_index:%(meta_track)s' \
  --convert-thumbnails jpg \
  --print before_dl:"[%(playlist_index)s/%(playlist_count)s]: %(playlist_index)s %(title)s" \
  --cookies-from-browser <BROWSER> \
  -o "%(playlist_index)02d %(title)s.%(ext)s" \
  <URL>
```

---

## macOS Note

### Disable macOS popup showing accented characters when holding down a key

```sh
defaults write -g ApplePressAndHoldEnabled -bool false
```

### Disable Window Animations

```sh
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool NO
```

### Generate SSH Key

```sh
ssh-keygen -q -t ed25519 -N '' -f "$HOME/.ssh/id_ed25519" && pbcopy < "$HOME/.ssh/id_ed25519.pub"
```

### Use Touch ID for sudo Commands

```sh
sudo nano /etc/pam.d/sudo_local
# Add this
auth       sufficient     pam_tid.so
```

### Remove Quarantine Attributes

```sh
sudo xattr -r -d com.apple.quarantine <FILE>
```

### Set DNS Servers with CLI

```sh
# List network interfaces
networksetup -listallnetworkservices
# Remove DNS servers by set to empty (no quote)
networksetup -setdnsservers 'Wi-Fi' empty
# Set DNS Servers (split by space)
networksetup -setdnsservers 'Wi-Fi' '8.8.8.8' '8.8.4.4' '2001:4860:4860::8888' '2001:4860:4860::8844'
```

### Clear DNS Cache

```sh
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

### CDN Alias

```sh
# Apple CDN
is1-ssl.mzstatic.com -> CNAME mzstatic.com.edgekey.net (Fast, at Taiwan)
                     -> CNAME h3.apis.apple.map.fastly.net (Slow, at JP or SG)
# X CDN
abs.twimg.com -> CNAME abs.twimg.com.cdn.cloudflare.net (Fast, at Taiwan)
              -> CNAME twimg.twitter.map.fastly.net (Slow, at SG)
pbs.twimg.com -> CNAME pbs.twimg.com.cdn.cloudflare.net (Fast, at Taiwan)
              -> CNAME dualstack.twimg.twitter.map.fastly.net  (Slow, at SG)
```

---

## Windows 11 Note

### Dev Drive (ReFS)

1. Open **Settings** $\rightarrow$ **System** $\rightarrow$ **Storage** $\rightarrow$ **Advanced storage settings** $\rightarrow$ **Disks & volumes**.
2. Click **Create Dev Drive** $\rightarrow$ **Resize an existing volume** (`50 GB–120 GB`), Label `Developer`, Drive Letter `E:`.
3. Verify volume and Dev Drive trust status:

```powershell
Get-Volume | Select-Object DriveLetter, FileSystemLabel, FileSystemType, Size, SizeRemaining | Format-Table -AutoSize
fsutil devdrv query E:
```

### Vite+ & Cache Relocation (`E:\vite-plus`)

```powershell
# Fresh install on E:\vite-plus
[Environment]::SetEnvironmentVariable("VP_HOME", "E:\vite-plus", "User"); $env:VP_HOME = "E:\vite-plus"; $env:VP_NODE_MANAGER = "yes"; $env:VP_PM_MANAGER = "yes"; irm https://vite.plus/ps1 | iex; vp env default lts; vp env install lts

# Relocate existing ~/.vite-plus & cache to E:\vite-plus
if (Test-Path "$HOME\.vite-plus") { Move-Item -Force "$HOME\.vite-plus" "E:\vite-plus" }; [Environment]::SetEnvironmentVariable("VP_HOME", "E:\vite-plus", "User"); $env:VP_HOME = "E:\vite-plus"; $cleanPath = ([Environment]::GetEnvironmentVariable("Path", "User") -split ';' | Where-Object { $_ -and $_ -notlike "*\.vite-plus*" }) -join ';'; [Environment]::SetEnvironmentVariable("Path", $cleanPath, "User"); irm https://vite.plus/ps1 | iex; Remove-Item "$env:LOCALAPPDATA\pnpm-store" -Recurse -Force -ErrorAction SilentlyContinue
```

### Modern CLI Tools & Desktop Apps (`winget`)

```powershell
# Modern CLI Tools
winget install --id Microsoft.PowerShell -e
winget install --id BurntSushi.ripgrep.MSVC -e
winget install --id sharkdp.fd -e
winget install --id ast-grep.ast-grep -e
winget install --id jqlang.jq -e
winget install --id MikeFarah.yq -e
winget install --id sharkdp.bat -e
winget install --id chmln.sd -e
winget install --id mvdan.shfmt -e
winget install --id oschwartz10612.Poppler -e
winget install --id XAMPPRocky.Tokei -e
winget install --id BurntSushi.xsv.MSVC -e
winget install --id SQLite.SQLite -e
winget install --id ducaale.xh -e
winget install --id bootandy.dust -e
winget install --id DuckDB.cli -e
winget install --id rhysd.actionlint -e
winget install --id sharkdp.hyperfine -e
winget install --id Gyan.FFmpeg -e
winget install --id yt-dlp.yt-dlp -e
winget install --id ImageOptim.gifski -e
winget install --id AgileBits.1Password.CLI -e

# Desktop Apps
winget install --id Git.Git -e
winget install --id Microsoft.VisualStudioCode -e
winget install --id Google.Chrome -e
winget install --id AgileBits.1Password -e
winget install --id WinMerge.WinMerge -e
winget install --id RevoUninstaller.RevoUninstaller -e
winget install --id 7zip.7zip -e

# Pin In-Box Self-Updating Packages
winget pin add --id Microsoft.Edge --blocking
```

### PowerShell 7 Profile & Terminal Defaults

```powershell
# Set Windows Terminal Default Profile to PowerShell 7
$wtSettings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"; if (Test-Path $wtSettings) { $json = Get-Content $wtSettings -Raw | ConvertFrom-Json; $json.defaultProfile = "{574e775e-4f2a-5b96-ac1e-a2962a402336}"; [IO.File]::WriteAllText($wtSettings, ($json | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false)) }

# Set VS Code Integrated Terminal Default Profile to PowerShell 7
$codeSettings = "$env:APPDATA\Code\User\settings.json"; if (Test-Path $codeSettings) { $c = Get-Content $codeSettings -Raw; if ($c -notmatch '"terminal\.integrated\.defaultProfile\.windows"') { $idx = $c.LastIndexOf('}'); if ($idx -ge 0) { $prefix = $c.Substring(0, $idx).TrimEnd(" `t`r`n"); $comma = if ($prefix.EndsWith(',')) { '' } else { ',' }; $new = "$prefix$comma`r`n  `"terminal.integrated.defaultProfile.windows`": `"PowerShell`"`r`n}`r`n"; [IO.File]::WriteAllText($codeSettings, $new, [Text.UTF8Encoding]::new($false)) } } }
```

### Global Git Config (Windows)

```powershell
git config --global user.name "Florencea"; git config --global user.email "bearflorencea@gmail.com"; git config --global core.editor "code --wait"; git config --global core.quotepath false; git config --global core.longpaths true; git config --global core.autocrlf false; git config --global core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"; git config --global core.fsmonitor true; git config --global core.untrackedcache true; git config --global init.defaultBranch main; git config --global push.autoSetupRemote true; git config --global pull.rebase false; git config --global fetch.prune true; git config --global http.sslBackend schannel; git config --global alias.st "status -sb"; git config --global alias.co "checkout"; git config --global alias.br "branch"; git config --global alias.ci "commit"; git config --global alias.lg "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"; git config --global alias.remote-init '!f() { name=$(basename $(pwd)); remote=$HOME/Documents/_GitRemote/${name}.git; git init --bare "$remote" && git remote add origin "$remote" && git push -u origin --all && git push origin --tags; }; f'
```

### Inspect & Prune User PATH

```powershell
# Inspect User PATH
([Environment]::GetEnvironmentVariable("Path", "User") -split ';' | Where-Object { $_ }) | ForEach-Object { [PSCustomObject]@{ Exists = (Test-Path $_); Path = $_ } } | Format-Table -AutoSize

# Prune Stale User PATH Entries
$cleanPath = ([Environment]::GetEnvironmentVariable("Path", "User") -split ';' | ForEach-Object { $_.Trim().TrimEnd('\') } | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique) -join ';'; [Environment]::SetEnvironmentVariable("Path", $cleanPath, "User")
```
