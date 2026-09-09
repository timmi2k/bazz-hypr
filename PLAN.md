# Plan: bazz-hypr

A phased plan for picking the work back up. Each phase is written so that a
fresh chat with none of the previous conversation can carry on — what is done,
what comes next, and how you can tell it worked.

**Goal in one line:** a Bazzite Nvidia image with Hyprland +
illogical-impulse (Quickshell) as the default session and end4-pC as a second,
pre-installed shell. Adopted on the machine via `rpm-ostree rebase` — **the user
does that last step themselves.**

Background and the reasoning behind every decision: `README.md`.

---

## Phase 1 — Research ✅ done

The results are written up at length in `README.md`. The four questions it was
about:

| Question | Answer |
|---|---|
| Does illogical-impulse bundle Quickshell? | Yes, `quickshell-git` from COPR `ririko66z/dots-hyprland`. Do not add a second Quickshell COPR. |
| Is a Python venv still needed? | Yes, not an AGS leftover. `~/.local/state/quickshell/.venv`, built here at image build time. |
| Does `solopasha/hyprland` provide Hyprland >= 0.55? | No — 0.49.0 and fedora-41 only. Replaced by `sdegler/hyprland` with 0.56.2. The pre-Luaification fallback is therefore unnecessary. |
| Does illogical-impulse handle Nvidia? | No, the installer says so itself. The env variables come from us in `custom/env.lua`. |

The cloned sources sat in the scratchpad (`dots-hyprland` @ `97c5bc65`,
`end4-pC` @ `9bcb64af`, plus both community installers). The two SHAs are pinned
in `files/scripts/install-dots.sh`.

---

## Phase 2 — Repository built ✅ done

```
recipes/recipe.yml                              BlueBuild recipe (dnf, script, files, systemd, signing)
files/scripts/install-dots.sh                   clones dots-hyprland + end4-pC at a pinned commit
files/scripts/build-venv.sh                     builds the Python venv into the image
files/scripts/enable-services.sh                ydotool user unit, systemctl --global enable
files/system/usr/libexec/bazz-hypr-seed         sets up the home directory (idempotent)
files/system/usr/libexec/bazz-hypr-session      session wrapper: seed, then Hyprland
files/system/usr/lib/systemd/user/bazz-hypr-firstrun.service
files/system/usr/lib/udev/rules.d/99-uinput.rules
files/system/usr/lib/modules-load.d/uinput.conf
files/system/usr/lib/modprobe.d/zz-bazz-hypr-nvidia.conf
files/system/usr/share/wayland-sessions/bazz-hypr.desktop
.github/workflows/build.yml                     daily build + push/workflow_dispatch
cosign.pub                                      public signing key
```

All 118 packages were checked for availability against Fedora 44 and the COPR
repodata of the target chroot `fedora-44-x86_64` — they all resolve.

**There was no old `hyprland.conf` and no existing `recipe.yml`** — the repo was
empty and was built from scratch. The obsolete config originally suspected did
not exist at all; the Lua structure was laid out correctly from the start.

---

## Phase 3 — GitHub & GHCR ✅ done

The cosign keypair already exists: `cosign.pub` (committed) and `cosign.key`
(kept locally, excluded via `.gitignore`, and must **never** be committed).

Steps:

1. **Log in** — interactive, has to come from the user:
   ```
   gh auth login
   ```
   (`gh` was installed via Homebrew and lives at
   `/home/linuxbrew/.linuxbrew/bin/gh`.) Scopes: `repo`, `read:org`,
   `workflow`.

2. **Create the repo and push**:
   ```
   gh repo create bazz-hypr --public --source=. --remote=origin --push
   ```

3. **Store the signing key**:
   ```
   gh secret set SIGNING_SECRET < cosign.key
   ```

4. **Make the package public** — only possible *after* the first build has run
   and the package exists:
   `https://github.com/users/timmi2k/packages/container/bazz-hypr/settings`
   → *Change visibility* → *Public*.
   Without this step the rebase fails with an auth error.

Done: the repo `timmi2k/bazz-hypr` is public, `SIGNING_SECRET` is set, and the
container package is anonymously retrievable (verified with HTTP 200 against
`ghcr.io/v2/.../manifests/latest` without logging in).

**A note on the history:** the repo was deleted and recreated once, because the
first commit carried a private email address as the git author. A force push is
not enough for that — GitHub keeps serving the replaced commit under its SHA.
The current history has exactly one commit, with
`74569037+timmi2k@users.noreply.github.com`.

Recommendation: in the GitHub settings under *Emails*, enable
**"Block command line pushes that expose my email"** — then GitHub rejects such
a push up front.

---

## Phase 4 — Build in CI ✅ green

Successful build: run `34246345464`, 7m29s.
Image: `ghcr.io/timmi2k/bazz-hypr:latest`

**Outcome:** the rebase went through, but the first login did not — Hyprland
came up without a configuration. Three faults compounded (a race in the seeding,
a self-generated Hyprland config, and a broken emptiness check in `write_once`).
Written up at length in `README.md`, appendix *"The first real rebase"*. All
three are fixed in commit `d74680d`.

The running system was brought up to date by hand: venv re-copied,
`hyprland.lua` replaced with the upstream version, `custom/*.lua` filled in,
keyboard set to `de`/`nodeadkeys`, shell and autostart services started. No
rollback was needed.

(Digest `sha256:0e9cf9ed1c41d552d33fa63a1d82f0b4814de09ab30b954ce887298d678ba76f`,
tags `latest`, `20260908`, `44`, `20260908-44` — cosign signatures sit
alongside.)

Verified in the build log:

* both dotfile repos cloned at the pinned commits, structure checks passed
* `quickshell-git 0.3.1^856` installed, `cpptrace 1.0.4-1.patched` and
  `libdwarf 2.3.1-1.fc44` resolved cleanly
* venv built with Python **3.12.14**, import check passed
  (`materialyoucolor`, `PIL`, `gi`, `cairo`, `numpy`, `cv2`, `sass`,
  `kde-material-you-colors`)
* `ydotool.service` linked as a user unit

### The two failures before it — both instructive

**Build 1 (34244504837), Qt conflict:**

```
quickshell-git … requires libQt6Qml.so.6(Qt_6.10_PRIVATE_API)
Package "qt6-qtdeclarative-6.11.2-1.fc44" is already installed
```

Quickshell binds Qt private APIs version-exactly. The build in
`ririko66z/dots-hyprland` — the COPR that `feddeps.toml` prescribes — is from
2025-12-18 and linked against Qt 6.10; Bazzite has Qt 6.11 and blocks the
downgrade. Solved by switching to `errornointernet/quickshell`.

**Build 2 (34245617493), self-inflicted:**

```
nothing provides libdwarf.so.2 needed by cpptrace-1.0.4-1.patched.fc44
```

The cause was the `repo:` pinning with which I had bound quickshell to the COPR.
A `repo:` entry restricts dnf resolution to exactly that repo — Fedora's
`libdwarf-2.3.1` (which does provide `libdwarf.so.2`) was invisible because of
it. Without pinning, dnf picks the highest version anyway.

**Rule of thumb:** `dnf repoquery` only tells you *whether* a package exists —
not whether it resolves against the base's existing set. Neither error was
findable locally; that needs the real build.

### Quickshell version situation

The RPM version strings are deceptive. Real releases: v0.2.1 (2025-10-12),
v0.3.0 (2026-05-04), v0.3.1 (2026-08-21). Actual git state:
end-4 `0.2.1^770` = ~2026-08-18, `errornointernet` `0.3.1^856` = 2026-09-04,
Fedora `0.2.1^git20260209` = 2026-02-09.

So the image sits about two weeks away from what end-4 builds themselves —
Fedora's package would be seven months away, and before v0.3.0. Switching there
is **not** the more conservative step, it is the bigger jump.

### If a later build breaks

| Symptom | Likely cause |
|---|---|
| `Qt_6.xx_PRIVATE_API` unsatisfiable | Bazzite bumped Qt, the COPR has not rebuilt yet. Alternatives in the README's Quickshell section. |
| `nothing provides <lib>` | A `repo:` pin is hiding the Fedora repo, or a COPR was not rebuilt. |
| `No match for argument: <package>` | Package renamed, or the COPR chroot for a new Fedora release is missing. `skip-unavailable: true` catches it — check the log for what was skipped. |
| `install-dots.sh` aborts with "structure changed" | Upstream moved files. Check the SHA, adjust the paths. |
| `build-venv.sh` fails while compiling | A `-devel` package is missing; the missing header is in the log. |

## Phase 5 — VM boot test ⚠️ skipped (replaced by the real rebase)

Neither `qemu-system-x86_64` nor `libvirt`/`virsh` is installed on the machine,
and explicitly nothing was to be installed.

If it is ever wanted after all, the route would be: convert the image to qcow2
with `bootc-image-builder` and boot it with virtio-gpu. That gives a session
bring-up test (does Hyprland start, does Quickshell come up) but says
**nothing** about the Nvidia specifics — those can only be checked on the real
machine.

---

## Phase 6 — Rebase ✅ carried out (2026-09-08)

Image: `ghcr.io/timmi2k/bazz-hypr:latest`

### Beforehand: note the current state

```
rpm-ostree status
```

At planning time that was:
`ostree-image-signed:docker://ghcr.io/ublue-os/bazzite-nvidia-open:stable`,
with the layered packages `kvantum` and `netbird-ui`.

### Rebase — two steps

The first rebase has to run **unverified**: the cosign policy that makes the
signature checkable is inside the image itself and is not yet present on the
running Bazzite. After the first boot it is there, and the second command
switches to the signature-checked reference — from then on every future
`rpm-ostree upgrade` is signature-checked too.

```
rpm-ostree rebase ostree-unverified-registry:ghcr.io/timmi2k/bazz-hypr:latest
systemctl reboot
```

After the reboot and a successful login:

```
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/timmi2k/bazz-hypr:latest
systemctl reboot
```

**From the second time on, the two-step dance is unnecessary.** The policy is
then in the running image, and every further update can be applied
signature-checked directly — the rebase to the signed reference fetches the new
image at the same time, so a separate `rpm-ostree upgrade` beforehand is
redundant.

This can be checked at any time without a rebase:

```
cosign verify --key cosign.pub ghcr.io/timmi2k/bazz-hypr:latest
jq '.transports.docker | to_entries[] | select(.key|test("bazz-hypr"))' /etc/containers/policy.json
```

The digest in the cosign output has to match the one the registry reports for
`:latest`.

**Your layered packages** (`kvantum`, `netbird-ui`) are carried across the
rebase. Neither is contained in the image, so there should be no conflict.

At the very first login, pick **"Hyprland (illogical-impulse)"** at the bottom
left in SDDM. Do *not* take a UWSM entry if one shows up.

### Rollback if the session does not come up

The previous Bazzite state remains as a second entry in the boot menu.

**Route 1 — in the boot menu:** pick the previous entry at boot. Then, in the
running system, make it permanent:

```
rpm-ostree rollback
systemctl reboot
```

**Route 2 — if you still have a TTY** (`Ctrl+Alt+F3`):

```
rpm-ostree rollback
systemctl reboot
```

**Route 3 — all the way back to stock Bazzite:**

```
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ublue-os/bazzite-nvidia-open:stable
systemctl reboot
```

### If only the shell is stuck but the session runs

```
journalctl --user -u bazz-hypr-firstrun -b     # did the seeding complete?
/usr/libexec/bazz-hypr-seed                    # run it by hand
qs -c ii                                       # start the original instead of end4-pC
```

---

## Cleanup (open, not carried out)

An aborted `podman pull` of the Bazzite base image left roughly **7 GB** of
orphaned layers in `~/.local/share/containers`. `podman system prune -a` does
not get rid of them, because no image entry references them any more.

Cleanup (this also deletes the three existing — empty — volumes, whose names are
recreated afterwards):

```
VOLS=$(podman volume ls -q)
podman system reset -f
for v in $VOLS; do podman volume create "$v"; done
```

The command was deliberately not run automatically.

---

## Phase 7 — Follow-up work ✅ done (2026-09-09)

1. **Fetch the new image.** Commit `d74680d` fixes the three login faults. Done;
   the system runs on version 44.20260908.

2. **Switch to the signature-checked reference.** Done — the system runs on
   `ostree-image-signed:docker://ghcr.io/timmi2k/bazz-hypr:latest`.

3. **Decide on the keyring.** Resolved by adding `gnome-keyring-pam` to the
   package list, **without** touching PAM files. The old kwallet passwords stay
   where they are and remain invisible under Hyprland; export them with
   `kwalletmanager5` if anything there is still needed.

4. **Wi-Fi panel fix.** Not needed. `apps.network` is
   `kcmshell6 kcm_networkmanagement` here — end4-pC brings its own default,
   which opens KDE's network settings and works. The fix described in the
   dist-fedora README addresses a different default.

5. **Electron / portals.** Verified: all four portals run,
   `graphical-session.target` is active, Discord starts and registers its tray
   icon (`discord_status_icon_1`), and screen sharing works.

Still open, deliberately:

* The `mirrored` TypeError from end4-pC on Qt 6.11 — not fixable from here, see
  the README. Switching `custom/variables.lua` to `"ii"` avoids it.
* The ~7 GB of orphaned podman layers above.
