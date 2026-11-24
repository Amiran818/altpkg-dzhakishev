#!/bin/sh
# prepare-hasher.sh - подготовка изолированного окружения для отладки (ЛР5)
#
# За один запуск: создаёт окружение, если его нет; копирует настройки
# разрешения имён; устанавливает перечень пакетов; монтирует /proc и
# входит в окружение (или выполняет в нём команду).
#
# Использование:
#   prepare-hasher.sh [-w КАТАЛОГ] [-n НОМЕР] [-p "ПАКЕТЫ"] [-r] [-N] [-c КОМАНДА]
#     -w  каталог окружения (по умолчанию ~/hasher-lab05)
#     -n  номер подконфигурации hasher-priv (вторая пара пользователей)
#     -p  дополнительные пакеты (по умолчанию gdb)
#     -r  работать от имени служебного суперпользователя (rooter)
#     -N  общая с хостом сеть (share_network=1)
#     -c  выполнить команду вместо интерактивного входа
#
# Для монтирования /proc нужны: строка proc в /etc/hasher-priv/fstab,
# allowed_mountpoints=/proc в /etc/hasher-priv/system, перезапуск
# hasher-privd и known_mountpoints=/proc в ~/.hasher/config (или --mountpoints).

set -eu

WORKDIR=$HOME/hasher-lab05
NUMBER=
PACKAGES=gdb
ROOTER=
COMMAND=
MOUNTPOINTS=/proc

usage() {
    sed -n '8,15p' "$0" >&2
    exit 1
}

opts=$(getopt -n prepare-hasher -o w:n:p:rNc:h -- "$@") || usage
eval set -- "$opts"
while :; do
    case "$1" in
        -w) WORKDIR=$2; shift 2 ;;
        -n) NUMBER=$2; shift 2 ;;
        -p) PACKAGES=$2; shift 2 ;;
        -r) ROOTER=--rooter; shift ;;
        -N) share_network=1; export share_network; shift ;;
        -c) COMMAND=$2; shift 2 ;;
        -h) usage ;;
        --) shift; break ;;
    esac
done

NUM=${NUMBER:+--number=$NUMBER}

# 1. создать окружение только при его отсутствии
if [ -d "$WORKDIR/chroot" ]; then
    echo "prepare-hasher: окружение $WORKDIR уже есть, не пересоздаётся"
else
    echo "prepare-hasher: создание окружения $WORKDIR"
    mkdir -p "$WORKDIR"
    # shellcheck disable=SC2086
    hsh --initroot-only $NUM "$WORKDIR" < /dev/null
fi

# 2. настройки разрешения имён
# shellcheck disable=SC2086
hsh-copy --rooter $NUM --workdir="$WORKDIR" /etc/resolv.conf /etc/hosts /etc/ < /dev/null

# 3. пакеты (уже установленные apt пропускает)
# shellcheck disable=SC2086
hsh-install $NUM "$WORKDIR" $PACKAGES < /dev/null

# 4. монтирование служебных файловых систем и вход в окружение
if [ -n "$COMMAND" ]; then
    # shellcheck disable=SC2086
    exec hsh-run $ROOTER $NUM --mountpoints="$MOUNTPOINTS" "$WORKDIR" -- sh -c "$COMMAND" < /dev/null
else
    # shellcheck disable=SC2086
    exec hsh-shell $ROOTER $NUM --mountpoints="$MOUNTPOINTS" "$WORKDIR"
fi
