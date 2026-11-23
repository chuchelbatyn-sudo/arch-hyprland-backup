
#!/usr/bin/env bash

THEME="$HOME/.config/rofi/powermenu.rasi"

confirm() {
    local choice
    choice=$(printf '%s\n' \
        'Да, продолжить' \
        'Нет, отмена' |
        rofi -dmenu -i -p "$1" -theme "$THEME")

    [[ "$choice" == "Да, продолжить" ]]
}

choice=$(printf '%s\n' \
    '󰌾  Заблокировать экран' \
    '󰒲  Спящий режим' \
    '󰍃  Выйти из системы' \
    '󰜉  Перезагрузка' \
    '󰐥  Выключение' \
    'Отмена' |
    rofi -dmenu -i -p 'Питание' -theme "$THEME")

case "$choice" in
    *"Заблокировать экран")
        hyprlock
        ;;
    *"Спящий режим")
        hyprlock &
        sleep 1
        systemctl suspend
        ;;
    *"Выйти из системы")
        hyprctl dispatch exit
        ;;
    *"Перезагрузка")
        confirm "Перезагрузить компьютер?" && systemctl reboot
        ;;
    *"Выключение")
        confirm "Выключить компьютер?" && systemctl poweroff
        ;;
esac
