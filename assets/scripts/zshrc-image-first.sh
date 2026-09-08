#!/bin/sh
# ~/.zshrc loads ~/.zshrc.image before anything else in the file.
#
# The image is the base layer: it is where `brew shellenv` puts the Homebrew
# prefix on PATH, so every brew-installed tool is unfindable until it has run. A
# tool that wires itself into the rc appends, which is correct and is what makes
# it survivable; what decides whether its line works is whether the image is
# already above it. temper's `block` primitive takes no position and places a
# missing region at the end, so on a machine where a tool got to the rc first the
# image lands last and every PATH-dependent guard above it silently does nothing.
# `command -v grove` is the one that shows it: the guard fails, the `&&`
# short-circuits, and the aliases are absent until the rc is sourced a second
# time — by which point PATH carries the prefix from the first pass, which is why
# it presents as "sourcing ~/.zshrc again fixes it".
#
# Hoisting the region is therefore the fix, and only temper's own marker block
# moves — every other line keeps its position and its owner. grove's block in
# particular is grove's to write: `grove setup` is the authoritative way that
# line and ~/.config/grove/aliases are maintained, it may run at any time, and a
# region that is already first stays first however often grove appends below it.
#
# Idempotent: a no-op once the image loads first.
set -eu

zshrc="$HOME/.zshrc"
[ -f "$zshrc" ] || exit 0

open='# >>> temper:zshrc-image >>>'
close='# <<< temper:zshrc-image <<<'

# Exactly one well-formed region, or there is nothing to reposition: creating and
# repairing the region is the `block` step's job, and guessing at a malformed one
# would fight it.
[ "$(grep -cxF "$open" "$zshrc" || true)" = 1 ] || exit 0
[ "$(grep -cxF "$close" "$zshrc" || true)" = 1 ] || exit 0

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

awk -v bopen="$open" -v bclose="$close" '
    { line[NR] = $0 }
    END {
        for (i = 1; i <= NR; i++) {
            if (line[i] == bopen)  bs = i
            if (line[i] == bclose) be = i
        }
        if (!bs || !be || bs > be) {
            for (i = 1; i <= NR; i++) print line[i]
            exit
        }

        # The leading comment run is the file header and keeps its place — but
        # only where a blank line (or the region itself) closes it. A comment run
        # sitting directly on code introduces that code, and inserting between
        # the two would split another tool block in half.
        for (i = 1; i < bs; i++) {
            if (line[i] ~ /^[ \t]*#/) p = i; else break
        }
        if (p && (p + 1 > NR || p + 1 == bs || line[p + 1] ~ /^[ \t]*$/)) h = p

        for (i = h + 1; i <= NR; i++) {
            if (i >= bs && i <= be) { seam = 1; continue }
            # Lifting the region out leaves the blank line above it touching the
            # one below. Close that seam, and only that one, so blank lines the
            # file has for its own reasons survive.
            if (seam) {
                seam = 0
                if (m && rest[m] ~ /^[ \t]*$/ && line[i] ~ /^[ \t]*$/) continue
            }
            rest[++m] = line[i]
        }
        s = 1; while (s <= m && rest[s] ~ /^[ \t]*$/) s++
        e = m; while (e >= s && rest[e] ~ /^[ \t]*$/) e--

        for (i = 1; i <= h; i++) print line[i]
        if (h) print ""
        for (i = bs; i <= be; i++) print line[i]
        if (e >= s) {
            print ""
            for (i = s; i <= e; i++) print rest[i]
        }
    }
' "$zshrc" > "$tmp"

# Rewrite in place so the file keeps its mode; skip the write when nothing moved.
cmp -s "$tmp" "$zshrc" || cat "$tmp" > "$zshrc"
