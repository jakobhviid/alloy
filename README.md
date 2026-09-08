# alloy

A [temper](https://github.com/jakobhviid/temper) home that turns a stock
[Bazzite](https://bazzite.gg) desktop into a set-up machine: the packages, the
third-party repos they come from, and the configuration, all declared in plain
files you can read and change.

It is meant to be **taken and made yours**. Clone it, edit it, keep it wherever
you like — a repo of your own, a synced folder, a USB stick. temper does not care
how the folder got to the machine, and nothing here reports home.

## What you need

A machine already running **stock Bazzite** — `bazzite-gnome` or
`bazzite-gnome-nvidia-open`. Nothing here builds or requires a custom image.

## Getting started

Homebrew ships with Bazzite, so the shortest path installs temper through it. The
tap is not an official one, hence the trust step:

```sh
brew trust --tap jakobhviid/tap && brew tap jakobhviid/tap
brew install jakobhviid/tap/temper
```

Then point temper at this folder and look before you leap:

```sh
temper setup /path/to/alloy   # records where the spec lives
temper drift                  # what is out of sync — reads only, changes nothing
temper install --dry-run      # what an install would do — writes nothing
temper install                # converge for real
```

`temper --llm` prints the full manual in one go if you want to know what any of
it means.

## Make it yours

Two edits, both in `temper.toml`:

1. **The machine name must match your hostname** (`hostname -s`). Without a
   matching `[[machine]]` block temper does not know which machine it is looking
   at and refuses to run. `temper init` will write the block for you and seed it
   from what you already have installed.
2. **The `apps` list is the selection.** A bundle in `apps/` does nothing until a
   machine names it. Removing a name is how you decline software; adding one is
   how you take it.

`Vivaldi` is the worked example of that second point. It is packaged and kept
current in `apps/vivaldi.toml`, and it is **nobody's default** — it is in this
spec because one machine's owner wants it. Leave `"vivaldi"` out of `apps` and
no Vivaldi repo, signing key or package ever touches your machine.

## What it sets up

| Bundle | What it does |
|---|---|
| `rpm-layered` | The third-party repos and their signing keys, plus the packages layered from them: Brave Origin, Ghostty, and a handful of Fedora-main packages the base leaves out. |
| `vivaldi` | Vivaldi, from Vivaldi's own repo. Opt-in — see above. |

Each bundle explains itself: the comments say *why* a package comes from where it
does, which is the part that is hard to reconstruct later. The channel policy
they follow is **Homebrew first, layer only when brew cannot work, Flatpak where
the app is sandboxable** — and browsers are the clearest case of "cannot work",
because 1Password's browser integration needs a native-messaging manifest and an
`/etc` allowlist entry that a sandboxed browser cannot reach.

## Updates take care of themselves

Worth knowing, because it is the main thing people expect to have to build and
should not:

- **Homebrew** upgrades on its own. Bazzite enables `brew-update.timer` (every
  6h) and `brew-upgrade.timer` (every 8h) out of the box, both `Persistent=true`
  so a machine that was switched off catches up at the next boot.
- **Layered packages** move with the base: `rpm-ostree upgrade` re-resolves every
  one of them against current repo metadata, and Bazzite's `uupd.timer` runs
  daily.
- **Flatpaks** update on that same daily timer.

So temper's job is the *declaration* — that what you asked for is installed and
configured — while the platform keeps it *current*. Do not add a timer or a unit
to upgrade brew; there already is one, and a second would only disagree with it.

## If something goes wrong

Anything that touched the OS is undone by a reboot: `bootc rollback` (or
`rpm-ostree rollback`) returns to the previous deployment, layered packages
included. Layering, rebasing and `override remove` each create a *new*
deployment and leave the old one intact — which is why a failed upgrade leaves
you **stale rather than broken**.

What that does not cover is your home directory. `temper undo` reverts the last
run's file writes and dconf keys; `exec` and `sysfile` steps are not journaled
and are not undone.

## Receiving a newer copy

This spec is handed out by copying, and every recipient is expected to diverge —
that is the point, not a problem. If you were given an updated copy:

- **Your `temper.toml` is yours.** The machine name and `apps` list are the parts
  you changed; keep them and take the rest.
- **`apps/` and `assets/` are the shared parts.** Overwriting them takes the
  upstream version of every recipe, including any comment explaining a decision
  that has since changed.
- **Then run `temper drift` before `temper install`.** It reads only, and it
  tells you exactly what the new copy would change on your machine, which is the
  cheapest possible review of someone else's edits.

If you would rather track it as a repo, turn the git behaviours back on — they
are all off by default here because a synced folder is not a repo:

```sh
temper configure set git.auto_commit true
```
