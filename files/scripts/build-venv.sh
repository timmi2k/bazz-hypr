#!/usr/bin/env bash
set -euo pipefail

# Builds the Python venv that illogical-impulse needs at runtime, already
# during the image build.
#
# Background: the Quickshell configuration calls a number of Python scripts
# (generate_colors_material.py, switchwall.sh, thumbgen, find_regions, ...).
# They all expect a venv at $ILLOGICAL_IMPULSE_VIRTUAL_ENV, by default
# ~/.local/state/quickshell/.venv (set in hypr/hyprland/env.lua).
# This is NOT an AGS leftover - in the current Quickshell version it is still
# the way kde-material-you-colors, materialyoucolor, pygobject and friends are
# provided.
#
# We build it here instead of on first boot because:
#   - the build runner has network and compilers, the target machine may not,
#   - pygobject/pycairo/dbus-python ship no wheels and get compiled,
#   - it keeps the first login fast.
# The first-boot service then only has to copy it into $HOME.

SHARE="/usr/share/bazz-hypr"
VENV="$SHARE/venv"
REQ="$SHARE/dots-hyprland/sdata/uv/requirements.txt"

test -f "$REQ" || { echo "ERROR: $REQ missing"; exit 1; }

export UV_NO_MODIFY_PATH=1
export UV_PYTHON_INSTALL_DIR="$SHARE/python"
export UV_LINK_MODE=copy

# Upstream pins Python 3.12 (the Pillow build breaks on newer versions, see
# python-pillow/Pillow#8089). Fedora 44 ships 3.12 as its own RPM; that one is
# preferred so the build does not depend on whether uv is allowed to fetch an
# interpreter from the network (some distributions disable that).
if [ -x /usr/bin/python3.12 ]; then
    PY312=/usr/bin/python3.12
    echo ">>> Creating venv with $PY312 ($("$PY312" -V))"
else
    PY312=3.12
    echo ">>> /usr/bin/python3.12 missing - letting uv fetch an interpreter"
fi
uv venv --relocatable --prompt .venv -p "$PY312" "$VENV"

echo ">>> Installing requirements.txt"
# shellcheck disable=SC1091
source "$VENV/bin/activate"
uv pip install --python "$VENV/bin/python" -r "$REQ"
deactivate

# Sanity check: the packages without which the shell is visibly broken.
echo ">>> Checking venv"
"$VENV/bin/python" - <<'PY'
import importlib, sys
missing = []
for m in ("materialyoucolor", "PIL", "gi", "cairo", "numpy", "cv2", "sass"):
    try:
        importlib.import_module(m)
    except Exception as e:
        missing.append(f"{m}: {e}")
if missing:
    print("ERROR: venv incomplete:")
    for f in missing:
        print("  -", f)
    sys.exit(1)
print("venv ok:", sys.version)
PY

test -x "$VENV/bin/kde-material-you-colors" \
    || { echo "ERROR: kde-material-you-colors missing from the venv"; exit 1; }

du -sh "$VENV"
echo ">>> venv built at $VENV"
