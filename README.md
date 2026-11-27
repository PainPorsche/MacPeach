# MacPeach

[Wersja PL](#wersja-pl) | [Wersja ENG](#wersja-eng)

## Wersja PL

Aplikacja do konfiguracji nowego Maca w kilka minut. Instaluje programy i narzędzia przez Homebrew, ustawia macOS pod pracę programisty i dodaje funkcje, których w systemie brakuje. Każdy skrypt można obejrzeć przed uruchomieniem.

Napisana w SwiftUI, bez zewnętrznych bibliotek. Wymaga macOS 14 Sonoma lub nowszego.

![MacPeach – tryb jasny, zakładka Aplikacje](assets/screenshot_pl.png)

### Funkcje

- **Aplikacje** – 44 programy (`brew install --cask`) i 36 narzędzi CLI w kategoriach, z wyszukiwarką. Przy starcie MacPeach sprawdza, co już jest na Macu (przez Homebrew lub zainstalowane ręcznie), i oznacza te pozycje zielonym „Zainstalowano”.
- **Konfiguracja systemu** – 61 ustawień: Finder, Dock, zrzuty ekranu (np. do schowka), klawiatura, gładzik, energia (czas uśpienia komputera i ekranu, osobno na zasilaczu i baterii), Git, zapora. MacPeach odczytuje bieżące wartości, oznacza ustawienia, które już obowiązują, i pokazuje obecne parametry obok listy wyboru.
- **Dodatki** – funkcje wymagające kilku poleceń: zapis na dyskach NTFS, odczyt dysków ext4, „Nowy plik” i „Otwórz w Terminalu” pod prawym przyciskiem w Finderze, klucz SSH do GitHuba, Touch ID dla `sudo`.
- **Presety** – zapis zaznaczeń do `~/.config/macpeach/presets.json`, eksport i import, żeby odtworzyć ten sam zestaw na innym Macu.
- Prawdziwe dane o urządzeniu (model, macOS, procesor, pamięć, wolne miejsce), odświeżane na bieżąco.
- Język polski i angielski, tryb jasny i ciemny.
- Logi w `~/Library/Logs/MacPeach`: wynik każdego skryptu, błędy, raport po awarii lub zawieszeniu pokazywany przy następnym uruchomieniu. Logi nie są nigdzie wysyłane.

### Instalacja

Pobierz `MacPeach.dmg` z [Releases](https://github.com/PainPorsche/MacPeach/releases), otwórz go i przeciągnij **MacPeach** do folderu **Applications**. Wersja jest uniwersalna – działa na Macach z procesorem Intel i Apple silicon. Przy pierwszym uruchomieniu zobacz sekcję [Pierwsze uruchomienie pobranej aplikacji](#pierwsze-uruchomienie-pobranej-aplikacji).

Do każdego wydania dołączony jest też PDF z procedurą zmian, np. `MacPeach_procedura_v1.0.1.pdf` – przegląd bezpieczeństwa i poprawki w wersji 1.0.1 (PL i ENG).

Przed otwarciem sprawdź, czy plik nie został podmieniony. Porównaj sumę z plikiem `SHA256SUMS` z tego samego wydania, a dla wydań budowanych w GitHub Actions sprawdź też atestację pochodzenia (wymaga [GitHub CLI](https://cli.github.com)):

```
shasum -a 256 MacPeach.dmg
gh attestation verify MacPeach.dmg --repo PainPorsche/MacPeach
```

Pobieraj MacPeach tylko z tego repozytorium. Aplikacja prosi o hasło administratora, więc podrobiona kopia byłaby groźna.

### Połączenia sieciowe

Sama aplikacja łączy się tylko z publicznym API Homebrew (`formulae.brew.sh/api/cask/<nazwa>.json`). Pobiera z niego opisy casków z listy, żeby wykryć programy zainstalowane ręcznie, i przechowuje je w pamięci podręcznej przez 7 dni. Serwer widzi więc adres IP i nazwy pakietów z listy. Uruchamiane przez Ciebie skrypty pobierają pakiety przez Homebrew, a instalator Homebrew przez GitHub Releases. Nie ma telemetrii, a logi zostają na Macu.

### Lista pakietów

Pozycje są wczytywane z pliku [`MacSetup.sh`](MacPeach/MacSetup.sh), który jest też samodzielnym skryptem instalacyjnym. Komentarz `# English | Polski` nad poleceniem to jego opis w obu językach, a `# --- Kategoria ---` zaczyna nową sekcję. Ustawienie z listą wyboru opisują dwie dodatkowe linie: `# @options 0=Never|Nigdy; 5=5 min` oraz `# @current <polecenie odczytujące obecną wartość>`, a w poleceniu wartość wstawiana jest w miejsce `${VALUE:-domyślna}`. Linia `# @security lowers` lub `# @security raises` oznacza ustawienie, które osłabia albo wzmacnia zabezpieczenia macOS; aplikacja pokazuje przy nim odpowiednią etykietę. W **Ustawieniach** można utworzyć własną kopię w `~/.config/macpeach/MacSetup.sh` i edytować listę bez przebudowywania aplikacji. Polecenia `@current` z własnej kopii, których nie ma w wersji dołączonej do aplikacji, są uruchamiane dopiero po zatwierdzeniu w oknie, które je pokazuje.

### Budowanie

```
git clone https://github.com/PainPorsche/MacPeach.git
cd MacPeach
open MacPeach.xcodeproj
```

W Xcode wybierz schemat **MacPeach** i **Product > Run**. Testy bezpieczeństwa uruchomisz poleceniem `Tests/run.sh`. Z terminala:

```
xcodebuild -project MacPeach.xcodeproj -scheme MacPeach -configuration Release -destination 'generic/platform=macOS' build
```

### Procesory Intel i Apple silicon

Program jest rozwijany i testowany na MacBooku Pro (13-inch, 2020, Two Thunderbolt 3 ports) z procesorem Intel. Build Release jest uniwersalny (`x86_64` + `arm64`), więc działa natywnie na obu architekturach. Ścieżki Homebrew (`/usr/local` i `/opt/homebrew`) są wykrywane automatycznie.

### Pierwsze uruchomienie pobranej aplikacji

Aplikacja jest podpisana tylko lokalnie (ad hoc, z Hardened Runtime) i nie przeszła notaryzacji Apple, bo to wymaga płatnego konta Apple Developer. Jeśli pobierzesz gotową aplikację (`MacPeach.dmg`) z internetu, macOS może zablokować pierwsze uruchomienie. Na Macach z procesorem Apple (M1 i nowsze) komunikat bywa mylący: „aplikacja jest uszkodzona i nie można jej otworzyć”.

Najpierw sprawdź sumę SHA-256 (sekcja [Instalacja](#instalacja)). Potem otwórz **Ustawienia systemowe › Prywatność i ochrona** i kliknij **Otwórz mimo to**. To wyjątek tylko dla tej jednej aplikacji, Gatekeeper dalej chroni resztę systemu.

Jeśli przycisku nie ma, nie wyłączaj Gatekeepera ani kwarantanny. Zbuduj aplikację ze źródeł (sekcja [Budowanie](#budowanie)), bo wtedy problem nie występuje.

Ten problem nie dotyczy aplikacji zbudowanej samodzielnie w Xcode.

### Cofanie zmian

- **Touch ID dla sudo, Szybkie czynności, NTFS, ext4:** przycisk **Wyłącz**, **Usuń** lub **Odinstaluj** na karcie dodatku. Odinstalowanie ostatniego dodatku korzystającego z macFUSE usuwa też macFUSE. Obniżone zabezpieczenia trzeba przywrócić ręcznie w trybie odzyskiwania (Narzędzie zabezpieczeń uruchamiania › Pełne zabezpieczenia).
- **Pytanie przed otwarciem pobranych aplikacji:** `defaults write com.apple.LaunchServices LSQuarantine -bool true`
- **Zapora i tryb ukryty:** Ustawienia systemowe › Sieć › Zapora.
- **Pozostałe ustawienia:** `defaults delete <domena> <klucz>` przywraca wartość domyślną. Polecenia każdego ustawienia widać w aplikacji i w `MacSetup.sh`.

### Bezpieczeństwo

Model zagrożeń, decyzje projektowe (m.in. wyłączony App Sandbox) i sposób zgłaszania podatności opisuje [SECURITY.md](SECURITY.md).

## Wersja ENG

An app that sets up a new Mac in minutes. It installs apps and tools with Homebrew, tunes macOS for development work and adds features the system lacks. Every script can be reviewed before it runs.

Built with SwiftUI and no third-party dependencies. Requires macOS 14 Sonoma or later.

![MacPeach – dark mode, Add-ons tab](assets/screenshot_en.png)

### Features

- **Applications** – 44 apps (`brew install --cask`) and 36 CLI tools grouped into categories, with search. On launch MacPeach checks what is already on the Mac (via Homebrew or installed manually) and marks those items with a green “Installed”.
- **System Configuration** – 61 settings: Finder, Dock, screenshots (e.g. to the clipboard), keyboard, trackpad, energy (computer and display sleep time, separately on power adapter and battery), Git, firewall. MacPeach reads the current values, marks the settings already in effect and shows current parameters next to the choice list.
- **Add-ons** – features that take several commands: NTFS write support, ext4 read access, “New File” and “Open in Terminal” in the Finder right-click menu, an SSH key for GitHub, Touch ID for `sudo`.
- **Presets** – save selections to `~/.config/macpeach/presets.json`, export and import them to recreate the same setup on another Mac.
- Real device information (model, macOS, chip, memory, free space), refreshed live.
- Polish and English, light and dark mode.
- Logs in `~/Library/Logs/MacPeach`: the output of every script, errors, and crash or hang reports shown on next launch. Logs are never sent anywhere.

### Installation

Download `MacPeach.dmg` from [Releases](https://github.com/PainPorsche/MacPeach/releases), open it and drag **MacPeach** to the **Applications** folder. The build is universal – it runs on both Intel and Apple silicon Macs. For the first launch see [First launch of a downloaded app](#first-launch-of-a-downloaded-app).

Every release also includes a PDF describing the changes, e.g. `MacPeach_procedura_v1.0.1.pdf` – the security review and fixes in version 1.0.1 (PL and ENG).

Before opening it, check that the file has not been tampered with. Compare its checksum with `SHA256SUMS` from the same release, and for releases built in GitHub Actions also verify the build provenance attestation (requires [GitHub CLI](https://cli.github.com)):

```
shasum -a 256 MacPeach.dmg
gh attestation verify MacPeach.dmg --repo PainPorsche/MacPeach
```

Only download MacPeach from this repository. The app asks for the administrator password, so a forged copy would be dangerous.

### Network connections

The app itself only connects to the public Homebrew API (`formulae.brew.sh/api/cask/<name>.json`). It fetches descriptions of the listed casks to detect apps installed manually and caches them for 7 days, so the server sees your IP address and the cask names from the list. Scripts you run download packages through Homebrew, and the Homebrew installer through GitHub Releases. There is no telemetry, and logs stay on your Mac.

### Package list

Items are read from [`MacSetup.sh`](MacPeach/MacSetup.sh), which is also a standalone setup script. A `# English | Polski` comment above a command is its description in both languages, and `# --- Category ---` starts a new section. A setting with a choice list has two extra lines: `# @options 0=Never|Nigdy; 5=5 min` and `# @current <command that reads the current value>`; the chosen value replaces `${VALUE:-default}` in the command. A `# @security lowers` or `# @security raises` line marks a setting that weakens or strengthens macOS protections, and the app labels it accordingly. In **Settings** you can create your own copy at `~/.config/macpeach/MacSetup.sh` and edit the list without rebuilding the app. `@current` commands in your copy that are not in the version shipped with the app only run after you approve them in a dialog that lists them.

### Building

```
git clone https://github.com/PainPorsche/MacPeach.git
cd MacPeach
open MacPeach.xcodeproj
```

In Xcode choose the **MacPeach** scheme and **Product > Run**. Run the security tests with `Tests/run.sh`. From the terminal:

```
xcodebuild -project MacPeach.xcodeproj -scheme MacPeach -configuration Release -destination 'generic/platform=macOS' build
```

### Intel and Apple silicon

The app is developed and tested on a MacBook Pro (13-inch, 2020, Two Thunderbolt 3 ports) with an Intel processor. The Release build is universal (`x86_64` + `arm64`), so it runs natively on both architectures. Homebrew paths (`/usr/local` and `/opt/homebrew`) are detected automatically.

### First launch of a downloaded app

The app is only signed locally (ad hoc, with the Hardened Runtime) and is not notarized by Apple, which requires a paid Apple Developer account. If you download the prebuilt app (`MacPeach.dmg`) from the internet, macOS may block the first launch. On Macs with Apple silicon (M1 and later) the message can be misleading: “the app is damaged and can't be opened”.

First verify the SHA-256 checksum (see [Installation](#installation)). Then go to **System Settings › Privacy & Security** and click **Open Anyway**. This makes an exception for this one app only, and Gatekeeper keeps protecting the rest of the system.

If the button does not appear, do not turn off Gatekeeper or the quarantine. Build the app from source instead (see [Building](#building)), which avoids the problem.

This does not affect an app you build yourself in Xcode.

### Undoing changes

- **Touch ID for sudo, Quick Actions, NTFS, ext4:** the **Disable**, **Remove** or **Uninstall** button on the add-on card. Uninstalling the last add-on that uses macFUSE also removes macFUSE. Reduced Security has to be restored by hand in Recovery (Startup Security Utility › Full Security).
- **Prompt before opening downloaded apps:** `defaults write com.apple.LaunchServices LSQuarantine -bool true`
- **Firewall and stealth mode:** System Settings › Network › Firewall.
- **Other settings:** `defaults delete <domain> <key>` restores the default. The commands of every setting are shown in the app and in `MacSetup.sh`.

### Security

[SECURITY.md](SECURITY.md) describes the threat model, design decisions (including why App Sandbox is off) and how to report a vulnerability.
