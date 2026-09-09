# Make 1Password's browser integration work with Brave Origin.
#
# Two things stand between a force-installed 1Password extension and a working
# one, and neither is done by 1Password's own installer:
#
#   1. 1Password only accepts connections from browsers whose basename is on a
#      hardcoded trusted list, plus whatever is listed in
#      /etc/1password/custom_allowed_browsers. `brave-origin` is not on the
#      hardcoded list, so it needs adding to that file. 1Password's package
#      ships the file with its own contents, so this APPENDS and never rewrites.
#      The file must be root:root mode 0755 — 1Password's test is "writable only
#      by root", and 0444 FAILS it, because root itself has no write bit there.
#
#   2. Brave Origin reads its native-messaging manifests from
#      ~/.config/BraveSoftware/Brave-Origin/, a peer of Brave-Browser/.
#      1Password's installer writes only into Brave-Browser/, so Brave Origin's
#      directory stays empty and the extension's native-messaging launch fails
#      before 1Password's IPC layer ever sees a connection. The manifest is
#      mirrored across and its `path` rewritten to the Brave-Origin copy of the
#      wrapper; the wrapper script itself is portable.
#
# This runs as YOU, not as root — it escalates with `sudo` only for the two /etc
# operations. The step declares no `sudo = true` on purpose: on Fedora, sudo
# caches credentials per parent process, so a password temper collected up front
# cannot be reused by a script temper spawned, and asking early would only add a
# prompt. Instead the paired check script verifies every outcome, so a machine
# that is already set up skips this entirely and never prompts at all.
#
# Re-exec under bash: temper invokes this with `sh`, and the array below needs
# more than POSIX provides.
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi
set -u

info() { printf '\033[0;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[!]\033[0m %s\n' "$*" >&2; }

# Being in the `onepassword` group breaks the integration rather than enabling
# it, and it is the first thing people try when a connection fails. 1Password
# authorises an IPC peer by checking its egid is `onepassword`, which is only
# meaningful while that egid is unreachable except through setgid exec; group
# membership lets any process you run claim it, so 1Password refuses every
# connection with PipeAuthError(NoCreds). Stop rather than build on top of it.
# The bundle's `[[assert]] not_member` reports this as drift on every run.
if id -nG "$USER" | tr ' ' '\n' | grep -qx onepassword; then
    warn "User '$USER' is in the 'onepassword' group, which BREAKS browser"
    warn "integration. Remove it, then log out and back in:"
    warn "    sudo gpasswd -d \"$USER\" onepassword"
    warn "Skipping 1Password/Brave Origin setup."
    exit 0
fi

# 1. The allowlist. Reads are unescalated on purpose — the file is world-readable
#    by 1Password's own 0755 requirement, so `sudo grep` would buy nothing and
#    cost a password prompt on every run.
cab=/etc/1password/custom_allowed_browsers
if [[ -f "$cab" ]]; then
    entries="brave-origin brave-origin-stable"
    # Vivaldi's basename is not on 1Password's trusted list either, and the
    # `vivaldi` bundle is optional — so add it only when Vivaldi is actually
    # here, rather than leaving an allowlist entry for software nobody has.
    # Vivaldi needs nothing else: being Chromium-based it reads the manifest
    # 1Password already installs, unlike Brave Origin with its own config dir.
    if command -v vivaldi-bin >/dev/null 2>&1 || [[ -x /opt/vivaldi/vivaldi-bin ]]; then
        entries="$entries vivaldi-bin"
    fi
    need=()
    for entry in $entries; do
        grep -qxF "$entry" "$cab" 2>/dev/null || need+=("$entry")
    done
    if (( ${#need[@]} > 0 )); then
        info "Adding to $cab: ${need[*]}"
        # 1Password ships the file with no trailing newline, so appending
        # naively would glue the first entry onto its last line.
        if [[ -n "$(tail -c1 "$cab" 2>/dev/null)" ]]; then
            printf '\n' | sudo tee -a "$cab" >/dev/null
        fi
        printf '%s\n' "${need[@]}" | sudo tee -a "$cab" >/dev/null
    fi
    if [[ "$(stat -c '%U:%G %a' "$cab")" != "root:root 755" ]]; then
        sudo chown root:root "$cab"
        sudo chmod 0755 "$cab"
    fi
else
    warn "$cab not found — 1Password does not look installed yet."
    warn "Install it, then run \`temper install\` again."
fi

# 2. The native-messaging manifest.
bo_dir=~/.config/BraveSoftware/Brave-Origin/NativeMessagingHosts
bb=~/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts
if [[ -d ~/.config/BraveSoftware/Brave-Origin && -f "$bb/com.1password.1password.json" && -f "$bb/1PasswordWrapper.sh" ]]; then
    mkdir -p "$bo_dir"
    cp -f "$bb/1PasswordWrapper.sh" "$bo_dir/1PasswordWrapper.sh"
    sed 's|/BraveSoftware/Brave-Browser/|/BraveSoftware/Brave-Origin/|g' \
        "$bb/com.1password.1password.json" > "$bo_dir/com.1password.1password.json"
    info "Installed Brave Origin's 1Password native-messaging manifest"
fi
