#!/bin/bash
# OwaisOS installer images — run inside the Cubic chroot as root,
# AFTER owaisos-customize.sh and owaisos-installer-rebrand.sh.
# Needs /root/owaisos-logo.svg and rsvg-convert (installed by owaisos-customize.sh).
#
# What it does:
#   1) renders 4 branded slides (800x450) from SVG templates
#   2) replaces Mint logo-like images in the installer with the wolf logo
#   3) replaces the large slideshow images with the branded slides, at the same size
# Mint's slideshow layout is not documented, so every replaced file is printed.
# Nothing is backed up inside the image (it would ship in the ISO); to undo,
# rebuild from the original ISO in Cubic.
set -uo pipefail

NAME="OwaisOS"
LOGO="${LOGO:-/root/owaisos-logo.svg}"
WORK="${WORK:-/tmp/owaisos-slides}"
OUT="${OUT:-/usr/share/owaisos/installer-slides}"
BG1="#16233a"; BG2="#0a1220"; ACC1="#5eead4"; ACC2="#3b82f6"

say() { echo "[images] $*"; }
[ -f "$LOGO" ] || { say "ERROR: $LOGO not found"; exit 1; }
command -v rsvg-convert >/dev/null || { say "ERROR: rsvg-convert missing (apt install librsvg2-bin)"; exit 1; }

mkdir -p "$WORK" "$OUT"
rsvg-convert -w 512 -h 512 "$LOGO" -o "$WORK/logo.png"

# ---------- 1) Slides ----------
# mkslide <n> <english title> <english subtitle> <arabic title> <arabic subtitle>
mkslide() {
cat > "$WORK/slide$1.svg" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 800 450" width="800" height="450">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="$BG1"/><stop offset="1" stop-color="$BG2"/>
    </linearGradient>
    <linearGradient id="ac" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="$ACC1"/><stop offset="1" stop-color="$ACC2"/>
    </linearGradient>
  </defs>
  <rect width="800" height="450" fill="url(#bg)"/>
  <polygon points="800,0 800,450 560,450" fill="#ffffff" opacity="0.03"/>
  <polygon points="800,0 650,0 800,200" fill="#ffffff" opacity="0.04"/>
  <image xlink:href="logo.png" x="50" y="105" width="220" height="220"/>
  <rect x="300" y="150" width="90" height="5" rx="2" fill="url(#ac)"/>
  <text x="300" y="215" font-family="'Noto Sans','DejaVu Sans',sans-serif" font-size="38" font-weight="700" fill="#f1f5f9">$2</text>
  <text x="300" y="252" font-family="'Noto Sans','DejaVu Sans',sans-serif" font-size="20" fill="#b6c2d4">$3</text>
  <text x="300" y="315" font-family="'Amiri','Noto Naskh Arabic','DejaVu Sans',sans-serif" font-size="36" fill="#f1f5f9">$4</text>
  <text x="300" y="352" font-family="'Amiri','Noto Naskh Arabic','DejaVu Sans',sans-serif" font-size="22" fill="#b6c2d4">$5</text>
  <text x="400" y="425" text-anchor="middle" font-family="'Noto Sans','DejaVu Sans',sans-serif" font-size="14" letter-spacing="4" fill="$ACC1">$NAME</text>
</svg>
EOF
rsvg-convert -w 800 -h 450 "$WORK/slide$1.svg" -o "$WORK/slide$1.png"
}

mkslide 1 "Welcome to $NAME" "Installing takes a few minutes" "مرحبًا بك في نظامك الجديد" "التثبيت يستغرق دقائق قليلة"
mkslide 2 "Ready for everyday work" "Writer, Calc and Impress included" "جاهز لعملك اليومي" "حزمة المكتب مثبّتة ومعها كل ما تحتاجه"
mkslide 3 "Built for Arabic and English" "Fonts, spell-check and RTL support" "دعم كامل للعربية والإنجليزية" "خطوط ومدقق إملائي واتجاه من اليمين لليسار"
mkslide 4 "Stable, fast and yours" "A reliable base with your identity" "مستقر وسريع وبهويتك" "أساس موثوق وتجربة تحمل اسمك"

cp "$WORK"/slide*.png "$WORK/logo.png" "$OUT"/
say "slides saved in $OUT"

# ---------- helpers ----------
dims() { # prints "W H" of a png/jpg using file(1)
  file -b "$1" | sed -n 's/.*[ ,]\([0-9]\+\) *x *\([0-9]\+\).*/\1 \2/p' | head -1
}

# ---------- 2) Logos ----------
count_logo=0
for d in /usr/share/ubiquity /usr/share/ubiquity-slideshow /usr/share/pixmaps; do
  [ -d "$d" ] || continue
  while IFS= read -r f; do
    base=$(basename "$f" | tr 'A-Z' 'a-z')
    case "$d" in /usr/share/pixmaps) echo "$base" | grep -q 'mint' || continue ;; esac
    echo "$base" | grep -Eq 'mint|logo|distro|brand' || continue
    case "$f" in
      *.svg) cp "$LOGO" "$f"; say "logo svg replaced: $f"; count_logo=$((count_logo+1)) ;;
      *.png|*.jpg|*.jpeg)
        read -r w h <<<"$(dims "$f")"
        [ -n "${w:-}" ] || continue
        s=$(( w < h ? w : h ))
        # square logo centred on a transparent canvas of the original size
        rsvg-convert -w "$s" -h "$s" "$LOGO" -o /tmp/owaisos-logo-$$.png
        if command -v convert >/dev/null; then
          convert -size ${w}x${h} xc:none /tmp/owaisos-logo-$$.png -gravity center -composite "$f"
        else
          rsvg-convert -w "$w" -h "$h" "$LOGO" -o "$f"
        fi
        say "logo replaced (${w}x${h}): $f"; count_logo=$((count_logo+1)) ;;
    esac
  done < <(find "$d" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.svg' \) 2>/dev/null)
done
rm -f /tmp/owaisos-logo-$$.png

# ---------- 3) Slideshow pictures ----------
count_slide=0; i=0
SL=$(find /usr/share/ubiquity-slideshow -type d -name slides 2>/dev/null | head -1)
if [ -n "$SL" ]; then
  while IFS= read -r f; do
    base=$(basename "$f" | tr 'A-Z' 'a-z')
    echo "$base" | grep -Eq 'mint|logo|distro|brand|icon|arrow|bullet' && continue
    read -r w h <<<"$(dims "$f")"
    [ -n "${w:-}" ] && [ "$w" -ge 400 ] && [ "$h" -ge 200 ] || continue
    n=$(( i % 4 + 1 )); i=$((i+1))
    rsvg-convert -w "$w" -h "$h" -b "$BG2" "$WORK/slide$n.svg" -o "$f"
    say "slide image replaced (${w}x${h}) with slide$n: $f"
    count_slide=$((count_slide+1))
  done < <(find "$SL" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) | sort)
else
  say "no ubiquity-slideshow 'slides' folder found; slides are in $OUT for manual use"
fi

say "done: $count_logo logo file(s), $count_slide slide image(s) replaced"
say "Check the ISO in a VM: if a slide looks wrong, rebuild and adjust the filters above."
rm -rf "$WORK"
