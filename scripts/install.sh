#!/bin/zsh
emulate -L zsh
set -euo pipefail

# 0. Initialize sudo timestamp database (prevents fresh-install race condition)
sudo -v

# 1. Touch ID for sudo via system template
if ! grep -Eq '^[[:space:]]*auth[[:space:]]+sufficient[[:space:]]+pam_tid\.so' /etc/pam.d/sudo_local 2>/dev/null; then
  if [[ -f /etc/pam.d/sudo_local.template ]]; then
    sudo sh -c 'awk "{sub(/^#auth/, \"auth\"); print}" /etc/pam.d/sudo_local.template > /etc/pam.d/sudo_local'
  else
    sudo sh -c 'printf "# sudo_local: local authentication customization for sudo\nauth       sufficient     pam_tid.so\n" > /etc/pam.d/sudo_local'
  fi
  sudo chmod 444 /etc/pam.d/sudo_local
fi

# 2. Internal Root CAs (Private PKI for *.internal)
readonly BHPD_ROOT_CA_B64="LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUNCRENDQWF1Z0F3SUJBZ0lCQURBS0JnZ3Foa2pPUFFRREFqQThNUXN3Q1FZRFZRUUdFd0pVVnpFTk1Bc0cKQTFVRUNnd0VRa2hRUkRFZU1Cd0dBMVVFQXd3VlFraFFSQ0JKYm5SbGNtNWhiQ0JTYjI5MElFTkJNQjRYRFRJMgpNRGt4T1RFMU1qRXdPVm9YRFRNMk1Ea3hOakUxTWpFd09Wb3dQREVMTUFrR0ExVUVCaE1DVkZjeERUQUxCZ05WCkJBb01CRUpJVUVReEhqQWNCZ05WQkFNTUZVSklVRVFnU1c1MFpYSnVZV3dnVW05dmRDQkRRVEJaTUJNR0J5cUcKU000OUFnRUdDQ3FHU000OUF3RUhBMElBQk95elJsUngvMGR6SjBScDlkYTFiQmdCSmxMbFpqU0NmcFN6ZjBMcQpaeWRjeFo0c1NmWENuTyt4MUhZU1JEa3Y0RGlnYVZwckhaUE1OYldjQ1FsRnBsK2pnWjB3Z1pvd053WUpZSVpJCkFZYjRRZ0VOQkNvV0tFOVFUbk5sYm5ObElFZGxibVZ5WVhSbFpDQkRaWEowYVdacFkyRjBaU0JCZFhSb2IzSnAKZEhrd0hRWURWUjBPQkJZRUZBZitMVWdDeTNKKzEwMEcwdUJHQ1JVWVMvQnRNQjhHQTFVZEl3UVlNQmFBRkFmKwpMVWdDeTNKKzEwMEcwdUJHQ1JVWVMvQnRNQThHQTFVZEV3RUIvd1FGTUFNQkFmOHdEZ1lEVlIwUEFRSC9CQVFECkFnR0dNQW9HQ0NxR1NNNDlCQU1DQTBjQU1FUUNJRmxqSXZKenIyWHJ5Y0FvYzgybVpjU2J3QzRPa1h3NExkQ3IKcU13SlpDWkRBaUJub2xGWjdLRUhtZWlUOU5xYUpmSEtSeW5rMzAwUDhSaDd1eDl2cWZIemNRPT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo="
readonly BHGS_ROOT_CA_B64="LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUNCVENDQWF1Z0F3SUJBZ0lCQURBS0JnZ3Foa2pPUFFRREFqQThNUXN3Q1FZRFZRUUdFd0pVVnpFTk1Bc0cKQTFVRUNnd0VRa2hIVXpFZU1Cd0dBMVVFQXd3VlFraEhVeUJKYm5SbGNtNWhiQ0JTYjI5MElFTkJNQjRYRFRJMgpNRGt4T1RFMU5UUTBNbG9YRFRNMk1Ea3hOakUxTlRRME1sb3dQREVMTUFrR0ExVUVCaE1DVkZjeERUQUxCZ05WCkJBb01CRUpJUjFNeEhqQWNCZ05WQkFNTUZVSklSMU1nU1c1MFpYSnVZV3dnVW05dmRDQkRRVEJaTUJNR0J5cUcKU000OUFnRUdDQ3FHU000OUF3RUhBMElBQkZGOVk0d0N5TVNnbzNJSjU2QnZOaE12Mnh2a2Y4MC9id2dCOGhILwpFZHhzUktYTS91YjhBWTlldmxaR0VzQlpUZzJaS0ZIT0dMajBpNngyWldUanA3T2pnWjB3Z1pvd053WUpZSVpJCkFZYjRRZ0VOQkNvV0tFOVFUbk5sYm5ObElFZGxibVZ5WVhSbFpDQkRaWEowYVdacFkyRjBaU0JCZFhSb2IzSnAKZEhrd0hRWURWUjBPQkJZRUZHMGU4VXdmZERWTlJ1N3RodXh1TmhmRVk0RG1NQjhHQTFVZEl3UVlNQmFBRkcwZQo4VXdmZERWTlJ1N3RodXh1TmhmRVk0RG1NQThHQTFVZEV3RUIvd1FGTUFNQkFmOHdEZ1lEVlIwUEFRSC9CQVFECkFnR0dNQW9HQ0NxR1NNNDlCQU1DQTBnQU1FVUNJUUNmd0JISXNaTVdHWUZEbVNFNHVuQlNlUUZidkZLMzU0NHUKQ1hadVYwRlhTd0lnR0hwRDVWMGN4RmluS2VtenJVMU1ZQklpZXB0SnVEVmFQSnVhK2Qya3JHST0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo="

trust_internal_ca() {
  local ca_name="$1"
  local ca_b64="$2"
  local trust_dump

  trust_dump="$(security dump-trust-settings -d 2>/dev/null || true)"
  if [[ -n "$trust_dump" ]] && awk -v cn="$ca_name" '
    $0 ~ ("Cert [0-9]+:.*" cn) { in_cert=1; next }
    /^Cert [0-9]+:/ { in_cert=0 }
    in_cert && /Trust Setting/ { trusted=1 }
    END { exit !trusted }
  ' <<<"$trust_dump"; then
    return 0
  fi

  local cert_tmp
  cert_tmp="$(mktemp -t ca_cert.XXXXXX)"

  base64 -d <<<"$ca_b64" >"$cert_tmp"
  sudo security add-trusted-cert \
    -d \
    -r trustRoot \
    -p ssl \
    -k /Library/Keychains/System.keychain \
    "$cert_tmp" >/dev/null 2>&1 || true

  rm -f "$cert_tmp"
}

trust_internal_ca "BHPD Internal Root CA" "$BHPD_ROOT_CA_B64"
trust_internal_ca "BHGS Internal Root CA" "$BHGS_ROOT_CA_B64"

# 3. Homebrew Setup
if [[ -x "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_ASK=1
export HOMEBREW_AUTO_UPDATE_QUIET=1
export HOMEBREW_CURL_RETRIES=3

# 4. System Performance & Native Defaults
defaults write -g ApplePressAndHoldEnabled -bool false
defaults write -g InitialKeyRepeat -int 12
defaults write -g KeyRepeat -int 1
defaults write -g NSAutomaticCapitalizationEnabled -bool false
defaults write -g NSAutomaticDashSubstitutionEnabled -bool false
defaults write -g NSAutomaticInlinePredictionEnabled -bool false
defaults write -g NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write -g NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write -g NSAutomaticSpellingCorrectionEnabled -bool false
defaults write -g NSAutomaticTextCompletionEnabled -bool false
defaults write -g UIKitRedesignedTextCursorEnabled -bool false
defaults write -g WebAutomaticSpellingCorrectionEnabled -bool false
defaults write -g NSWindowResizeTime -float 0.001
defaults write -g NSDocumentSaveNewDocumentsToCloud -bool false

# Keyboard & Input Method Anti-Stutter (Disable CursorUIViewService floating indicator & Caps Lock delay)
defaults write kCFPreferencesAnyApplication TSMLanguageIndicatorEnabled -int 0
defaults write com.apple.HIToolbox AppleCapsLockPressAndHoldToggleOff -int 1
hidutil property --set '{"CapsLockDelayOverride":0}' >/dev/null 2>&1 || true

# Persist CapsLockDelayOverride=0 across reboots via LaunchAgent (idempotent)
mkdir -p "$HOME/Library/LaunchAgents"
KEY_REMAP_PLIST="$HOME/Library/LaunchAgents/com.local.KeyRemapping.plist"
KEY_REMAP_CONTENT='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.local.KeyRemapping</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/hidutil</string>
    <string>property</string>
    <string>--set</string>
    <string>{"CapsLockDelayOverride":0}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>'

if [[ ! -f "$KEY_REMAP_PLIST" ]] || [[ "$(<"$KEY_REMAP_PLIST")" != "$KEY_REMAP_CONTENT" ]]; then
  printf '%s\n' "$KEY_REMAP_CONTENT" >"$KEY_REMAP_PLIST"
  chmod 644 "$KEY_REMAP_PLIST"
  launchctl bootout "gui/$(id -u)/com.local.KeyRemapping" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$KEY_REMAP_PLIST" 2>/dev/null || true
elif ! launchctl print "gui/$(id -u)/com.local.KeyRemapping" >/dev/null 2>&1; then
  launchctl bootstrap "gui/$(id -u)" "$KEY_REMAP_PLIST" 2>/dev/null || true
fi

if [[ "$(defaults read /Library/Preferences/FeatureFlags/Domain/UIKit.plist redesigned_text_cursor 2>/dev/null || true)" != *"Enabled = 0"* ]]; then
  sudo mkdir -p /Library/Preferences/FeatureFlags/Domain
  sudo defaults write /Library/Preferences/FeatureFlags/Domain/UIKit.plist redesigned_text_cursor -dict Enabled -bool false
fi

# Terminal configuration: prevent disk I/O freezes
defaults write com.apple.Terminal ApplePersistenceIgnoreState -bool true
defaults write com.apple.Terminal NSQuitAlwaysKeepsWindows -bool false

# Prevent .DS_Store generation on Network & USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Suppress crash reporter UI dialogs
defaults write com.apple.CrashReporter DialogType none

# Accelerate DMG mounting by skipping validation
defaults write com.apple.frameworks.diskimages skip-verify -bool true
defaults write com.apple.frameworks.diskimages skip-verify-locked -bool true
defaults write com.apple.frameworks.diskimages skip-verify-remote -bool true

# 5. Disable Spotlight, Siri, and Background Intelligence safely & completely
disable_spotlight_and_siri() {
  # Turn off indexing globally (idempotent check)
  if ! mdutil -s / 2>/dev/null | grep -q "Indexing disabled"; then
    sudo mdutil -a -i off >/dev/null 2>&1 || true
    sudo mdutil -a -E >/dev/null 2>&1 || true
  fi
  sudo defaults write /Library/Preferences/com.apple.SpotlightServer.plist ExternalVolumesIndexed -bool false

  # Place native marker to avoid indexing loops
  [[ -f "$HOME/.metadata_never_index" ]] || touch "$HOME/.metadata_never_index" 2>/dev/null || true

  # Disable Spotlight UI and Global Shortcuts
  /usr/libexec/PlistBuddy -c "Set :AppleSymbolicHotKeys:64:enabled false" ~/Library/Preferences/com.apple.symbolichotkeys.plist 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Set :AppleSymbolicHotKeys:65:enabled false" ~/Library/Preferences/com.apple.symbolichotkeys.plist 2>/dev/null || true
  defaults -currentHost write com.apple.Spotlight MenuItemHidden -int 1 2>/dev/null || true

  # Disable Siri, Intelligence, Dictation, and Diagnostic telemetry
  defaults write com.apple.assistant.support "Assistant Enabled" -bool false
  defaults write com.apple.speech.recognition.AppleSpeechRecognition.prefs DictationIMMasterDictationSwitch -bool false
  defaults write com.apple.suggestions "SuggestionsAppLibraryEnabled" -bool false
  defaults write com.apple.suggestions "SuggestionsCalendarEnabled" -bool false
  defaults write com.apple.suggestions "SuggestionsEmailEnabled" -bool false
  defaults write com.apple.assistant.backedup "Logging Enabled" -bool false
  sudo defaults write /Library/Preferences/com.apple.SubmitDiagInfo AutoSubmit -bool false

  # Terminal-specific Siri learning exclusion
  if ! defaults read com.apple.suggestions SiriCanLearnFromAppBlacklist 2>/dev/null | grep -q 'com.apple.Terminal'; then
    defaults write com.apple.suggestions SiriCanLearnFromAppBlacklist -array-add "com.apple.Terminal"
  fi
  if ! defaults read com.apple.suggestions AppCanShowSiriSuggestionsBlacklist 2>/dev/null | grep -q 'com.apple.Terminal'; then
    defaults write com.apple.suggestions AppCanShowSiriSuggestionsBlacklist -array-add "com.apple.Terminal"
  fi
}

disable_spotlight_and_siri

# 6. Git Config & HostName
git config --global user.name "Florencea"
git config --global user.email "bearflorencea@gmail.com"
git config --global core.editor "nano"
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.quotepath false

TARGET_HOSTNAME="florenceambp"
if [[ "$(scutil --get HostName 2>/dev/null || true)" != "$TARGET_HOSTNAME" ]]; then
  sudo scutil --set HostName "$TARGET_HOSTNAME"
fi

# 7. Dotfiles and Custom Configurations
SCRIPT_DIR="${0:A:h}"
REPO_DIR="${SCRIPT_DIR:h}"
if [[ ! -d "${REPO_DIR:-}/configs" && -d "$HOME/Developer/my-machine-build/configs" ]]; then
  REPO_DIR="$HOME/Developer/my-machine-build"
fi

fetch_file() {
  local rel_path="$1"
  local dest_path="$2"
  local src_path="${REPO_DIR:-}/$rel_path"

  mkdir -p "${dest_path:h}"

  if [[ -n "${REPO_DIR:-}" && -f "$src_path" ]]; then
    if [[ -L "$dest_path" ]]; then
      rm -f "$dest_path"
    fi
    if [[ ! -f "$dest_path" ]] || ! cmp -s "$src_path" "$dest_path"; then
      cp -f "$src_path" "$dest_path"
    fi
  else
    local encoded_path="${rel_path// /%20}"
    curl -fsSL "https://raw.githubusercontent.com/Florencea/my-machine-build/main/$encoded_path" -o "$dest_path"
  fi
}

mkdir -p "$HOME/.config/git/hooks"
fetch_file "configs/git/hooks/pre-commit.sh" "$HOME/.config/git/hooks/pre-commit"
chmod +x "$HOME/.config/git/hooks/pre-commit"
git config --global core.hooksPath "$HOME/.config/git/hooks"

fetch_file "configs/bash/bash_profile" "$HOME/.bash_profile"
fetch_file "configs/bash/bashrc" "$HOME/.bashrc"

[[ -f "$HOME/.hushlogin" ]] || touch "$HOME/.hushlogin"
mkdir -p "$HOME/.local/share/zsh/site-functions"
mkdir -p "$HOME/.config/zsh/functions"
fetch_file "configs/zsh/zshenv" "$HOME/.zshenv"
fetch_file "configs/zsh/zprofile" "$HOME/.zprofile"
fetch_file "configs/zsh/zshrc" "$HOME/.zshrc"

if [[ -d "$REPO_DIR/configs/zsh/completions" ]]; then
  for comp in "$REPO_DIR/configs/zsh/completions"/_*(N); do
    dest="$HOME/.local/share/zsh/site-functions/${comp:t}"
    if [[ -L "$dest" ]]; then
      rm -f "$dest"
    fi
    if [[ ! -f "$dest" ]] || ! cmp -s "$comp" "$dest"; then
      cp -f "$comp" "$dest"
    fi
    chmod 644 "$dest"
  done
else
  local -a completions=(clall ebk mdig mkclp mkgif mmb rea ua unodev up webread)
  for comp in "${completions[@]}"; do
    fetch_file "configs/zsh/completions/_$comp" "$HOME/.local/share/zsh/site-functions/_$comp"
    chmod 644 "$HOME/.local/share/zsh/site-functions/_$comp"
  done
fi

# 7.5 Deploy Antigravity Plugins (common-modern-tools, macos-modern-tools & modern-web-stack)
sync_plugin_dir() {
  local plugin_name="$1"
  local src_dir="$REPO_DIR/plugins/$plugin_name"
  local dest_dir="$HOME/.gemini/config/plugins/$plugin_name"

  mkdir -p "$dest_dir"
  if [[ -n "${REPO_DIR:-}" && -d "$src_dir" ]]; then
    if ! diff -qr "$src_dir" "$dest_dir" >/dev/null 2>&1; then
      rm -rf "$dest_dir"
      mkdir -p "$dest_dir"
      cp -R -c "$src_dir/." "$dest_dir/"
    fi
  else
    fetch_file "plugins/$plugin_name/plugin.json" "$dest_dir/plugin.json"
    fetch_file "plugins/$plugin_name/rules/AGENTS.md" "$dest_dir/rules/AGENTS.md"
  fi
}

sync_plugin_dir "common-modern-tools"
sync_plugin_dir "macos-modern-tools"
sync_plugin_dir "modern-web-stack"

if [[ ! -d "$REPO_DIR/plugins" ]]; then
  fetch_file "plugins/common-modern-tools/PSScriptAnalyzerSettings.psd1" "$HOME/.gemini/config/plugins/common-modern-tools/PSScriptAnalyzerSettings.psd1"
  fetch_file "plugins/common-modern-tools/skills/common-toolchain/SKILL.md" "$HOME/.gemini/config/plugins/common-modern-tools/skills/common-toolchain/SKILL.md"
  fetch_file "plugins/common-modern-tools/skills/modern-powershell/SKILL.md" "$HOME/.gemini/config/plugins/common-modern-tools/skills/modern-powershell/SKILL.md"
  fetch_file "plugins/macos-modern-tools/skills/macos-toolchain/SKILL.md" "$HOME/.gemini/config/plugins/macos-modern-tools/skills/macos-toolchain/SKILL.md"
  local -a web_skills=(modern-hono-drizzle modern-nodejs modern-react-tailwind modern-typescript modern-web-guidance node-project-architecture tanstack-router)
  for skill in "${web_skills[@]}"; do
    fetch_file "plugins/modern-web-stack/skills/$skill/SKILL.md" "$HOME/.gemini/config/plugins/modern-web-stack/skills/$skill/SKILL.md"
  done
fi

# Clean up legacy standalone rules and skills migrated into plugins
local -a legacy_rules=(ci-workflows macos-execution modern-nodejs modern-react-tailwind modern-testing modern-typescript)
for rule in "${legacy_rules[@]}"; do
  rm -f "$HOME/.gemini/config/rules/$rule.md"
done
rmdir "$HOME/.gemini/config/rules" 2>/dev/null || true

local -a legacy_skills=(macos-toolchain modern-nodejs modern-react-tailwind modern-typescript node-project-architecture tanstack-router)
for skill in "${legacy_skills[@]}"; do
  rm -rf "$HOME/.gemini/config/skills/$skill"
done
rmdir "$HOME/.gemini/config/skills" 2>/dev/null || true

# 8. Setup CLI Symlinks (PowerShell 7 CLI scripts)
CLI_DIR=""
if [[ -n "${REPO_DIR:-}" && -d "$REPO_DIR/cli" ]]; then
  CLI_DIR="$REPO_DIR/cli"
elif [[ -d "$HOME/Developer/my-machine-build/cli" ]]; then
  CLI_DIR="$HOME/Developer/my-machine-build/cli"
fi

if [[ -n "$CLI_DIR" ]]; then
  mkdir -p "$HOME/.local/bin"
  chmod +x "$CLI_DIR"/*.ps1(N)
  for script in "$CLI_DIR"/*.ps1(N); do
    cmd_name="${script:t:r}"
    link_path="$HOME/.local/bin/$cmd_name"
    if [[ "$(readlink "$link_path" 2>/dev/null || true)" != "$script" ]]; then
      ln -sf "$script" "$link_path"
    fi
  done

  for link in "$HOME/.local/bin"/*(-@N); do
    target="$(readlink "$link" 2>/dev/null || true)"
    if [[ "$target" == "$CLI_DIR"* ]]; then
      rm -f "$link"
    fi
  done
fi

# 9. Package Installation (Casks & Formulas)
install_casks() {
  local installed
  installed="$(brew list --cask -1 2>/dev/null || true)"
  local -a to_install=()
  for cask in "$@"; do
    if ! grep -Fxq "$cask" <<<"$installed"; then
      to_install+=("$cask")
    fi
  done
  if (($#to_install > 0)); then
    brew install --cask "${to_install[@]}" || true
  fi
}

install_formulas() {
  local brew_opt="${HOMEBREW_PREFIX:-/opt/homebrew}/opt"
  local installed
  installed="$(brew list --formula -1 2>/dev/null || true)"
  local -a to_install=()
  for formula in "$@"; do
    if ! grep -Fxq "$formula" <<<"$installed" && [[ ! -d "$brew_opt/$formula" ]]; then
      to_install+=("$formula")
    fi
  done
  if (($#to_install > 0)); then
    brew install --formula "${to_install[@]}" || true
  fi
}

# Install all casks in one batch for better resolution speed
install_casks \
  1password-cli \
  font-jetbrains-mono \
  font-inter \
  istat-menus@6 \
  logi-options+ \
  1password \
  microsoft-edge \
  keka \
  iina \
  visual-studio-code \
  cloudflare-warp

# iStat Menus 6 License
defaults write com.bjango.istatmenus license6 -dict email "982092332@qq.com" serial "GAWAE-FCWQ3-P8NYB-C7GF7-NEDRT-Q5DTB-MFZG6-6NEQC-CRMUD-8MZ2K-66SRB-SU8EW-EDLZ9-TGH3S-8SGA"

# Keka configuration
defaults write com.aone.keka SetAsDefaultApp -bool true 2>/dev/null || true
defaults write com.aone.keka UseGrowl -bool false 2>/dev/null || true
defaults write com.aone.keka SelectedTab -string "TAR" 2>/dev/null || true

# IINA configuration
defaults write com.colliderli.iina actionAfterLaunch -int 2
defaults write com.colliderli.iina quitWhenNoOpenedWindow -bool true
defaults write com.colliderli.iina recordPlaybackHistory -bool false
defaults write com.colliderli.iina recordRecentFiles -bool false
defaults write com.colliderli.iina resumeLastPosition -int 0
defaults write com.colliderli.iina arrowBtnAction -int 1
defaults write com.colliderli.iina displayInLetterBox -bool false
defaults write com.colliderli.iina horizontalScrollAction -int 2
defaults write com.colliderli.iina verticalScrollAction -int 2
defaults write com.colliderli.iina pinchAction -int 2

# IINA toolbar buttons array using PlistBuddy for strict integer types (idempotent)
IINA_PREF="$HOME/Library/Preferences/com.colliderli.iina.plist"
if [[ "$(/usr/libexec/PlistBuddy -c "Print :controlBarToolbarButtons" "$IINA_PREF" 2>/dev/null | awk '/^[[:space:]]+[0-9]+$/ {printf "%s ", $1}')" != "2 1 5 0 " ]]; then
  /usr/libexec/PlistBuddy -c "Delete :controlBarToolbarButtons" "$IINA_PREF" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :controlBarToolbarButtons array" "$IINA_PREF" 2>/dev/null || true
  for btn_val in 2 1 5 0; do
    /usr/libexec/PlistBuddy -c "Add :controlBarToolbarButtons: integer $btn_val" "$IINA_PREF" 2>/dev/null || true
  done
fi

# Transmission configuration
defaults write org.m0k.transmission BindPort -int 51247
defaults write org.m0k.transmission PeersTorrent -int 200
defaults write org.m0k.transmission PeersTotal -int 1000
defaults write org.m0k.transmission LocalPeerDiscoveryGlobal -bool true
defaults write org.m0k.transmission DownloadAsk -bool false
defaults write org.m0k.transmission MagnetOpenAsk -bool false
defaults write org.m0k.transmission DownloadLocationConstant -bool true
defaults write org.m0k.transmission DisplayPeerProgressBarNumber -bool true
defaults write org.m0k.transmission FilterSearchType -string "Name"
defaults write org.m0k.transmission AutoSize -bool true

# Register default file associations directly to LaunchServices (idempotent, no UI confirmation dialogs)
LS_SECURE_PLIST="$HOME/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist"
mkdir -p "${LS_SECURE_PLIST:h}"
if ! /usr/libexec/PlistBuddy -c "Print :LSHandlers" "$LS_SECURE_PLIST" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Add :LSHandlers array" "$LS_SECURE_PLIST" 2>/dev/null || true
fi
LS_HANDLERS_DUMP="$(/usr/libexec/PlistBuddy -c "Print :LSHandlers" "$LS_SECURE_PLIST" 2>/dev/null || true)"

has_ls_uti() {
  local uti="$1" role="$2"
  awk -v uti="$uti" -v role="$role" '
    /^    Dict \{/ { in_dict=1; has_uti=0; has_role=0 }
    in_dict && $1 == "LSHandlerContentType" && $3 == uti { has_uti=1 }
    in_dict && $1 == "LSHandlerRoleAll" && $3 == role { has_role=1 }
    in_dict && /^    \}/ { if (has_uti && has_role) { found=1; exit 0 }; in_dict=0 }
    END { exit !found }
  ' <<<"$LS_HANDLERS_DUMP"
}

has_ls_ext() {
  local ext="$1" role="$2"
  awk -v ext="$ext" -v role="$role" '
    /^    Dict \{/ { in_dict=1; has_ext=0; has_class=0; has_role=0 }
    in_dict && $1 == "LSHandlerContentTag" && $3 == ext { has_ext=1 }
    in_dict && $1 == "LSHandlerContentTagClass" && $3 == "public.filename-extension" { has_class=1 }
    in_dict && $1 == "LSHandlerRoleAll" && $3 == role { has_role=1 }
    in_dict && /^    \}/ { if (has_ext && has_class && has_role) { found=1; exit 0 }; in_dict=0 }
    END { exit !found }
  ' <<<"$LS_HANDLERS_DUMP"
}

# Keka default associations
local -a keka_utis=(
  "public.zip-archive"
  "public.tar-archive"
  "public.tar-bzip2-archive"
  "public.bzip2-archive"
  "public.cpio-archive"
  "public.z-archive"
  "org.7-zip.7-zip-archive"
  "org.gnu.gnu-zip-archive"
  "org.gnu.gnu-zip-tar-archive"
  "org.tukaani.xz-archive"
  "org.tukaani.tar-xz-archive"
  "com.apple.archive"
  "com.apple.bom-compressed-cpio"
  "com.microsoft.cab"
)
for uti in "${keka_utis[@]}"; do
  if ! has_ls_uti "$uti" "com.aone.keka"; then
    /usr/libexec/PlistBuddy -c "Add :LSHandlers:0 dict" "$LS_SECURE_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :LSHandlers:0:LSHandlerContentType string $uti" "$LS_SECURE_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :LSHandlers:0:LSHandlerRoleAll string com.aone.keka" "$LS_SECURE_PLIST" 2>/dev/null || true
  fi
done

local -a keka_exts=(7z rar zip tar gz tgz bz2 tbz2 xz txz iso dmg)
for ext in "${keka_exts[@]}"; do
  if ! has_ls_ext "$ext" "com.aone.keka"; then
    /usr/libexec/PlistBuddy -c "Add :LSHandlers:0 dict" "$LS_SECURE_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :LSHandlers:0:LSHandlerContentTag string $ext" "$LS_SECURE_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :LSHandlers:0:LSHandlerContentTagClass string public.filename-extension" "$LS_SECURE_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :LSHandlers:0:LSHandlerRoleAll string com.aone.keka" "$LS_SECURE_PLIST" 2>/dev/null || true
  fi
done

# IINA default associations
local -a iina_utis=(
  "public.mpeg-4"
  "public.avi"
  "public.mpeg"
  "public.mpeg-2-video"
  "public.dv-movie"
  "com.apple.quicktime-movie"
  "com.apple.m4v-video"
  "public.3gpp"
  "public.3gpp2"
  "public.mp3"
  "public.mp2"
  "public.mpeg-4-audio"
  "public.aac-audio"
  "public.aiff-audio"
  "public.ac3-audio"
  "com.microsoft.waveform-audio"
  "com.apple.m4a-audio"
  "com.apple.music.mp2"
  "com.apple.music.m3u-playlist"
  "public.m3u-playlist"
)
for uti in "${iina_utis[@]}"; do
  if ! has_ls_uti "$uti" "com.colliderli.iina"; then
    /usr/libexec/PlistBuddy -c "Add :LSHandlers:0 dict" "$LS_SECURE_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :LSHandlers:0:LSHandlerContentType string $uti" "$LS_SECURE_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :LSHandlers:0:LSHandlerRoleAll string com.colliderli.iina" "$LS_SECURE_PLIST" 2>/dev/null || true
  fi
done

local -a iina_exts=(mkv flv webm wmv rmvb vob mov ts m4v avi mp4 mp3 flac wav aac ogg ape opus)
for ext in "${iina_exts[@]}"; do
  if ! has_ls_ext "$ext" "com.colliderli.iina"; then
    /usr/libexec/PlistBuddy -c "Add :LSHandlers:0 dict" "$LS_SECURE_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :LSHandlers:0:LSHandlerContentTag string $ext" "$LS_SECURE_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :LSHandlers:0:LSHandlerContentTagClass string public.filename-extension" "$LS_SECURE_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :LSHandlers:0:LSHandlerRoleAll string com.colliderli.iina" "$LS_SECURE_PLIST" 2>/dev/null || true
  fi
done

# CLI tools
install_formulas \
  actionlint \
  ast-grep \
  bat \
  duckdb \
  dust \
  fd \
  ffmpeg \
  gifski \
  htmlq \
  hyperfine \
  jq \
  mtr \
  poppler \
  powershell \
  ripgrep \
  sd \
  shfmt \
  tokei \
  tree \
  xh \
  xsv \
  yq \
  yt-dlp \
  zsh-autosuggestions \
  zsh-syntax-highlighting

# Ensure PSScriptAnalyzer is installed for PowerShell static analysis
install_psscriptanalyzer() {
  if ! command -v pwsh >/dev/null 2>&1; then
    return 0
  fi

  if pwsh -NoLogo -NoProfile -Command "if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) { exit 1 }" >/dev/null 2>&1; then
    return 0
  fi

  local pssa_version="1.25.0"
  local pssa_dest="$HOME/.local/share/powershell/Modules/PSScriptAnalyzer/$pssa_version"
  local pssa_tmp
  pssa_tmp="$(mktemp -t pssa.XXXXXX).zip"

  if curl -4 -fsSL "https://github.com/PowerShell/PSScriptAnalyzer/releases/download/${pssa_version}/PSScriptAnalyzer.${pssa_version}.nupkg" -o "$pssa_tmp" 2>/dev/null ||
    curl -fsSL "https://github.com/PowerShell/PSScriptAnalyzer/releases/download/${pssa_version}/PSScriptAnalyzer.${pssa_version}.nupkg" -o "$pssa_tmp" 2>/dev/null; then
    mkdir -p "$pssa_dest"
    unzip -q -o "$pssa_tmp" -d "$pssa_dest" >/dev/null 2>&1 || true
    rm -f "$pssa_tmp"
  fi
}

install_psscriptanalyzer

# 10. Vite+ Global CLI & Node.js Runtime Management
[[ -f "$HOME/.config/vite-plus/env" ]] && . "$HOME/.config/vite-plus/env"

local vp_home="${VP_HOME:-$HOME/.local/share/vite-plus}"
if ! command -v vp >/dev/null 2>&1 && [[ ! -x "$vp_home/bin/vp" ]]; then
  curl -fsSL https://vite.plus | CI=true VP_NODE_MANAGER=yes VP_PM_MANAGER=yes bash >/dev/null 2>&1
  [[ -f "$HOME/.config/vite-plus/env" ]] && . "$HOME/.config/vite-plus/env"
  vp_home="${VP_HOME:-$HOME/.local/share/vite-plus}"
fi

# Ensure Active LTS is default, installed, and global oxfmt matches bundled vp version
local vp_bin="${commands[vp]:-$vp_home/bin/vp}"
if [[ -x "$vp_bin" ]]; then
  VP_LOG=error "$vp_bin" env default lts >/dev/null 2>&1
  VP_LOG=error "$vp_bin" env install lts >/dev/null 2>&1

  local vp_pkg_json="$vp_home/current/node_modules/vite-plus/package.json"
  if [[ ! -f "$vp_pkg_json" ]]; then
    local vp_ver
    vp_ver="$("$vp_bin" --version 2>/dev/null | awk '/^vp v/ { sub(/^v/, "", $2); print $2; exit }')"
    if [[ -n "$vp_ver" && -f "$vp_home/$vp_ver/node_modules/vite-plus/package.json" ]]; then
      vp_pkg_json="$vp_home/$vp_ver/node_modules/vite-plus/package.json"
    fi
  fi

  if [[ -f "$vp_pkg_json" ]] && command -v jq >/dev/null 2>&1; then
    local target_oxfmt_ver
    target_oxfmt_ver="$(jq -r '(.dependencies.oxfmt // empty) | sub("^[^0-9]*"; "")' "$vp_pkg_json")"
    if [[ -n "$target_oxfmt_ver" ]]; then
      local vp_oxfmt_shim="$vp_home/bin/oxfmt"
      local current_oxfmt_ver=""
      if [[ -x "$vp_oxfmt_shim" ]]; then
        current_oxfmt_ver="$("$vp_oxfmt_shim" --version 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+\.[0-9]+\.[0-9]+/) { print $i; exit } }')"
      fi
      if [[ "$current_oxfmt_ver" != "$target_oxfmt_ver" ]]; then
        VP_LOG=error "$vp_bin" install -g "oxfmt@$target_oxfmt_ver" >/dev/null 2>&1
      fi
    fi
  fi
fi

# Clean up legacy standalone Node.js directory if present
if [[ -d "$HOME/.local/opt/node" ]]; then
  rm -rf "$HOME/.local/opt"/node*(N)
  rmdir "$HOME/.local/opt" 2>/dev/null || true
fi

# 11. Flush preferences cache and restart input/cursor services before reboot
killall cfprefsd 2>/dev/null || true
killall CursorUIViewService 2>/dev/null || true
pkill -HUP -f "/System/Library/Input Methods/TCIM.app" 2>/dev/null || true
