#!/bin/sh
# Enable the user units listed in assets/systemd/user-units-list.
#
# `copy` puts a unit file in place but cannot enable it — a unit's [Install]
# section only takes effect once systemd links it into default.target.wants, and
# that is a `systemctl` call. Idempotent: enabling an enabled unit is a no-op.
set -eu

# Read the list into a variable rather than piping it into `while`: a pipeline
# runs its loop in a subshell, which is a needless place for a failure or an
# early exit to get lost. Unit names never contain whitespace, so plain
# word-splitting is the whole parser.
units=$(sed 's/#.*//' "$TEMPER_HOME/assets/systemd/user-units-list")

# Pick up unit files that were just copied in; without this, enable fails with
# "unit not found" on the first converge after a unit is added.
systemctl --user daemon-reload

for unit in $units; do
    # A unit whose file is not deployed was skipped by its step's `when` gate —
    # its app is not installed on this machine. Enabling it would fail with
    # "unit not found", so the gate decides here too rather than being
    # duplicated as a second condition in the manifest.
    [ -f "$HOME/.config/systemd/user/$unit" ] || continue
    systemctl --user enable "$unit"
done
