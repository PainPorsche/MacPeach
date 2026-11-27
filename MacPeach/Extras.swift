import Foundation

nonisolated enum ExtrasCatalog {
    static let all: [Extra] = [ntfs, ext4, quickActions, githubSSH, touchID]

    private static func t(_ lang: Lang, _ pl: String, _ en: String) -> String {
        Shell.quote(lang == .pl ? pl : en)
    }

    private static let fuseInstalled = "[ -d /Library/Filesystems/macfuse.fs ]"

    private static func uninstallFUSE(_ formula: String, other: String, _ lang: Lang) -> String {
        """
        brew uninstall \(formula)
        if ! { \(formulaInstalled(other)); }; then
          brew uninstall --cask macfuse || true
        fi
        echo \(t(lang, "Jeśli obniżono zabezpieczenia dla macFUSE, przywróć pełne w trybie odzyskiwania (Narzędzie zabezpieczeń uruchamiania).",
                       "If you lowered security for macFUSE, restore Full Security in Recovery (Startup Security Utility)."))
        """
    }

    private static func formulaInstalled(_ name: String) -> String {
        "[ -d /opt/homebrew/opt/\(name) ] || [ -d /usr/local/opt/\(name) ]"
    }

    static let ntfs = Extra(
        id: "ntfs",
        icon: "externaldrive.badge.plus",
        title: BiText(en: "NTFS write support", pl: "Zapis na dyskach NTFS"),
        summary: BiText(en: "macOS can only read Windows drives. macFUSE + ntfs-3g add full write access.",
                        pl: "macOS tylko odczytuje dyski z Windowsa. macFUSE + ntfs-3g dodają pełny zapis."),
        note: BiText(en: "Lowers system security: macFUSE is a kernel extension and on Apple silicon needs Reduced Security set in Recovery plus system extensions allowed in Privacy & Security. ntfs-3g comes from the third-party tap gromgit/fuse, not from homebrew-core. Mounting runs ntfs-3g from the Homebrew folder as root, so only use it on a Mac where you trust everything running under your account. A restart may be required.",
                     pl: "Obniża bezpieczeństwo systemu: macFUSE to rozszerzenie jądra i na Apple silicon wymaga ustawienia obniżonych zabezpieczeń w trybie odzyskiwania oraz zezwolenia na rozszerzenia w Prywatność i ochrona. ntfs-3g pochodzi z zewnętrznego tapa gromgit/fuse, nie z homebrew-core. Montowanie uruchamia ntfs-3g z katalogu Homebrew jako root, więc używaj go tylko na Macu, na którym ufasz wszystkiemu, co działa na Twoim koncie. Może być potrzebny restart."),
        steps: [
            ExtraStep(
                id: "ntfs.install",
                title: BiText(en: "Install drivers", pl: "Zainstaluj sterowniki"),
                script: { lang in
                    """
                    set -e
                    brew install --cask macfuse
                    brew tap gromgit/fuse
                    brew install gromgit/fuse/ntfs-3g-mac
                    echo
                    echo \(t(lang, "Gotowe. Jeśli macOS poprosi, zezwól na rozszerzenie macFUSE w Ustawieniach systemowych → Prywatność i ochrona.",
                                   "Done. If macOS asks, allow the macFUSE extension in System Settings → Privacy & Security."))
                    """
                },
                requiresBrew: true,
                check: "\(fuseInstalled) && { \(formulaInstalled("ntfs-3g-mac")); }"
            ),
            ExtraStep(
                id: "ntfs.mount",
                title: BiText(en: "Mount NTFS drives", pl: "Zamontuj dyski NTFS"),
                script: { lang in
                    """
                    NTFS3G=""
                    for candidate in "$(brew --prefix)/sbin/ntfs-3g" "$(brew --prefix)/bin/ntfs-3g"; do
                      [ -x "$candidate" ] && { NTFS3G="$candidate"; break; }
                    done
                    if [ -z "$NTFS3G" ]; then
                      echo \(t(lang, "Brak ntfs-3g. Najpierw wykonaj krok 1.", "ntfs-3g not found. Run step 1 first."))
                      exit 1
                    fi
                    found=0
                    for dev in $(diskutil list | grep -oE 'disk[0-9]+s[0-9]+' | sort -u); do
                      info="$(diskutil info "$dev" 2>/dev/null)"
                      echo "$info" | grep -qiE '(Type \\(Bundle\\)|File System Personality): +ntfs' || continue
                      found=1
                      # The volume label comes from the drive, so it is untrusted: keep safe characters only.
                      name="$(echo "$info" | sed -n 's/^ *Volume Name: *//p' | head -n 1 | LC_ALL=C tr -d '\\n' | LC_ALL=C tr -c 'A-Za-z0-9._ -' '_' | cut -c1-64)"
                      case "$name" in ''|.*) name="$dev" ;; esac
                      mountpoint="/Volumes/$name"
                      if /sbin/mount | grep -qF " on $mountpoint ("; then mountpoint="/Volumes/NTFS-$dev"; fi
                      echo "==> /dev/$dev → $mountpoint"
                      diskutil unmount "/dev/$dev" >/dev/null 2>&1 || true
                      sudo mkdir -p "$mountpoint"
                      sudo "$NTFS3G" "/dev/$dev" "$mountpoint" -o local -o allow_other -o auto_xattr -o auto_cache \\
                        -o uid="$(id -u)" -o gid="$(id -g)" -o volname="$name"
                    done
                    if [ "$found" -eq 0 ]; then
                      echo \(t(lang, "Nie znaleziono podłączonych dysków NTFS.", "No connected NTFS drives were found."))
                      exit 1
                    fi
                    echo \(t(lang, "Dyski NTFS są zamontowane z prawem zapisu.", "NTFS drives are mounted with write access."))
                    """
                },
                requiresBrew: true,
                check: nil
            ),
        ],
        undo: ExtraAction(
            title: BiText(en: "Uninstall", pl: "Odinstaluj"),
            script: { lang in uninstallFUSE("gromgit/fuse/ntfs-3g-mac", other: "ext4fuse-mac", lang) }
        )
    )

    static let ext4 = Extra(
        id: "ext4",
        icon: "server.rack",
        title: BiText(en: "Linux (ext4) drives", pl: "Dyski z Linuksa (ext4)"),
        summary: BiText(en: "Read ext4 partitions from Linux disks and Raspberry Pi SD cards (read-only).",
                        pl: "Odczyt partycji ext4 z dysków Linuksa i kart SD z Raspberry Pi (tylko odczyt)."),
        note: BiText(en: "Uses macFUSE (a kernel extension that needs Reduced Security on Apple silicon), like NTFS support. ext4fuse comes from the third-party tap gromgit/fuse.",
                     pl: "Korzysta z macFUSE (rozszerzenie jądra, które na Apple silicon wymaga obniżonych zabezpieczeń), tak jak obsługa NTFS. ext4fuse pochodzi z zewnętrznego tapa gromgit/fuse."),
        steps: [
            ExtraStep(
                id: "ext4.install",
                title: BiText(en: "Install ext4fuse", pl: "Zainstaluj ext4fuse"),
                script: { _ in
                    """
                    set -e
                    brew install --cask macfuse
                    brew tap gromgit/fuse
                    brew install gromgit/fuse/ext4fuse-mac
                    """
                },
                requiresBrew: true,
                check: "\(fuseInstalled) && { \(formulaInstalled("ext4fuse-mac")); }"
            ),
            ExtraStep(
                id: "ext4.mount",
                title: BiText(en: "Mount Linux drives", pl: "Zamontuj dyski Linux"),
                script: { lang in
                    """
                    EXT4=""
                    [ -x "$(brew --prefix)/bin/ext4fuse" ] && EXT4="$(brew --prefix)/bin/ext4fuse"
                    if [ -z "$EXT4" ]; then
                      echo \(t(lang, "Brak ext4fuse. Najpierw wykonaj krok 1.", "ext4fuse not found. Run step 1 first."))
                      exit 1
                    fi
                    found=0
                    for dev in $(diskutil list | awk '/Linux/ {print $NF}' | grep -E '^disk[0-9]+s[0-9]+$'); do
                      found=1
                      mountpoint="/Volumes/Linux-$dev"
                      echo "==> /dev/$dev → $mountpoint"
                      sudo mkdir -p "$mountpoint"
                      sudo "$EXT4" "/dev/$dev" "$mountpoint" -o allow_other -o volname="Linux-$dev"
                    done
                    if [ "$found" -eq 0 ]; then
                      echo \(t(lang, "Nie znaleziono partycji Linux.", "No Linux partitions were found."))
                      exit 1
                    fi
                    """
                },
                requiresBrew: true,
                check: nil
            ),
        ],
        undo: ExtraAction(
            title: BiText(en: "Uninstall", pl: "Odinstaluj"),
            script: { lang in uninstallFUSE("gromgit/fuse/ext4fuse-mac", other: "ntfs-3g-mac", lang) }
        )
    )

    private static func workflowNames(_ lang: Lang) -> (newFile: String, terminal: String, untitled: String) {
        lang == .pl ? ("Nowy plik", "Otwórz w Terminalu", "bez nazwy") : ("New File", "Open in Terminal", "untitled")
    }

    static let quickActions = Extra(
        id: "quickactions",
        icon: "contextualmenu.and.cursorarrow",
        title: BiText(en: "Finder: New File & Open in Terminal", pl: "Finder: Nowy plik i Otwórz w Terminalu"),
        summary: BiText(en: "Adds “New File” and “Open in Terminal” to the right-click menu of files and folders.",
                        pl: "Dodaje „Nowy plik” i „Otwórz w Terminalu” do menu pod prawym przyciskiem na plikach i folderach."),
        note: BiText(en: "Right-click a folder → Quick Actions. If they don't show up, enable them in System Settings → Privacy & Security → Extensions → Finder.",
                     pl: "Prawy przycisk na folderze → Szybkie czynności. Jeśli ich nie widać, włącz je w Ustawieniach → Prywatność i ochrona → Rozszerzenia → Finder."),
        steps: [
            ExtraStep(
                id: "quickactions.install",
                title: BiText(en: "Add Quick Actions", pl: "Dodaj szybkie czynności"),
                script: { lang in
                    let names = workflowNames(lang)
                    let newFile = """
                    target="$1"
                    [ -d "$target" ] || target="$(dirname "$target")"
                    name="\(names.untitled).txt"
                    i=2
                    while [ -e "$target/$name" ]; do name="\(names.untitled) $i.txt"; i=$((i+1)); done
                    touch "$target/$name" && open -R "$target/$name"
                    """
                    let terminal = """
                    for item in "$@"; do
                      [ -d "$item" ] || item="$(dirname "$item")"
                      open -a Terminal "$item"
                    done
                    """
                    return """
                    set -e
                    SERVICES="$HOME/Library/Services"
                    mkdir -p "$SERVICES"
                    rm -rf "$SERVICES/New File.workflow" "$SERVICES/Nowy plik.workflow" "$SERVICES/Open in Terminal.workflow" "$SERVICES/Otwórz w Terminalu.workflow"
                    \(Workflow.installCommands(name: names.newFile, shellScript: newFile))
                    \(Workflow.installCommands(name: names.terminal, shellScript: terminal))
                    /System/Library/CoreServices/pbs -flush || true
                    /System/Library/CoreServices/pbs -update || true
                    killall Finder || true
                    echo \(t(lang, "Gotowe: kliknij prawym przyciskiem folder → Szybkie czynności.", "Done: right-click a folder → Quick Actions."))
                    """
                },
                requiresBrew: false,
                check: "[ -d \"$HOME/Library/Services/New File.workflow\" ] || [ -d \"$HOME/Library/Services/Nowy plik.workflow\" ]"
            ),
            ExtraStep(
                id: "quickactions.settings",
                title: BiText(en: "Check in Settings", pl: "Sprawdź w Ustawieniach"),
                script: { lang in
                    """
                    open "x-apple.systempreferences:com.apple.ExtensionsPreferences"
                    echo \(t(lang, "Otworzono Ustawienia → Rozszerzenia. Upewnij się, że akcje są zaznaczone w sekcji Finder.",
                                   "Opened Settings → Extensions. Make sure the actions are enabled under Finder."))
                    """
                },
                requiresBrew: false,
                check: nil
            ),
        ],
        undo: ExtraAction(
            title: BiText(en: "Remove", pl: "Usuń"),
            script: { _ in
                """
                SERVICES="$HOME/Library/Services"
                rm -rf "$SERVICES/New File.workflow" "$SERVICES/Nowy plik.workflow" "$SERVICES/Open in Terminal.workflow" "$SERVICES/Otwórz w Terminalu.workflow"
                /System/Library/CoreServices/pbs -update || true
                """
            }
        )
    )

    /// Host keys published by GitHub (https://api.github.com/meta, "ssh_keys"), pinned instead of trusting the first connection.
    static let githubHostKeys = [
        "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl",
        "github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=",
        "github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=",
    ]

    private static func pinGitHubHostKeys(_ lang: Lang) -> String {
        let lines = githubHostKeys.map(Shell.quote).joined(separator: " ")
        return """
        KH="$HOME/.ssh/known_hosts"
        mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
        touch "$KH" && chmod 600 "$KH"
        if ! ssh-keygen -F github.com -f "$KH" >/dev/null 2>&1; then
          printf '%s\\n' \(lines) >> "$KH"
          echo \(t(lang, "Dodano klucze hosta GitHuba do ~/.ssh/known_hosts", "Added GitHub's host keys to ~/.ssh/known_hosts"))
        fi
        """
    }

    static let githubSSH = Extra(
        id: "ssh",
        icon: "key.horizontal.fill",
        title: BiText(en: "SSH key for GitHub", pl: "Klucz SSH do GitHuba"),
        summary: BiText(en: "Generates an Ed25519 key, stores its passphrase in the Keychain and connects it to GitHub.",
                        pl: "Tworzy klucz Ed25519, zapisuje hasło w Pęku kluczy i podłącza go do GitHuba."),
        note: BiText(en: "An existing ~/.ssh/id_ed25519 key is never overwritten. GitHub's published host keys are added to ~/.ssh/known_hosts, so the connection is checked against them.",
                     pl: "Istniejący klucz ~/.ssh/id_ed25519 nigdy nie jest nadpisywany. Opublikowane przez GitHub klucze hosta trafiają do ~/.ssh/known_hosts, więc połączenie jest z nimi porównywane."),
        steps: [
            ExtraStep(
                id: "ssh.generate",
                title: BiText(en: "Create key", pl: "Utwórz klucz"),
                script: { lang in
                    """
                    set -e
                    KEY="$HOME/.ssh/id_ed25519"
                    mkdir -p "$HOME/.ssh"
                    chmod 700 "$HOME/.ssh"
                    if [ -f "$KEY" ]; then
                      echo \(t(lang, "Klucz już istnieje:", "Key already exists:")) "$KEY"
                    else
                      PASS=""
                      for _ in 1 2 3; do
                        PASS="$("$SUDO_ASKPASS" \(t(lang, "Podaj hasło do nowego klucza SSH (co najmniej 8 znaków). Zostanie zapisane w Pęku kluczy.", "Enter a passphrase for the new SSH key (at least 8 characters). It will be stored in the Keychain.")))" || { echo \(t(lang, "Anulowano.", "Cancelled.")); exit 1; }
                        [ "${#PASS}" -ge 8 ] && break
                        echo \(t(lang, "Hasło jest za krótkie.", "The passphrase is too short."))
                        PASS=""
                      done
                      if [ -z "$PASS" ]; then
                        echo \(t(lang, "Nie utworzono klucza: wymagane hasło o długości co najmniej 8 znaków.", "No key was created: a passphrase of at least 8 characters is required."))
                        exit 1
                      fi
                      # The passphrase goes through a 0600 file read by SSH_ASKPASS, never through argv (visible in ps).
                      (umask 077; printf '%s' "$PASS" > "$MACPEACH_RUN_DIR/keypass")
                      unset PASS
                      cat > "$MACPEACH_RUN_DIR/keypass.sh" <<'KEYPASS'
                    #!/bin/bash
                    cat "$MACPEACH_RUN_DIR/keypass"
                    KEYPASS
                      chmod 700 "$MACPEACH_RUN_DIR/keypass.sh"
                      SSH_ASKPASS="$MACPEACH_RUN_DIR/keypass.sh" SSH_ASKPASS_REQUIRE=force \
                        ssh-keygen -q -t ed25519 -a 64 -C "$(whoami)@$(scutil --get LocalHostName 2>/dev/null || hostname -s)" -f "$KEY" </dev/null
                      SSH_ASKPASS="$MACPEACH_RUN_DIR/keypass.sh" SSH_ASKPASS_REQUIRE=force \
                        ssh-add --apple-use-keychain "$KEY" </dev/null
                      rm -f "$MACPEACH_RUN_DIR/keypass" "$MACPEACH_RUN_DIR/keypass.sh"
                    fi
                    touch "$HOME/.ssh/config"
                    chmod 600 "$HOME/.ssh/config"
                    if ! grep -q "^Host github.com" "$HOME/.ssh/config"; then
                      printf '\\nHost github.com\\n  AddKeysToAgent yes\\n  UseKeychain yes\\n  IdentityFile ~/.ssh/id_ed25519\\n' >> "$HOME/.ssh/config"
                      echo \(t(lang, "Dodano wpis github.com do ~/.ssh/config", "Added a github.com entry to ~/.ssh/config"))
                    fi
                    \(pinGitHubHostKeys(lang))
                    """
                },
                requiresBrew: false,
                check: "[ -f \"$HOME/.ssh/id_ed25519.pub\" ]"
            ),
            ExtraStep(
                id: "ssh.github",
                title: BiText(en: "Add to GitHub", pl: "Dodaj do GitHuba"),
                script: { lang in
                    """
                    set -e
                    pbcopy < "$HOME/.ssh/id_ed25519.pub"
                    open "https://github.com/settings/ssh/new"
                    echo \(t(lang, "Klucz publiczny jest w schowku. Wklej go na otwartej stronie GitHuba i zapisz.",
                                   "The public key is in your clipboard. Paste it on the GitHub page that just opened and save."))
                    """
                },
                requiresBrew: false,
                check: nil
            ),
            ExtraStep(
                id: "ssh.test",
                title: BiText(en: "Test connection", pl: "Sprawdź połączenie"),
                script: { lang in
                    """
                    \(pinGitHubHostKeys(lang))
                    result="$(ssh -T -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10 git@github.com 2>&1 || true)"
                    echo "$result"
                    if echo "$result" | grep -q "successfully authenticated"; then
                      echo \(t(lang, "Połączenie z GitHubem działa.", "GitHub connection works."))
                    else
                      echo \(t(lang, "GitHub nie rozpoznał klucza. Upewnij się, że został dodany (krok 2).", "GitHub did not accept the key. Make sure it was added (step 2)."))
                      exit 1
                    fi
                    """
                },
                requiresBrew: false,
                check: nil
            ),
        ],
        undo: nil
    )

    static let touchID = Extra(
        id: "touchid",
        icon: "touchid",
        title: BiText(en: "Touch ID for sudo", pl: "Touch ID dla sudo"),
        summary: BiText(en: "Confirm sudo in the terminal with your fingerprint, also inside tmux. Survives macOS updates.",
                        pl: "Potwierdzaj sudo w terminalu odciskiem palca, także w tmux. Działa po aktualizacjach macOS."),
        note: BiText(en: "Requires macOS 14 or newer and a Mac with Touch ID. The tmux helper (pam_reattach) is copied to /opt/macpeach/pam, owned by root. After upgrading pam-reattach in Homebrew, or if you enabled this in MacPeach 1.0.0, run the step again.",
                     pl: "Wymaga macOS 14 lub nowszego i Maca z Touch ID. Moduł dla tmux (pam_reattach) jest kopiowany do /opt/macpeach/pam, należącego do roota. Po aktualizacji pam-reattach w Homebrew albo jeśli włączono to w MacPeach 1.0.0, wykonaj krok ponownie."),
        steps: [
            ExtraStep(
                id: "touchid.enable",
                title: BiText(en: "Enable Touch ID", pl: "Włącz Touch ID"),
                script: { lang in
                    """
                    set -e
                    if [ ! -f /etc/pam.d/sudo_local.template ]; then
                      echo \(t(lang, "Ta wersja macOS nie obsługuje sudo_local (wymagany macOS 14+).", "This macOS version does not support sudo_local (macOS 14+ required)."))
                      exit 1
                    fi
                    PAM_DIR="/opt/macpeach/pam"
                    REATTACH=""
                    if command -v brew >/dev/null 2>&1; then
                      brew install pam-reattach || true
                      SRC="$(brew --prefix)/lib/pam/pam_reattach.so"
                      if [ -f "$SRC" ]; then
                        sudo /bin/mkdir -p /opt
                        if [ "$(/usr/bin/stat -f '%u' /opt)" != 0 ] || [ -n "$(/usr/bin/find /opt -maxdepth 0 -perm -g+w -o -maxdepth 0 -perm -o+w)" ]; then
                          echo \(t(lang, "Katalog /opt nie należy do roota. Pomijam pam_reattach (Touch ID zadziała poza tmux).",
                                         "/opt is not owned by root. Skipping pam_reattach (Touch ID will work outside tmux)."))
                        else
                          # The PAM module runs inside sudo as root, so it must not stay in the user-writable Homebrew prefix.
                          sudo /usr/bin/install -d -o root -g wheel -m 755 /opt/macpeach "$PAM_DIR"
                          sudo /usr/sbin/chown root:wheel /opt/macpeach "$PAM_DIR"
                          sudo /bin/chmod 755 /opt/macpeach "$PAM_DIR"
                          sudo /usr/bin/install -o root -g wheel -m 444 "$SRC" "$PAM_DIR/pam_reattach.so"
                          if /usr/bin/file -b "$PAM_DIR/pam_reattach.so" | /usr/bin/grep -q 'Mach-O'; then
                            REATTACH="$PAM_DIR/pam_reattach.so"
                          else
                            sudo /bin/rm -f "$PAM_DIR/pam_reattach.so"
                          fi
                          [ -n "$REATTACH" ] && echo \(t(lang, "Skopiowano pam_reattach.so do katalogu roota:", "Copied pam_reattach.so to a root-owned folder:")) "$REATTACH"
                        fi
                      fi
                    fi
                    CONTENT="# sudo_local: local config file which survives system update and is included for sudo"
                    [ -n "$REATTACH" ] && CONTENT="$CONTENT"$'\\n'"auth       optional       $REATTACH ignore_ssh"
                    CONTENT="$CONTENT"$'\\n'"auth       sufficient     pam_tid.so"
                    echo "$CONTENT"
                    # Written through a pipe, not a temp file another process could swap while the password dialog is open.
                    printf '%s\\n' "$CONTENT" | sudo /usr/bin/tee /etc/pam.d/sudo_local.macpeach >/dev/null
                    sudo /usr/sbin/chown root:wheel /etc/pam.d/sudo_local.macpeach
                    sudo /bin/chmod 444 /etc/pam.d/sudo_local.macpeach
                    sudo /bin/mv -f /etc/pam.d/sudo_local.macpeach /etc/pam.d/sudo_local
                    echo \(t(lang, "Touch ID dla sudo jest włączony. Otwórz nowe okno terminala, aby sprawdzić.", "Touch ID for sudo is on. Open a new terminal window to try it."))
                    """
                },
                requiresBrew: false,
                check: """
                grep -qE '^[[:space:]]*auth[[:space:]]+sufficient[[:space:]]+pam_tid.so' /etc/pam.d/sudo_local 2>/dev/null && \
                ! grep -E '^[[:space:]]*auth[[:space:]].*pam_reattach' /etc/pam.d/sudo_local | grep -qv '[[:space:]]/opt/macpeach/pam/pam_reattach.so[[:space:]]'
                """
            ),
        ],
        undo: ExtraAction(
            title: BiText(en: "Disable", pl: "Wyłącz"),
            script: { _ in
                """
                sudo /bin/rm -f /etc/pam.d/sudo_local
                sudo /bin/rm -rf /opt/macpeach/pam
                sudo /bin/rmdir /opt/macpeach 2>/dev/null || true
                """
            }
        )
    )
}

nonisolated enum Workflow {
    static func installCommands(name: String, shellScript: String) -> String {
        let bundle = "$SERVICES/\(name).workflow/Contents"
        return """
        mkdir -p "\(bundle)"
        cat > "\(bundle)/Info.plist" <<'MACPEACH_PLIST'
        \(infoPlist(name: name))
        MACPEACH_PLIST
        cat > "\(bundle)/document.wflow" <<'MACPEACH_PLIST'
        \(document(shellScript: shellScript))
        MACPEACH_PLIST
        """
    }

    private static func xml(_ object: Any) -> String {
        guard let data = try? PropertyListSerialization.data(fromPropertyList: object, format: .xml, options: 0) else { return "" }
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func infoPlist(name: String) -> String {
        xml([
            "NSServices": [[
                "NSBackgroundColorName": "background",
                "NSIconName": "NSActionTemplate",
                "NSMenuItem": ["default": name],
                "NSMessage": "runWorkflowAsService",
                "NSRequiredContext": ["NSApplicationIdentifier": "com.apple.finder"],
                "NSSendFileTypes": ["public.item"],
            ]],
        ])
    }

    static func document(shellScript: String) -> String {
        let action: [String: Any] = [
            "AMAccepts": ["Container": "List", "Optional": true, "Types": ["com.apple.cocoa.string"]],
            "AMActionVersion": "2.0.3",
            "AMApplication": ["Automator"],
            "AMParameterProperties": [
                "COMMAND_STRING": [String: Any](), "CheckedForUserDefaultShell": [String: Any](),
                "inputMethod": [String: Any](), "shell": [String: Any](), "source": [String: Any](),
            ],
            "AMProvides": ["Container": "List", "Types": ["com.apple.cocoa.string"]],
            "ActionBundlePath": "/System/Library/Automator/Run Shell Script.action",
            "ActionName": "Run Shell Script",
            "ActionParameters": [
                "COMMAND_STRING": shellScript,
                "CheckedForUserDefaultShell": true,
                "inputMethod": 1,
                "shell": "/bin/bash",
                "source": "",
            ],
            "BundleIdentifier": "com.apple.RunShellScript",
            "CFBundleVersion": "2.0.3",
            "CanShowSelectedItemsWhenRun": false,
            "CanShowWhenRun": true,
            "Category": ["AMCategoryUtilities"],
            "Class Name": "RunShellScriptAction",
            "InputUUID": UUID().uuidString,
            "Keywords": ["Shell", "Script", "Command", "Run", "Unix"],
            "OutputUUID": UUID().uuidString,
            "UUID": UUID().uuidString,
            "UnlocalizedApplications": ["Automator"],
            "isViewVisible": 1,
            "location": "309.000000:253.000000",
            "nibPath": "/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib",
        ]
        return xml([
            "AMApplicationBuild": "528",
            "AMApplicationVersion": "2.10",
            "AMDocumentVersion": "2",
            "actions": [["action": action, "isViewVisible": 1]],
            "connectors": [String: Any](),
            "workflowMetaData": [
                "applicationBundleIDsByPath": [String: Any](),
                "applicationPaths": [String](),
                "inputTypeIdentifier": "com.apple.Automator.fileSystemObject",
                "outputTypeIdentifier": "com.apple.Automator.nothing",
                "presentationMode": 15,
                "processesInput": 0,
                "serviceApplicationBundleID": "com.apple.finder",
                "serviceApplicationPath": "/System/Library/CoreServices/Finder.app",
                "serviceInputTypeIdentifier": "com.apple.Automator.fileSystemObject",
                "serviceOutputTypeIdentifier": "com.apple.Automator.nothing",
                "serviceProcessesInput": 0,
                "systemImageName": "NSActionTemplate",
                "useAutomaticInputType": 0,
                "workflowTypeIdentifier": "com.apple.Automator.servicesMenu",
            ],
        ])
    }
}
