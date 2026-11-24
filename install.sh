#!/usr/bin/env bash
# Kuro Plymouth theme — installer
# Copyright (C) 2026 Pascal — GPL-2.0-or-later, see LICENSE
#
# Installs the Kuro Plymouth theme.
#   sudo ./install.sh          -> variant "cat"  (#161616 background, like the KDE splash)
#   sudo ./install.sh --oled   -> variant "oled" (pure black)
# Only the chosen variant is copied, to keep the initramfs small.
set -euo pipefail

variant="cat"
[[ "${1:-}" == "--oled" ]] && variant="oled"

src="$(cd "$(dirname "$0")" && pwd)/kuro"
dest="/usr/share/plymouth/themes/kuro"

[[ $EUID -eq 0 ]] || { echo "Please run with sudo." >&2; exit 1; }
[[ -f "$src/kuro.script" ]] || { echo "Theme folder not found: $src" >&2; exit 1; }

install -d "$dest/frames"
install -m 644 "$src/kuro.plymouth" "$src/spinner.png" "$src/bullet.png" "$dest/"
install -m 644 "$src"/frames/"$variant"-*.png "$dest/frames/"
sed "s/^variant *= *\"[a-z]*\";/variant        = \"$variant\";/" "$src/kuro.script" > "$dest/kuro.script"
chmod 644 "$dest/kuro.script"

echo "Installed: $dest (variant: $variant)"
echo "Activate:  plymouth-set-default-theme -R kuro"
