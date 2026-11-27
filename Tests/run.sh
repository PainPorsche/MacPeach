#!/bin/bash
# Security regression tests for MacPeach. Needs Xcode (swiftc); uses shellcheck when installed.
# Never runs sudo, never touches the network or system settings.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }

sources=()
for f in "$ROOT"/MacPeach/*.swift; do
  [ "$(basename "$f")" = MacPeachApp.swift ] || sources+=("$f")
done
swiftc -default-isolation MainActor -o "$WORK/tests" "$ROOT/Tests/main.swift" "${sources[@]}" || { echo "FAIL compile"; exit 1; }
DYLD_MACPEACH_TEST=1 BASH_ENV=/nonexistent "$WORK/tests" "$ROOT/MacPeach/MacSetup.sh" "$WORK" || fail=1
S="$WORK/scripts"

for f in "$S"/*.sh; do bash -n "$f" || bad "bash -n $(basename "$f")"; done
ok "generated scripts parse"
if command -v shellcheck >/dev/null; then
  shellcheck -s bash -S warning -e SC2317 "$S"/*.sh "$ROOT/MacPeach/MacSetup.sh" && ok "shellcheck" || bad "shellcheck"
fi

# sudo wrapper: a planted "sudo" earlier in PATH must not run, and the real sudo must get a system-only PATH
mkdir -p "$WORK/planted"
printf '#!/bin/bash\necho planted > "%s/planted.txt"\n' "$WORK" > "$WORK/planted/sudo"
printf '#!/bin/bash\necho "$PATH" > "%s/sudo-path.txt"\n' "$WORK" > "$WORK/fake-real-sudo"
chmod 755 "$WORK/planted/sudo" "$WORK/fake-real-sudo"
sed -n '/^sudo() {/p' "$S/touchid.enable.en.sh" | sed "s#/usr/bin/sudo#$WORK/fake-real-sudo#" > "$WORK/wrapper.sh"
grep -q 'PATH=/usr/bin:/bin:/usr/sbin:/sbin /usr/bin/sudo -A' "$S/touchid.enable.en.sh" || bad "wrapper uses absolute sudo"
PATH="$WORK/planted:/usr/bin:/bin" bash -c ". '$WORK/wrapper.sh'; sudo pmset -g"
[ ! -e "$WORK/planted.txt" ] && [ "$(cat "$WORK/sudo-path.txt")" = /usr/bin:/bin:/usr/sbin:/sbin ] \
  && ok "planted sudo is ignored, sudo gets system PATH" || bad "sudo wrapper"

# Touch ID check: a pam_reattach line outside /opt/macpeach/pam must count as not done
CHK="$(sed 's#/etc/pam.d/sudo_local#"$F"#g' "$S/touchid.enable.check.sh")"
t() { printf "$2" > "$WORK/pam"; if F="$WORK/pam" bash -c "$CHK"; then r=done; else r=todo; fi; [ "$r" = "$3" ] && ok "pam check: $1" || bad "pam check: $1"; }
t "root-owned module"   'auth optional /opt/macpeach/pam/pam_reattach.so ignore_ssh\nauth sufficient pam_tid.so\n' done
t "Homebrew module"     'auth optional /opt/homebrew/lib/pam/pam_reattach.so ignore_ssh\nauth sufficient pam_tid.so\n' todo
t "pam_tid only"        'auth sufficient pam_tid.so\n' done
t "nothing"             '# empty\n' todo
grep -q 'MACPEACH_RUN_DIR/sudo_local' "$S/touchid.enable.en.sh" && bad "sudo_local is not staged in a swappable temp file" || ok "sudo_local is written through a pipe"

# NTFS volume label from the drive is untrusted
NAME_LINES="$(grep -E '^ *name="\$\(echo "\$info"|^ *case "\$name"' "$S/ntfs.mount.en.sh")"
label() { info="   Volume Name: $1"; dev=disk9s1; eval "$NAME_LINES"; printf '%s' "$name"; }
[ "$(label '../../etc')" = disk9s1 ] && ok "label ../../etc" || bad "label ../../etc -> $(label '../../etc')"
[ "$(label 'x/../../private/etc')" = 'x_.._.._private_etc' ] && ok "label with slashes" || bad "label with slashes -> $(label 'x/../../private/etc')"
[ "$(label 'a,uid=0')" = 'a_uid_0' ] && ok "label with mount options" || bad "label with mount options -> $(label 'a,uid=0')"
[ "$(label 'My Drive')" = 'My Drive' ] && ok "normal label kept" || bad "normal label -> $(label 'My Drive')"

# Homebrew installer: pinned team ID, absolute tools, no curl | bash
grep -q '927JGANW46' "$S/homebrew.sh" && ! grep -q 'install.sh)' "$S/homebrew.sh" && grep -q '/usr/bin/grep' "$S/homebrew.sh" \
  && ok "Homebrew installer is pinned" || bad "Homebrew installer"

# SSH: no passphrase in argv, pinned host keys
! grep -q -- '-N "\$PASS"' "$S/ssh.generate.en.sh" && grep -q 'StrictHostKeyChecking=yes' "$S/ssh.test.en.sh" \
  && ok "SSH passphrase not in argv, host keys pinned" || bad "SSH"

[ "$fail" = 0 ] && echo "All tests passed." || { echo "Some tests failed."; exit 1; }
