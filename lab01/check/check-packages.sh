#!/bin/bash
# Проверка наличия пакетов курса на хост-системе (задание 2)
LIST="$(dirname "$0")/../env/course-packages.txt"
rc=0
while read -r pkg; do
    [ -z "$pkg" ] && continue
    if out=$(rpm -q "$pkg"); then
        echo "OK   $out"
    else
        echo "MISS $pkg"
        rc=1
    fi
done < "$LIST"
exit $rc
