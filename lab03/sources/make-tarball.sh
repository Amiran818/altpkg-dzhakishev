#!/bin/sh
# Формирование архива исходных текстов по правилу «имя-версия»:
#   dzhakishev-args-1.0.tar.gz -> dzhakishev-args-1.0/{*.c,prog.h,Makefile}
# Использование: sh make-tarball.sh [каталог_для_архива]
set -e
NAME=dzhakishev-args
VERSION=1.0
SRC=$(cd "$(dirname "$0")" && pwd)
OUT=$(cd "${1:-.}" && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir "$TMP/$NAME-$VERSION"
cp "$SRC/main.c" "$SRC/output.c" "$SRC/counter.c" "$SRC/prog.h" "$SRC/Makefile" "$TMP/$NAME-$VERSION/"
tar -C "$TMP" -czf "$OUT/$NAME-$VERSION.tar.gz" "$NAME-$VERSION"
echo "$OUT/$NAME-$VERSION.tar.gz"
