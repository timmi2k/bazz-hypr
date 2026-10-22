#!/usr/bin/env bash
set -euo pipefail

# Hyprland requires xorg-x11-server-Xwayland(x86-64). Bazzite swaps Fedora's
# Xwayland for terra-xorg-x11-server-Xwayland and versionlocks it, and the
# swap takes the highest version in terra-extras: 26.0.99.903, a leftover of
# Terra's first f44 build from 2026-10-08 that lacks the arch-qualified
# provide. Terra fixed the spec the same day but went back to 24.1.x, so the
# broken build still sorts first and the dnf module fails with "none of the
# providers can be installed".
#
# Move to the newest Terra build that does carry the provide - same SteamOS
# and Nobara patches. Does nothing once the base ships a good build again.
PROVIDE='xorg-x11-server-Xwayland(x86-64)'
PKG=terra-xorg-x11-server-Xwayland

if rpm -q --whatprovides "$PROVIDE" >/dev/null 2>&1; then
    echo ">>> $(rpm -q --whatprovides "$PROVIDE") provides $PROVIDE, nothing to do"
    exit 0
fi

# Not --latest-limit: dnf5 applies it before --whatprovides, so it picks the
# broken build and the filter then drops it. -y because loading terra-extras
# can ask to import its repo key, and a refused prompt yields an empty result.
GOOD=$(dnf5 -y repoquery -q --repo terra-extras --whatprovides "$PROVIDE" \
       --qf '%{name}-%{evr}.%{arch}\n' "$PKG" | sort -V | tail -n 1)
test -n "$GOOD" || { echo "ERROR: no $PKG in terra-extras provides $PROVIDE"; exit 1; }

echo ">>> $(rpm -q "$PKG") lacks $PROVIDE, moving to $GOOD"
dnf5 versionlock delete "$PKG"
# Bazzite leaves terra-extras disabled in the finished image.
dnf5 -y downgrade --enable-repo=terra-extras "$GOOD"
dnf5 versionlock add "$PKG"
rpm -q --whatprovides "$PROVIDE"
