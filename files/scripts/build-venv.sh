#!/usr/bin/env bash
set -euo pipefail

# Baut das Python-venv, das illogical-impulse zur Laufzeit braucht, schon
# waehrend des Image-Builds.
#
# Hintergrund: Die Quickshell-Konfiguration ruft eine Reihe Python-Skripte auf
# (generate_colors_material.py, switchwall.sh, thumbgen, find_regions, ...).
# Die erwarten alle ein venv unter $ILLOGICAL_IMPULSE_VIRTUAL_ENV, per Default
# ~/.local/state/quickshell/.venv (gesetzt in hypr/hyprland/env.lua).
# Das ist KEIN AGS-Ueberbleibsel - es ist in der aktuellen Quickshell-Version
# weiterhin der Weg, auf dem kde-material-you-colors, materialyoucolor,
# pygobject usw. bereitgestellt werden.
#
# Wir bauen es hier statt beim ersten Boot, weil:
#   - der Build-Runner Netz und Compiler hat, die Zielmaschine evtl. nicht,
#   - pygobject/pycairo/dbus-python keine Wheels liefern und kompiliert werden,
#   - der erste Login dadurch schnell bleibt.
# Der First-Boot-Dienst kopiert es dann nur noch nach $HOME.

SHARE="/usr/share/bazz-hypr"
VENV="$SHARE/venv"
REQ="$SHARE/dots-hyprland/sdata/uv/requirements.txt"

test -f "$REQ" || { echo "FEHLER: $REQ fehlt"; exit 1; }

export UV_NO_MODIFY_PATH=1
export UV_PYTHON_INSTALL_DIR="$SHARE/python"
export UV_LINK_MODE=copy

# Upstream nagelt Python 3.12 fest (Pillow-Build bricht auf neueren Versionen,
# siehe python-pillow/Pillow#8089). Fedora 44 liefert 3.12 als eigenes RPM;
# das wird bevorzugt, damit der Build nicht davon abhaengt, ob uv sich einen
# Interpreter aus dem Netz holen darf (manche Distributionen schalten das ab).
if [ -x /usr/bin/python3.12 ]; then
    PY312=/usr/bin/python3.12
    echo ">>> Erzeuge venv mit $PY312 ($("$PY312" -V))"
else
    PY312=3.12
    echo ">>> /usr/bin/python3.12 fehlt - lasse uv einen Interpreter holen"
fi
uv venv --relocatable --prompt .venv -p "$PY312" "$VENV"

echo ">>> Installiere requirements.txt"
# shellcheck disable=SC1091
source "$VENV/bin/activate"
uv pip install --python "$VENV/bin/python" -r "$REQ"
deactivate

# Sanity-Check: die Pakete, ohne die die Shell sichtbar kaputt ist.
echo ">>> Pruefe venv"
"$VENV/bin/python" - <<'PY'
import importlib, sys
fehlend = []
for m in ("materialyoucolor", "PIL", "gi", "cairo", "numpy", "cv2", "sass"):
    try:
        importlib.import_module(m)
    except Exception as e:
        fehlend.append(f"{m}: {e}")
if fehlend:
    print("FEHLER: venv unvollstaendig:")
    for f in fehlend:
        print("  -", f)
    sys.exit(1)
print("venv ok:", sys.version)
PY

test -x "$VENV/bin/kde-material-you-colors" \
    || { echo "FEHLER: kde-material-you-colors fehlt im venv"; exit 1; }

du -sh "$VENV"
echo ">>> venv gebaut unter $VENV"
