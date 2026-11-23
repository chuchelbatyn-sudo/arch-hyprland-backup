# MANIFEST — состав резервной копии

- Собрано: **2026-11-23 15:26**
- Хост: `arch-host` (ASUS ROG arch-host G14 GA401IH), Arch Linux
- Ядро: `7.2.14-arch1-1`
- Окружение: SDDM → Hyprland, Wayland, fish
- Hyprland: Hyprland 0.57.2 built from branch v0.57.2 at commit 11cbc6c577b84ffb1edf4df3fc5b6128c3ae6947 clean (VERSION: bump to 0.57.2).
- Каталог копии: `~/Projects/ArchBackup-2026-11-23`

## Сводка

| Раздел | Файлов | Размер | Назначение |
|---|---:|---:|---|
| `system/` | 24 | 53.6 КБ | Системные настройки: /etc, загрузчик, железо |
| `packages/` | 9 | 44.8 КБ | Списки пакетов (pacman/AUR/сироты/версии) |
| `home/` | 48 | 68.1 КБ | Домашние конфиги и скрипты (зеркало путей) |
| `applications/` | 3 | 875 Б | Настройки приложений, установленных вручную |
| `scripts/` | 2 | 770 Б | Служебные пометки сборки |
| `services/` | 4 | 8.0 КБ | Службы, автозапуск, exec-once |
| `gtk/` | 5 | 1.9 КБ | GTK-настройки (дубль для удобства) |
| `MANIFEST.md` | 1 | 7.1 КБ | перечень сохранённого (этот файл) |
| `README.md` | 1 | 11.8 КБ | инструкция по восстановлению (RU) |
| `audit.sh` | 1 | 7.7 КБ | скрипт повторной проверки |
| `checksums.sha256` | 1 | 9.3 КБ | контрольные суммы SHA256 |
| `restore.sh` | 1 | 11.8 КБ | скрипт восстановления |
| **Итого** | **100** | **225.7 КБ** | |

## Пакеты

- Всего сохранено названий: **1070** (в системе 1079, минус исключённые)
- Явно установленных (официальные репозитории): **99**
- AUR (явные): **7** (в системе 13, 6 исключены по вашему решению)
- Сирот: **16**
- Flatpak: не установлен; Snap: не установлен
- Файлы: `packages/{all,explicit,deps,aur,aur-explicit,orphans,versions,key-versions,flatpak}.txt`

## Содержимое по разделам

### `system/` — 24 файлов, 53.6 КБ

- `collection-notes.txt`
- `etc-filelist.txt`
- `missing-etc.txt`
- `boot/boot-listing.txt`
- `boot/grub.cfg`
- `boot/grubenv`
- `etc/fstab`
- `etc/hostname`
- `etc/hosts`
- `etc/locale.conf`
- `etc/mkinitcpio.conf`
- `etc/pacman.conf`
- `etc/sddm.conf`
- `etc/vconsole.conf`
- `etc/NetworkManager/NetworkManager.conf`
- `etc/default/grub`
- `etc/grub.d/40_custom`
- `etc/mkinitcpio.d/linux.preset`
- `etc/pacman.d/mirrorlist`
- `etc/systemd/journald.conf`
- `etc/systemd/zram-generator.conf`
- `hw/hardware.txt`

### `packages/` — 9 файлов, 44.8 КБ

- `all.txt`
- `aur-explicit.txt`
- `aur.txt`
- `deps.txt`
- `explicit.txt`
- `flatpak.txt`
- `key-versions.txt`
- `orphans.txt`
- `versions.txt`

### `home/` — 48 файлов, 68.1 КБ

- `.gtkrc-2.0`
- `.config/PortProton.conf`
- `.config/mimeapps.list`
- `.config/pavucontrol.ini`
- `.config/user-dirs.dirs`
- `.config/user-dirs.locale`
- `.config/autostart/remmina-applet.desktop`
- `.config/dunst/dunstrc`
- `.config/fish/config.fish`
- `.config/fish/fish_variables`
- `.config/gtk-3.0/settings.ini`
- `.config/gtk-4.0/settings.ini`
- `.config/hypr/hypridle.conf`
- `.config/hypr/hyprland.lua`
- `.config/hypr/hyprland.lua.backup`
- `.config/hypr/hyprlock.conf`
- `.config/hypr/hyprlock.conf.backup`
- `.config/networkmanager-dmenu/config.ini`
- `.config/nwg-look/config`
- `.config/rofi/apps.rasi`
- `.config/rofi/powermenu.rasi`
- `.config/rofi/powermenu.rasi.save`
- `.config/rofi/wifi.rasi`
- `.config/swayosd/style.css`
- `.config/waybar/config`
- `.config/waybar/config.22`
- `.config/waybar/style.css`
- `.config/waybar/style.css.22`
- `.config/xdg-desktop-portal/hyprland-portals.conf`
- `.config/xsettingsd/xsettingsd.conf`
- `.local/bin/bluetooth-menu`
- `.local/bin/cliphist-menu`
- `.local/bin/cliphist-watch`
- `.local/bin/power-menu`
- `.local/bin/proton-install`
- `.local/bin/proton-install.bak`
- `.local/bin/proton-remove`
- `.local/bin/proton-run`
- `.local/bin/run-proton.sh`
- `.local/bin/run-proton.sh.bak`
- `.local/bin/screenshot`

### `applications/` — 3 файлов, 875 Б

- `PortProton.conf`
- `README.txt`

### `scripts/` — 2 файлов, 770 Б

- `collection-notes.txt`
- `source-paths.txt`

### `services/` — 4 файлов, 8.0 КБ

- `autostart.txt`
- `enabled-units.txt`
- `units.txt`
- `user-units-note.txt`

### `gtk/` — 5 файлов, 1.9 КБ

- `.gtkrc-2.0`
- `gtk-3.0/settings.ini`
- `gtk-4.0/settings.ini`
- `nwg-look/config`
- `xsettingsd/xsettingsd.conf`

## Исключено по решению пользователя

Не копировалось полностью (файлы, каталоги, `/opt/*`, юниты, пакеты):

- `claude-code`, `claude-desktop`
- `kvn-tui`
- `vpn-manager`, `xray`, `tun2socks`, `drkvl`, `sotavpn`, `hiddify`

## Не сохранено: секреты

| Что | Почему |
|---|---|
| Wi-Fi профили | `/etc/NetworkManager/system-connections/` — только root |
| Bluetooth-спаривания | `/var/lib/bluetooth/` — только root |
| Хеши паролей | `/etc/shadow` — только root |
| VPN/прокси-креды | `xray`, `hiddify`, `sotavpn`, `kvn-tui/profiles.json` |
| Пароль qBittorrent | `qBittorrent.conf` |
| Identity TeamSpeak | `~/.config/TeamSpeak/` |
| RDP/VNC-учётки | `~/.config/remmina/` |
| Токены CLI и браузеров | `~/.claude.json`, cookies, `pulse/cookie` |
| SSH/GPG | `~/.ssh`, `~/.gnupg` |

## Не сохранено: тяжёлые данные

Браузеры (chromium, mozilla), discord, Steam, TelegramDesktop, WarThunder, `.cache`,
Trash, логи, `.local/share/{uv,pnpm,lutris,umu,proton-prefixes}`.

## Не удалось прочитать без root

- `btrfs subvolume list /` — «Operation not permitted»
- `efibootmgr -v` — требует root
- `/etc/NetworkManager/system-connections/`, `/var/lib/bluetooth/`, `/etc/shadow`

Подробности — `system/hw/hardware.txt`.
Список ненайденных файлов `/etc` — `system/missing-etc.txt`.

## Проверка целостности

- `checksums.sha256`: **99** записей SHA256
- Проверка: `cd ~/Projects/ArchBackup-2026-11-23 && sha256sum -c checksums.sha256`
- Файлов в копии: **100** (`checksums.sha256` — служебный, хеша самого себя не содержит)
- Суммарный размер (по содержимому файлов): **225.7 КБ**

## Служебные пометки

- `scripts/source-paths.txt` — соответствие «копия → оригинал»
- `scripts/collection-notes.txt` — что не нашлось при сборе
- `system/etc-filelist.txt` — полный список файлов `/etc` на момент сборки
- `services/units.txt` — снимок включённых служб
- `services/enabled-units.txt` — список для `restore.sh --mode services`
