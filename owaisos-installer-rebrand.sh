#!/bin/bash
# OwaisOS installer / live-session rebrand — run inside the Cubic chroot as root,
# AFTER owaisos-customize.sh.
# Mint 22.3 still uses Ubiquity (the LMDE installer arrives with Mint 23).
# Every step is guarded: missing files are skipped and reported, nothing is guessed.
set -uo pipefail

NAME="OwaisOS"
OLD="Linux Mint"

say() { echo "[rebrand] $*"; }

# ---------- 1) Live session identity (casper) ----------
if [ -f /etc/casper.conf ]; then
  sed -i "s|^export USERNAME=.*|export USERNAME=\"owais\"|"            /etc/casper.conf
  sed -i "s|^export USERFULLNAME=.*|export USERFULLNAME=\"$NAME Live\"|" /etc/casper.conf
  sed -i "s|^export HOST=.*|export HOST=\"owaisos\"|"                  /etc/casper.conf
  say "casper.conf updated (live user: owais, host: owaisos)"
else
  say "no /etc/casper.conf found, skipped"
fi

# ---------- 2) "Install Linux Mint" launcher ----------
for f in /usr/share/applications/ubiquity*.desktop /usr/share/ubiquity/*.desktop; do
  [ -f "$f" ] || continue
  sed -i "s/$OLD/$NAME/g" "$f"
  say "launcher rebranded: $f"
done

# ---------- 3) Installer slideshow text ----------
for d in /usr/share/ubiquity-slideshow /usr/share/ubiquity/slideshow; do
  [ -d "$d" ] || continue
  find "$d" -type f \( -name '*.html' -o -name '*.js' -o -name '*.css' -o -name '*.txt' -o -name '*.json' \) \
    -exec sed -i "s/$OLD/$NAME/g" {} +
  say "slideshow text rebranded in $d"
done

# ---------- 4) Mint Welcome screen: do not auto-start (it is Mint-branded) ----------
mkdir -p /etc/skel/.config/autostart
cat > /etc/skel/.config/autostart/mintwelcome.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Welcome Screen
Hidden=true
EOF
say "Mint Welcome disabled at first login"

# NOTE: /etc/linuxmint/info is intentionally NOT modified: Mint's update and
# upgrade tools read EDITION/RELEASE from it.

# ---------- 5) Report what still says "Linux Mint" ----------
say "Remaining mentions (review manually; ignore docs, licenses, translations):"
grep -rIl "$OLD" /usr/share/applications /usr/share/ubiquity* /etc 2>/dev/null \
  | grep -v -E '/doc/|/locale/|/common-licenses/|\.po$' | sort -u | head -50

say "Done. Image files (logos in the slideshow, wallpapers) are not touched by this script."
