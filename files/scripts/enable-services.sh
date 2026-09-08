#!/usr/bin/env bash
set -euo pipefail

# ydotool: das Fedora-RPM liefert nur eine System-Unit, illogical-impulse
# erwartet sie aber als User-Unit (der Upstream-Installer legt denselben
# Symlink an). Auf einem read-only /usr geht das nur zur Build-Zeit.
if [ -f /usr/lib/systemd/system/ydotool.service ] \
   && [ ! -e /usr/lib/systemd/user/ydotool.service ]; then
    ln -s /usr/lib/systemd/system/ydotool.service \
          /usr/lib/systemd/user/ydotool.service
    echo ">>> ydotool.service als User-Unit verlinkt"
else
    echo ">>> ydotool User-Unit bereits vorhanden oder System-Unit fehlt"
    ls -l /usr/lib/systemd/system/ydotool.service 2>&1 || true
fi

# Beide User-Dienste fuer jeden Benutzer vorab aktivieren. `systemctl --global`
# schreibt nach /usr/lib/systemd/user/*.target.wants/ und gilt damit auch fuer
# Benutzer, die es zum Build-Zeitpunkt noch gar nicht gibt - also auch fuer
# einen bestehenden Account nach einem rpm-ostree rebase.
systemctl --global enable ydotool.service || true
systemctl --global enable bazz-hypr-firstrun.service

# bluetooth wird von illogical-impulse vorausgesetzt (Bluetooth-Panel).
systemctl enable bluetooth.service || true

echo ">>> aktivierte User-Units:"
ls -l /usr/lib/systemd/user/default.target.wants/ 2>&1 || true
