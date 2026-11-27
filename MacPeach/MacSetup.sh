#!/bin/bash

set -uo pipefail

sudo() { PATH=/usr/bin:/bin:/usr/sbin:/sbin /usr/bin/sudo "$@"; }

for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [ -x "$brew_bin" ]; then eval "$("$brew_bin" shellenv)"; break; fi
done

echo "Starting Mac setup..."

# =========================================================
# PIPELINE 1 — CLI TOOLS
# =========================================================

# --- Essentials | Podstawy ---

# Distributed version control system | Rozproszony system kontroli wersji
echo "Installing Git..."
brew install git || true

# GitHub from the command line: PRs, issues, releases | GitHub z terminala: PR-y, zgłoszenia, wydania
echo "Installing GitHub CLI..."
brew install gh || true

# Download files over HTTP, HTTPS and FTP | Pobieranie plików przez HTTP, HTTPS i FTP
echo "Installing wget..."
brew install wget || true

# Query and transform JSON | Przetwarzanie i filtrowanie JSON
echo "Installing jq..."
brew install jq || true

# jq for YAML, XML and TOML | jq dla plików YAML, XML i TOML
echo "Installing yq..."
brew install yq || true

# Directory listing as a tree | Wyświetlanie katalogów w formie drzewa
echo "Installing tree..."
brew install tree || true

# Short, practical examples for commands | Krótkie, praktyczne przykłady użycia komend
echo "Installing tldr..."
brew install tlrc || true

# 7-Zip archiver (7z, zip, rar and more) | Archiwizator 7-Zip (7z, zip, rar i inne)
echo "Installing 7-Zip..."
brew install sevenzip || true

# Install Mac App Store apps from the terminal | Instalacja aplikacji z Mac App Store z terminala
echo "Installing mas..."
brew install mas || true

# GNU core utilities (gls, gdate, gsed...) | Narzędzia GNU (gls, gdate, gsed...)
echo "Installing GNU coreutils..."
brew install coreutils || true

# --- Modern CLI | Nowoczesne zamienniki ---

# Very fast recursive search (better grep) | Bardzo szybkie wyszukiwanie w plikach (lepszy grep)
echo "Installing ripgrep..."
brew install ripgrep || true

# Simple, fast alternative to find | Prosty i szybki zamiennik find
echo "Installing fd..."
brew install fd || true

# Fuzzy finder for files, history and more | Wyszukiwarka rozmyta: pliki, historia i więcej
echo "Installing fzf..."
brew install fzf || true

# cat with syntax highlighting | cat z kolorowaniem składni
echo "Installing bat..."
brew install bat || true

# Modern ls with icons and Git status | Nowoczesny ls z ikonami i statusem Gita
echo "Installing eza..."
brew install eza || true

# Smarter cd that remembers your folders | Sprytniejszy cd, który pamięta katalogi
echo "Installing zoxide..."
brew install zoxide || true

# Readable, highlighted git diffs | Czytelne, kolorowe diffy w Gicie
echo "Installing delta..."
brew install git-delta || true

# Terminal UI for Git | Interfejs Gita w terminalu
echo "Installing lazygit..."
brew install lazygit || true

# Friendly HTTP client for APIs | Wygodny klient HTTP do testowania API
echo "Installing HTTPie..."
brew install httpie || true

# --- Shell & Editors | Terminal i edytory ---

# Fast, customizable shell prompt | Szybki, konfigurowalny prompt powłoki
echo "Installing Starship..."
brew install starship || true

# Terminal multiplexer: panes, sessions | Multiplekser terminala: panele i sesje
echo "Installing tmux..."
brew install tmux || true

# Hyperextensible Vim-based editor | Rozszerzalny edytor oparty na Vimie
echo "Installing Neovim..."
brew install neovim || true

# System information in the terminal | Informacje o systemie w terminalu
echo "Installing Fastfetch..."
brew install fastfetch || true

# Git repository summary in the terminal | Podsumowanie repozytorium Git w terminalu
echo "Installing onefetch..."
brew install onefetch || true

# --- Monitoring | Monitorowanie ---

# Interactive process viewer | Interaktywny podgląd procesów
echo "Installing htop..."
brew install htop || true

# Resource monitor with graphs | Monitor zasobów z wykresami
echo "Installing btop..."
brew install btop || true

# Disk usage analyzer for the terminal | Analiza zajętości dysku w terminalu
echo "Installing ncdu..."
brew install ncdu || true

# Intuitive version of du | Czytelniejsza wersja du
echo "Installing dust..."
brew install dust || true

# Command-line benchmarking tool | Benchmarkowanie poleceń w terminalu
echo "Installing hyperfine..."
brew install hyperfine || true

# --- Languages & Runtimes | Języki i środowiska ---

# JavaScript runtime with npm | Środowisko JavaScript z npm
echo "Installing Node.js..."
brew install node || true

# Extremely fast Python package and project manager | Bardzo szybki menedżer pakietów i projektów Pythona
echo "Installing uv..."
brew install uv || true

# Go programming language | Język programowania Go
echo "Installing Go..."
brew install go || true

# Rust toolchain installer | Instalator narzędzi języka Rust
echo "Installing rustup..."
brew install rustup || true

# --- Security & Network | Bezpieczeństwo i sieć ---

# Static analysis for shell scripts | Analiza statyczna skryptów powłoki
echo "Installing ShellCheck..."
brew install shellcheck || true

# GnuPG: signing commits and encryption | GnuPG: podpisywanie commitów i szyfrowanie
echo "Installing GnuPG..."
brew install gnupg || true

# Network scanner and port discovery | Skaner sieci i otwartych portów
echo "Installing Nmap..."
brew install nmap || true


# =========================================================
# PIPELINE 2 — APPLICATIONS (CASKS)
# =========================================================

# --- Browsers | Przeglądarki ---

# Privacy-focused browser with built-in ad blocking | Przeglądarka dbająca o prywatność, z blokowaniem reklam
echo "Installing Brave..."
brew install --cask brave-browser || true

# Chromium browser with a sidebar and Spaces | Przeglądarka na Chromium z panelem bocznym i Spaces
echo "Installing Arc..."
brew install --cask arc || true

# Open-source browser from Mozilla | Otwarta przeglądarka od Mozilli
echo "Installing Firefox..."
brew install --cask firefox || true

# Web browser from Google | Przeglądarka internetowa Google
echo "Installing Google Chrome..."
brew install --cask google-chrome || true

# --- Development | Programowanie ---

# AI coding assistant in your terminal | Asystent AI do programowania w terminalu
echo "Installing Claude Code..."
brew install --cask claude-code || true

# Code editor from Microsoft | Edytor kodu od Microsoftu
echo "Installing Visual Studio Code..."
brew install --cask visual-studio-code || true

# Fast, lightweight text and code editor | Szybki, lekki edytor tekstu i kodu
echo "Installing Sublime Text..."
brew install --cask sublime-text || true

# High-performance collaborative code editor | Wydajny edytor kodu do pracy zespołowej
echo "Installing Zed..."
brew install --cask zed || true

# Fast, native, GPU-accelerated terminal | Szybki, natywny terminal z akceleracją GPU
echo "Installing Ghostty..."
brew install --cask ghostty || true

# Feature-rich terminal emulator | Rozbudowany emulator terminala
echo "Installing iTerm2..."
brew install --cask iterm2 || true

# Light, fast Docker containers and Linux VMs | Lekkie i szybkie kontenery Docker oraz maszyny Linux
echo "Installing OrbStack..."
brew install --cask orbstack || true

# Docker Engine with a desktop app | Docker Engine z aplikacją okienkową
echo "Installing Docker Desktop..."
brew install --cask docker-desktop || true

# Open-source API client (Postman alternative) | Otwarty klient API (alternatywa dla Postmana)
echo "Installing Bruno..."
brew install --cask bruno || true

# Manager for JetBrains IDEs | Menedżer środowisk JetBrains
echo "Installing JetBrains Toolbox..."
brew install --cask jetbrains-toolbox || true

# Visual editor for SQLite databases | Wizualny edytor baz SQLite
echo "Installing DB Browser for SQLite..."
brew install --cask db-browser-for-sqlite || true

# Network protocol analyzer | Analizator ruchu sieciowego
echo "Installing Wireshark..."
brew install --cask wireshark-app || true

# Virtual machines on Mac | Maszyny wirtualne na Macu
echo "Installing UTM..."
brew install --cask utm || true

# --- Productivity | Produktywność ---

# Launcher with extensions, clipboard and snippets | Launcher z rozszerzeniami, schowkiem i snippetami
echo "Installing Raycast..."
brew install --cask raycast || true

# Window snapping with keyboard shortcuts | Układanie okien skrótami klawiszowymi
echo "Installing Rectangle..."
brew install --cask rectangle || true

# Windows-style window switcher | Przełącznik okien jak w Windowsie
echo "Installing AltTab..."
brew install --cask alt-tab || true

# Lightweight clipboard history | Lekka historia schowka
echo "Installing Maccy..."
brew install --cask maccy || true

# Screenshots with annotations and OCR | Zrzuty ekranu z adnotacjami i OCR
echo "Installing Shottr..."
brew install --cask shottr || true

# Markdown knowledge base | Baza wiedzy w Markdown
echo "Installing Obsidian..."
brew install --cask obsidian || true

# Hide and organize menu bar icons | Ukrywanie i porządkowanie ikon paska menu
echo "Installing Ice..."
brew install --cask jordanbaird-ice || true

# System monitor in the menu bar | Monitor systemu w pasku menu
echo "Installing Stats..."
brew install --cask stats || true

# Brightness and volume for external displays | Jasność i głośność monitorów zewnętrznych
echo "Installing MonitorControl..."
brew install --cask monitorcontrol || true

# --- Keyboard & Mouse | Klawiatura i mysz ---

# Powerful keyboard remapping | Zaawansowane przemapowanie klawiatury
echo "Installing Karabiner-Elements..."
brew install --cask karabiner-elements || true

# Separate scroll direction and acceleration for mice | Osobny kierunek przewijania i przyspieszenie myszy
echo "Installing LinearMouse..."
brew install --cask linearmouse || true

# --- Files & Disks | Pliki i dyski ---

# Archiver for 7z, zip, rar and more | Archiwizator 7z, zip, rar i innych
echo "Installing Keka..."
brew install --cask keka || true

# Unpacks almost any archive | Rozpakowuje niemal każde archiwum
echo "Installing The Unarchiver..."
brew install --cask the-unarchiver || true

# Search files by name, including hidden ones | Wyszukiwanie plików po nazwie, także ukrytych
echo "Installing Find Any File..."
brew install --cask find-any-file || true

# Visual map of disk usage | Graficzna mapa zajętości dysku
echo "Installing GrandPerspective..."
brew install --cask grandperspective || true

# Uninstall apps with all their leftovers | Odinstalowanie aplikacji razem z pozostałościami
echo "Installing AppCleaner..."
brew install --cask appcleaner || true

# Flash OS images to USB drives and SD cards | Nagrywanie obrazów systemów na pendrive i karty SD
echo "Installing Etcher..."
brew install --cask balenaetcher || true

# --- Quick Look ---

# Quick Look preview for Markdown files | Podgląd plików Markdown w Quick Look (spacja)
echo "Installing QLMarkdown..."
brew install --cask qlmarkdown || true

# Quick Look preview of source code with highlighting | Podgląd kodu źródłowego z kolorowaniem w Quick Look
echo "Installing Syntax Highlight..."
brew install --cask syntax-highlight || true

# --- Media & Communication | Multimedia i komunikacja ---

# Modern media player | Nowoczesny odtwarzacz multimediów
echo "Installing IINA..."
brew install --cask iina || true

# Music streaming | Muzyka w streamingu
echo "Installing Spotify..."
brew install --cask spotify || true

# Voice, video and text chat | Czat głosowy, wideo i tekstowy
echo "Installing Discord..."
brew install --cask discord || true

# Messenger | Komunikator
echo "Installing Telegram..."
brew install --cask telegram || true

# Team communication | Komunikacja w zespole
echo "Installing Slack..."
brew install --cask slack || true

# Audio file converter | Konwerter plików audio
echo "Installing Switch..."
brew install --cask switch || true

# --- Other | Inne ---

# CPU and GPU benchmark | Test wydajności procesora i grafiki
echo "Installing Geekbench..."
brew install --cask geekbench || true

# Run Windows applications | Uruchamianie aplikacji Windows
echo "Installing Wine Stable..."
brew install --cask wine-stable || true


# =========================================================
# PIPELINE 3 — SYSTEM CONFIGURATION
# =========================================================

echo "Configuring system settings..."

# --- Finder ---

# Show path bar | Pokaż pasek ścieżki
defaults write com.apple.finder ShowPathbar -bool true

# Show status bar | Pokaż pasek stanu
defaults write com.apple.finder ShowStatusBar -bool true

# Show hidden files | Pokaż ukryte pliki
defaults write com.apple.finder AppleShowAllFiles -bool true

# Show all filename extensions | Pokaż wszystkie rozszerzenia plików
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show full POSIX path in window title | Pokaż pełną ścieżkę w tytule okna
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Keep folders on top when sorting | Foldery zawsze na górze listy
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Keep folders on top on Desktop | Foldery na górze także na biurku
defaults write com.apple.finder _FXSortFoldersFirstOnDesktop -bool true

# Search the current folder by default | Domyślnie szukaj w bieżącym folderze
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Use column view by default | Domyślnie widok kolumn
defaults write com.apple.finder FXPreferredViewStyle -string "clmv"

# Open new windows in the home folder | Nowe okna otwieraj w katalogu domowym
defaults write com.apple.finder NewWindowTarget -string "PfHm"
defaults write com.apple.finder NewWindowTargetPath -string "file://$HOME/"

# Disable warning when changing a file extension | Bez ostrzeżenia przy zmianie rozszerzenia
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Show external drives on Desktop | Pokaż dyski zewnętrzne na biurku
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true

# Show removable media on Desktop | Pokaż nośniki wymienne na biurku
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

# Hide the internal drive on Desktop | Ukryj dysk wewnętrzny na biurku
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false

# No .DS_Store files on network drives | Bez plików .DS_Store na dyskach sieciowych
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# No .DS_Store files on USB drives | Bez plików .DS_Store na dyskach USB
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Show the ~/Library folder | Pokaż folder ~/Library
chflags nohidden "$HOME/Library"

# --- Dock & Mission Control ---

# Automatically hide the Dock | Automatycznie ukrywaj Dock
defaults write com.apple.dock autohide -bool true

# Show the hidden Dock instantly | Ukryty Dock pojawia się od razu
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.4

# Don't show recent apps in the Dock | Nie pokazuj ostatnich aplikacji w Docku
defaults write com.apple.dock show-recents -bool false

# Minimize windows into the app icon | Minimalizuj okna do ikony aplikacji
defaults write com.apple.dock minimize-to-application -bool true

# Group windows by application in Mission Control | Grupuj okna według aplikacji w Mission Control
defaults write com.apple.dock expose-group-apps -bool true

# Don't rearrange Spaces by recent use | Nie zmieniaj kolejności biurek (Spaces)
defaults write com.apple.dock mru-spaces -bool false

# Faster Mission Control animation | Szybsza animacja Mission Control
defaults write com.apple.dock expose-animation-duration -float 0.1

# Spring loading for all Dock items | Sprężynowe otwieranie wszystkich elementów Docka
defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true

# --- Screenshots | Zrzuty ekranu ---

# Copy screenshots to the clipboard | Kopiuj zrzuty ekranu do schowka
defaults write com.apple.screencapture target -string "clipboard"

# Save screenshots to ~/Pictures/Screenshots | Zapisuj zrzuty do ~/Pictures/Screenshots
mkdir -p "$HOME/Pictures/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Pictures/Screenshots"

# No window shadow in screenshots | Bez cienia okna na zrzutach
defaults write com.apple.screencapture disable-shadow -bool true

# Don't show the floating thumbnail | Bez pływającej miniatury po zrzucie
defaults write com.apple.screencapture show-thumbnail -bool false

# --- Keyboard & Trackpad | Klawiatura i gładzik ---

# Key repeat instead of the accent popup | Powtarzanie klawisza zamiast menu akcentów
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Fast key repeat | Szybkie powtarzanie klawiszy
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Full keyboard navigation in dialogs | Pełna obsługa okien dialogowych z klawiatury
defaults write NSGlobalDomain AppleKeyboardUIMode -int 2

# Disable autocorrect | Wyłącz autokorektę
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Disable smart quotes and dashes | Wyłącz inteligentne cudzysłowy i myślniki
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Disable automatic capitalization | Wyłącz automatyczne wielkie litery
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

# Disable period with double space | Wyłącz kropkę po podwójnej spacji
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Tap to click | Stuknięcie jako kliknięcie
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Three-finger drag | Przeciąganie trzema palcami
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true

# --- System ---

# Expand save dialogs by default | Rozwinięte okna zapisu
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Expand print dialogs by default | Rozwinięte okna drukowania
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Save new documents to disk, not iCloud | Zapisuj nowe dokumenty na dysku, nie w iCloud
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Show seconds in the menu bar clock | Pokaż sekundy w zegarze na pasku menu
defaults write com.apple.menuextra.clock ShowSeconds -bool true

# Don't offer new disks for Time Machine | Nie proponuj nowych dysków dla Time Machine
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# Don't open Photos when a device is connected | Nie otwieraj Zdjęć po podłączeniu urządzenia
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

# AirDrop over Ethernet | AirDrop przez Ethernet
defaults write com.apple.NetworkBrowser BrowseAllInterfaces -bool true

# Don't ask before opening downloaded apps (less secure) | Nie pytaj przed otwarciem pobranych aplikacji (mniej bezpieczne)
# @security lowers
defaults write com.apple.LaunchServices LSQuarantine -bool false

# --- Energy | Energia ---

# Computer sleep on power adapter | Usypianie komputera na zasilaczu
# @options 0=Never|Nigdy; 1=1 min; 2=2 min; 5=5 min; 10=10 min; 15=15 min; 30=30 min; 60=1 hour|1 godzina; 180=3 hours|3 godziny
# @current pmset -g custom | awk '/^AC Power/{s=1;next} /Power:$/{s=0} s && $1=="sleep"{print $2; exit}'
sudo pmset -c sleep "${VALUE:-0}"

# Computer sleep on battery | Usypianie komputera na baterii
# @options 0=Never|Nigdy; 1=1 min; 2=2 min; 5=5 min; 10=10 min; 15=15 min; 30=30 min; 60=1 hour|1 godzina; 180=3 hours|3 godziny
# @current pmset -g custom | awk '/^Battery Power/{s=1;next} /Power:$/{s=0} s && $1=="sleep"{print $2; exit}'
sudo pmset -b sleep "${VALUE:-15}"

# Display sleep on power adapter | Wygaszanie ekranu na zasilaczu
# @options 0=Never|Nigdy; 1=1 min; 2=2 min; 5=5 min; 10=10 min; 15=15 min; 30=30 min; 60=1 hour|1 godzina; 180=3 hours|3 godziny
# @current pmset -g custom | awk '/^AC Power/{s=1;next} /Power:$/{s=0} s && $1=="displaysleep"{print $2; exit}'
sudo pmset -c displaysleep "${VALUE:-15}"

# Display sleep on battery | Wygaszanie ekranu na baterii
# @options 0=Never|Nigdy; 1=1 min; 2=2 min; 5=5 min; 10=10 min; 15=15 min; 30=30 min; 60=1 hour|1 godzina; 180=3 hours|3 godziny
# @current pmset -g custom | awk '/^Battery Power/{s=1;next} /Power:$/{s=0} s && $1=="displaysleep"{print $2; exit}'
sudo pmset -b displaysleep "${VALUE:-5}"

# --- Developer | Dla programisty ---

# Create the ~/Developer folder | Utwórz folder ~/Developer
mkdir -p "$HOME/Developer"

# Hide "Last login" in new terminals | Ukryj komunikat „Last login” w terminalu
touch "$HOME/.hushlogin"

# Terminal: focus follows the mouse | Terminal: fokus podąża za myszą
defaults write com.apple.Terminal FocusFollowsMouse -bool true

# TextEdit opens plain text by default | TextEdit domyślnie w trybie zwykłego tekstu
defaults write com.apple.TextEdit RichText -bool false

# Show all processes in Activity Monitor | Pokaż wszystkie procesy w Monitorze aktywności
defaults write com.apple.ActivityMonitor ShowCategory -int 0

# Show all devices in Disk Utility | Pokaż wszystkie urządzenia w Narzędziu dyskowym
defaults write com.apple.DiskUtility SidebarShowAllDevices -bool true

# Git: name new branches "main" | Git: nowe gałęzie domyślnie „main”
git config --global init.defaultBranch main

# Git: push new branches without --set-upstream | Git: push nowych gałęzi bez --set-upstream
git config --global push.autoSetupRemote true

# Git: ignore .DS_Store in every repository | Git: ignoruj .DS_Store we wszystkich repozytoriach
grep -qxF ".DS_Store" "$HOME/.gitignore_global" 2>/dev/null || echo ".DS_Store" >> "$HOME/.gitignore_global"
git config --global core.excludesfile "$HOME/.gitignore_global"

# --- Security | Bezpieczeństwo ---

# Turn on the firewall | Włącz zaporę sieciową
# @security raises
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

# Firewall stealth mode (ignore pings) | Tryb ukryty zapory (ignoruj pingi)
# @security raises
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on

echo "Restarting system services..."
killall Dock Finder SystemUIServer 2>/dev/null || true

echo "Setup completed successfully."
