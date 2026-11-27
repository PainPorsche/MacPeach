# Changelog

## [1.0.1] - 2026-11-27

Wydanie poprawiające bezpieczeństwo. To pierwsze wydanie z sumą `SHA256SUMS` i atestacją pochodzenia (SLSA) – wydanie 1.0.0 ich nie ma.

### Bezpieczeństwo
- `sudo` w skryptach to zawsze `/usr/bin/sudo` z systemowym `PATH` (CWE-426). Wcześniej fałszywy `sudo` lub `pmset` podrzucony
  do `/usr/local/bin` albo `/opt/homebrew/bin` uruchamiał się zamiast prawdziwego i mógł przechwycić hasło administratora.
- Touch ID dla sudo: moduł `pam_reattach.so` jest kopiowany do `/opt/macpeach/pam` (właściciel root, tylko odczyt) i stamtąd
  ładowany przez PAM (CWE-427). Wcześniej był ładowany z katalogu Homebrew, do którego może pisać zwykłe konto.
  Jeśli dodatek włączono w 1.0.0, aplikacja pokaże go jako niewykonany – wykonaj krok ponownie.
- `/etc/pam.d/sudo_local` jest zapisywany przez potok, a nie z pliku tymczasowego, który dało się podmienić w trakcie podawania hasła (CWE-367).
- Homebrew jest instalowany z podpisanego i notaryzowanego `.pkg` z GitHub Releases (sprawdzany zespół `927JGANW46`
  i Gatekeeper) zamiast `curl … HEAD/install.sh | bash`.
- Klucz SSH: hasło nie trafia do argumentów `ssh-keygen` (widocznych w `ps`), wymagane co najmniej 8 znaków,
  klucze hosta GitHuba są przypięte (`StrictHostKeyChecking=yes` zamiast `accept-new`).
- Polecenia `@current` z własnego `~/.config/macpeach/MacSetup.sh`, których nie ma w wersji dołączonej do aplikacji,
  są uruchamiane dopiero po zatwierdzeniu w oknie, które je pokazuje.
- Procesy potomne dostają minimalne środowisko budowane od zera – bez `DYLD_*`, `BASH_ENV` itp.
- Montowanie NTFS: etykieta woluminu z dysku jest ograniczana do bezpiecznych znaków (CWE-22), a `ntfs-3g` i `ext4fuse`
  są brane tylko z katalogu Homebrew, nie z `PATH`.
- Presety i własny `MacSetup.sh` są wczytywane tylko jako zwykłe pliki z limitem rozmiaru sprawdzanym przed odczytem (CWE-400).
- Hardened Runtime jest włączony.

### Zmienione
- Ustawienia oznaczone w `MacSetup.sh` jako `# @security lowers|raises` mają w aplikacji etykietę „Obniża bezpieczeństwo”
  (wyłączenie kwarantanny) lub „Wzmacnia bezpieczeństwo” (zapora, tryb ukryty).
- Opisy dodatków NTFS i ext4 informują o rozszerzeniu jądra macFUSE i zewnętrznym tapie `gromgit/fuse`.
- Odinstalowanie ostatniego dodatku korzystającego z macFUSE usuwa też macFUSE.
- README: rzeczywiste połączenia sieciowe, weryfikacja wydania (`SHA256SUMS`, `gh attestation verify`), cofanie zmian;
  usunięta instrukcja wyłączania kwarantanny przez `xattr`.

### Dodane
- `SECURITY.md`: model zagrożeń, decyzje projektowe, ryzyka szczątkowe i zgłaszanie podatności.
- Testy regresji bezpieczeństwa (`Tests/run.sh`).
- CI: ShellCheck, testy, gitleaks, build Release, CodeQL, OpenSSF Scorecard, Dependabot.
- Pliki wydania (`MacPeach.dmg`, `SHA256SUMS`) budowane automatycznie przez GitHub Actions, z atestacją pochodzenia (SLSA).

## [1.0.0] - 2026-11-26

- Pierwsze wydanie.
