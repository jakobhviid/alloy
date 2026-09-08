#!/bin/sh
# Put Vivaldi's RPM repo in place so vivaldi-stable has somewhere to come from
# on a machine that has never had it.
#
# Create-once, then hand off. vivaldi-stable's %post runs `cat > /etc/yum.repos.d/
# vivaldi.repo` unconditionally on every install and upgrade, so the package —
# not this spec — owns the file's steady state. A declarative `sysfile` here
# would revert Vivaldi's write on every converge and be reverted right back on
# every Vivaldi update, which is a fight with no winner and no reader.
#
# The asset is Vivaldi's own content verbatim, including the archive baseurl,
# the literal x86_64 (its %post hardcodes DEFAULT_ARCH) and the remote gpgkey it
# imports itself. Writing what the package would write means the handoff is
# invisible: nothing changes on the first Vivaldi upgrade.
set -eu

REPO=/etc/yum.repos.d/vivaldi.repo

[ -f "$REPO" ] && exit 0

sudo install -m 0644 -o root -g root "$TEMPER_HOME/assets/rpm-repos/vivaldi.repo" "$REPO"
