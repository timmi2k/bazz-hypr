# Plan: bazz-hypr

Phasenplan zum Wiedereinsteigen. Jede Phase ist so beschrieben, dass ein frischer
Chat ohne die bisherige Unterhaltung weiterarbeiten kann — Stand, was fertig ist,
was als naechstes kommt und woran man erkennt, dass es geklappt hat.

**Kurzfassung des Ziels:** Bazzite-Nvidia-Image mit Hyprland +
illogical-impulse (Quickshell) als Standard-Session und end4-pC als zweiter,
vorinstallierter Shell. Uebernahme auf die Maschine per `rpm-ostree rebase` —
**den letzten Schritt macht der Benutzer selbst.**

Hintergrund und Begruendungen zu allen Entscheidungen: `README.md`.

---

## Phase 1 — Recherche ✅ abgeschlossen

Ergebnisse stehen ausfuehrlich im `README.md`. Die vier Fragen, um die es ging:

| Frage | Antwort |
|---|---|
| Bringt illogical-impulse Quickshell mit? | Ja, `quickshell-git` aus COPR `ririko66z/dots-hyprland`. Keine zweite Quickshell-COPR einbinden. |
| Braucht es noch ein Python-venv? | Ja, kein AGS-Rest. `~/.local/state/quickshell/.venv`, wird hier zur Build-Zeit erzeugt. |
| Liefert `solopasha/hyprland` Hyprland >= 0.55? | Nein — 0.49.0 und nur fedora-41. Ersetzt durch `sdegler/hyprland` mit 0.56.2. Pre-Luaification-Fallback dadurch nicht noetig. |
| Bringt illogical-impulse Nvidia-Handling mit? | Nein, sagt der Installer selbst. Env-Variablen kommen von uns in `custom/env.lua`. |

Geklonte Quellen lagen im Scratchpad (`dots-hyprland` @ `97c5bc65`, `end4-pC`
@ `9bcb64af`, beide Community-Installer). Die beiden SHAs sind in
`files/scripts/install-dots.sh` festgenagelt.

---

## Phase 2 — Repo aufgebaut ✅ abgeschlossen

```
recipes/recipe.yml                              BlueBuild-Rezept (dnf, script, files, systemd, signing)
files/scripts/install-dots.sh                   klont dots-hyprland + end4-pC auf festen Commit
files/scripts/build-venv.sh                     baut das Python-venv ins Image
files/scripts/enable-services.sh                ydotool-User-Unit, systemctl --global enable
files/system/usr/libexec/bazz-hypr-seed         richtet das HOME ein (idempotent)
files/system/usr/libexec/bazz-hypr-session      Session-Wrapper: seed, dann Hyprland
files/system/usr/lib/systemd/user/bazz-hypr-firstrun.service
files/system/usr/lib/udev/rules.d/99-uinput.rules
files/system/usr/lib/modules-load.d/uinput.conf
files/system/usr/lib/modprobe.d/zz-bazz-hypr-nvidia.conf
files/system/usr/share/wayland-sessions/bazz-hypr.desktop
.github/workflows/build.yml                     taeglicher Build + push/workflow_dispatch
cosign.pub                                      oeffentlicher Signaturschluessel
```

Alle 118 Pakete wurden gegen Fedora 44 und die COPR-Repodata der Ziel-Chroot
`fedora-44-x86_64` auf Verfuegbarkeit geprueft — alle loesen auf.

**Es gab keine alte `hyprland.conf` und kein bestehendes `recipe.yml`** — das
Repo war leer, es wurde von Grund auf neu gebaut. Die urspruenglich vermutete
obsolete Config existierte gar nicht; die Lua-Struktur ist von Anfang an
richtig angelegt.

---

## Phase 3 — GitHub & GHCR ⏳ braucht dich

Cosign-Keypair ist bereits erzeugt: `cosign.pub` (eingecheckt) und `cosign.key`
(liegt lokal, ist per `.gitignore` ausgeschlossen und darf **nie** committet
werden).

Schritte:

1. **Anmelden** — interaktiv, muss vom Benutzer kommen:
   ```
   gh auth login
   ```
   (`gh` wurde per Homebrew installiert, liegt unter
   `/home/linuxbrew/.linuxbrew/bin/gh`.) Scopes: `repo`, `read:org`,
   `workflow`.

2. **Repo anlegen und pushen**:
   ```
   gh repo create bazz-hypr --public --source=. --remote=origin --push
   ```

3. **Signaturschluessel hinterlegen**:
   ```
   gh secret set SIGNING_SECRET < cosign.key
   ```

4. **Package public stellen** — erst moeglich, *nachdem* der erste Build
   gelaufen ist und das Package existiert:
   `https://github.com/users/timmi2k/packages/container/bazz-hypr/settings`
   → *Change visibility* → *Public*.
   Ohne diesen Schritt scheitert der Rebase mit einem Auth-Fehler.

**Fertig, wenn:** `gh repo view` das Repo zeigt und
`gh secret list` `SIGNING_SECRET` enthaelt.

---

## Phase 4 — Build in CI ⏳ laeuft, ein Fehler bereits behoben

**Build 1 (34244504837) ist fehlgeschlagen** — und der Fehler war wertvoll:

```
quickshell-git … requires libQt6Qml.so.6(Qt_6.10_PRIVATE_API)
Package "qt6-qtdeclarative-6.11.2-1.fc44" is already installed
```

Quickshell aus `ririko66z/dots-hyprland` ist gegen Qt 6.10 gelinkt, Bazzite hat
Qt 6.11 und sperrt das Downgrade. Behoben durch Umstellung auf
`errornointernet/quickshell` und Repo-Pinning der beiden Qt-empfindlichen
Pakete. Details und die verbleibende Unsicherheit: `README.md`, Abschnitt
*"Quickshell: warum nicht die COPR von illogical-impulse"*.

Diese Klasse von Fehler war lokal nicht auffindbar: `dnf repoquery` zeigt nur,
**ob** ein Paket existiert, nicht ob es sich gegen den Bestand der Base
aufloesen laesst. Dafuer braucht es den echten Build.

```
gh workflow run bluebuild
gh run watch
```

Bei Fehlern iterieren. Was erfahrungsgemaess zuerst bricht:

| Symptom | wahrscheinliche Ursache |
|---|---|
| `No match for argument: <paket>` | Paketname in Fedora 45 umbenannt, oder COPR-Chroot fuer neues Release fehlt. `skip-unavailable: true` faengt das ab — im Log nachsehen, was uebersprungen wurde. |
| Build bricht in `install-dots.sh` mit "Struktur hat sich geaendert" | Upstream hat Dateien verschoben. SHA pruefen, Pfade im Skript anpassen. |
| `build-venv.sh` scheitert beim Kompilieren | ein `-devel`-Paket fehlt. Fehlender Header steht im Log. |
| Runner hat keinen Plattenplatz | `maximize_build_space: true` ist gesetzt; ggf. `tesseract-langpack-*` und weitere Fonts kuerzen. |
| Push nach ghcr.io mit 403 | `packages: write`-Permission oder `SIGNING_SECRET` fehlt. |

**Fertig, wenn:** der Run gruen ist und
```
skopeo inspect docker://ghcr.io/timmi2k/bazz-hypr:latest
```
ein Manifest zurueckgibt.

---

## Phase 5 — VM-Boot-Test ⚠️ uebersprungen

Auf der Maschine sind weder `qemu-system-x86_64` noch `libvirt`/`virsh`
installiert, und es sollte ausdruecklich nichts nachinstalliert werden.

Falls das doch noch gewuenscht ist, waere der Weg: Image mit `bootc-image-builder`
in ein qcow2 wandeln und mit virtio-gpu starten. Das bringt einen
Session-Bring-up-Test (startet Hyprland, kommt Quickshell hoch), sagt aber
**nichts** ueber die Nvidia-Spezifika aus — die lassen sich nur auf der echten
Maschine pruefen.

---

## Phase 6 — Rebase 🔒 macht der Benutzer selbst

Image: `ghcr.io/timmi2k/bazz-hypr:latest`

### Vorher: aktuellen Stand notieren

```
rpm-ostree status
```

Zur Zeit der Planung war das:
`ostree-image-signed:docker://ghcr.io/ublue-os/bazzite-nvidia-open:stable`,
mit den gelayerten Paketen `kvantum` und `netbird-ui`.

### Rebase

```
rpm-ostree rebase ostree-unverified-registry:ghcr.io/timmi2k/bazz-hypr:latest
systemctl reboot
```

Beim allerersten Login im SDDM unten links **"Hyprland (illogical-impulse)"**
auswaehlen. Einen etwaigen UWSM-Eintrag *nicht* nehmen.

### Rollback, wenn die Session nicht hochkommt

Der vorherige Bazzite-Stand bleibt als zweiter Eintrag im Bootmenue stehen.

**Weg 1 — im Bootmenue:** beim Start den vorherigen Eintrag waehlen. Danach im
laufenden System festschreiben:

```
rpm-ostree rollback
systemctl reboot
```

**Weg 2 — falls du noch eine TTY hast** (`Ctrl+Alt+F3`):

```
rpm-ostree rollback
systemctl reboot
```

**Weg 3 — komplett zurueck auf das Original-Bazzite:**

```
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ublue-os/bazzite-nvidia-open:stable
systemctl reboot
```

### Wenn nur die Shell klemmt, die Session aber laeuft

```
journalctl --user -u bazz-hypr-firstrun -b     # lief das Seeding durch?
/usr/libexec/bazz-hypr-seed                    # von Hand nachholen
qs -c ii                                       # das Original statt end4-pC starten
```

---

## Aufraeumen (offen, nicht ausgefuehrt)

Ein abgebrochener `podman pull` des Bazzite-Base-Images hat ca. **7 GB**
verwaiste Layer in `~/.local/share/containers` hinterlassen. `podman system
prune -a` bekommt die nicht weg, weil kein Image-Eintrag mehr darauf verweist.

Aufraeumen (loescht auch die drei vorhandenen — leeren — Volumes, deren Namen
danach wieder angelegt werden):

```
VOLS=$(podman volume ls -q)
podman system reset -f
for v in $VOLS; do podman volume create "$v"; done
```

Der Befehl wurde bewusst nicht automatisch ausgefuehrt.
