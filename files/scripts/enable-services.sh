#!/usr/bin/env bash
set -euo pipefail

# ydotool: the Fedora RPM ships only a system unit, but illogical-impulse
# expects it as a user unit (the upstream installer creates the same symlink).
# On a read-only /usr this is only possible at build time.
if [ -f /usr/lib/systemd/system/ydotool.service ] \
   && [ ! -e /usr/lib/systemd/user/ydotool.service ]; then
    ln -s /usr/lib/systemd/system/ydotool.service \
          /usr/lib/systemd/user/ydotool.service
    echo ">>> linked ydotool.service as a user unit"
else
    echo ">>> ydotool user unit already present, or system unit missing"
    ls -l /usr/lib/systemd/system/ydotool.service 2>&1 || true
fi

# Pre-enable both user services for every user. `systemctl --global` writes to
# /usr/lib/systemd/user/*.target.wants/ and therefore also applies to users who
# do not exist yet at build time - so also to an existing account after an
# rpm-ostree rebase.
systemctl --global enable ydotool.service || true
systemctl --global enable bazz-hypr-firstrun.service

# bluetooth is assumed by illogical-impulse (Bluetooth panel).
systemctl enable bluetooth.service || true

echo ">>> enabled user units:"
ls -l /usr/lib/systemd/user/default.target.wants/ 2>&1 || true
