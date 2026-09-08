#!/bin/sh
# Drift hook for the ~/.zshrc load order (see apps/zsh.toml).
# exit 0 = the image block loads first (skip) · exit 1 = something runs ahead of it.
#
# Read-only, and it reports exactly what the script acts on, so a machine whose
# rc is already ordered never runs it and never reports "changed".
set -u

zshrc="$HOME/.zshrc"
[ -f "$zshrc" ] || exit 0

open='# >>> temper:zshrc-image >>>'
close='# <<< temper:zshrc-image <<<'

# Exactly one well-formed region, or there is nothing to reposition: creating and
# repairing the region is the `block` step's job, and guessing at a malformed one
# would fight it.
[ "$(grep -cxF "$open" "$zshrc" || true)" = 1 ] || exit 0
[ "$(grep -cxF "$close" "$zshrc" || true)" = 1 ] || exit 0

# Comments and blank lines execute nothing, so only real code ahead of the region
# counts. Naming the offending line makes the report actionable on its own.
awk -v bopen="$open" '
    $0 == bopen { exit }
    /^[ \t]*#/  { next }
    /^[ \t]*$/  { next }
    {
        print "~/.zshrc runs line " NR " before ~/.zshrc.image is loaded: " $0
        found = 1
        exit
    }
    END { exit(found ? 1 : 0) }
' "$zshrc"
