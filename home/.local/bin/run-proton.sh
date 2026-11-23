#!/usr/bin/env bash
set -Eeuo pipefail

# Проверка аргумента
if [[ $# -lt 1 ]]; then
    echo "Использование: run-proton.sh /path/to/game.exe"
    exit 1
fi

GAME="$(realpath -- "$1")"
shift

if [[ ! -f "$GAME" ]]; then
    echo "Файл не найден: $GAME"
    exit 1
fi

# Автоматический поиск последней версии GE-Proton
PROTON_ROOT="$HOME/.local/share/Steam/compatibilitytools.d"

mapfile -t VERSIONS < <(
    find "$PROTON_ROOT" -mindepth 1 -maxdepth 1 \
        -type d -name 'GE-Proton*' | sort -V
)

if [[ ${#VERSIONS[@]} -eq 0 ]]; then
    echo "GE-Proton не найден!"
    exit 1
fi

PROTON_DIR="${VERSIONS[-1]}"

# Рабочая директория программы
GAME_DIR="$(dirname "$GAME")"
GAME_NAME="$(basename "$GAME_DIR")"

# Уникальный Prefix для папки игры
HASH="$(printf '%s' "$GAME_DIR" | sha256sum | cut -c1-10)"

SAFE_NAME="$(echo "$GAME_NAME" | tr -cd '[:alnum:]_.-')"

PREFIX="$HOME/.local/share/proton-prefixes/${SAFE_NAME}-${HASH}"

mkdir -p "$PREFIX"

# Переменные Proton
export STEAM_COMPAT_DATA_PATH="$PREFIX"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/Steam"
export PROTON_DISABLE_XALIA=1

# Запуск из директории игры
cd "$GAME_DIR"

echo "Game: $GAME"
echo "Proton: $(basename "$PROTON_DIR")"
echo "Prefix: $PREFIX"

# NVIDIA можно включить через PROTON_NVIDIA=1
if [[ "${PROTON_NVIDIA:-0}" == "1" ]] && command -v prime-run >/dev/null; then
    exec prime-run "$PROTON_DIR/proton" run "$GAME" "$@"
else
    exec "$PROTON_DIR/proton" run "$GAME" "$@"
fi
