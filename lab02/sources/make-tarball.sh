#!/bin/sh
# Формирование архива исходных текстов по правилу «имя-версия»:
#   dzhakishev-show-1.0.tar.gz -> dzhakishev-show-1.0/{show.c,Makefile}
# Использование: sh make-tarball.sh [каталог_для_архива]
set -e
NAME=dzhakishev-show
VERSION=1.0
SRC=$(cd "$(dirname "$0")" && pwd)
OUT=$(cd "${1:-.}" && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir "$TMP/$NAME-$VERSION"
cp "$SRC/show.c" "$SRC/Makefile" "$TMP/$NAME-$VERSION/"
# архивируем из каталога размещения, чтобы в архив не попал путь $TMP
tar -C "$TMP" -czf "$OUT/$NAME-$VERSION.tar.gz" "$NAME-$VERSION"
echo "$OUT/$NAME-$VERSION.tar.gz"
