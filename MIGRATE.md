# Migrating a machine off a custom image onto stock Bazzite

**Delete this file once your machine is migrated.** It is a handoff for one job,
not documentation. The durable reasoning lives in the bundles it points at; this
carries only the order of operations and the traps, which stop being true the
moment the job is done.

## Who needs this

You are running a base that is **not** stock Bazzite — your own build, someone
else's custom image, anything that bakes applications into `/usr` — and you want
to end up on a stock base with this folder declaring the software instead.

If you are already on stock Bazzite you do not need any of this. The README's
**Getting started** is your path.

## If you are handing this to an LLM

Read these, in this order, before changing anything:

1. **`README.md`** in this folder — what this spec is, and the two edits that
   make it yours.
2. **`temper --llm`**, in full. Not the top; the bottom. `MANIFEST SCHEMA` is
   the field list the parser enforces (an unknown field is a parse error, not a
   warning) and `PATTERNS` says which primitive to reach for. **Do not trust
   prose about temper — here or anywhere — over that output.**
3. **The bundles in `apps/`** that this job touches. Every decision has its
   reasoning written beside the thing it decided, and none of it is repeated
   here.

Then work the sequence below in order. The order is the content: three of the
five phases exist only because the phase after them fails otherwise.

## The two constraints that set the order

**rpm-ostree cannot layer a package the base already provides.** So
`apps/rpm-layered.toml` cannot be composed while you are still on an image that
bakes those packages in — the whole list reports as failed. It joins your `apps`
list in the same change that rebases you, not before.

**Your login shell may be a path that only exists on the old base.** If a custom
image installed zsh as a system package and something set your login shell to
it, rebasing deletes the binary and leaves your account pointing at a path that
is gone. Fix this *before* the rebase, not after.

## A — while still on the old image

Get temper current first, because an old one cannot read this folder at all:

```sh
brew update && brew upgrade temper
temper --version
```

An unknown manifest field is a parse error, so an old binary does not converge
partially — it refuses to load the folder, and what you see is a parse failure
that says nothing about the field that caused it. The README states the floor
this folder was written against.

Now converge everything that does **not** conflict with the old base. Make sure
`rpm-layered` is **not** in your machine's `apps` list yet, then:

```sh
temper drift            # reads only
temper install
```

This installs the Homebrew packages, the Flatpaks and the configuration. Expect
duplicate application entries for anything the image baked that is also declared
here as a Flatpak or cask — both close at the rebase, and they are cosmetic.

Do not split this into separate package and config runs. temper converges
packages before configuration on purpose, and here that ordering is what makes
the terminal work: brew's zsh is installed before the terminal config points at
its absolute path.

Then the login-shell gate:

```sh
getent passwd "$USER" | cut -d: -f7     # what is it now?
sudo usermod -s /bin/bash "$USER"       # if it is not already /bin/bash
```

`chsh` may not be installed (`util-linux-user` is often absent on these images).
`usermod -s` only touches the shell field. **Log out and back in**, then confirm
your terminals still give you zsh — they set it as a launch command, which is
independent of your login shell.

## B — rebase

```sh
sudo rpm-ostree rebase ostree-image-signed:registry:ghcr.io/ublue-os/bazzite-gnome:stable
```

Use the **`bazzite-gnome-nvidia-open`** image instead if the machine has an
NVIDIA card. Match the variant you are already on: this is the one step where
the graphics stack changes, and nothing in this spec covers the driver.

**Use `ostree-image-signed:registry:`, not a bare `bootc switch`.** A plain
`bootc switch` produces an `ostree-unverified-registry:` deployment, which
silently gives up signature verification on every future upgrade. Check that
`/etc/containers/policy.json` carries a `sigstoreSigned` rule for
`ghcr.io/ublue-os` — on Bazzite it already does — and then **confirm the staged
line begins with `ostree-image-signed:` before you reboot**:

```sh
rpm-ostree status
```

Fixing that after the boot means rebasing again. `rpm-ostree rebase` preserves
layered packages, so anything you had layered carries across.

Then reboot, and expect the first boot to be sparse: every application the image
baked in is gone, and nothing has replaced it yet. Flatpaks and the
Bazzite-shipped terminal still work, which is why the next phases are runnable.

## C — clear what blocks the casks

**A Homebrew cask refuses to overwrite a file it did not install.** It fails
with "the existing Font is different from the one being installed" or similar,
and whatever needed it never arrives. Everything in this phase is that one
failure mode. Three things commonly cause it:

- **Fonts seeded into `~/.local/share/fonts`** by a unit the image shipped. The
  unit goes away with the image; its files do not. Delete the families you are
  about to declare as casks — check what is there first, and remove only the
  families the image seeded:

  ```sh
  ls ~/.local/share/fonts
  ```

- **`.desktop` launchers** written for image-baked applications, at paths a cask
  now installs its own launcher to. Check `~/.local/share/applications` for
  entries whose `Exec=` names a binary that no longer exists.

- **Duplicate repo files** declaring the same repo id under
  `/etc/yum.repos.d/` — `/etc` is merge-forward on an ostree system, so the old
  base's copies survive the rebase.

The blast radius is contained, which is worth knowing so a short converge does
not send you hunting a bigger fault: `brew bundle` attempts every entry and one
provider failing does not cancel the rest. Flatpak, GNOME extensions,
rpm-ostree and every configuration step still converge. The price of skipping
this phase is those casks and only those — and `temper drift` lists exactly what
is still missing.

## D — declare what the image used to bake

Now edit the spec. In `temper.toml`:

- add **`rpm-layered`** to your machine's `apps` list;
- add any opt-in bundle you need — the browser policy, 1Password, Vivaldi,
  Proton Mail, the document fonts. The manifest lists them all with what each
  one decides on your behalf.

In `brewfiles/desktop`, declare anything else the image provided that you
actually want. **Carve from what the image had rather than porting it whole** —
an image builds one set of choices for everyone it was built for, and a machine
does not need all of them.

## E — converge

```sh
temper install
```

**One pass for the packages.** Every bundle that layers packages declares its
repos as `rpm_repos`, which temper installs — keys first — before any package
converge, so the layered set resolves on this run. A package failing to resolve
for want of a repo is a fault, not something to work around by running install
again.

Then **reboot** — layering lands in a new deployment.

Then **`temper install` a second time.** Configuration steps gated on a binary
that only exists after the reboot were skipped on the first pass — terminal
keybindings, the session unlock units — and this is the run that applies them.
That is not a failure of the one-pass rule above, which is about package
resolution.

Finally, absorb what the live desktop has drifted:

```sh
temper reconcile
```

Not `temper snapshot-dconf`, which captures a whole subtree and would sweep in
keys that `setkey` steps own.

## Do not

- **Run `temper prune` blind.** It offers to uninstall every package and Flatpak
  you have that this spec does not declare. If your image preinstalled a set of
  Flatpaks, those are real installs under `/var/lib/flatpak` — they **survive
  the rebase**, the mechanism that added them does not, and `prune` is the one
  thing in this process that would remove them. Use **`temper reconcile`** to
  absorb them into your spec instead, and read every prompt if you do run prune.
- **Use `retire` to clean up a launcher path a cask will own.** `retire` means
  "must not exist", so once the cask installs its own launcher there, you have
  pointed `prune` at a working file.
- **`brew uninstall --cask --zap` anything.** Zap deletes application data along
  with the app, including profiles and vaults you meant to keep.
- **Assume a claim measured on one machine holds on another.** Say which machine
  you measured on. `temper drift` is per-machine and is the only thing that
  answers it.

## Verify by hand

Nothing automated proves these, and they are the point of the migration:

- **Your browser and your password manager talk to each other.** Native
  messaging plus the `/etc` allowlist is why the browser is layered and not a
  Flatpak, and "layered versus baked should be invisible to it" is an argument,
  not a test.
- **Your terminal opens into zsh**, and its new-window shortcut works.
- **Fonts render in the browser** — it reads `~/.local/share/fonts`, which is
  where the casks put them and where phase C had to be clear.
- **`infocmp xterm-ghostty` resolves**, if you took Ghostty. That is the entire
  reason it is layered rather than a cask.
- **The desktop composites and games launch**, if the base variant changed.

## If it goes wrong

```sh
sudo bootc rollback && systemctl reboot
```

returns you to the previous deployment with its layered packages intact, at any
point. Layering, rebasing and `override remove` each create a *new* deployment
and leave the old one alone, which is why a failed step leaves you **stale
rather than broken**.

What that does not cover is your home directory. `temper undo` reverts the last
run's file writes and dconf keys; `exec` and `sysfile` steps are not journaled
and are not undone.

## When you are done

Delete this file. Keeping a finished migration guide costs more than it saves:
a reader cannot tell a live constraint from a dead one, so they route around a
problem that no longer exists. Git history keeps it, with a date and a diff,
which is where it belongs.
