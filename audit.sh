#!/usr/bin/env bash
# =============================================================================
# audit.sh — повторная проверка системы после переустановки.
# Только чтение: ничего не копирует, не устанавливает и не меняет.
#
# Использование:
#   ./audit.sh              отчёт в терминал
#   ./audit.sh --write      дополнительно сохранить audit-report-<дата>.md
#   ./audit.sh --no-checksum  не сверять хеши файлов (быстрее)
#
# Код возврата: 0 — всё на месте, 1 — есть расхождения.
# =============================================================================
set -uo pipefail

BACKUP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WRITE=0
DO_SUM=1
PROBLEMS=0
REPORT="$(mktemp)"

while [ $# -gt 0 ]; do
  case "$1" in
    --write)       WRITE=1 ;;
    --no-checksum) DO_SUM=0 ;;
    -h|--help)     sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Неизвестный аргумент: $1"; exit 2 ;;
  esac
  shift
done

h() { printf '\n## %s\n\n' "$*" | tee -a "$REPORT"; }
line() { printf '%s\n' "$*" | tee -a "$REPORT"; }
bad() { printf '  [!] %s\n' "$*" | tee -a "$REPORT"; PROBLEMS=$((PROBLEMS+1)); }
good() { printf '  [ok] %s\n' "$*" | tee -a "$REPORT"; }

printf '# Аудит системы %s\n\nДата: %s\n\n' "$(cat /etc/hostname 2>/dev/null || uname -n)" "$(date -Is)" | tee -a "$REPORT"

# ------------------------------------------------------------------ система
h "Система"
line "- ОС: $(grep -m1 PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '\"')"
line "- Ядро: $(uname -r)"
line "- Сессия: ${XDG_SESSION_TYPE:-?} / ${XDG_CURRENT_DESKTOP:-?}"
if command -v hyprctl >/dev/null 2>&1; then
  line "- Hyprland: $(hyprctl version 2>/dev/null | head -1)"
else
  bad "hyprctl не найден — Hyprland не установлен?"
fi

# ------------------------------------------------------------------ пакеты
h "Пакеты"
cur_all="$(mktemp)"; cur_exp="$(mktemp)"; cur_aur="$(mktemp)"
pacman -Qq 2>/dev/null | sort > "$cur_all"
pacman -Qqen 2>/dev/null | sort > "$cur_exp"
pacman -Qqem 2>/dev/null | sort > "$cur_aur"

if [ -f "$BACKUP_DIR/packages/all.txt" ]; then
  miss_pkg="$(comm -23 <(sort "$BACKUP_DIR/packages/all.txt") "$cur_all")"
  extra_pkg="$(comm -13 <(sort "$BACKUP_DIR/packages/all.txt") "$cur_all")"
  line "- Всего пакетов: $(wc -l < "$cur_all") (в копии: $(wc -l < "$BACKUP_DIR/packages/all.txt"))"
  if [ -z "$miss_pkg" ]; then good "все пакеты из копии установлены"
  else bad "не установлены ($(printf '%s\n' "$miss_pkg" | wc -l)): $(printf '%s ' $miss_pkg | cut -c1-300)"; fi
  line "- Лишних (нет в копии): $(printf '%s\n' "$extra_pkg" | sed '/^$/d' | wc -l)"
else
  bad "packages/all.txt отсутствует"
fi

if [ -f "$BACKUP_DIR/packages/explicit.txt" ]; then
  miss_exp="$(comm -23 <(sort "$BACKUP_DIR/packages/explicit.txt") "$cur_exp")"
  if [ -z "$miss_exp" ]; then good "явно установленные пакеты совпадают"
  else bad "не хватает явных пакетов: $(printf '%s ' $miss_exp | cut -c1-300)"; fi
fi

if [ -f "$BACKUP_DIR/packages/aur-explicit.txt" ] && [ -s "$BACKUP_DIR/packages/aur-explicit.txt" ]; then
  miss_aur="$(comm -23 <(sort "$BACKUP_DIR/packages/aur-explicit.txt") "$cur_aur")"
  if [ -z "$miss_aur" ]; then good "AUR-пакеты совпадают"
  else bad "не хватает AUR: $(printf '%s ' $miss_aur | cut -c1-300)"; fi
fi

# ------------------------------------------------------------------ конфиги
h "Конфигурации"
cfg_missing=0; cfg_diff=0; cfg_ok=0

# home/ -> $HOME, gtk/ -> ~/.config/..., applications/ -> ~/.config/...
map_path() {
  local rel="$1"
  case "$rel" in
    home/*)         printf '%s\n' "$HOME/${rel#home/}" ;;
    gtk/gtk-3.0/*)  printf '%s\n' "$HOME/.config/${rel#gtk/}" ;;
    gtk/gtk-4.0/*)  printf '%s\n' "$HOME/.config/${rel#gtk/}" ;;
    gtk/xsettingsd/*) printf '%s\n' "$HOME/.config/${rel#gtk/}" ;;
    gtk/nwg-look/*) printf '%s\n' "$HOME/.config/${rel#gtk/}" ;;
    gtk/.gtkrc-2.0) printf '%s\n' "$HOME/.gtkrc-2.0" ;;
    applications/*) printf '%s\n' "$HOME/.config/${rel#applications/}" ;;
    *)              printf '%s\n' "" ;;
  esac
}

while IFS= read -r -d '' src; do
  rel="${src#"$BACKUP_DIR"/}"
  case "$rel" in applications/README.txt) continue ;; esac
  dst="$(map_path "$rel")"
  [ -z "$dst" ] && continue
  if [ ! -e "$dst" ]; then
    bad "нет файла: $dst"; cfg_missing=$((cfg_missing+1)); continue
  fi
  if [ "$DO_SUM" = 1 ]; then
    if cmp -s "$src" "$dst"; then cfg_ok=$((cfg_ok+1)); else printf '  [~] отличается: %s\n' "$dst" | tee -a "$REPORT"; cfg_diff=$((cfg_diff+1)); fi
  else
    cfg_ok=$((cfg_ok+1))
  fi
done < <(find "$BACKUP_DIR/home" "$BACKUP_DIR/gtk" "$BACKUP_DIR/applications" -type f -print0 2>/dev/null)

line ""
line "- Совпадает: $cfg_ok, отличается: $cfg_diff, отсутствует: $cfg_missing"
[ "$cfg_missing" -eq 0 ] && good "все файлы конфигурации на месте"

# ------------------------------------------------------------------ службы
h "Службы"
if [ -f "$BACKUP_DIR/services/enabled-units.txt" ]; then
  cur_en="$(mktemp)"
  systemctl list-unit-files --state=enabled --no-legend 2>/dev/null | awk '{print $1}' | sort > "$cur_en"
  miss_en="$(comm -23 <(sort "$BACKUP_DIR/services/enabled-units.txt") "$cur_en")"
  if [ -z "$miss_en" ]; then good "все сохранённые службы включены"
  else bad "не включены: $(printf '%s ' $miss_en)"; fi
else
  line "- services/enabled-units.txt отсутствует"
fi

# ------------------------------------------------------------------ /etc и загрузчик
h "Системные файлы"
if [ -f "$BACKUP_DIR/system/etc/default/grub" ]; then
  if cmp -s "$BACKUP_DIR/system/etc/default/grub" /etc/default/grub; then
    good "/etc/default/grub совпадает"
  else
    printf '  [~] /etc/default/grub отличается от копии\n' | tee -a "$REPORT"
  fi
fi
if [ -f "$BACKUP_DIR/system/etc/systemd/logind.conf.d/10-lid-suspend.conf" ]; then
  if cmp -s "$BACKUP_DIR/system/etc/systemd/logind.conf.d/10-lid-suspend.conf" \
            /etc/systemd/logind.conf.d/10-lid-suspend.conf 2>/dev/null; then
    good "настройка крышки (logind) на месте"
  else
    bad "нет /etc/systemd/logind.conf.d/10-lid-suspend.conf"
  fi
fi
line "- Загрузка: $( [ -d /sys/firmware/efi ] && echo UEFI || echo BIOS )"
[ -f /boot/grub/grub.cfg ] && good "GRUB найден (/boot/grub/grub.cfg)" || bad "GRUB не найден"

# ------------------------------------------------------------------ итог
h "Итог"
line "Проблем: $PROBLEMS"
if [ "$PROBLEMS" -eq 0 ]; then
  line "Система соответствует резервной копии."
else
  line "Есть расхождения — смотрите строки [!] и [~] выше."
fi

if [ "$WRITE" = 1 ]; then
  out="$BACKUP_DIR/audit-report-$(date +%Y%m%d-%H%M%S).md"
  if ! ( : > "$BACKUP_DIR/.write-test" ) 2>/dev/null; then
    out="${XDG_STATE_HOME:-$HOME/.local/state}/archbackup/audit-report-$(date +%Y%m%d-%H%M%S).md"
    mkdir -p "$(dirname -- "$out")" 2>/dev/null || out="${TMPDIR:-/tmp}/audit-report-$(date +%Y%m%d-%H%M%S).md"
  fi
  rm -f "$BACKUP_DIR/.write-test" 2>/dev/null || true
  cp "$REPORT" "$out"
  printf '\nОтчёт сохранён: %s\n' "$out"
fi
rm -f "$REPORT" "$cur_all" "$cur_exp" "$cur_aur" "${cur_en:-/dev/null}" 2>/dev/null
[ "$PROBLEMS" -eq 0 ] || exit 1
