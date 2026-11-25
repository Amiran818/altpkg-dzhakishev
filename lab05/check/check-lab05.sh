#!/bin/bash
# Функциональная проверка лабораторной работы 5 (задания 1-7).
# Запуск: bash lab05/check/check-lab05.sh
#
# Группы с пропуском (SKIP) при недоступности ресурса:
#   стенд  - пакет glibc-core-debuginfo и локальный сервер debuginfod;
#   hasher - окружение HASHER_DIR (~/hasher-lab05) с разрешённым /proc;
#   журналы заданий 6-7, требовавших прав администратора, проверяются всегда.

set -u

LAB="$(cd "$(dirname "$0")/.." && pwd)"
HASHER_DIR="${HASHER_DIR:-$HOME/hasher-lab05}"
LOGS="$LAB/logs"
GDBDIR="$LAB/gdb"
CHK="$LAB/check"
GDB="gdb -q -batch -nx"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cp "$LAB"/sources/*.c "$LAB"/sources/*.h "$LAB"/sources/Makefile "$WORK/"
cd "$WORK" || exit 1

pass=0
fail=0
skip=0

check() {
    local name="$1"
    shift
    if (cd "$WORK" && "$@") >/dev/null 2>&1; then
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

hdr() { LC_ALL=C readelf -h "$1" | sed -n "s/^ *$2: *//p"; }

# ---------- задание 1: ELF ----------
t1_types() {
    gcc -c main.c -o main.o && gcc -fPIC -shared seq.c -o libseq.so &&
    gcc -g -o progression main.c seq.c || return 1
    [ "$(hdr main.o Type | cut -d' ' -f1)" = REL ] && file main.o | grep -q relocatable &&
    [ "$(hdr libseq.so Type | cut -d' ' -f1)" = DYN ] && file libseq.so | grep -q 'shared object' &&
    [ "$(hdr progression Type | cut -d' ' -f1)" = DYN ] && file progression | grep -q 'pie executable'
}
t1_buildid() {
    local a b
    a=$(file progression | grep -oE 'BuildID\[sha1\]=[0-9a-f]+' | cut -d= -f2)
    b=$(LC_ALL=C readelf -n progression | grep -oE 'Build ID: [0-9a-f]+' | cut -d' ' -f3)
    [ -n "$a" ] && [ "$a" = "$b" ]
}
t1_counts() {
    [ "$(hdr progression 'Number of program headers')" -eq "$(LC_ALL=C readelf -lW progression | grep -cE '^  [A-Z_]+ +0x')" ] &&
    [ "$(hdr progression 'Number of section headers')" -eq "$(LC_ALL=C readelf -SW progression | grep -cE '^  \[ *[0-9]+\]')" ]
}
t1_entry() {
    local e
    e=$(hdr progression 'Entry point address' | sed 's/^0x//')
    objdump -d progression | grep -qE "^0*$e <_start>:"
}
t1_debug() { [ "$(LC_ALL=C readelf -SW progression | grep -c '\.debug_')" -ge 3 ] && [ -s "$LOGS/01-debug-sections.txt" ]; }

# ---------- задание 2: варианты сборки ----------
t2_list() {
    gcc -o p-plain main.c seq.c && gcc -O0 -g -o p-O0g main.c seq.c && gcc -O2 -g -o p-O2g main.c seq.c || return 1
    [ "$($GDB -ex 'list run' ./p-plain 2>&1 | grep -cE '^[0-9]+\s')" -eq 0 ] &&
    [ "$($GDB -ex 'list run' ./p-O0g 2>&1 | grep -cE '^[0-9]+\s')" -ge 5 ]
}
t2_optimized() { $GDB -x "$GDBDIR/variants.gdb" ./p-O2g 2>&1 | grep -q 'optimized out'; }
t2_nosrc() {
    mkdir -p b n && cp main.c seq.c seq.h b/ && (cd b && gcc -O0 -g -o p main.c seq.c) && mv b/p n/ && rm -rf b
    (cd n && $GDB -ex 'list run' ./p 2>&1) | grep -q 'seq.c: Нет такого файла\|seq.c: No such file' || return 1
    [ "$($GDB -ex 'list run' n/p 2>&1 | grep -cE '^[0-9]+\s')" -ge 5 ]   # исходники в текущем каталоге ($cwd)
}
t2_sizes() { [ "$(stat -c %s p-plain p-O0g p-O2g | sort -u | wc -l)" -eq 3 ]; }

# ---------- задание 3: поиск ошибки ----------
t3_warning() {
    # вывод сначала в файл: при "gcc | grep -q" grep выходит на первом совпадении,
    # gcc получает SIGPIPE и может не успеть создать ./bug
    LC_ALL=C gcc -Wall -O0 -g -o bug bug.c > warn.txt 2>&1 && [ -x bug ] &&
    grep -q "'bonus' is used uninitialized" warn.txt
}
t3_addresses() {
    $GDB -x "$GDBDIR/bug.gdb" ./bug > s 2>&1 || return 1
    local a b
    # print &field и print &bonus дают строки вида "$N = (int **) 0x..."
    a=$(grep -E '^\$[0-9]+ = \(int \*\*\) 0x' s | sed -n 1p | grep -oE '0x[0-9a-f]+')
    b=$(grep -E '^\$[0-9]+ = \(int \*\*\) 0x' s | sed -n 2p | grep -oE '0x[0-9a-f]+')
    [ -n "$a" ] && [ "$a" = "$b" ]
}
t3_backtrace() { [ "$(sed -n '/== стек вызовов/,/^percent/p' s | grep -cE '^#[0-9]+ ')" -ge 3 ]; }
t3_fix() {
    gcc -O0 -o bug-fixed bug-fixed.c || return 1
    ./bug > o1 && ./bug-fixed > o2 &&
    ! diff -q o1 "$CHK/expected-bug.txt" && diff o2 "$CHK/expected-bug.txt"
}

# ---------- задание 4: отладочная информация ----------
t4_strip() {
    gcc -O0 -g -o p-dbg main.c seq.c && cp p-dbg p-str && strip p-str || return 1
    [ "$(stat -c %s p-str)" -lt "$(stat -c %s p-dbg)" ] && file p-str | grep -q ', stripped' &&
    file p-dbg | grep -q 'not stripped' &&
    gdb -q -nx -ex quit ./p-str 2>&1 | grep -q 'No debugging symbols found' &&
    ! gdb -q -nx -ex quit ./p-dbg 2>&1 | grep -q 'No debugging symbols found'
}
t4_debuginfod_logs() {
    grep -q 'Downloading separate debug info' "$LOGS/04-debuginfod-local.txt" &&
    ! grep -q 'Downloading' "$LOGS/04-debuginfod-empty.txt" && grep -q '/debuginfo$' "$LOGS/04-debuginfod-cache.txt"
}
s_debuginfo_pkg() {
    rpm -q glibc-core-debuginfo && [ "$(rpm -ql glibc-core-debuginfo | grep -c '\.debug$')" -ge 1 ] &&
    grep -rqs 'x86_64 classic debuginfo' /etc/apt/sources.list.d/ &&
    $GDB -ex 'set breakpoint pending on' -ex 'break write' -ex 'run 1 > /dev/null' -ex bt ./p-dbg 2>&1 | grep -q 'write.c:'
}
s_debuginfod_live() {
    local port=$((20000 + RANDOM % 20000)) pid id
    mkdir -p store && cp p-dbg store/ || return 1
    debuginfod -F store -p $port -d "$WORK/db.sqlite" > dlog 2>&1 & pid=$!
    sleep 4
    id=$(LC_ALL=C readelf -n p-str | grep -oE 'Build ID: [0-9a-f]+' | cut -d' ' -f3)
    DEBUGINFOD_CACHE_PATH="$WORK/c0" DEBUGINFOD_URLS='' gdb -q -nx -iex 'set debuginfod enabled on' -ex quit ./p-str > g0 2>&1
    DEBUGINFOD_CACHE_PATH="$WORK/c1" DEBUGINFOD_URLS=http://127.0.0.1:$port gdb -q -nx -iex 'set debuginfod enabled on' -ex 'list run' -ex quit ./p-str > g1 2>&1
    kill $pid
    ! grep -q Downloading g0 && grep -q 'Downloading separate debug info' g1 && [ -s "$WORK/c1/$id/debuginfo" ]
}

# ---------- задание 5: сценарии gdb ----------
t5_make() { make -s progression >/dev/null && make check GDBDIR="$GDBDIR" CHKDIR="$CHK" >/dev/null 2>&1; }
t5_stable() {
    local n1 n2 n3
    n1=$($GDB -x "$GDBDIR/trace.gdb" ./progression < /dev/null 2>&1 | grep -c '^LAB5 ')
    n2=$($GDB -x "$GDBDIR/trace.gdb" ./progression < /dev/null 2>&1 | grep -c '^LAB5 ')
    n3=$($GDB -x "$GDBDIR/trace.gdb" ./progression < /dev/null 2>&1 | grep -c '^LAB5 ')
    [ "$n1" -gt 0 ] && [ "$n1" = "$n2" ] && [ "$n2" = "$n3" ]
}
t5_broken() {
    mkdir -p ck && cp "$CHK"/expected-*.txt ck/ && sed -i 's/value=15/value=16/' ck/expected-trace.txt
    ! make check GDBDIR="$GDBDIR" CHKDIR=ck >/dev/null 2>&1
}
t5_gdbinit() {
    mkdir -p d h && cp "$GDBDIR/local-gdbinit" d/.gdbinit &&
    sed "s|/home/user/lab05-work/gdbinit-demo|$WORK/d|" "$GDBDIR/home-gdbinit" > h/.gdbinit || return 1
    (cd d && gdb -q -batch -ex lab5hello 2>&1) | grep -q 'Undefined command' &&
    (cd d && HOME="$WORK/h" gdb -q -batch -ex lab5hello 2>&1) | grep -q 'LAB5 hello'
}

# ---------- задания 6-7: журналы ----------
l6_logs() {
    grep -q '/proc is not accessible' "$LOGS/06-gdb-no-proc.txt" &&
    grep -q 'mount point is not allowed' "$LOGS/06-mount-not-allowed.txt" &&
    grep -q '^proc /proc proc' "$LOGS/06-proc-mounted.txt" &&
    grep -q 'Breakpoint 1, emit' "$LOGS/06-gdb-with-proc.txt" &&
    grep -q '^proc /proc proc rw' "$LAB/env/hasher-priv-fstab" && grep -q '^allowed_mountpoints=/proc' "$LAB/env/hasher-priv-system" &&
    grep -q '^known_mountpoints=/proc' "$LAB/env/hasher-config"
}
l6_prepare() {
    grep -q 'создание окружения' "$LOGS/07-prepare-env2-first.log" && grep -q '^gdb-' "$LOGS/07-prepare-env2-first.log" &&
    grep -q 'не пересоздаётся' "$LOGS/07-prepare-env2-second.log" && grep -q '^gdb-' "$LOGS/07-prepare-env2-second.log"
}
l7_remote() {
    grep -q 'Listening on port 2345' "$LOGS/07-gdbserver.log" && grep -q 'Remote debugging from host 127.0.0.1' "$LOGS/07-gdbserver.log" &&
    grep -q 'Breakpoint 1, emit' "$LOGS/07-gdb-remote.txt" && grep -qE '^7\s+printf' "$LOGS/07-gdb-remote.txt"
}
l7_ptrace() {
    grep -q 'ptrace_scope = 1' "$LOGS/07-ptrace-scope-initial.txt" && grep -q 'ptrace:' "$LOGS/07-attach-scope1.txt" &&
    grep -q 'ptrace_scope = 0' "$LOGS/07-ptrace-scope-0.txt" && grep -q 'detached' "$LOGS/07-attach-scope0.txt" &&
    grep -q 'ptrace_scope = 1' "$LOGS/07-ptrace-scope-restored.txt" && grep -q 'ptrace:' "$LOGS/07-attach-restored.txt" &&
    [ "$(cat /proc/sys/kernel/yama/ptrace_scope)" = 1 ]
}
l7_groups() { id -Gn "$(id -un)" | tr ' ' '\n' | grep -cxE 'user_[abcd]' | grep -qx 4; }

# ---------- hasher: живая проверка ----------
h_gdb() {
    hsh-run --mountpoints=/proc "$HASHER_DIR" -- sh -c 'grep -q "^proc /proc" /proc/mounts && rpm -q gdb' < /dev/null &&
    hsh-run --mountpoints=/proc "$HASHER_DIR" -- sh -c 'cd ~ && gdb -q -batch -ex "break emit" -ex "run 2 >/dev/null" -ex bt ./progression' < /dev/null 2>&1 |
        grep -q 'Breakpoint 1, emit'
}
h_prepare() {
    sh "$LAB/env/prepare-hasher.sh" -w "$HASHER_DIR" -p gdb -c 'rpm -q gdb' 2>&1 | grep -q 'не пересоздаётся'
}

echo "== Задание 1: формат ELF"
check "1.1 REL, DYN (библиотека), DYN (PIE) по file и readelf" t1_types
check "1.2 Build ID из file и readelf -n совпадают"            t1_buildid
check "1.3 число заголовков программ и разделов"              t1_counts
check "1.4 точка входа есть в objdump -d (_start)"            t1_entry
check "1.5 разделы .debug_* в сборке с -g"                    t1_debug

echo "== Задание 2: варианты сборки"
check "2.1 list: без -g пусто, с -g строки исходника"         t2_list
check "2.2 -O2 -g: значения <optimized out>"                  t2_optimized
check "2.3 без исходников строк нет, в их каталоге - есть"    t2_nosrc
check "2.4 размеры трёх вариантов различаются"                t2_sizes

echo "== Задание 3: поиск ошибки"
check "3.1 -Wall: 'bonus' is used uninitialized"              t3_warning
check "3.2 адреса field и bonus совпадают"                    t3_addresses
check "3.3 стек вызовов не меньше трёх уровней"               t3_backtrace
check "3.4 до исправления вывод неверный, после - эталон"     t3_fix

echo "== Задание 4: отладочная информация"
check "4.1 strip: меньше, stripped, нет символов в gdb"       t4_strip
check "4.2 журналы debuginfod: загрузка и каталог кэша"       t4_debuginfod_logs

echo "== Задание 5: сценарии gdb"
check "5.1 make check: строки LAB5 совпадают с эталоном"       t5_make
check "5.2 три запуска - одинаковое число строк LAB5"         t5_stable
check "5.3 испорченный эталон - make check с ошибкой"         t5_broken
check "5.4 ./.gdbinit только после auto-load safe-path"       t5_gdbinit

echo "== Задания 6-7: журналы (права администратора)"
check "6.1 /proc: отказ, четыре условия, отладка в окружении" l6_logs
check "6.2 сценарий подготовки: создаёт, повторно - нет"      l6_prepare
check "7.1 gdbserver/gdb между двумя окружениями"            l7_remote
check "7.2 ptrace_scope: 1 отказ, 0 подключение, 1 отказ"    l7_ptrace
check "7.3 две пары служебных групп у пользователя"          l7_groups

echo "== Стенд: debuginfo и debuginfod"
if rpm -q glibc-core-debuginfo >/dev/null 2>&1; then
    check "4.3 glibc-core-debuginfo: символы libc в gdb"     s_debuginfo_pkg
else
    skip "4.3 glibc-core-debuginfo" "пакет не установлен"
fi
if command -v debuginfod >/dev/null 2>&1; then
    check "4.4 debuginfod: загрузка только при заданном URL"  s_debuginfod_live
else
    skip "4.4 локальный debuginfod" "нет debuginfod"
fi

echo "== Hasher ($HASHER_DIR)"
if command -v hsh >/dev/null 2>&1 && [ -d "$HASHER_DIR/chroot" ] &&
   hsh-run --mountpoints=/proc "$HASHER_DIR" -- true < /dev/null >/dev/null 2>&1; then
    check "6.3 /proc смонтирован, gdb в окружении работает"   h_gdb
    check "6.4 повторный запуск сценария не пересоздаёт"      h_prepare
else
    skip "6.3 gdb в окружении" "нет окружения или /proc не разрешён"
    skip "6.4 сценарий подготовки" "нет окружения или /proc не разрешён"
fi

echo
echo "Пройдено: $pass, не пройдено: $fail, пропущено: $skip"
[ "$fail" -eq 0 ]
