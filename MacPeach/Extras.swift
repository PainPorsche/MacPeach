import Foundation

nonisolated enum ExtrasCatalog {
    static let all: [Extra] = [ntfs, ext4, quickActions, githubSSH, touchID]

    private static func t(_ lang: Lang, _ pl: String, _ en: String) -> String {
        Shell.quote(lang == .pl ? pl : en)
    }

    private static let fuseInstalled = "[ -d /Library/Filesystems/macfuse.fs ]"

    private static func formulaInstalled(_ name: String) -> String {
        "[ -d /opt/homebrew/opt/\(name) ] || [ -d /usr/local/opt/\(name) ]"
    }

    static let ntfs = Extra(
        id: "ntfs",
        icon: "externaldrive.badge.plus",
        title: BiText(en: "NTFS write support", pl: "Zapis na dyskach NTFS"),
        summary: BiText(en: "macOS can only read Windows drives. macFUSE + ntfs-3g add full write access.",
                        pl: "macOS tylko odczytuje dyski z Windowsa. macFUSE + ntfs-3g dodają pełny zapis."),
        note: BiText(en: "On Apple silicon macFUSE needs system extensions allowed in Privacy & Security (and Reduced Security in Recovery). A restart may be required.",
                     pl: "Na Apple silicon macFUSE wymaga zezwolenia na rozszerzenia w Prywatność i ochrona (oraz obniżonych zabezpieczeń w trybie odzyskiwania). Może być potrzebny restart."),
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
                    NTFS3G="$(command -v ntfs-3g || true)"
                    [ -z "$NTFS3G" ] && [ -x "$(brew --prefix)/sbin/ntfs-3g" ] && NTFS3G="$(brew --prefix)/sbin/ntfs-3g"
                    if [ -z "$NTFS3G" ]; then
                      echo \(t(lang, "Brak ntfs-3g. Najpierw wykonaj krok 1.", "ntfs-3g not found. Run step 1 first."))
                      exit 1
                    fi
                    found=0
                    for dev in $(diskutil list | grep -oE 'disk[0-9]+s[0-9]+' | sort -u); do
                      info="$(diskutil info "$dev" 2>/dev/null)"
                      echo "$info" | grep -qiE '(Type \\(Bundle\\)|File System Personality): +ntfs' || continue
                      found=1
                      name="$(echo "$info" | sed -n 's/^ *Volume Name: *//p')"
                      [ -z "$name" ] && name="$dev"
                      mountpoint="/Volumes/$name"
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
            script: { _ in "brew uninstall gromgit/fuse/ntfs-3g-mac" }
        )
    )

    static let ext4 = Extra(
        id: "ext4",
        icon: "server.rack",
        title: BiText(en: "Linux (ext4) drives", pl: "Dyski z Linuksa (ext4)"),
        summary: BiText(en: "Read ext4 partitions from Linux disks and Raspberry Pi SD cards (read-only).",
                        pl: "Odczyt partycji ext4 z dysków Linuksa i kart SD z Raspberry Pi (tylko odczyt)."),
        note: BiText(en: "Uses macFUSE, like NTFS support.", pl: "Korzysta z macFUSE, tak jak obsługa NTFS."),
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
                    EXT4="$(command -v ext4fuse || true)"
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
            script: { _ in "brew uninstall gromgit/fuse/ext4fuse-mac" }
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

    static let githubSSH = Extra(
        id: "ssh",
        icon: "key.horizontal.fill",
        title: BiText(en: "SSH key for GitHub", pl: "Klucz SSH do GitHuba"),
        summary: BiText(en: "Generates an Ed25519 key, stores its passphrase in the Keychain and connects it to GitHub.",
                        pl: "Tworzy klucz Ed25519, zapisuje hasło w Pęku kluczy i podłącza go do GitHuba."),
        note: BiText(en: "An existing ~/.ssh/id_ed25519 key is never overwritten.",
                     pl: "Istniejący klucz ~/.ssh/id_ed25519 nigdy nie jest nadpisywany."),
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
                      PASS="$("$SUDO_ASKPASS" \(t(lang, "Podaj hasło do nowego klucza SSH (możesz zostawić puste).", "Enter a passphrase for the new SSH key (you can leave it empty).")))" || { echo \(t(lang, "Anulowano.", "Cancelled.")); exit 1; }
                      ssh-keygen -t ed25519 -a 64 -C "$(whoami)@$(scutil --get LocalHostName 2>/dev/null || hostname -s)" -f "$KEY" -N "$PASS"
                      if [ -n "$PASS" ]; then
                        cat > "$MACPEACH_RUN_DIR/keypass.sh" <<'KEYPASS'
                    #!/bin/bash
                    printf '%s\\n' "$MACPEACH_KEY_PASS"
                    KEYPASS
                        chmod 700 "$MACPEACH_RUN_DIR/keypass.sh"
                        MACPEACH_KEY_PASS="$PASS" SSH_ASKPASS="$MACPEACH_RUN_DIR/keypass.sh" SSH_ASKPASS_REQUIRE=force ssh-add --apple-use-keychain "$KEY"
                      fi
                    fi
                    touch "$HOME/.ssh/config"
                    chmod 600 "$HOME/.ssh/config"
                    if ! grep -q "^Host github.com" "$HOME/.ssh/config"; then
                      printf '\\nHost github.com\\n  AddKeysToAgent yes\\n  UseKeychain yes\\n  IdentityFile ~/.ssh/id_ed25519\\n' >> "$HOME/.ssh/config"
                      echo \(t(lang, "Dodano wpis github.com do ~/.ssh/config", "Added a github.com entry to ~/.ssh/config"))
                    fi
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
                    result="$(ssh -T -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 git@github.com 2>&1 || true)"
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
        note: BiText(en: "Requires macOS 14 or newer and a Mac with Touch ID.", pl: "Wymaga macOS 14 lub nowszego i Maca z Touch ID."),
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
                    REATTACH=""
                    if command -v brew >/dev/null 2>&1; then
                      brew install pam-reattach || true
                      [ -f "$(brew --prefix)/lib/pam/pam_reattach.so" ] && REATTACH="$(brew --prefix)/lib/pam/pam_reattach.so"
                    fi
                    {
                      echo "# sudo_local: local config file which survives system update and is included for sudo"
                      [ -n "$REATTACH" ] && echo "auth       optional       $REATTACH ignore_ssh"
                      echo "auth       sufficient     pam_tid.so"
                    } > "$MACPEACH_RUN_DIR/sudo_local"
                    cat "$MACPEACH_RUN_DIR/sudo_local"
                    sudo install -m 444 -o root -g wheel "$MACPEACH_RUN_DIR/sudo_local" /etc/pam.d/sudo_local
                    echo \(t(lang, "Touch ID dla sudo jest włączony. Otwórz nowe okno terminala, aby sprawdzić.", "Touch ID for sudo is on. Open a new terminal window to try it."))
                    """
                },
                requiresBrew: false,
                check: "grep -qE '^[[:space:]]*auth[[:space:]]+sufficient[[:space:]]+pam_tid.so' /etc/pam.d/sudo_local 2>/dev/null"
            ),
        ],
        undo: ExtraAction(
            title: BiText(en: "Disable", pl: "Wyłącz"),
            script: { _ in "sudo rm -f /etc/pam.d/sudo_local" }
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
