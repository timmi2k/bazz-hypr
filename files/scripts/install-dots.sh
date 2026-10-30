#!/usr/bin/env bash
set -euo pipefail

# Fetches illogical-impulse (end-4/dots-hyprland) and end4-pC (pctrade/end4-pC)
# into the image at a pinned commit.
#
# Why keep the .git directory? So that the first boot can copy a real git
# checkout into $HOME. The user can then update the shell themselves via
# `git pull`, without waiting for a new image.
#
# Updating = bump the two SHAs here and rebuild.

DOTS_REPO="https://github.com/end-4/dots-hyprland.git"
DOTS_SHA="97c5bc651f68092351b24aaa935af708b1e04514"   # 2026-08-27

PC_REPO="https://github.com/pctrade/end4-pC.git"
PC_SHA="9bcb64aff23b6eae0cb9349457fdd49c701500ab"     # 2026-09-08

SHARE="/usr/share/bazz-hypr"
mkdir -p "$SHARE"

clone_pinned() {
    local url="$1" sha="$2" dest="$3"
    echo ">>> Cloning $url @ $sha -> $dest"
    rm -rf "$dest"
    git clone --filter=blob:none "$url" "$dest"
    git -C "$dest" checkout --detach "$sha"
    git -C "$dest" submodule update --init --recursive
    # Materialise the blobs so the finished image needs no network.
    git -C "$dest" gc --aggressive --prune=all >/dev/null 2>&1 || true
}

clone_pinned "$DOTS_REPO" "$DOTS_SHA" "$SHARE/dots-hyprland"
clone_pinned "$PC_REPO"   "$PC_SHA"   "$SHARE/end4-pC"

# Sanity checks: if upstream restructures things, the build should fail here
# and not later on the user's machine.
test -f "$SHARE/dots-hyprland/dots/.config/hypr/hyprland.lua" \
    || { echo "ERROR: hyprland.lua missing - dots-hyprland structure changed"; exit 1; }
test -d "$SHARE/dots-hyprland/dots/.config/quickshell/ii" \
    || { echo "ERROR: quickshell/ii missing - dots-hyprland structure changed"; exit 1; }
test -f "$SHARE/dots-hyprland/sdata/uv/requirements.txt" \
    || { echo "ERROR: uv/requirements.txt missing - dots-hyprland structure changed"; exit 1; }
test -f "$SHARE/end4-pC/shell.qml" \
    || { echo "ERROR: end4-pC/shell.qml missing - end4-pC structure changed"; exit 1; }

# matugen comes from Fedora, which ships 3.x. switchwall.sh in both shells still
# passes --source-color-index 0, a 2.x flag that 3.x rejects: matugen exits
# before writing colors.json, so no scheme or accent change reaches the shell
# any more. Drop the flag, and fail the build if the call ever moves somewhere
# this sed does not reach.
for f in "$SHARE/dots-hyprland/dots/.config/quickshell/ii/scripts/colors/switchwall.sh" \
         "$SHARE/end4-pC/scripts/colors/switchwall.sh"; do
    sed -i 's/matugen_args=(--source-color-index 0)/matugen_args=()/' "$f"
    if grep -q -- '--source-color-index' "$f"; then
        echo "ERROR: $f still passes --source-color-index to matugen"
        exit 1
    fi
done

# Hyprland 0.57 enforces decoration.shadow.render_power in 1-4 and puts up a
# config error for anything above; older releases clamped silently. Upstream
# still sets 10, so set it to 4, which is what 10 effectively was before.
GENERAL="$SHARE/dots-hyprland/dots/.config/hypr/hyprland/general.lua"
sed -i -E 's/render_power = [0-9]+,/render_power = 4,/' "$GENERAL"
if ! grep -q 'render_power = 4,' "$GENERAL"; then
    echo "ERROR: $GENERAL no longer sets render_power where the sed expects it"
    exit 1
fi

# Since 0.57 Hyprland hands the shell the release of SUPER + SUPER_L even when
# another key was pressed in between; before, the combo shadowed it. Nothing in
# the Lua config sends searchToggleReleaseInterrupt any more, so every Super+1,
# Super+Enter, ... opened the search on release. This is
# end-4/dots-hyprland#3732, still open upstream: the tap becomes a release
# bind, which Hyprland drops once another key or button comes in between, and
# the wheel binds cancel it. If a dots bump makes git apply fail, check whether
# upstream has fixed it and drop the patch.
git -C "$SHARE/dots-hyprland" apply <<'PATCH'
diff --git a/dots/.config/hypr/hyprland/keybinds.lua b/dots/.config/hypr/hyprland/keybinds.lua
--- a/dots/.config/hypr/hyprland/keybinds.lua
+++ b/dots/.config/hypr/hyprland/keybinds.lua
@@ -9,10 +9,22 @@ local hyprScripts = "$HOME/.config/hypr/hyprland/scripts"
 local qsIpcCall = "qs -c $qsConfig ipc call"
 local qsIsAlive = qsIpcCall .. " TEST_ALIVE"
 
-hl.bind("SUPER + SUPER_L", hl.dsp.global("quickshell:searchToggleRelease"), { description = "Shell: Toggle search" })
-hl.bind("SUPER + SUPER_R", hl.dsp.global("quickshell:searchToggleRelease"))
-hl.bind("SUPER + SUPER_L", hl.dsp.exec_cmd(qsIsAlive .. " || pkill fuzzel || fuzzel"))
-hl.bind("SUPER + SUPER_R", hl.dsp.exec_cmd(qsIsAlive .. " || pkill fuzzel || fuzzel"))
+-- Hyprland skips release binds if another key or button is pressed while Super is held, but not on scroll
+local superTapPending = false
+local function startSuperTap() superTapPending = true end
+local function cancelSuperTap() superTapPending = false end
+local function toggleSearchOnSuperTap()
+    if not superTapPending then return end
+    hl.dispatch(hl.dsp.global("quickshell:searchToggleRelease"))
+    hl.exec_cmd(qsIsAlive .. " || pkill fuzzel || fuzzel")
+end
+hl.bind("SUPER + SUPER_L", startSuperTap)
+hl.bind("SUPER + SUPER_R", startSuperTap)
+hl.bind("SUPER + SUPER_L", toggleSearchOnSuperTap, { release = true, description = "Shell: Toggle search" })
+hl.bind("SUPER + SUPER_R", toggleSearchOnSuperTap, { release = true })
+for _, wheel in ipairs({ "mouse_up", "mouse_down", "mouse_left", "mouse_right" }) do
+    hl.bind("SUPER + " .. wheel, cancelSuperTap, { non_consuming = true, transparent = true })
+end
 
 hl.bind("SUPER_L", hl.dsp.global("quickshell:workspaceNumber"), { ignore_mods = true, transparent = true })
 hl.bind("SUPER_R", hl.dsp.global("quickshell:workspaceNumber"), { ignore_mods = true, transparent = true })
PATCH

# Version stamp for the first-boot service: when it changes, bazz-hypr-seed
# re-syncs the upstream configuration in HOME.
printf '%s\n' "${DOTS_SHA}+${PC_SHA}" > "$SHARE/dots-version"

echo ">>> Dotfiles are at $SHARE"
du -sh "$SHARE"/* || true
