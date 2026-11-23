#!/usr/bin/env bash
# =============================================================================
# restore.sh — восстановление конфигурации Arch Linux + Hyprland
#
# Использование:
#   ./restore.sh --dry-run                     показать план без изменений
#   ./restore.sh --mode configs                конфиги в $HOME
#   ./restore.sh --mode services --yes         включить системные службы
#   ./restore.sh --mode packages --yes         установить пакеты (pacman + yay)
#   ./restore.sh --mode system                 напечатать, что будет сделано
#   ./restore.sh --mode system --yes           применить: fstab с реальными UUID,
#                                              /etc, hostname, grub-mkconfig, mkinitcpio
#   ./restore.sh --mode system --yes --hostname zephyrus
#   ./restore.sh --mode apps                   инструкции для приложений вручную
#   ./restore.sh --mode all                    configs + services (+ packages с --yes)
#
# Безопасность:
#   * ничего не удаляет;
#   * перед перезаписью существующего файла делает копию .bak-<дата>;
#   * /etc и /boot меняются только с флагом --yes;
#   * UUID в fstab подставляются автоматически: blkid + findmnt по точкам монтирования;
#   * grub.cfg не копируется, а пересобирается grub-mkconfig;
#   * при --mode packages установка идёт только с флагом --yes.
# =============================================================================
set -uo pipefail

BACKUP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET_HOME="${TARGET_HOME:-$HOME}"
STAMP="$(date +%Y%m%d-%H%M%S)"
# Каталог для лога: рядом с копией, если он доступен на запись,
# иначе ~/.local/state (копия может лежать на read-only носителе).
LOG_DIR="$BACKUP_DIR"
if ! ( : > "$BACKUP_DIR/.write-test" ) 2>/dev/null; then
  LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/archbackup"
  mkdir -p "$LOG_DIR" 2>/dev/null || LOG_DIR="${TMPDIR:-/tmp}"
fi
rm -f "$BACKUP_DIR/.write-test" 2>/dev/null || true
LOG="$LOG_DIR/restore-log-$STAMP.txt"

MODE="all"
DRY=0
ASSUME_YES=0
NEW_HOSTNAME=""
ERRORS=0

usage() {
  cat <<'EOF'
restore.sh — восстановление конфигурации Arch Linux + Hyprland

  --dry-run              показать, что будет сделано, ничего не меняя
  --mode <режим>         configs | services | packages | system | apps | all
  --hostname <имя>       задать hostname (без флага hostname не меняется)
  --yes, -y              выполнять изменения (иначе только печать команд)
  --backup-dir <путь>    каталог резервной копии
  -h, --help             эта справка

Примеры:
  ./restore.sh --mode configs
  ./restore.sh --mode services --yes
  ./restore.sh --mode system --yes --hostname zephyrus
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)      DRY=1 ;;
    --mode)         MODE="${2:-}"; shift ;;
    --yes|-y)       ASSUME_YES=1 ;;
    --backup-dir)   BACKUP_DIR="${2:-}"; shift ;;
    --hostname)     NEW_HOSTNAME="${2:-}"; shift ;;
    -h|--help)      usage; exit 0 ;;
    *) echo "Неизвестный аргумент: $1"; usage; exit 2 ;;
  esac
  shift
done

case "$MODE" in
  packages|configs|services|apps|system|all) ;;
  *) echo "Неверный --mode: $MODE (packages|configs|services|apps|system|all)"; exit 2 ;;
esac

if [ -n "$NEW_HOSTNAME" ] && ! printf '%s' "$NEW_HOSTNAME" | grep -qE '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$'; then
  echo "Недопустимый hostname: $NEW_HOSTNAME (a-z, 0-9, дефис; до 63 символов)"
  exit 2
fi

# ------------------------------------------------------------------ вывод
log()  { printf '%s\n' "$*" >> "$LOG" 2>/dev/null || true; }
say()  { printf '%s\n' "$*"; log "$*"; }
head1(){ printf '\n=== %s ===\n' "$*"; log ""; log "=== $* ==="; }
warn() { printf '  [!] %s\n' "$*"; log "  [!] $*"; }
ok()   { printf '  [ok] %s\n' "$*"; log "  [ok] $*"; }
skip() { printf '  [-] %s\n' "$*"; log "  [-] $*"; }
err()  { printf '  [ОШИБКА] %s\n' "$*"; log "  [ОШИБКА] $*"; ERRORS=$((ERRORS+1)); }

say "Резервная копия: $BACKUP_DIR"
say "Целевой HOME:   $TARGET_HOME"
say "Режим:          $MODE$( [ "$DRY" = 1 ] && echo ' (dry-run)' )"
say "Лог:            $LOG"

# ------------------------------------------------------------ проверка копии
verify_checksums() {
  head1 "Проверка контрольных сумм"
  if [ ! -f "$BACKUP_DIR/checksums.sha256" ]; then
    warn "checksums.sha256 отсутствует — пропускаю"
    return
  fi
  if ( cd "$BACKUP_DIR" && sha256sum -c --quiet checksums.sha256 ) 2>/dev/null; then
    ok "все контрольные суммы сходятся"
  else
    warn "есть расхождения или отсутствующие файлы — подробности:"
    ( cd "$BACKUP_DIR" && sha256sum -c checksums.sha256 2>&1 | grep -v ': OK$' ) | sed 's/^/    /'
    ERRORS=$((ERRORS+1))
  fi
}

# ------------------------------------------------------------------ копирование
# safe_copy_file <src> <dst>
safe_copy_file() {
  local src="$1" dst="$2"
  if [ ! -e "$src" ]; then
    warn "в копии нет: ${src#"$BACKUP_DIR"/}"
    return
  fi
  if [ -e "$dst" ] && cmp -s "$src" "$dst"; then
    skip "без изменений: $dst"
    return
  fi
  say "  + $dst"
  [ "$DRY" = 1 ] && return 0
  mkdir -p "$(dirname -- "$dst")" || { err "не создать каталог для $dst"; return; }
  if [ -e "$dst" ]; then
    cp -a -- "$dst" "$dst.bak-$STAMP" && log "    прежняя версия: $dst.bak-$STAMP"
  fi
  if cp -a -- "$src" "$dst"; then ok "записан: $dst"; else err "не удалось записать: $dst"; fi
}

# safe_copy_dir <srcdir> <dstdir>
safe_copy_dir() {
  local src="$1" dst="$2"
  [ -d "$src" ] || { warn "в копии нет каталога: ${src#"$BACKUP_DIR"/}"; return; }
  say "  + $dst/ (каталог)"
  [ "$DRY" = 1 ] && return 0
  mkdir -p "$dst" || { err "не создать $dst"; return; }
  if cp -a -- "$src/." "$dst/"; then ok "восстановлен: $dst/"; else err "ошибка каталога: $dst/"; fi
}

restore_configs() {
  head1 "Конфигурации в \$HOME"
  local h="$TARGET_HOME"

  # 1. home/ — зеркало домашнего каталога
  if [ -d "$BACKUP_DIR/home" ]; then
    local rel
    while IFS= read -r -d '' rel; do
      rel="${rel#"$BACKUP_DIR/home/"}"
      safe_copy_file "$BACKUP_DIR/home/$rel" "$h/$rel"
    done < <(find "$BACKUP_DIR/home" -type f -print0 2>/dev/null)
  fi

  # 2. gtk/ — раскладывается по своим местам
  [ -d "$BACKUP_DIR/gtk/gtk-3.0" ] && safe_copy_dir "$BACKUP_DIR/gtk/gtk-3.0" "$h/.config/gtk-3.0"
  [ -d "$BACKUP_DIR/gtk/gtk-4.0" ] && safe_copy_dir "$BACKUP_DIR/gtk/gtk-4.0" "$h/.config/gtk-4.0"
  [ -d "$BACKUP_DIR/gtk/xsettingsd" ] && safe_copy_dir "$BACKUP_DIR/gtk/xsettingsd" "$h/.config/xsettingsd"
  [ -d "$BACKUP_DIR/gtk/nwg-look" ] && safe_copy_dir "$BACKUP_DIR/gtk/nwg-look" "$h/.config/nwg-look"
  [ -f "$BACKUP_DIR/gtk/.gtkrc-2.0" ] && safe_copy_file "$BACKUP_DIR/gtk/.gtkrc-2.0" "$h/.gtkrc-2.0"

  # 3. applications/ — конфиги приложений
  [ -f "$BACKUP_DIR/applications/PortProton.conf" ] && \
    safe_copy_file "$BACKUP_DIR/applications/PortProton.conf" "$h/.config/PortProton.conf"
  [ -d "$BACKUP_DIR/applications/Gaijin" ] && \
    safe_copy_dir "$BACKUP_DIR/applications/Gaijin" "$h/.config/Gaijin"

  # 4. Пустые каталоги fish, которые не переносятся копированием файлов
  [ "$DRY" = 0 ] && mkdir -p "$h/.config/fish/functions" "$h/.config/fish/completions" "$h/.config/fish/conf.d" 2>/dev/null

  # 5. Права на чувствительные файлы
  [ "$DRY" = 0 ] && chmod 700 "$h/.config/fish" 2>/dev/null
  [ "$DRY" = 0 ] && chmod 600 "$h/.config/fish/fish_variables" 2>/dev/null
}

restore_services() {
  head1 "Системные службы"
  local f="$BACKUP_DIR/services/enabled-units.txt"
  if [ ! -f "$f" ]; then warn "нет services/enabled-units.txt — пропускаю"; return; fi

  local u
  while IFS= read -r u; do
    [ -z "$u" ] && continue
    case "$u" in \#*) continue ;; esac
    if systemctl is-enabled "$u" >/dev/null 2>&1; then
      skip "уже включена: $u"
    else
      say "  sudo systemctl enable --now $u"
      if [ "$DRY" = 0 ] && [ "$ASSUME_YES" = 1 ]; then
        if sudo systemctl enable --now "$u"; then ok "включена: $u"; else err "не включилась: $u"; fi
      fi
    fi
  done < "$f"

  if [ -d "$TARGET_HOME/.config/systemd/user" ] && [ -n "$(ls -A "$TARGET_HOME/.config/systemd/user" 2>/dev/null)" ]; then
    say "  пользовательские юниты: systemctl --user daemon-reload; systemctl --user enable --now <unit>"
  else
    skip "пользовательских юнитов нет (в копии их тоже нет)"
  fi
}

restore_packages() {
  head1 "Пакеты"
  if [ ! -f "$BACKUP_DIR/packages/explicit.txt" ]; then warn "нет packages/explicit.txt"; return; fi

  say "Официальные пакеты (${#}): всего $(wc -l < "$BACKUP_DIR/packages/explicit.txt")"
  say "  sudo pacman -S --needed - < \"$BACKUP_DIR/packages/explicit.txt\""

  if [ -s "$BACKUP_DIR/packages/aur-explicit.txt" ]; then
    say "AUR-пакеты ($(wc -l < "$BACKUP_DIR/packages/aur-explicit.txt")):"
    say "  yay -S --needed - < \"$BACKUP_DIR/packages/aur-explicit.txt\""
  fi

  if grep -q 'не установлен' "$BACKUP_DIR/packages/flatpak.txt" 2>/dev/null; then
    skip "Flatpak в системе не использовался"
  fi

  if [ "$DRY" = 1 ]; then
    say "  (dry-run: установка не выполняется)"
    return
  fi
  if [ "$ASSUME_YES" != 1 ]; then
    say "  Установка не запущена: добавьте --yes, чтобы выполнить."
    return
  fi

  sudo pacman -S --needed - < "$BACKUP_DIR/packages/explicit.txt" || err "pacman завершился с ошибкой"
  if command -v yay >/dev/null 2>&1 && [ -s "$BACKUP_DIR/packages/aur-explicit.txt" ]; then
    yay -S --needed - < "$BACKUP_DIR/packages/aur-explicit.txt" || err "yay завершился с ошибкой"
  elif [ -s "$BACKUP_DIR/packages/aur-explicit.txt" ]; then
    warn "yay не установлен — AUR-пакеты пропущены"
  fi
}

# Устройство, на котором смонтирована точка (без суффикса [/subvol]).
dev_for_mount() {
  local mnt="$1" d=""
  d="$(findmnt -no SOURCE --target "$mnt" 2>/dev/null | head -1)"
  if [ -z "$d" ] && [ -r /proc/mounts ]; then
    d="$(awk -v m="$mnt" '$2==m {print $1; exit}' /proc/mounts 2>/dev/null)"
  fi
  printf '%s' "${d%%\[*}"
}

# UUID раздела: blkid, затем lsblk (в том числе по имени ядра).
uuid_of() {
  local dev="$1" u=""
  [ -z "$dev" ] && return 0
  u="$(blkid -s UUID -o value "$dev" 2>/dev/null)"
  [ -n "$u" ] || u="$(lsblk -no UUID "$dev" 2>/dev/null | head -1)"
  if [ -z "$u" ]; then
    u="$(lsblk -lno NAME,UUID 2>/dev/null | awk -v n="$(basename "$dev")" '$1==n {print $2; exit}')"
  fi
  printf '%s' "$u"
}

# Подставляет реальные UUID в fstab по точкам монтирования.
gen_fstab() {
  local out="$1" src="$BACKUP_DIR/system/etc/fstab"
  local line spec mnt fstype opts dump pass dev uuid
  : > "$out"
  while IFS= read -r line; do
    case "$line" in
      ''|\#*) printf '%s\n' "$line" >> "$out"; continue ;;
    esac
    read -r spec mnt fstype opts dump pass <<< "$line"
    if [ "${spec#UUID=}" != "$spec" ]; then
      dev="$(dev_for_mount "$mnt")"
      if [ -z "$dev" ]; then
        warn "$mnt: точка монтирования не найдена — оставляю плейсхолдер"
      else
        uuid="$(uuid_of "$dev")"
        if [ -n "$uuid" ]; then
          say "    $mnt: $spec -> UUID=$uuid ($dev)"
          spec="UUID=$uuid"
        else
          warn "$mnt: не удалось определить UUID для $dev"
        fi
      fi
    fi
    printf '%s\t%s\t%s\t%s\t%s %s\n' "$spec" "$mnt" "$fstype" "$opts" "$dump" "$pass" >> "$out"
  done < "$src"
}

# Копирует файл в /etc (с резервной копией) либо печатает команду.
install_etc() {
  local src="$1" dst="$2"
  say "  sudo cp -a \"$src\" \"$dst\""
  [ "$DRY" = 1 ] && return 0
  [ "$ASSUME_YES" = 1 ] || return 0
  sudo mkdir -p "$(dirname -- "$dst")" 2>/dev/null || true
  [ -e "$dst" ] && sudo cp -a "$dst" "$dst.bak-$STAMP" 2>/dev/null
  if sudo cp -a "$src" "$dst"; then ok "обновлён: $dst"; else err "не удалось: $dst"; fi
}

set_hostname() {
  local name="$1"
  say "  hostname -> $name (/etc/hostname и /etc/hosts)"
  [ "$DRY" = 1 ] && return 0
  [ "$ASSUME_YES" = 1 ] || return 0
  [ -e /etc/hostname ] && sudo cp -a /etc/hostname "/etc/hostname.bak-$STAMP" 2>/dev/null
  if ! printf '%s\n' "$name" | sudo tee /etc/hostname >/dev/null; then
    err "не записался /etc/hostname"; return
  fi
  if grep -q '^127\.0\.1\.1' /etc/hosts 2>/dev/null; then
    sudo sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$name/" /etc/hosts || warn "не поправился /etc/hosts"
  else
    printf '127.0.1.1\t%s\n' "$name" | sudo tee -a /etc/hosts >/dev/null || warn "не дописался /etc/hosts"
  fi
  ok "hostname: $name"
}

restore_system() {
  head1 "Системные файлы (/etc, /boot)"
  local root="$BACKUP_DIR/system/etc"
  if [ ! -d "$root" ]; then warn "каталог system/etc отсутствует"; return; fi

  if [ "$DRY" = 0 ] && [ "$ASSUME_YES" = 0 ]; then
    say "Показан план. Применить изменения: добавьте --yes."
  fi

  # 1. fstab с реальными UUID
  say ""
  say "1) fstab — реальные UUID текущих разделов"
  local genf="${TMPDIR:-/tmp}/fstab-restored-$STAMP"
  gen_fstab "$genf"
  say "   готовый файл: $genf"
  if [ "$DRY" = 0 ] && [ "$ASSUME_YES" = 1 ]; then
    [ -e /etc/fstab ] && sudo cp -a /etc/fstab "/etc/fstab.bak-$STAMP" 2>/dev/null
    if sudo cp "$genf" /etc/fstab; then ok "fstab записан"; else err "fstab не записался"; fi
  else
    say "   применить:   sudo cp \"$genf\" /etc/fstab"
  fi

  # 2. остальные файлы /etc (fstab/hostname/hosts — отдельно)
  say ""
  say "2) остальные файлы /etc"
  local rel
  while IFS= read -r -d '' rel; do
    rel="${rel#"$root/"}"
    case "$rel" in fstab|hostname|hosts) continue ;; esac
    install_etc "$root/$rel" "/etc/$rel"
  done < <(find "$root" -type f -print0 2>/dev/null | sort -z)

  # 3. hostname
  say ""
  say "3) hostname"
  if [ -n "$NEW_HOSTNAME" ]; then
    set_hostname "$NEW_HOSTNAME"
  else
    local old_host
    old_host="$(cat "$root/hostname" 2>/dev/null)"
    warn "hostname не задан (--hostname): /etc/hostname и /etc/hosts не меняются"
    [ -n "$old_host" ] && say "   в копии было: $old_host (обезличено)"
  fi

  # 4. загрузчик и initramfs
  say ""
  say "4) загрузчик и initramfs"
  say "   sudo grub-mkconfig -o /boot/grub/grub.cfg"
  say "   sudo mkinitcpio -P"
  say "   (system/boot/grub.cfg не копируется — он пересобирается)"
  if [ "$DRY" = 0 ] && [ "$ASSUME_YES" = 1 ]; then
    sudo grub-mkconfig -o /boot/grub/grub.cfg || err "grub-mkconfig завершился с ошибкой"
    sudo mkinitcpio -P || err "mkinitcpio -P завершился с ошибкой"
  fi

  say ""
  say "   sudo systemctl daemon-reload"
}

restore_apps() {
  head1 "Приложения, установленные вручную"
  say "PortProton.conf и Gaijin/ восстанавливаются в --mode configs."
  say ""
  say "Вручную после переустановки:"
  say "  1) PortProton: установить заново (pacman/yay), затем сверить ~/.config/PortProton.conf"
  say "  2) WarThunder: игра ставится заново; ярлык ~/.local/share/applications/warthunder.desktop"
  say "     указывает на ~/WarThunder/launcher"
  say "  3) Скрипты ~/.local/bin/* — уже восстановлены, но требуют зависимостей:"
  say "     grim, slurp, wl-clipboard, cliphist, blueman, rofi, swayosd, libnotify"
  say "  4) claude-code, claude-desktop, kvn-tui, vpn-manager, xray, sotavpn, hiddify, drkvl"
  say "     в копии отсутствуют по вашему решению — ставятся отдельно."
}

verify_checksums

case "$MODE" in
  configs)  restore_configs ;;
  services) restore_services ;;
  packages) restore_packages ;;
  system)   restore_system ;;
  apps)     restore_apps ;;
  all)
    restore_configs
    restore_services
    restore_packages
    restore_system
    restore_apps
    ;;
esac

head1 "Итог"
say "Ошибок: $ERRORS"
say "Лог:    $LOG"
if [ "$DRY" = 1 ]; then
  say "Это был dry-run. Запустите без --dry-run, чтобы применить."
fi
[ "$ERRORS" -eq 0 ] || exit 1
