#!/bin/bash
# Функциональная проверка лабораторной работы 3 (задания 1-7).
# Запуск: bash lab03/check/check-lab03.sh
#
# Все сборки выполняются во временной копии каталога sources.
# Группа «hasher» использует локальный репозиторий HASHER_DIR/repo
# (по умолчанию ~/hasher-lab03) и пропускается (SKIP), если его нет.

set -u

LAB="$(cd "$(dirname "$0")/.." && pwd)"
HASHER_DIR="${HASHER_DIR:-$HOME/hasher-lab03}"
LOGS="$LAB/logs"
SRC="$LAB/sources"
STEPS="$SRC/steps"
REPO="$HASHER_DIR/repo"
NAME=dzhakishev-args
NVR=$NAME-1.0-alt1
ARCH=$(uname -m)
PKG="$REPO/$ARCH/RPMS.hasher/$NVR.$ARCH.rpm"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0
skip=0

check() {
    local name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo "PASS  $name"
        pass=$((pass + 1))
    else
        echo "FAIL  $name"
        fail=$((fail + 1))
    fi
}

skip() {
    echo "SKIP  $1 ($2)"
    skip=$((skip + 1))
}

# свежая копия исходных текстов: $1 - имя каталога
fresh() {
    rm -rf "${WORK:?}/$1"
    mkdir -p "$WORK/$1"
    cp "$SRC"/*.c "$SRC/prog.h" "$SRC/Makefile" "$WORK/$1/"
}

# ---------- задание 1: модули и этапы сборки ----------
t1_help() {
    fresh t1 && cd "$WORK/t1" && gcc -Wall -o dzhargs main.c output.c counter.c || return 1
    ./dzhargs > out 2> err; local rc=$?
    [ "$rc" -eq 1 ] && [ ! -s out ] && grep -q 'Usage:' err && grep -q 'dzhargs 1.0' err &&
    grep -qx 'rc=1' "$LOGS/01-noargs-rc.txt"
}
t1_three() { [ "$("$WORK/t1/dzhargs" a "b c" d | wc -l)" -eq 5 ]; }
t1_cpp() {
    gcc -E "$WORK/t1/main.c" -o "$WORK/t1/main.i" &&
    grep -q 'void print_arg(const char \*arg);' "$WORK/t1/main.i" &&
    grep -q 'extern int counter;' "$WORK/t1/main.i"
}
t1_objects() {
    cd "$WORK/t1" || return 1
    local m
    for m in main output counter; do
        gcc -Wall -c $m.c -o $m.o && file $m.o | grep -q 'relocatable' || return 1
    done
}
t1_strace() {
    local f="$LOGS/01-strace-programs.txt"
    grep -q '/cc1$' "$f" && grep -q '/as$' "$f" && grep -q '/collect2$' "$f" && grep -q '/ld$' "$f"
}
t1_multidef() {
    fresh dup && cd "$WORK/dup" || return 1
    sed -i 's|^void print_help(const char \*name);.*|&\nint twice(int x) { return 2 * x; }|' prog.h
    gcc -c main.c && gcc -c output.c && gcc -c counter.c || return 1
    ! gcc -o x main.o output.o counter.o > err 2>&1 &&
    grep -Eq 'multiple definition|повторное определение' err &&
    grep -Eq 'multiple definition|повторное определение' "$LOGS/01-multiple-definition.txt"
}

# ---------- задание 2: таблицы символов ----------
t2_counter() {
    cd "$WORK/t1" || return 1
    [ "$(nm main.o output.o counter.o | grep -cE ' [BDC] counter$')" -eq 1 ] &&
    nm counter.o | grep -qE ' [BD] counter$' &&
    nm main.o | grep -q ' U counter$' && nm output.o | grep -q ' U counter$'
}
t2_external() {
    cd "$WORK/t1" || return 1
    nm --undefined-only ./*.o | awk 'NF==2{print $2}' | sort -u > und
    nm --defined-only -g ./*.o | awk 'NF==3{print $3}' | sort -u > def
    nm -D --defined-only /lib64/libc.so.6 | awk '{print $3}' | sed 's/@.*//' | sort -u > libc
    comm -23 und def > ext
    [ -s ext ] && [ -z "$(comm -23 ext libc)" ]
}
t2_ldd() {
    cd "$WORK/t1" && gcc -o dzhargs main.o output.o counter.o || return 1
    ldd ./dzhargs > ldd.txt
    [ "$(wc -l < ldd.txt)" -ge 2 ] && grep -q 'libc.so.6 =>' ldd.txt && ! grep -q 'not found' ldd.txt
}
t2_logs() { [ -s "$LOGS/02-nm-main.txt" ] && [ -s "$LOGS/02-nm-output.txt" ] && [ -s "$LOGS/02-nm-counter.txt" ] && [ -s "$LOGS/02-external.txt" ]; }

# ---------- задание 3: make ----------
t3_selective() {
    fresh t3 && cd "$WORK/t3" || return 1
    make -s -f "$STEPS/Makefile.2-pattern" >/dev/null || return 1
    sleep 1; touch output.c
    [ "$(make -f "$STEPS/Makefile.2-pattern" | wc -l)" -eq 2 ]
}
t3_header() {
    cd "$WORK/t3" || return 1
    sleep 1; touch prog.h
    make -f "$STEPS/Makefile.2-pattern" 2>&1 | grep -Eq 'не требует|up to date|Nothing to be done' &&
    [ "$(make -f "$STEPS/Makefile.4-header" | grep -c ' -c ')" -eq 3 ]
}
t3_builtin() {
    cd "$WORK/t3" && rm -f ./*.o dzhargs || return 1
    make -f "$STEPS/Makefile.3-builtin" > b.txt 2>&1 || return 1
    rm -f ./*.o dzhargs; make -f "$STEPS/Makefile.2-pattern" > p.txt 2>&1 || return 1
    ! diff -q b.txt p.txt && grep -q 'gcc -O2 -Wall   -c -o main.o main.c' b.txt
}
t3_cflags() {
    cd "$WORK/t3" && rm -f ./*.o dzhargs || return 1
    make -f "$STEPS/Makefile.5-phony" CFLAGS="-O0 -DCHECK_LAB03" | grep -q 'gcc -c -O0 -DCHECK_LAB03 main.c'
}
t3_phony() {
    cd "$WORK/t3" && touch clean || return 1
    make -f "$STEPS/Makefile.5-phony" clean | grep -q '^rm -f' || return 1
    make -s -f "$STEPS/Makefile.5-phony" >/dev/null
    make -f "$STEPS/Makefile.5b-nophony" clean 2>&1 | grep -Eq 'не требует|up to date'
}

# ---------- задание 4: статическая библиотека ----------
t4_ar() {
    fresh t4 && cd "$WORK/t4" && make -s dzhargs dzhargs-static >/dev/null 2>&1 || return 1
    [ "$(ar -t libdzhargs.a | sort | tr '\n' ' ')" = "counter.o output.o " ]
}
t4_cmp() {
    cd "$WORK/t4" || return 1
    ./dzhargs one "two words" three > o1 && ./dzhargs-static one "two words" three > o2 && cmp o1 o2 &&
    ! ldd ./dzhargs-static | grep -q dzhargs
}
t4_full() {
    grep -q -- '-lc' "$LOGS/04-static-no-libc.txt" || return 1
    cd "$WORK/t4" && gcc -static -o full main.o -L. -ldzhargs || return 1
    local s1 s2 n1 n2
    s1=$(stat -c %s dzhargs-static); s2=$(stat -c %s full)
    n1=$(nm dzhargs-static | wc -l); n2=$(nm full | wc -l)
    [ "$s2" -gt $((s1 * 10)) ] && [ "$n2" -gt $((n1 * 10)) ] &&
    ldd ./full 2>&1 | grep -Eq 'не является динамическим|not a dynamic executable'
}

# ---------- задание 5: динамическая библиотека ----------
t5_pic() {
    cd "$WORK/t1" || return 1
    ! gcc -shared -o bad.so output.o counter.o > err 2>&1 &&
    grep -Eq 'recompile with -fPIC|перекомпилируйте с параметром -fPIC' err || return 1
    fresh t5 && cd "$WORK/t5" && make -s dzhargs-shared >/dev/null 2>&1 && [ -f libdzhargs.so.1 ]
}
t5_dynsym() {
    local s
    s=$(nm -D --defined-only "$WORK/t5/libdzhargs.so.1")
    [[ "$s" == *" T print_arg"* && "$s" == *" T print_help"* && "$s" == *" B counter"* && "$s" == *" D mark_begin"* ]]
}
t5_noldpath() {
    cd "$WORK/t5" || return 1
    env -u LD_LIBRARY_PATH ./dzhargs-shared x > out 2>&1; local rc=$?
    [ "$rc" -ne 0 ] && grep -q 'cannot open shared object file' out &&
    env -u LD_LIBRARY_PATH ldd ./dzhargs-shared | grep -q 'libdzhargs.so.1 => not found'
}
t5_ldpath() {
    cd "$WORK/t5" && make -s dzhargs-static >/dev/null 2>&1 || return 1
    LD_LIBRARY_PATH=. ldd ./dzhargs-shared | grep -q 'libdzhargs.so.1 => ./libdzhargs.so.1' &&
    ! LD_LIBRARY_PATH=. ldd ./dzhargs-shared | grep -q 'not found' &&
    LD_LIBRARY_PATH=. ./dzhargs-shared one "two words" three > o1 && ./dzhargs-static one "two words" three > o2 && cmp o1 o2
}

# ---------- задание 6: цель тестирования ----------
t6_test() {
    fresh t6 && cd "$WORK/t6" && make -s >/dev/null 2>&1 && make test >/dev/null 2>&1 &&
    [ "$(find . -maxdepth 1 -name '*.out[013]' | wc -l)" -eq 9 ]
}
t6_pairs() {
    cd "$WORK/t6" || return 1
    local n
    for n in 0 1 3; do
        cmp dzhargs.out$n dzhargs-static.out$n && cmp dzhargs.out$n dzhargs-shared.out$n || return 1
    done
    grep -q 'Usage: PROG ARG' dzhargs-shared.out0
}
t6_sensitive() {
    cd "$WORK/t6" || return 1
    cp output.c output.c.orig
    sed -i 's/printf("%d: %s\\n"/printf("%d) %s\\n"/' output.c
    make -s dzhargs-static >/dev/null 2>&1 || return 1
    if make test >/dev/null 2>&1; then return 1; fi
    mv output.c.orig output.c && touch output.c   # исходник снова новее объектных файлов
    make -s >/dev/null 2>&1 && make test >/dev/null 2>&1
}
t6_distclean() {
    cd "$WORK/t6" && make -s distclean >/dev/null 2>&1 &&
    [ "$(find . -mindepth 1 | LC_ALL=C sort | tr '\n' ' ')" = "./Makefile ./counter.c ./main.c ./output.c ./prog.h " ]
}

# ---------- задание 7: журналы установки в hasher ----------
t7_run_log() {
    local l="$LOGS/07-run-in-hasher.txt"
    grep -qx 'LD_LIBRARY_PATH=\[\]' "$l" && grep -qx '/usr/bin/dzhargs-static' "$l" &&
    grep -qx '/usr/bin/dzhargs-shared' "$l" && grep -q 'cmp: выводы совпадают' "$l" &&
    grep -q 'libdzhargs.so.1 => /.*lib64/libdzhargs.so.1' "$l" && grep -qx "$NVR.$ARCH" "$l"
}
t7_selfreq_log() {
    grep -q '^libdzhargs.so.1()(64bit)' "$LOGS/07-lib-req-shared.txt" &&
    grep -q '^libdzhargs.so.1()(64bit)' "$LOGS/07-lib-prov.txt"
}

# ---------- hasher: локальный репозиторий ----------
h_files() {
    local l
    l=$(rpm -qpl "$PKG" | LC_ALL=C sort | tr '\n' ' ')
    [ "$l" = "/usr/bin/dzhargs-shared /usr/bin/dzhargs-static $(rpm --eval %_libdir)/libdzhargs.so.1 " ] &&
    [ "$(rpm --eval %_libdir)" = /usr/lib64 ]
}
h_provides() {
    rpm -qp --provides "$PKG" | grep -q '^libdzhargs.so.1()(64bit)' &&
    ! rpm -qp --requires "$PKG" | grep -q 'devel'
}
h_libreq() {
    rm -rf "$WORK/x" && mkdir "$WORK/x" && cd "$WORK/x" || return 1
    rpm2cpio "$PKG" | cpio -id --quiet || return 1
    echo "$WORK/x/usr/bin/dzhargs-shared" | RPM_BUILD_ROOT="$WORK/x" /usr/lib/rpm/lib.req | grep -q '^libdzhargs.so.1()(64bit)' &&
    readelf -d usr/bin/dzhargs-shared | grep -q 'NEEDED.*libdzhargs.so.1' &&
    ! readelf -d usr/bin/dzhargs-static | grep -q 'libdzhargs'
}
h_debuginfo() {
    [ -f "$REPO/$ARCH/RPMS.hasher/$NAME-debuginfo-1.0-alt1.$ARCH.rpm" ] && [ -f "$REPO/SRPMS.hasher/$NVR.src.rpm" ]
}

echo "== Задание 1: модули и этапы сборки"
check "1.1 без параметров справка в stderr, код 1"           t1_help
check "1.2 три параметра - пять строк"                      t1_three
check "1.3 результат препроцессора содержит prog.h"         t1_cpp
check "1.4 по объектному файлу на модуль (relocatable)"     t1_objects
check "1.5 трассировка: cc1, as, collect2, ld"              t1_strace
check "1.6 определение в заголовке: повторное определение"  t1_multidef

echo "== Задание 2: таблицы символов"
check "2.1 counter определён в одном модуле"                t2_counter
check "2.2 внешние символы - только из libc"                t2_external
check "2.3 ldd: libc найдена, not found нет"                t2_ldd
check "2.4 журналы таблиц символов"                         t2_logs

echo "== Задание 3: make"
check "3.1 touch одного модуля - ровно 2 команды"           t3_selective
check "3.2 зависимость от prog.h"                           t3_header
check "3.3 встроенное правило отличается от шаблонного"     t3_builtin
check "3.4 CFLAGS из командной строки"                      t3_cflags
check "3.5 .PHONY: clean при наличии файла clean"           t3_phony

echo "== Задание 4: статическая библиотека"
check "4.1 ar -t: output.o и counter.o"                     t4_ar
check "4.2 вывод со статической библиотекой совпадает"      t4_cmp
check "4.3 -static: размер и символы x10, ldd - не динамич." t4_full

echo "== Задание 5: динамическая библиотека"
check "5.1 без -fPIC ошибка перемещения, с -fPIC сборка"    t5_pic
check "5.2 экспорт: print_arg, print_help, counter, mark"   t5_dynsym
check "5.3 без LD_LIBRARY_PATH библиотека не найдена"       t5_noldpath
check "5.4 с LD_LIBRARY_PATH вывод совпадает"               t5_ldpath

echo "== Задание 6: цель тестирования"
check "6.1 make test: код 0, девять файлов выводов"         t6_test
check "6.2 попарное сравнение выводов"                      t6_pairs
check "6.3 пересборка одного варианта - тест падает"        t6_sensitive
check "6.4 distclean оставляет только исходники"            t6_distclean

echo "== Задание 7: журналы установки в hasher"
check "7.1 оба файла по имени, без LD_LIBRARY_PATH"         t7_run_log
check "7.2 lib.req/lib.prov: libdzhargs.so.1()(64bit)"      t7_selfreq_log

echo "== Hasher: локальный репозиторий ($REPO)"
if command -v hsh >/dev/null 2>&1 && [ -f "$PKG" ]; then
    check "7.3 файлы: 2 в /usr/bin, библиотека в %_libdir"  h_files
    check "7.4 Provides: libdzhargs.so.1()(64bit)"          h_provides
    check "7.5 NEEDED и lib.req: зависит только -shared"    h_libreq
    check "7.6 src.rpm и подпакет debuginfo"                h_debuginfo
else
    for n in "7.3 файлы пакета" "7.4 Provides" "7.5 NEEDED и lib.req" "7.6 src.rpm и debuginfo"; do
        skip "$n" "нет $PKG"
    done
fi

echo
echo "Пройдено: $pass, не пройдено: $fail, пропущено: $skip"
[ "$fail" -eq 0 ]
