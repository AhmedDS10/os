#!/bin/bash
# OwaisOS customization — run inside the Cubic chroot terminal as root.
# Base: Linux Mint 22.3 Cinnamon (Ubuntu 24.04 "noble").
set -euo pipefail

NAME="OwaisOS"
VERSION="1.0"
export DEBIAN_FRONTEND=noninteractive

# ---------- 1) Identity ----------
cat > /etc/os-release <<EOF
NAME="$NAME"
VERSION="$VERSION"
ID=owaisos
ID_LIKE="ubuntu debian"
PRETTY_NAME="$NAME $VERSION"
VERSION_ID="$VERSION"
HOME_URL=""
SUPPORT_URL=""
BUG_REPORT_URL=""
UBUNTU_CODENAME=noble
EOF

# Keep lsb_release working for third-party installers
cat > /etc/lsb-release <<EOF
DISTRIB_ID=$NAME
DISTRIB_RELEASE=$VERSION
DISTRIB_CODENAME=noble
DISTRIB_DESCRIPTION="$NAME $VERSION"
EOF

echo "$NAME $VERSION \\n \\l" > /etc/issue
echo "$NAME $VERSION" > /etc/issue.net

# ---------- 2) Wallpaper (place your image next to this script first) ----------
# cp /root/owaisos-wallpaper.jpg /usr/share/backgrounds/owaisos.jpg
mkdir -p /usr/share/glib-2.0/schemas
cat > /usr/share/glib-2.0/schemas/90_owaisos.gschema.override <<'EOF'
[org.cinnamon.desktop.background]
# picture-uri='file:///usr/share/backgrounds/owaisos.jpg'
picture-options='zoom'
EOF

# ---------- 3) Defaults for new users ----------
mkdir -p /etc/skel
# Put dotfiles / dconf / Cinnamon settings you want for every new user here.

# ---------- 4) Packages ----------
apt-get update

# Office suite (LibreOffice ships with Mint; make sure the full suite + Arabic is present)
apt-get install -y libreoffice libreoffice-writer libreoffice-calc \
  libreoffice-impress libreoffice-draw libreoffice-base \
  libreoffice-l10n-ar libreoffice-help-ar hunspell-ar \
  libreoffice-gtk3

# Arabic fonts and general fonts
apt-get install -y fonts-noto-core fonts-noto-ui-core fonts-hosny-amiri \
  fonts-kacst fonts-liberation2 fonts-crosextra-carlito fonts-crosextra-caladea

# Daily-use apps (trim this list to taste)
apt-get install -y vlc gimp keepassxc xournalpp

# apt-get purge -y <packages to remove>
apt-get autoremove -y

# ---------- 4b) Wolf-head logo ----------
# Put your logo (SVG preferred) at /root/owaisos-logo.svg before running.
LOGO=/root/owaisos-logo.svg
if [ -f "$LOGO" ]; then
  apt-get install -y librsvg2-bin plymouth plymouth-themes

  # System icon + PNG renditions
  install -D "$LOGO" /usr/share/icons/hicolor/scalable/apps/owaisos-logo.svg
  install -D "$LOGO" /usr/share/pixmaps/owaisos-logo.svg
  for s in 48 64 128 256 512; do
    mkdir -p /usr/share/icons/hicolor/${s}x${s}/apps
    rsvg-convert -w $s -h $s "$LOGO" -o /usr/share/icons/hicolor/${s}x${s}/apps/owaisos-logo.png
  done
  rsvg-convert -w 256 -h 256 "$LOGO" -o /usr/share/pixmaps/owaisos-logo.png
  gtk-update-icon-cache -f /usr/share/icons/hicolor || true

  # --- Login screen (LightDM Slick Greeter) ---
  mkdir -p /etc/lightdm
  CONF=/etc/lightdm/slick-greeter.conf
  touch "$CONF"
  grep -q '^\[Greeter\]' "$CONF" || echo '[Greeter]' >> "$CONF"
  sed -i '/^logo=/d;/^other-monitors-logo=/d' "$CONF"
  sed -i '/^\[Greeter\]/a logo=/usr/share/pixmaps/owaisos-logo.png\nother-monitors-logo=/usr/share/pixmaps/owaisos-logo.png' "$CONF"

  # --- Boot splash (Plymouth, script theme) ---
  T=/usr/share/plymouth/themes/owaisos
  mkdir -p "$T"
  rsvg-convert -w 256 -h 256 "$LOGO" -o "$T/logo.png"
  cat > "$T/owaisos.plymouth" <<EOF
[Plymouth Theme]
Name=$NAME
Description=$NAME boot splash
ModuleName=script

[script]
ImageDir=$T
ScriptFile=$T/owaisos.script
EOF
  cat > "$T/owaisos.script" <<'EOF'
Window.SetBackgroundTopColor(0.086, 0.137, 0.227);
Window.SetBackgroundBottomColor(0.039, 0.071, 0.125);
logo.image = Image("logo.png");
logo.sprite = Sprite(logo.image);
logo.sprite.SetX(Window.GetX() + Window.GetWidth()  / 2 - logo.image.GetWidth()  / 2);
logo.sprite.SetY(Window.GetY() + Window.GetHeight() / 2 - logo.image.GetHeight() / 2);
EOF
  update-alternatives --install /usr/share/plymouth/themes/default.plymouth \
    default.plymouth "$T/owaisos.plymouth" 200
  update-alternatives --set default.plymouth "$T/owaisos.plymouth"
  update-initramfs -u || true

  # --- Cinnamon menu button icon (default for new users / live session) ---
  S=/usr/share/cinnamon/applets/menu@cinnamon.org/settings-schema.json
  if [ -f "$S" ]; then
    python3 - "$S" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
if "menu-icon" in d:
    d["menu-icon"]["default"] = "owaisos-logo"
    json.dump(d, open(p, "w"), indent=4)
    print("menu icon default set")
else:
    print("menu-icon key not found: set the icon manually in the menu applet settings")
PY
  fi
else
  echo "WARNING: $LOGO not found, skipping logo installation"
fi

# ---------- 5) Finish ----------
glib-compile-schemas /usr/share/glib-2.0/schemas
apt-get clean
rm -rf /tmp/* /var/lib/apt/lists/*
echo "Done. Continue in Cubic -> Next."
