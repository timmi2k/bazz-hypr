#!/usr/bin/env bash
set -euo pipefail

# Holt illogical-impulse (end-4/dots-hyprland) und end4-pC (pctrade/end4-pC)
# auf einem festgenagelten Commit ins Image.
#
# Warum mit .git-Verzeichnis? Damit der erste Boot einen echten git-Checkout
# nach $HOME kopieren kann. Der Benutzer kann die Shell danach selbst per
# `git pull` aktualisieren, ohne auf ein neues Image warten zu muessen.
#
# Aktualisieren = die beiden SHAs hier hochziehen und neu bauen.

DOTS_REPO="https://github.com/end-4/dots-hyprland.git"
DOTS_SHA="97c5bc651f68092351b24aaa935af708b1e04514"   # 2026-08-27

PC_REPO="https://github.com/pctrade/end4-pC.git"
PC_SHA="9bcb64aff23b6eae0cb9349457fdd49c701500ab"     # 2026-09-08

SHARE="/usr/share/bazz-hypr"
mkdir -p "$SHARE"

clone_pinned() {
    local url="$1" sha="$2" dest="$3"
    echo ">>> Klone $url @ $sha -> $dest"
    rm -rf "$dest"
    git clone --filter=blob:none "$url" "$dest"
    git -C "$dest" checkout --detach "$sha"
    git -C "$dest" submodule update --init --recursive
    # Blobs materialisieren, damit im fertigen Image kein Netz noetig ist.
    git -C "$dest" gc --aggressive --prune=all >/dev/null 2>&1 || true
}

clone_pinned "$DOTS_REPO" "$DOTS_SHA" "$SHARE/dots-hyprland"
clone_pinned "$PC_REPO"   "$PC_SHA"   "$SHARE/end4-pC"

# Sanity-Checks: wenn Upstream die Struktur umbaut, soll der Build hier
# scheitern und nicht erst auf der Maschine des Benutzers.
test -f "$SHARE/dots-hyprland/dots/.config/hypr/hyprland.lua" \
    || { echo "FEHLER: hyprland.lua fehlt - dots-hyprland-Struktur hat sich geaendert"; exit 1; }
test -d "$SHARE/dots-hyprland/dots/.config/quickshell/ii" \
    || { echo "FEHLER: quickshell/ii fehlt - dots-hyprland-Struktur hat sich geaendert"; exit 1; }
test -f "$SHARE/dots-hyprland/sdata/uv/requirements.txt" \
    || { echo "FEHLER: uv/requirements.txt fehlt - dots-hyprland-Struktur hat sich geaendert"; exit 1; }
test -f "$SHARE/end4-pC/shell.qml" \
    || { echo "FEHLER: end4-pC/shell.qml fehlt - end4-pC-Struktur hat sich geaendert"; exit 1; }

# Versionsmarke fuer den First-Boot-Dienst: aendert sie sich, synchronisiert
# bazz-hypr-seed die Upstream-Konfiguration im HOME neu.
printf '%s\n' "${DOTS_SHA}+${PC_SHA}" > "$SHARE/dots-version"

echo ">>> Dotfiles liegen unter $SHARE"
du -sh "$SHARE"/* || true
