> **Версия для GitHub (приватный репозиторий).**
> Из этой копии вычищены machine-id, boot-id, UUID разделов, hostname и имя
> пользователя — заменены на нули, `arch-host` и `/home/user`.
> Контрольные суммы пересчитаны для этой версии; локальная копия в
> `~/Projects/ArchBackup-2026-11-23` осталась нетронутой.

# ArchBackup — конфигурация Arch Linux + Hyprland

Резервная копия пользовательской конфигурации перед переустановкой системы.
Собрана **только чтением**: оригинальные файлы не изменялись, не перемещались и не удалялись.

- Хост: `arch-host` (ASUS ROG arch-host G14 GA401IH, AMD + NVIDIA)
- Система: Arch Linux (rolling), UEFI + GRUB, btrfs (`@`, `@home`, `@pkg`, `@log`)
- Графика: SDDM → Hyprland 0.57.2, Wayland, конфиг на Lua
- Оболочка: fish
- Дата сборки и полный перечень — в [MANIFEST.md](MANIFEST.md)

> Каталог этой копии: `~/Projects/ArchBackup-2026-11-23`.
> Прежняя копия `~/Projects/ArchBackup` (19.11.2026) **не тронута**.

---

## 1. Структура

```
ArchBackup-2026-11-23/
├── README.md              этот файл
├── MANIFEST.md            что именно сохранено, размеры, что не удалось
├── checksums.sha256       SHA256 всех файлов копии
├── restore.sh             восстановление (есть --dry-run)
├── audit.sh               повторная проверка системы после переустановки
├── system/                /etc, загрузчик, железо
│   ├── etc/               grub, mkinitcpio, sddm, logind.d, xorg, locale,
│   │                      vconsole, fstab, pacman.conf, mirrorlist, zram
│   ├── boot/              grub.cfg, grubenv
│   ├── hw/                CPU/GPU/PCI/USB, разделы, swap/zram, cmdline
│   └── etc-filelist.txt   список всех файлов /etc (для сверки)
├── packages/              списки пакетов: всё, явные, AUR, сироты, версии
├── home/                  зеркало домашних путей
│   ├── .config/           hypr, waybar, rofi, dunst, fish, gtk, swayosd, …
│   ├── .local/bin/        пользовательские скрипты
│   ├── .local/share/      ярлыки .desktop, proton-launchers
│   └── .gtkrc-2.0
├── applications/          PortProton.conf, Gaijin/
├── scripts/               служебные пометки сборки
├── services/              включённые юниты, автозапуск, exec-once
└── gtk/                   GTK-настройки (дубль для удобства)
```

Соответствие путей «копия → оригинал» — в `scripts/source-paths.txt`.

---

## 2. Что сохранено

| Раздел | Содержимое |
|---|---|
| Hyprland | `hyprland.lua` (14 КБ), `hyprlock.conf`, `hypridle.conf`, `.backup`-версии |
| Waybar | `config`, `style.css`, `config.22`, `style.css.22`, `scripts/powermenu.sh` |
| Rofi | `apps.rasi`, `powermenu.rasi`, `wifi.rasi`, `powermenu.rasi.save` |
| Dunst | `dunstrc` |
| Fish | `config.fish`, `fish_variables`, пустые `functions/`, `completions/`, `conf.d/` |
| GTK | `gtk-3.0/settings.ini`, `gtk-4.0/settings.ini`, `~/.gtkrc-2.0`, `xsettingsd`, `nwg-look` |
| Скрипты | `screenshot`, `cliphist-menu`, `cliphist-watch`, `bluetooth-menu`, `power-menu`, `proton-*`, `run-proton.sh` |
| Ярлыки | `warthunder`, `proton-exe`, `rail-route`, каталог `wine/` |
| Приложения | `~/.config/PortProton.conf`, `~/.config/Gaijin/` |
| Службы | список включённых системных юнитов, симлинки `*.wants`, автозапуск XDG, `exec-once` из Hyprland |
| Система | `/etc/default/grub`, `mkinitcpio.conf` + preset, `sddm.conf`, `logind.conf.d/10-lid-suspend.conf`, `xorg.conf.d/00-keyboard.conf`, `locale.conf`, `vconsole.conf`, `fstab`, `pacman.conf`, `mirrorlist`, `journald.conf`, `zram-generator.conf`, `NetworkManager.conf`, `hostname`, `hosts`, `grub.d/40_custom`, `grub.cfg` |
| Пакеты | 1079 названий (все), 99 явных, 13 AUR-явных, сироты, версии |

---

## 3. Что НЕ сохранено (важно!)

### 3.1 По вашему решению (не копировалось вообще)
`claude-code`, `claude-desktop`, `kvn-tui`, `vpn-manager`, `xray`, `tun2socks`,
`drkvl`, `sotavpn`, `hiddify` — их файлы, каталоги `/opt/*`, юниты и пакеты.

### 3.2 Секреты (сознательно исключены)
Восстановить доступ придётся вручную, значения в отчётах не фигурируют:

| Что | Где было |
|---|---|
| Wi-Fi пароли | `/etc/NetworkManager/system-connections/` (нужен root) |
| Bluetooth-спаривания | `/var/lib/bluetooth/` (нужен root) |
| Хеши паролей | `/etc/shadow` (нужен root) |
| VPN/прокси-креды | `~/.config/{xray,hiddify,sotavpn}`, `~/.config/kvn-tui/profiles.json` |
| Пароль qBittorrent | `~/.config/qBittorrent/qBittorrent.conf` |
| Identity TeamSpeak | `~/.config/TeamSpeak/` |
| Сохранённые RDP/VNC | `~/.config/remmina/` |
| Токены CLI | `~/.claude.json`, cookies/токены браузеров, `~/.config/pulse/cookie` |
| SSH/GPG | `~/.ssh`, `~/.gnupg` |

### 3.3 Тяжёлые данные (не копировались)
Браузеры (`chromium`, `mozilla`), `discord`, `Steam`, `TelegramDesktop`, `WarThunder` (72 ГБ),
`.cache`, `Trash`, логи, `~/.local/share/{uv,pnpm,lutris,umu,proton-prefixes}`, `node_modules`.

### 3.4 Не удалось прочитать без root
`/etc/NetworkManager/system-connections/`, `/var/lib/bluetooth/`, `/etc/shadow`,
`btrfs subvolume list`, `efibootmgr -v` (последние два — в `system/hw/hardware.txt` с пометкой об ошибке).

---

## 4. Восстановление

Порядок важен. Сначала система и пакеты, потом конфиги, потом службы.

### Шаг 0. Железо и разделы (вручную, до chroot)
Разметка была: GPT + EFI (`/dev/nvme0n1p1`, vfat, `/boot`, 1 ГБ) + btrfs (`/dev/nvme0n1p2`)
с субтомами `@` → `/`, `@home` → `/home`, `@pkg` → `/var/cache/pacman/pkg`, `@log` → `/var/log`.
Опции монтирования из `system/etc/fstab`: `compress=zstd:3,ssd,discard=async,space_cache=v2`.
Файловая система — btrfs, корень монтируется с `subvol=@`.

### Шаг 1. Базовые пакеты
```bash
# после arch-chroot и настройки зеркал (system/etc/pacman.d/mirrorlist)
pacman -Syu
sudo pacman -S --needed - < packages/explicit.txt
# AUR: сначала yay, потом остальное
yay -S --needed - < packages/aur-explicit.txt
```
Можно автоматизировать: `./restore.sh --mode packages --yes`
(без `--yes` скрипт только напечатает команды).

### Шаг 2. Конфиги
```bash
./restore.sh --dry-run --mode configs   # посмотреть план
./restore.sh --mode configs             # применить
```
Скрипт раскладывает `home/` в `$HOME`, `gtk/` и `applications/` — по своим местам.
Существующие файлы сохраняются как `<файл>.bak-<дата>`, ничего не удаляется.

### Шаг 3. Службы
```bash
./restore.sh --mode services            # напечатает sudo systemctl enable --now ...
./restore.sh --mode services --yes      # выполнит (спросит пароль sudo)
```
Пользовательских юнитов не было (`~/.config/systemd/user` отсутствовал).
Автозапуск в сессии Hyprland — через `exec-once` в `hyprland.lua`:
`waybar`, `kvn`, `hypridle`, `cliphist-watch`, `swayosd-server` (строку про `kvn` можно убрать — пакет не восстановлен).

### Шаг 4. Системные файлы (вручную)
`restore.sh --mode system` **только печатает** готовые `sudo cp` — скрипт не меняет `/etc` и `/boot`.
После копирования:
```bash
sudo mkinitcpio -P                 # если меняли mkinitcpio.conf
sudo grub-mkconfig -o /boot/grub/grub.cfg
sudo systemctl daemon-reload
```
Загрузчик: GRUB 2.16 в UEFI. `efibootmgr` требует root — проверьте порядок загрузки после установки.

### Шаг 5. Вручную, после первого входа
1. **Wi-Fi/сеть**: `nmcli device wifi connect "<SSID>" password "<пароль>"` — пароли не сохранены.
2. **Bluetooth**: заново спарить наушники/мышь (`bluetoothctl`).
3. **NVIDIA**: `nvidia-open-dkms`, `nvidia-prime`, `libva-nvidia-driver`; проверить `nvidia-smi`, при гибридной графике — `prime-run`.
4. **zram**: пакет `zram-generator` + `system/etc/systemd/zram-generator.conf`, затем `sudo systemctl daemon-reload && sudo systemctl start systemd-zram-setup@zram0.service`.
5. **SDDM**: тема `elarun` входит в пакет `sddm`; `system/etc/sddm.conf` вернёт её.
6. **Крышка ноутбука**: `system/etc/systemd/logind.conf.d/10-lid-suspend.conf` → suspend при закрытии.
7. **Шрифты и темы**: отдельных каталогов в `$HOME` не было — всё из пакетов
   (`adw-gtk-theme`, `noto-fonts`, `noto-fonts-emoji`, `ttf-jetbrains-mono-nerd`, `ttf-nerd-fonts-symbols`).
8. **AUR**: сборка требует `base-devel` и `git`; `yay` ставится первым.
9. **Multilib** включён в `pacman.conf` (для `lib32-*`, Steam).
10. **Зеркала**: в `mirrorlist` были российские зеркала; при переезде замените на актуальные.

### Шаг 6. Проверка
```bash
./audit.sh              # отчёт в терминал
./audit.sh --write      # + файл audit-report-<дата>.md
```
Скрипт только читает: сверяет пакеты, наличие и содержимое конфигов, включённые службы,
`/etc/default/grub` и настройку крышки. Код возврата `0` — всё совпало.

---

## 5. Ограничения и предупреждения

- `restore.sh` не удаляет ничего и не трогает `/etc`, `/boot` самостоятельно.
- `restore.sh --mode all` устанавливает пакеты **только** с `--yes`.
- Секреты в копии отсутствуют: после переустановки их нужно ввести заново.
- Копия не заменяет резервную копию личных файлов (`~/Documents`, `~/Pictures`, `~/Projects` и т.п.) — их нужно сохранить отдельно.
- Если Hyprland обновится до версии с другим синтаксисом Lua-конфига — сверяйтесь с `hyprland.lua.backup` и вики Hyprland.
- Проверка целостности копии: `sha256sum -c checksums.sha256` (запускать из каталога копии).

---

## 6. Быстрый старт (кратко)

```bash
cd ~/Projects/ArchBackup-2026-11-23
sha256sum -c checksums.sha256      # 1. целостность
./restore.sh --dry-run             # 2. план
./restore.sh --mode packages --yes # 3. пакеты
./restore.sh --mode configs        # 4. конфиги
./restore.sh --mode services --yes # 5. службы
./restore.sh --mode system         # 6. sudo-команды для /etc и GRUB
./audit.sh                         # 7. проверка
```
