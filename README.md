# alloy

A [temper](https://github.com/jakobhviid/temper) home that turns a stock
[Bazzite](https://bazzite.gg) desktop into a set-up machine: the packages, the
third-party repos they come from, and the configuration, all declared in plain
files you can read and change.

It is meant to be **taken and made yours**. Clone it, edit it, keep it wherever
you like — a repo of your own, a synced folder, a USB stick. temper does not care
how the folder got to the machine, and nothing here reports home.

## What this is, and what temper is

Two things, and keeping them apart is the whole idea.

**[temper](https://github.com/jakobhviid/temper) is the tool.** It reads a folder
of files and makes the machine match them — installing what is missing, writing
the config, and telling you what has drifted since. It is public, identical for
everyone, and knows nothing about any particular machine.

**This folder is the data**, and temper calls it a *home*: the description of
what a machine should be. Which packages, from which channel, which files land
where, which settings are fixed policy. One tool, many homes — mine is private
and yours will be too, once you have edited this one enough.

So `temper --llm` is where the tool's contract lives: every verb, the manifest
schema, which primitive to reach for. Read it there rather than here, because it
changes faster than this folder does. What lives *here* is the other half — the
decisions. Every bundle in `apps/` says not just what it installs but **why it
comes from where it does**, because that is the part that is expensive to work
out twice: why Brave is layered from an rpm repo while Boxes is a flatpak, why
zsh comes from Homebrew and is never your login shell, why one file has to be
root-owned. Those answers are the actual content; the TOML around them is
bookkeeping.

**It is a worked example, not a template.** Nothing here is filled in with blanks
for you to complete — it is a spec that converges a real stock Bazzite desktop,
published so that "how do I write one of these" has an answer you can read end to
end and run. Change the hostname, drop the bundles you do not want, add your own,
and it stops being an example and becomes yours.

## The temper this was written for

Written and verified against **temper 7.5.5**. The newest thing it uses is
`rpm_repos`, which arrived in **7.4.0** — below that the folder does not load at
all, because temper treats an unknown manifest field as a parse error rather than
ignoring it. So an old temper fails with a parse error that says nothing about
repos, which is a confusing way to learn you need `brew upgrade temper`.

**temper moves faster than this folder, and that is the expected state.** If you
are on a newer version and something here no longer parses, or a primitive
behaves differently from what a comment describes, then `temper --llm` is the
authority and this folder is out of date — not the other way round. Read it in
full, and the **MANIFEST SCHEMA** section in particular: that is the
field-by-field list the parser actually enforces, and it is where a renamed or
removed field shows up.

That reconciliation is a good job to hand to an LLM, and it is most of why the
reasoning in these bundles is written out at length. Point it at this folder and
at the output of `temper --llm`, and ask it to bring the two into agreement.
Renamed fields, changed defaults and a primitive that has gained an option are
all mechanical once both halves are visible — and the comments tell it *why* each
choice was made, so it can preserve the intent rather than just satisfying the
new schema.

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

Then **reboot** — layered packages land in a new deployment, so the browser and
terminal appear after it, not before.

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

Three bundles are shipped but **not composed by default**, because each makes a
decision that should be yours. `vivaldi` installs the Vivaldi browser from
Vivaldi's own repo. `brave-linux` applies Brave's managed policy — which
force-installs the 1Password extension, disables Brave's own password manager,
and pins DNS and search — and makes Brave the default handler for web content;
read `apps/brave-linux.toml` before taking it. `1password` installs 1Password
and adds the two things its own installer leaves out for Brave Origin, so take
it alongside `brave-linux` if you use 1Password. Leave a name out of `apps` and
nothing it declares ever touches your machine.

## One thing you have to set by hand

zsh is installed from Homebrew and is selected **per terminal**, not as your
login shell — leave that as `/bin/bash`. `chsh` to a path under the brew prefix
is a documented way to end up unable to log in (ublue-os/bazzite#4159), and the
prefix is extracted on first boot, so it can be absent exactly when it is
needed.

Ghostty is handled for you: `apps/ghostty.toml` sets its launch command to the
absolute brew zsh. **Ptyxis, the terminal Bazzite ships, you have to set
yourself** — its profile is keyed by a uuid generated on your machine, so no
shared spec can name it. Preferences → your profile → Custom Command, and give
it the absolute path that `brew --prefix`/bin/zsh prints.

Do not put a bare `zsh` there. It works on any system that has `/usr/bin/zsh`
and fails on one that does not: a terminal execs its custom command directly,
with no shell in between to have put the brew prefix on PATH, so the name
resolves to nothing and the terminal simply will not open — with no message
saying why. That exact mistake broke the terminal on the machine this spec came
from.

## What it sets up

| Bundle | What it does | Default |
|---|---|---|
| `rpm-layered` | The third-party repos and signing keys, and the three packages layered from them: Brave Origin, Ghostty, gnome-tweaks. | yes |
| `shell` | The starship prompt and a tmux config. | yes |
| `zsh` | zsh in two files — one this spec owns, one that stays yours. | yes |
| `ghostty` | Ghostty's config, and Ctrl+Alt+T for a new window. | yes |
| `gnome` | Fractional-scaling and compositing fixes, and terminal blur. No extensions — those are left to you. | yes |
| `vivaldi` | The Vivaldi browser. | opt-in |
| `brave-linux` | Brave's managed policy. Opinionated; read it first. | opt-in |

It is deliberately a short list. This spec covers what is true of *any* Bazzite
desktop and stops there — it is not a copy of anyone's personal setup, and the
bundles carry no dotfiles, keys, hostnames or identities.

Each bundle explains itself: the comments say *why* something comes from where it
does, which is the part that is hard to reconstruct later. The channel policy
they follow is **Homebrew first, layer only when brew cannot work, Flatpak where
the app is sandboxable**. Browsers are the clearest case of "cannot work":
1Password's browser integration needs a native-messaging manifest and an `/etc`
allowlist entry that a sandboxed browser cannot reach — which is why Brave is
layered and not a flatpak. If you do not use 1Password, a flatpak browser is a
perfectly good choice and one less repo in your update path.

That integration also does not work the moment the app is installed, which is
what the `1password` bundle is for. 1Password trusts a fixed list of browser
basenames, and `brave-origin` is not on it, so it needs adding to
`/etc/1password/custom_allowed_browsers` — root-owned and mode 0755, because the
test is "writable only by root" and 0444 fails it on root's own missing write
bit. And Brave Origin reads native-messaging manifests from its own config
directory, which 1Password's installer never writes to, so the manifest has to
be mirrored across from Brave-Browser with its `path` rewritten. One more thing
worth knowing before you debug it the hard way: do **not** add your user to the
`onepassword` group. It looks like the fix and is the opposite — 1Password
authorises a connection by checking the peer's egid is `onepassword`, which only
means something while that egid is unreachable outside setgid exec.

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

## License

MIT — see `LICENSE`. Take it, fork it, strip it back, publish your own version;
the only thing asked is that the copyright notice travels with the parts you
keep. The configuration this deploys is one person's taste and carries no
warranty: read a bundle before you compose it, and `temper drift` and
`temper install --dry-run` both tell you what would happen without doing it.

