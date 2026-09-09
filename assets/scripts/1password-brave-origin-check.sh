# Is 1Password's Brave Origin integration already in place?
#
# Exit 0 means "nothing to do" and temper skips the setup script — which is what
# keeps a converged machine from ever asking for a password. So this has to
# verify every outcome that script produces, not merely that it once ran: it is
# also the bundle's whole drift story, and anything not checked here is silently
# re-enforced on every install while `temper drift` reports nothing.
#
# POSIX sh: temper runs checks with `sh`, and nothing here needs more.
set -u

# The allowlist: our entries, plus the mode and owner 1Password demands. Readable
# unprivileged precisely because 1Password requires 0755.
cab=/etc/1password/custom_allowed_browsers
if [ -f "$cab" ]; then
    entries="brave-origin brave-origin-stable"
    # Mirrors the setup script: Vivaldi is only expected in the file when
    # Vivaldi is installed. A check that asked for more than setup writes would
    # report drift nobody could clear.
    if command -v vivaldi-bin >/dev/null 2>&1 || [ -x /opt/vivaldi/vivaldi-bin ]; then
        entries="$entries vivaldi-bin"
    fi
    for entry in $entries; do
        grep -qxF "$entry" "$cab" 2>/dev/null || {
            echo "$cab missing entry: $entry"
            exit 1
        }
    done
    owner_mode=$(stat -c '%U:%G %a' "$cab" 2>/dev/null) || {
        echo "cannot stat $cab"
        exit 1
    }
    # 1Password's test is "writable only by root": 0755 and 0644 pass, 0444 does
    # not, because root has no write bit.
    [ "$owner_mode" = "root:root 755" ] || {
        echo "$cab is '$owner_mode', want 'root:root 755'"
        exit 1
    }
fi

# Brave Origin's mirrored manifest and wrapper. The manifest's content is checked,
# not just its existence — a copy still naming Brave-Browser would launch the
# wrong wrapper path and fail exactly as if it were missing.
bo="$HOME/.config/BraveSoftware/Brave-Origin/NativeMessagingHosts"
bb="$HOME/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts"
if [ -d "$HOME/.config/BraveSoftware/Brave-Origin" ] && [ -f "$bb/com.1password.1password.json" ]; then
    [ -f "$bo/1PasswordWrapper.sh" ] || {
        echo "Brave Origin 1Password wrapper missing"
        exit 1
    }
    grep -q 'Brave-Origin' "$bo/com.1password.1password.json" 2>/dev/null || {
        echo "Brave Origin manifest missing, or still points at Brave-Browser"
        exit 1
    }
fi

exit 0
