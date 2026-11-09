#!/bin/sh
# pipeline.sh - конвейер над выводом системной утилиты и цикл с проверкой
# статуса завершения; список проверяемых утилит берётся из встроенного документа.
export LC_ALL=C

# число учётных записей по оболочкам входа: getent | cut | sort | uniq | sort
getent passwd | cut -d: -f7 | sort | uniq -c | sort -k2 |
while read -r n sh; do
    if [ -x "$sh" ]; then state="executable"; else state="not executable"; fi
    printf '%-24s %3s  %s\n' "$sh" "$n" "$state"
done

while read -r cmd; do
    if command -v "$cmd" > /dev/null; then echo "$cmd: found"; else echo "$cmd: not found"; fi
done <<END
dialog
sponge
gear-srpmimport
xxd
END
