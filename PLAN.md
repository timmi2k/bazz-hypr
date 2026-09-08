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

## Phase 3 — GitHub & GHCR ✅ abgeschlossen

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

Erledigt: Repo `timmi2k/bazz-hypr` ist public, `SIGNING_SECRET` gesetzt, das
Container-Package ist anonym abrufbar (gegen `ghcr.io/v2/.../manifests/latest`
ohne Anmeldung mit HTTP 200 geprueft).

**Hinweis zur Historie:** Das Repo wurde einmal geloescht und neu angelegt, weil
der erste Commit die private Mailadresse als Git-Author enthielt. Ein
force-push reicht dafuer nicht - GitHub liefert den ersetzten Commit unter
seiner SHA weiter aus. Die aktuelle Historie hat genau einen Commit mit
`74569037+timmi2k@users.noreply.github.com`.

Empfehlung: in den GitHub-Einstellungen unter *Emails* die Option
**"Block command line pushes that expose my email"** einschalten - dann lehnt
GitHub so einen Push von vornherein ab.

---

## Phase 4 — Build in CI ✅ gruen

Erfolgreicher Build: Run `34246345464`, 7m29s.
Image: `ghcr.io/timmi2k/bazz-hypr:latest`
(Digest `sha256:0e9cf9ed1c41d552d33fa63a1d82f0b4814de09ab30b954ce887298d678ba76f`,
Tags `latest`, `20260908`, `44`, `20260908-44` — cosign-Signaturen liegen daneben.)

Verifiziert im Build-Log:

* beide Dotfile-Repos auf den gepinnten Commits geklont, Struktur-Checks bestanden
* `quickshell-git 0.3.1^856` installiert, `cpptrace 1.0.4-1.patched` und
  `libdwarf 2.3.1-1.fc44` sauber aufgeloest
* venv mit Python **3.12.14** gebaut, Import-Check bestanden
  (`materialyoucolor`, `PIL`, `gi`, `cairo`, `numpy`, `cv2`, `sass`,
  `kde-material-you-colors`)
* `ydotool.service` als User-Unit verlinkt

### Die zwei Fehlschlaege davor — beide lehrreich

**Build 1 (34244504837), Qt-Konflikt:**

```
quickshell-git … requires libQt6Qml.so.6(Qt_6.10_PRIVATE_API)
Package "qt6-qtdeclarative-6.11.2-1.fc44" is already installed
```

Quickshell bindet Qt-Private-APIs versionsgenau. Der Build in
`ririko66z/dots-hyprland` — die COPR, die `feddeps.toml` vorschreibt — ist vom
2025-12-18 und gegen Qt 6.10 gelinkt; Bazzite hat Qt 6.11 und sperrt das
Downgrade. Geloest durch Umstieg auf `errornointernet/quickshell`.

**Build 2 (34245617493), selbstverschuldet:**

```
nothing provides libdwarf.so.2 needed by cpptrace-1.0.4-1.patched.fc44
```

Ursache war das `repo:`-Pinning, mit dem ich quickshell an die COPR gebunden
hatte. Ein `repo:`-Eintrag schraenkt die dnf-Aufloesung auf genau diese Repo
ein — Fedoras `libdwarf-2.3.1` (das `libdwarf.so.2` sehr wohl liefert) war
dadurch unsichtbar. Ohne Pinning waehlt dnf ohnehin die hoechste Version.

**Merkregel:** `dnf repoquery` sagt nur, *ob* ein Paket existiert — nicht, ob es
sich gegen den Bestand der Base aufloesen laesst. Beide Fehler waren lokal nicht
findbar, dafuer braucht es den echten Build.

### Versionslage bei Quickshell

Die RPM-Versionsstrings taeuschen. Echte Releases: v0.2.1 (2025-10-12),
v0.3.0 (2026-05-04), v0.3.1 (2026-08-21). Tatsaechlicher git-Stand:
end-4 `0.2.1^770` = ~2026-08-18, `errornointernet` `0.3.1^856` = 2026-09-04,
Fedora `0.2.1^git20260209` = 2026-02-09.

Das Image liegt also rund zwei Wochen neben dem, was end-4 selbst baut —
Fedoras Paket laege sieben Monate daneben und vor v0.3.0. Ein Wechsel dorthin
ist **kein** konservativerer Schritt, sondern der groessere Sprung.

### Wenn ein spaeterer Build bricht

| Symptom | wahrscheinliche Ursache |
|---|---|
| `Qt_6.xx_PRIVATE_API` nicht erfuellbar | Bazzite hat Qt gebumpt, die COPR noch nicht nachgebaut. Alternativen im README-Abschnitt zu Quickshell. |
| `nothing provides <lib>` | Ein `repo:`-Pinning verdeckt das Fedora-Repo, oder eine COPR wurde nicht neu gebaut. |
| `No match for argument: <paket>` | Paketname umbenannt oder COPR-Chroot fuer ein neues Fedora-Release fehlt. `skip-unavailable: true` faengt das ab — im Log nachsehen, was uebersprungen wurde. |
| Abbruch in `install-dots.sh` mit "Struktur hat sich geaendert" | Upstream hat Dateien verschoben. SHA pruefen, Pfade anpassen. |
| `build-venv.sh` scheitert beim Kompilieren | ein `-devel`-Paket fehlt; der fehlende Header steht im Log. |

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

### Rebase — zwei Schritte

Der erste Rebase muss **unverified** laufen: die cosign-Policy, die die Signatur
pruefbar macht, steckt im Image selbst und ist auf dem laufenden Bazzite noch
nicht vorhanden. Nach dem ersten Boot ist sie da, und der zweite Befehl stellt
auf die signaturgepruefte Referenz um - ab dann sind auch alle kuenftigen
`rpm-ostree upgrade` signaturgeprueft.

```
rpm-ostree rebase ostree-unverified-registry:ghcr.io/timmi2k/bazz-hypr:latest
systemctl reboot
```

Nach dem Neustart und einem erfolgreichen Login:

```
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/timmi2k/bazz-hypr:latest
systemctl reboot
```

**Deine gelayerten Pakete** (`kvantum`, `netbird-ui`) werden beim Rebase
mitgenommen. Keines davon ist im Image enthalten, es sollte also keinen
Konflikt geben.

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
