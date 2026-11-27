# Security / Bezpieczeństwo

[English](#english) | [Polski](#polski)

## English

### Reporting a vulnerability

Please do not open a public issue. Use **Security › Report a vulnerability** on GitHub (private vulnerability reporting). Describe the affected version, the steps to reproduce and the impact. You should get a reply within 7 days.

Only the latest release is supported.

### Threat model

MacPeach is a setup tool: it runs shell scripts, some of them with `sudo`, after you review them. The parts that matter for security are:

- **Privilege boundary.** The administrator password is requested through an `askpass` dialog, passed straight to `sudo -A` and never stored or logged. Every script, its temporary files (0700) and logs (0600) stay in your account.
- **Supply chain.** Packages come from Homebrew. Most come from `homebrew-core` and the official cask repository. The NTFS and ext4 add-ons use the third-party tap `gromgit/fuse` and the macFUSE kernel extension; the app says so next to them. Homebrew itself is installed from its signed and notarized `.pkg`: the script checks the Developer ID Installer team (`927JGANW46`) and Gatekeeper before running it.
- **Persistent changes.** The Touch ID add-on writes `/etc/pam.d/sudo_local`. The optional `pam_reattach.so` module runs inside `sudo` as root, so it is copied to `/opt/macpeach/pam` (owned by `root:wheel`, read-only). It is never loaded from the Homebrew prefix, which your user account can write to. Quick Actions are written to `~/Library/Services`.
- **Input handling.** Package names and option values must match strict allow-list patterns and are shell-quoted. `@current` commands from a custom `~/.config/macpeach/MacSetup.sh` that differ from the bundled file only run after you approve them in a dialog that lists them.
- **Child process environment.** Scripts get a minimal environment built from scratch (`PATH`, `HOME`, `USER`, locale, proxy and `SSH_AUTH_SOCK`). `DYLD_*`, `BASH_ENV` and similar variables are not inherited.
- **Network.** The app only calls `formulae.brew.sh` to read cask metadata. There is no telemetry.

### Design decisions

- **App Sandbox is off.** The app has to run `brew`, `defaults`, `pmset`, `diskutil` and `sudo` and write to `~/Library/Services`, and none of that is possible from the sandbox. The Hardened Runtime is on.
- **No notarization.** It needs a paid Apple Developer account. Releases are signed ad hoc. To check that a downloaded file is genuine, use `SHA256SUMS` and `gh attestation verify` (see README).
- **Settings that lower security** (for example turning off the download quarantine prompt) are marked with `# @security lowers` in `MacSetup.sh` and labelled in the app. Settings that raise it (firewall, stealth mode) are marked `# @security raises`.

### Known residual risks

- **Another process under your account.** MacPeach cannot fully protect against malware that already runs as you. Mitigations: `sudo` is always `/usr/bin/sudo` with a system-only `PATH`, so a fake `sudo` or `pmset` planted in `/usr/local/bin` or `/opt/homebrew/bin` never runs; `sudo_local` is written through a pipe, not a temp file; PAM modules are loaded only from a root-owned folder.
- **NTFS and ext4 mounting** runs `ntfs-3g` / `ext4fuse` from the Homebrew prefix as root. Volume labels read from the drive are reduced to safe characters before they are used as a mount point.
- **Casks without a checksum.** `find-any-file`, `google-chrome`, `spotify` and `switch` use `sha256 :no_check` (the vendor always serves the latest build). Integrity relies on HTTPS and on Gatekeeper checking the app's signature on first launch.
- **Unsigned commits and tags.** Signing is set up on the maintainer's machine: `git config --global gpg.format ssh`, `git config --global user.signingkey ~/.ssh/id_ed25519.pub`, `git config --global commit.gpgsign true`, `git config --global tag.gpgsign true`, then add the key on GitHub as a *Signing key*.

### Development process

- CI runs ShellCheck, the security regression tests (`Tests/run.sh`), gitleaks, a Release build, CodeQL and OpenSSF Scorecard.
- Release files are built in GitHub Actions and published with `SHA256SUMS` and a SLSA build provenance attestation.
- Third-party GitHub Actions are pinned to commit SHAs and updated by Dependabot.

## Polski

### Zgłaszanie podatności

Nie zakładaj publicznego zgłoszenia (issue). Użyj w GitHubie **Security › Report a vulnerability** (prywatne zgłaszanie podatności). Opisz wersję, kroki do odtworzenia i skutki. Odpowiedź powinna przyjść w ciągu 7 dni.

Wspierana jest tylko najnowsza wersja.

### Model zagrożeń

MacPeach to narzędzie konfiguracyjne: uruchamia skrypty powłoki, część z nich przez `sudo`, po tym jak je obejrzysz. Dla bezpieczeństwa liczą się:

- **Granica uprawnień.** Hasło administratora jest pobierane w oknie `askpass`, przekazywane wprost do `sudo -A` i nigdzie nie jest zapisywane ani logowane. Skrypty, ich pliki tymczasowe (0700) i logi (0600) zostają na Twoim koncie.
- **Łańcuch dostaw.** Pakiety pochodzą z Homebrew, głównie z `homebrew-core` i oficjalnego repozytorium casków. Dodatki NTFS i ext4 korzystają z zewnętrznego tapa `gromgit/fuse` i rozszerzenia jądra macFUSE, o czym aplikacja informuje przy nich. Sam Homebrew jest instalowany z podpisanego i notaryzowanego `.pkg`: skrypt przed uruchomieniem sprawdza zespół Developer ID Installer (`927JGANW46`) i Gatekeepera.
- **Trwałe zmiany.** Dodatek Touch ID zapisuje `/etc/pam.d/sudo_local`. Opcjonalny moduł `pam_reattach.so` działa wewnątrz `sudo` jako root, dlatego jest kopiowany do `/opt/macpeach/pam` (właściciel `root:wheel`, tylko do odczytu). Nigdy nie jest ładowany z katalogu Homebrew, do którego może pisać Twoje konto. Szybkie czynności trafiają do `~/Library/Services`.
- **Dane wejściowe.** Nazwy pakietów i wartości opcji muszą pasować do ścisłych wzorców i są cytowane dla powłoki. Polecenia `@current` z własnego `~/.config/macpeach/MacSetup.sh`, które różnią się od pliku dołączonego do aplikacji, są uruchamiane dopiero po zatwierdzeniu w oknie, które je pokazuje.
- **Środowisko procesów potomnych.** Skrypty dostają minimalne środowisko budowane od zera (`PATH`, `HOME`, `USER`, ustawienia językowe, proxy i `SSH_AUTH_SOCK`). Zmienne `DYLD_*`, `BASH_ENV` i podobne nie są dziedziczone.
- **Sieć.** Aplikacja łączy się tylko z `formulae.brew.sh`, żeby odczytać opisy casków. Nie ma telemetrii.

### Decyzje projektowe

- **App Sandbox jest wyłączony.** Aplikacja musi uruchamiać `brew`, `defaults`, `pmset`, `diskutil` i `sudo` oraz pisać do `~/Library/Services`, a w piaskownicy nic z tego nie zadziała. Hardened Runtime jest włączony.
- **Brak notaryzacji.** Wymaga płatnego konta Apple Developer. Wydania są podpisane ad hoc. Autentyczność pobranego pliku sprawdzisz przez `SHA256SUMS` i `gh attestation verify` (zob. README).
- **Ustawienia obniżające bezpieczeństwo** (np. wyłączenie pytania o pobrane aplikacje) są oznaczone w `MacSetup.sh` linią `# @security lowers` i mają etykietę w aplikacji. Ustawienia wzmacniające (zapora, tryb ukryty) mają `# @security raises`.

### Znane ryzyka szczątkowe

- **Inny proces na Twoim koncie.** MacPeach nie obroni się w pełni przed złośliwym programem, który już działa jako Ty. Zabezpieczenia: `sudo` to zawsze `/usr/bin/sudo` z systemowym `PATH`, więc fałszywy `sudo` lub `pmset` podrzucony do `/usr/local/bin` albo `/opt/homebrew/bin` nigdy się nie uruchomi; `sudo_local` jest zapisywany przez potok, a nie plik tymczasowy; moduły PAM są ładowane tylko z katalogu należącego do roota.
- **Montowanie NTFS i ext4** uruchamia `ntfs-3g` / `ext4fuse` z katalogu Homebrew jako root. Etykieta woluminu odczytana z dysku jest przed użyciem jako punkt montowania ograniczana do bezpiecznych znaków.
- **Casks bez sumy kontrolnej.** `find-any-file`, `google-chrome`, `spotify` i `switch` mają `sha256 :no_check` (producent zawsze udostępnia najnowszą wersję). Integralność zapewniają HTTPS i Gatekeeper, który sprawdza podpis aplikacji przy pierwszym uruchomieniu.
- **Niepodpisane commity i tagi.** Podpisywanie konfiguruje się na komputerze opiekuna: `git config --global gpg.format ssh`, `git config --global user.signingkey ~/.ssh/id_ed25519.pub`, `git config --global commit.gpgsign true`, `git config --global tag.gpgsign true`, a potem dodaje klucz w GitHubie jako *Signing key*.

### Proces wytwarzania

- CI uruchamia ShellCheck, testy regresji bezpieczeństwa (`Tests/run.sh`), gitleaks, build Release, CodeQL i OpenSSF Scorecard.
- Pliki wydania są budowane w GitHub Actions i publikowane razem z `SHA256SUMS` i atestacją pochodzenia buildu (SLSA).
- Zewnętrzne akcje GitHuba są przypięte do SHA commitów i aktualizowane przez Dependabota.
