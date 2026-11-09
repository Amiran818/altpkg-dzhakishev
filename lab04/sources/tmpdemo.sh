#!/bin/sh
# tmpdemo.sh - работа с временным файлом и его гарантированное удаление
# Использование: sh tmpdemo.sh [ok|error|wait [секунд]]
# Имя временного файла дописывается в файл $TMPDEMO_NAME (если задан).

tmp=$(mktemp) || exit 1
[ -n "${TMPDEMO_NAME:-}" ] && echo "$tmp" >> "$TMPDEMO_NAME"

cleanup() { rm -f "$tmp"; }
trap cleanup EXIT        # любое завершение: штатное, exit по ошибке
trap 'exit 130' INT      # Ctrl+C: выйти, сработает обработчик EXIT
trap 'exit 143' TERM     # kill: то же

echo "временный файл: $tmp"
ls -l "$tmp"
ps -o pid,comm > "$tmp"  # произвольная работа с файлом
echo "строк записано: $(wc -l < "$tmp")"

case "${1:-ok}" in
    ok)    ;;
    error) echo "имитация ошибки" >&2; exit 2 ;;
    wait)  sleep "${2:-30}" & wait $! ;;
esac
