#!/bin/sh
# In sync when every listed unit is enabled.
#
# Read-only, which `temper drift` requires of a check: `is-enabled` queries
# state and links nothing. A unit that is not installed yet reports as out of
# sync rather than as an error, which is what makes the first converge on a new
# machine actually do the work.
set -eu

units=$(sed 's/#.*//' "$TEMPER_HOME/assets/systemd/user-units-list")

for unit in $units; do
    # Not deployed means its `when` gate skipped it, which is in sync rather
    # than pending — the app it unlocks is not on this machine.
    [ -f "$HOME/.config/systemd/user/$unit" ] || continue
    state=$(systemctl --user is-enabled "$unit" 2>/dev/null || true)
    [ "$state" = "enabled" ] || exit 1
done
