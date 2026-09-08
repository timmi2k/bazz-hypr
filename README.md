# bazz-hypr

Ein eigenes [BlueBuild](https://blue-build.org)-Image auf Basis von
**Bazzite (Nvidia, offene Kernelmodule)**, das Hyprland mit
[illogical-impulse](https://github.com/end-4/dots-hyprland) (Quickshell) als
Standard-Oberflaeche mitbringt, plus [end4-pC](https://github.com/pctrade/end4-pC)
als zweite, vorinstallierte Shell.

Zielmaschine laeuft bereits Bazzite, der Wechsel passiert per `rpm-ostree rebase`
(siehe [Rebase](#rebase) ganz unten).

---

## Die wichtigste Entscheidung: KDE Plasma bleibt drin

Der urspruengliche Plan war, Plasma/KWin aus dem Image zu werfen. Die Recherche
hat gezeigt, dass das die Shell kaputtmachen wuerde:

`sdata/dist-fedora/feddeps.toml` von end-4 installiert selbst eine
`[groups.kde]`-Gruppe mit `polkit-kde`, `plasma-nm`, `bluedevil`, `dolphin` und
`plasma-systemsettings`. Die Quickshell-Konfiguration ruft KDE-Programme direkt
auf:

| Aufruf | wo |
|---|---|
| `kcmshell6 kcm_bluetooth` | Bluetooth-Einstellungen aus dem Shell-Panel |
| `plasmawindowed org.kde.plasma.networkmanagement` | Netzwerk-Details (empfohlener Fix im Upstream-README fuer dist-fedora) |
| `plasma-systemmonitor --page-name Processes` | Taskmanager-Fallback |
| `kdialog` | Dateidialoge |
| `/usr/libexec/kf6/polkit-kde-authentication-agent-1` | Rechteabfragen — auf Fedora startet der Agent nicht von allein |

Dazu kommt: Bazzite Kinoite hat all diese Pakete ohnehin schon installiert
(auf der Zielmaschine verifiziert). Plasma zu entfernen haette also bedeutet,
Pakete wieder einzeln reinzuholen, auf die die Shell aufsetzt — und dabei die
Fallback-Session zu verlieren, die man auf einer Daily-Driver-Maschine nach
einem Rebase gebrauchen kann.

**Ergebnis:** Hyprland wird die Standard-Session, Plasma bleibt installiert und
im Login-Manager waehlbar. Der Desktop ist damit ersetzt, der Unterbau nicht.

---

## Beantwortete Recherchefragen

### Bringt illogical-impulse Quickshell selbst mit?

**Ja.** `feddeps.toml` hat eine eigene Gruppe:

```toml
[groups.illogical-impulse]
packages = ["quickshell-git", "matugen"]
```

`quickshell-git` kommt aus der COPR `ririko66z/dots-hyprland` (Version
`0.2.1^713.git26531fc`, gebaut fuer `fedora-44-x86_64`). Eine generische
Quickshell-COPR wie `errornointernet/quickshell` waere eine
Doppelinstallation — sie ist hier **nicht** eingebunden.

`matugen` liegt inzwischen in Fedora 44 selbst; das RPM aus
`end-4/ii-package-builds` (was der Upstream-Installer herunterlaedt) wird nicht
gebraucht.

### Braucht es noch ein Python-venv?

**Ja, unveraendert.** Das ist *kein* AGS-Ueberbleibsel — in der aktuellen
Quickshell-Version haengen etliche Skripte daran:

```
scripts/colors/generate_colors_material.py   Material-You-Farbschema
scripts/colors/switchwall.sh                 Wallpaper- und Farbwechsel
scripts/thumbnails/thumbgen-venv.sh          Wallpaper-Vorschaubilder
scripts/images/find-regions-venv.sh          Screenshot-Texterkennung
scripts/hyprland/hyprconfigurator.py         Hyprland-Einstellungsdialog
services/gCloud/token-from-key-venv.sh       Google-Cloud-Anbindung
```

`$ILLOGICAL_IMPULSE_VIRTUAL_ENV` wird in `hypr/hyprland/env.lua` auf
`~/.local/state/quickshell/.venv` gesetzt und mit `uv` aus
`sdata/uv/requirements.txt` befuellt (materialyoucolor, kde-material-you-colors,
pygobject, pycairo, opencv, libsass, …). Ohne venv startet die Shell zwar, aber
Farbschema-Generierung und Wallpaper-Vorschau sind tot.

**Wie dieses Image das loest:** Das venv wird beim *Image-Build* fertig gebaut
(`files/scripts/build-venv.sh`) und liegt unter `/usr/share/bazz-hypr/venv`.
Beim ersten Login kopiert `bazz-hypr-seed` es nach
`~/.local/state/quickshell/.venv`. Damit braucht der erste Start weder Netz noch
Compiler auf der Zielmaschine — `pygobject`, `pycairo` und `dbus-python` liefern
keine fertigen Wheels und muessten sonst dort uebersetzt werden.

Upstream nagelt Python **3.12** fest (Pillow baut auf neueren Versionen nicht,
siehe [Pillow#8089](https://github.com/python-pillow/Pillow/issues/8089)).
Fedora 44 liefert eine neuere Standard-Python-Version, deshalb holt sich `uv`
beim Build ein eigenes 3.12.

### Hyprland-Version und Lua-Config

illogical-impulse nutzt seit dem Hyprland-0.55-Update das **Lua-Format**
(`~/.config/hypr/hyprland.lua` plus `hypr/hyprland/*.lua` und `hypr/custom/*.lua`).
Eine `hyprland.conf` im alten Format ist damit obsolet — der Upstream-Installer
benennt eine vorgefundene sogar aktiv in `hyprland.conf.old` um, damit sie die
Lua-Konfiguration nicht blockiert.

| COPR | Hyprland | Chroots |
|---|---|---|
| `solopasha/hyprland` | 0.49.0-7 | nur fedora-41 |
| `sdegler/hyprland` | **0.56.2-2** | fedora-43/44/45, rawhide |

`solopasha/hyprland` ist damit doppelt unbrauchbar: zu alt fuer Lua *und* ohne
Fedora-44-Build. `feddeps.toml` sagt das selbst:

> `# "solopasha/hyprland" is not up to date to the current Hyprland version, replaced with the fork "sdegler/hyprland"`

Da `sdegler/hyprland` mit 0.56.2 ueber der Luaification-Schwelle 0.55 liegt,
**wird die Pre-Luaification-Schiene von illogical-impulse nicht gebraucht.**
Es werden keine Versionen gemischt: aktuelles dots-hyprland `main` auf
Hyprland 0.56.2.

### Nvidia

Gegen [wiki.hypr.land/Nvidia](https://wiki.hypr.land/Nvidia/) (Abruf 2026-09-08)
auf der Zielmaschine geprueft:

| Anforderung | Wiki verlangt | Bazzite liefert | |
|---|---|---|---|
| Nvidia-Treiber | >= 555 | 610.57.04 (open kernel modules) | OK |
| xorg-x11-server-Xwayland | >= 24.1 | 24.1.11 | OK |
| wayland-protocols | >= 1.34 | Fedora 44 | OK |

Empfohlene Umgebungsvariablen laut Wiki — es sind nur noch zwei:

```lua
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
```

`GBM_BACKEND=nvidia-drm` steht dort **nicht mehr** und wird hier bewusst nicht
gesetzt. Zusaetzlich gesetzt wird `NVD_BACKEND=direct` (Hardware-Decoding ohne
VDPAU-Umweg). Das landet in `~/.config/hypr/custom/env.lua`, das von
dots-hyprland-Updates nie ueberschrieben wird.

**illogical-impulse bringt selbst kein Nvidia-Handling mit** — der Installer
sagt das explizit: *"It does not handle system-level/hardware stuff like Nvidia
drivers. Please do it by yourself."* Unsere Variablen sind also keine
Doppelung.

DRM-Modesetting wird in `/usr/lib/modprobe.d/zz-bazz-hypr-nvidia.conf` explizit
gesetzt. Bazzites eigene `nvidia.conf` setzt es nicht, auf aktuellen Treibern
ist es zwar ohnehin Default, aber so kann es nicht wegkippen. Ab Treiber
570.86.16 wird `fbdev` automatisch mitaktiviert, ein separater Schalter dafuer
entfaellt.

### Quickshell: warum nicht die COPR von illogical-impulse

Das ist die einzige Stelle, an der dieses Image bewusst von `feddeps.toml`
abweicht — und der erste CI-Build ist genau daran gescheitert:

```
quickshell-git-0.2.1^713.git26531fc requires libQt6Qml.so.6(Qt_6.10_PRIVATE_API)
Package "qt6-qtdeclarative-6.11.2-1.fc44" is already installed
qt6-qtdeclarative-6.10.2-2.fc44 from fedora is filtered out by exclude filtering
```

Quickshell bindet **Qt-Private-APIs**, die versionsgenau passen muessen. Der
Build in `ririko66z/dots-hyprland` stammt vom **2025-12-18** und ist gegen
Qt 6.10 gelinkt; Bazzite liefert Qt **6.11.2** und laesst kein Downgrade zu.
Die COPR ist damit auf Bazzite schlicht nicht installierbar.

Alle COPR-Pakete wurden daraufhin systematisch geprueft:

| Paket | COPR | Qt-Private-API | |
|---|---|---|---|
| `quickshell-git` | `ririko66z/dots-hyprland` | 6.10 | unbrauchbar |
| `hyprland-qt-support` | `ririko66z/dots-hyprland` | 6.10 | unbrauchbar |
| `quickshell-git` | `errornointernet/quickshell` | **6.11** | genommen |
| `hyprland-qt-support` | `sdegler/hyprland` | **6.11** | genommen |
| `hyprpolkitagent`, `hyprqt6engine` | `sdegler/hyprland` | 6.11 | ok (nicht installiert) |
| `qt6ct` | `sdegler/hyprland` | 6.10 | nicht installiert |

Beide kritischen Pakete sind im Rezept ueber `repo:` an die richtige Quelle
gebunden, statt dnf die Version waehlen zu lassen. `ririko66z/dots-hyprland`
bleibt eingebunden, aber nur noch fuer die Qt-freien Pakete (microtex,
breakpad, songrec, Cursor, Icons, Fonts).

**Zur Versionsfrage** — die Versionsstrings sind irrefuehrend, deshalb hier
aufgeloest. Quickshell-Releases: v0.2.1 am 2025-10-12, v0.3.0 am 2026-05-04,
v0.3.1 am 2026-08-21.

| Quelle | Versionsstring | tatsaechlicher git-Stand |
|---|---|---|
| end-4 fuer sich selbst | `0.2.1^770.git7511545` | ~2026-08-18 |
| `errornointernet` (in diesem Image) | `0.3.1^856.git2d3b3e9` | 2026-09-04 |
| Fedora 44 | `0.2.1^git20260209.dacfa9d` | 2026-02-09 |

end-4s `0.2.1^770` zaehlt Commits seit dem alten Tag v0.2.1, liegt aber
tatsaechlich im August 2026 — also in der v0.3.1-Generation. **end-4 und
errornointernet trennen nur rund zwei Wochen.** Das hier eingebundene Paket ist
damit die beste verfuegbare Uebereinstimmung mit dem, wogegen illogical-impulse
entwickelt wird.

Fedoras Paket ist der Ausreisser: Stand Februar 2026, also **vor v0.3.0**. Es
haette eine Konfiguration von August 2026 auf einer Shell von sieben Monaten
davor bedeutet, quer ueber eine Major-Release-Grenze. Als Ausweichpfad ist es
deshalb die *letzte* Wahl, nicht die erste.

Verifiziert ist der Build, nicht der Betrieb: ob die ii-QML-Konfiguration
vollstaendig laeuft, zeigt sich erst beim Start der Shell. Falls es klemmt, in
dieser Reihenfolge probieren — jeweils eine Zeile im Rezept:

1. `quickshell` (getaggtes Release 0.3.1-2, 2026-08-21) aus derselben COPR
   statt `quickshell-git`. Minimal aelter, dafuer ein Release statt eines
   git-Snapshots.
2. Den Dotfiles-Pin in `files/scripts/install-dots.sh` auf einen aelteren
   dots-hyprland-Commit zurueckziehen, statt an der Shell zu drehen.
3. Fedoras `quickshell` — nur, wenn die COPR ausfaellt. Es wird von Fedora bei
   jedem Qt-Bump neu gebaut und ist dadurch langfristig am wartungsaermsten,
   liegt inhaltlich aber am weitesten weg.

### Doppelungen bei den KDE-Ersatzdiensten

Der urspruengliche Entwurf hatte generische Ersatzdienste vorgesehen. Abgleich
mit dem, was illogical-impulse tatsaechlich erwartet:

| urspruenglich geplant | was illogical-impulse nutzt | Entscheidung |
|---|---|---|
| `hyprpolkitagent` | `polkit-kde` (`/usr/libexec/kf6/polkit-kde-authentication-agent-1`) | polkit-kde — schon in Bazzite, wird in `custom/execs.lua` gestartet |
| `network-manager-applet` | `plasma-nm` + `plasmawindowed` | plasma-nm — schon in Bazzite |
| `blueman` | `bluedevil` + `kcmshell6 kcm_bluetooth` | bluedevil — schon in Bazzite |
| `gnome-keyring` | `gnome-keyring-daemon --components=secrets` | uebernommen, **fehlt** in Bazzite und wird installiert |
| `hyprsunset` | `hyprsunset` (in `[groups.hyprland]`) | uebernommen, keine Doppelung |

Zwei Dienste, die Fedora-spezifisch nachgezogen werden mussten:

* **polkit-Agent**: Der Upstream-Installer haengt die `exec-once`-Zeile dafuer an
  `hypr/hyprland/execs.conf` an — eine Datei, die seit der Lua-Umstellung gar
  nicht mehr gelesen wird. Ein Upstream-Bug. Hier steht die Zeile korrekt in
  `custom/execs.lua`.
* **ydotool**: Das Fedora-RPM liefert nur eine System-Unit, illogical-impulse
  braucht sie als User-Unit. Der Symlink wird zur Build-Zeit angelegt
  (`/usr` ist zur Laufzeit read-only).

---

## Paketliste

Quelle ist `sdata/dist-fedora/feddeps.toml` aus dots-hyprland — die offizielle,
laut Upstream-README auf *Fedora Everything 44* getestete Liste. Die beiden
Community-Installer wurden gegengeprueft und **nicht** uebernommen:

| Repo | Stand | Bewertung |
|---|---|---|
| `EisregenHaha/fedora-hyprland` | Feb 2026, README sagt "Tested on Fedora 42", letzter Commit heisst woertlich *"DONT USE THIS"* | AGS-Ueberbleibsel (`gjs-devel`, `gtk-layer-shell-devel`, `typescript`, `npm`, `gtksourceview`), nutzt die tote `solopasha/hyprland` |
| `MateuszFido/fedora-hyprland` | Aug 2025, Fork des obigen | noch aelter, gleiche Probleme |

Beide bestaetigen zwar die Paketnamen `matugen`, `quickshell-git`, `wtype`,
`ydotool`, `mpvpaper` — sind aber gegenueber dem Upstream-eigenen `dist-fedora`
veraltet.

**Verfuegbarkeit vollstaendig geprueft** (`dnf repoquery` gegen Fedora 44 +
COPR-Repodata der Ziel-Chroot `fedora-44-x86_64`): alle 118 Pakete loesen auf.

| Quelle | Anzahl |
|---|---|
| Fedora 44 (`fedora` + `updates`) | 94 |
| COPR `sdegler/hyprland` | hyprland, hypridle, hyprlock, hyprpicker, hyprshot, hyprsunset, hyprland-guiutils, xdg-desktop-portal-hyprland, mpvpaper |
| COPR `ririko66z/dots-hyprland` | microtex, breakpad, songrec, bibata-cursor-theme, breeze-plus-icon-theme + 6 Font-Pakete |
| COPR `errornointernet/quickshell` | quickshell-git (gegen Qt 6.11 gebaut, siehe oben) |
| COPR `deltacopy/darkly` | darkly |
| COPR `atim/starship` | starship |

Aus `feddeps.toml` bewusst **nicht** uebernommen:

| Paket | Grund |
|---|---|
| `grub2-breeze-theme` | wuerde den Bootloader umthemen — auf einem atomaren System unnoetiges Risiko |
| `sddm-breeze` | wuerde den Login-Manager umthemen, Bazzite bringt eigenes SDDM-Theming |
| COPR `alternateved/eza` | `eza` liegt inzwischen in Fedora 44 selbst |
| `tesseract-langpack-chi_sim` | chinesische OCR-Sprachdaten, hier nicht gebraucht |

Zusaetzlich installiert (nicht in `feddeps.toml`), damit der venv-Bau im Image
durchlaeuft: `gcc`, `pkgconf-pkg-config`, `glib2-devel`, `cairo-devel`,
`cairo-gobject-devel`, `dbus-devel`.

---

## Wie die Dotfiles ins Benutzerverzeichnis kommen

Das ist der Teil, der bei einem Rebase anders laufen muss als bei einer
Neuinstallation: **`/etc/skel` greift nur bei neu angelegten Benutzern.** Auf der
Zielmaschine existiert der Account laengst, skel wuerde nie ausgewertet.

Deshalb:

1. **Build-Zeit** — `files/scripts/install-dots.sh` klont dots-hyprland und
   end4-pC auf einem festgenagelten Commit nach `/usr/share/bazz-hypr/`,
   inklusive `.git`. Danach laufen Struktur-Checks: wenn Upstream z.B.
   `hyprland.lua` verschiebt, scheitert der Build hier und nicht spaeter auf
   deiner Maschine.
2. **Laufzeit** — `/usr/libexec/bazz-hypr-seed` legt die Konfiguration im HOME an.
   Zwei Ausloeser, damit nichts durchrutscht:
   * der User-Dienst `bazz-hypr-firstrun.service` (bei jedem Login),
   * der Session-Wrapper `/usr/libexec/bazz-hypr-session`, den der
     Desktop-Eintrag startet. Der macht das Seeding **synchron vor** Hyprland.
     Ohne ihn koennte Hyprland beim allerersten Login nach dem Rebase den
     parallel laufenden User-Dienst ueberholen und ohne Konfiguration hochkommen.

Das Skript ist idempotent und unterscheidet sauber:

| Pfad | Verhalten |
|---|---|
| `~/.config/quickshell/ii/`, `~/.config/hypr/hyprland/`, `~/.config/matugen/` | gehoert Upstream, wird bei jedem Image-Update ueberschrieben |
| `~/.config/hypr/custom/`, `hyprland.lua`, `hyprlock.conf`, `hypridle.conf` | wird nur angelegt, wenn nicht vorhanden |
| `~/.config/fish`, `kitty`, `kdeglobals`, `Kvantum`, … | wird nur angelegt, wenn nicht vorhanden — dein eingerichtetes KDE wird nicht ueberbuegelt |
| `~/.local/state/quickshell/.venv` | wird kopiert, wenn nicht vorhanden |

`~/.config/quickshell/end4-pC` wird als echter git-Checkout kopiert — du kannst
dort selbst `git pull` machen, ohne auf ein neues Image zu warten.

### end4-pC aktivieren und wieder abwaehlen

end4-pC ist ein reiner Quickshell-Config-Ordner (GPL-3.0) und setzt
illogical-impulse voraus — es ersetzt es nicht, es liegt daneben. Umgeschaltet
wird in `~/.config/hypr/custom/variables.lua`:

```lua
hl.env("qsConfig", "end4-pC")   -- Standard in diesem Image
-- hl.env("qsConfig", "ii")     -- das Original von end-4
```

Danach `hyprctl reload`, oder `Ctrl+Super+R` startet die Shell neu.

---

## Offene Punkte vor dem Rebase

* **Session-Auswahl ist manuell.** SDDM merkt sich die zuletzt benutzte Session
  pro Benutzer; es gibt keinen sauberen Weg, das aus dem Image heraus
  vorzugeben. Beim ersten Login nach dem Rebase musst du unten links
  **"Hyprland (illogical-impulse)"** auswaehlen. Falls dort zusaetzlich ein
  UWSM-Eintrag auftaucht: **den nicht nehmen**, das sagt der Upstream-Installer
  ausdruecklich.
* **`nvidia_drm.modeset`** konnte auf der Zielmaschine nicht direkt ausgelesen
  werden (`/sys/module/nvidia_drm/parameters/modeset` ist fuer normale Benutzer
  nicht lesbar). Da dort Bazzite Kinoite auf Wayland laeuft, muss es aktiv sein.
  Die modprobe-Datei setzt es zusaetzlich explizit.
* **Erster Login dauert laenger.** Das venv (mehrere hundert MB) wird ins HOME
  kopiert. Einmalig.
* **`ydotool` und `/dev/uinput`**: geloest ueber `TAG+="uaccess"` in der
  udev-Regel, damit systemd-logind dem Sitzungsbenutzer eine ACL gibt und kein
  `usermod -aG input` noetig ist. Falls die virtuelle Tastatur trotzdem nicht
  geht, ist der Fallback `sudo usermod -aG input,video $USER` plus Neustart.
* **Bekannter Upstream-Bug (Wi-Fi-Panel)**: Das dist-fedora-README beschreibt,
  dass der "Details"-Knopf im WLAN-Panel abstuerzt. Fix in
  `~/.config/illogical-impulse/config.json`:
  `"network": "kitty -1 fish -c nmtui"` → `"network": "plasmawindowed org.kde.plasma.networkmanagement"`.
  Diese Datei entsteht erst beim ersten Start der Shell, deshalb ist der Fix
  hier nicht vorbaked.
* **Quickshell ist ein git-Snapshot vom 2026-09-04**, end-4 selbst baut einen
  vom ~2026-08-18. Zwei Wochen Abstand, gleiche Generation — das Risiko ist
  klein, aber der Build beweist nur, dass sich alles installieren laesst, nicht
  dass die Shell laeuft. Ausweichpfade im Abschnitt *"Quickshell: warum nicht
  die COPR von illogical-impulse"*.
* **Nicht getestet**: Es gab keinen Boot-Test in einer VM — auf dieser Maschine
  sind weder `qemu` noch `libvirt` installiert, und es sollte nichts
  nachinstalliert werden. Der Build ist gruen, der tatsaechliche
  Session-Start ist unverifiziert.

---

## Rebase

Das Image steht: `ghcr.io/timmi2k/bazz-hypr:latest`

> Wird **nicht** automatisch ausgefuehrt. Die Befehle stehen in `PLAN.md`,
> Phase 6 — dort auch der Rollback.

## Aktualisieren

* **Base + Pakete**: passiert automatisch, der Workflow baut taeglich um 06:20 UTC.
  Auf der Maschine dann `rpm-ostree upgrade`.
* **Dotfiles**: die beiden SHAs oben in `files/scripts/install-dots.sh`
  hochziehen und pushen. `bazz-hypr-seed` erkennt die neue Version am
  Versionsstempel und synchronisiert das HOME nach.

## Lizenzen

* [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) — GPL-3.0
* [pctrade/end4-pC](https://github.com/pctrade/end4-pC) — GPL-3.0

Beide werden zur Build-Zeit unveraendert geklont, nicht in dieses Repo kopiert.
