#!/bin/bash
# Функциональная проверка лабораторной работы 2 (задания 1-7).
# Запуск: bash lab02/check/check-lab02.sh
#
# Группы проверок:
#   локальные   - выполняются всегда (терминал, программа Show, make, журналы);
#   стенд       - используют пакеты, собранные на стенде (каталог MANUAL_DIR);
#   hasher      - используют изолированное окружение (каталог HASHER_DIR).
# Если каталога стенда или окружения hasher нет, проверки группы
# пропускаются (SKIP) и не считаются ошибкой.

set -u

LAB="$(cd "$(dirname "$0")/.." && pwd)"
HASHER_DIR="${HASHER_DIR:-$HOME/hasher-lab02}"
MANUAL_DIR="${MANUAL_DIR:-$HOME/lab02-work/manual}"
LOGS="$LAB/logs"
SRC="$LAB/sources"
CHK="$LAB/check"

NAME=dzhakishev-show
NVR=$NAME-1.0-alt1
ARCH=$(uname -m)
MANUAL_RPM="$MANUAL_DIR/$NVR.$ARCH.rpm"
REPO="$HASHER_DIR/repo"
TAB=$(printf '\t')

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

# сеанс в псевдотерминале: $1 - каталог, $2 - команда, $3 - файл протокола;
# клавиши «пробел, пробел, q» подаются через секунду после запуска
pty_run() {
    (sleep 1; printf '  q') |
        (cd "$1" && TERM=xterm-256color script -qec "$2" "$3") >/dev/null
}

# тело протокола script без строк «Script started/done»
pty_body() { sed '1d' "$1" | head -n -2; }

# ---------- задание 1: терминал ----------
t1_clear() {
    printf '\033[H\033[2J' > "$WORK/c1"
    TERM=xterm-256color tput -x clear > "$WORK/c2"
    cmp "$WORK/c1" "$WORK/c2" && cmp "$LOGS/01-clear-printf.bin" "$LOGS/01-clear-tput.bin"
}
t1_stty() {
    local f="$LOGS/stty-before.txt"
    grep -q 'intr = \^C;' "$f" && grep -q ' erase = \^?;' "$f" &&
    grep -q ' kill = \^U;' "$f" && grep -q ' eof = \^D;' "$f" &&
    grep -q '^hello pal' "$LOGS/01-ctrl-erase-kill-eof.txt" &&
    grep -q 'script rc=130' "$LOGS/01-ctrl-intr.txt"
}
t1_infocmp() {
    [ "$(infocmp -1 vt100 | wc -l)" -ne "$(infocmp -1 xterm-256color | wc -l)" ] &&
    ! diff -q <(infocmp -1 vt100) <(infocmp -1 xterm-256color) &&
    [ "$(tput -Tvt100 colors)" != "$(tput -Txterm-256color colors)" ]
}
t1_overstrike() {
    xzcat /usr/share/man/man1/ls.1.xz | nroff -man 2>/dev/null | hexdump -C > "$WORK/man.hex"
    grep -Eq '([0-9a-f]{2}) 08 \1' "$WORK/man.hex" && grep -q '5f 08' "$WORK/man.hex"
}
t1_wrong_term() {
    # у adm3a своя последовательность очистки (\032), у xterm - ANSI
    [ "$(TERM=adm3a tput clear | od -An -c | tr -d ' ')" != "$(TERM=xterm-256color tput -x clear | od -An -c | tr -d ' ')" ] &&
    [ "$(TERM=xterm-256color tput cup 0 0 | od -An -c | tr -d ' ')" = '033[1;1H' ]
}

# ---------- задание 2: программа Show ----------
t2_link() {
    mkdir -p "$WORK/b" && cp "$SRC/show.c" "$WORK/b/"
    ! gcc -o "$WORK/b/x" "$WORK/b/show.c" > "$WORK/b/err" 2>&1 &&
    grep -q 'undefined reference' "$WORK/b/err" &&
    grep -q 'undefined reference' "$LOGS/02-build-no-lib.txt" &&
    gcc -Wall -o "$WORK/b/Show" "$WORK/b/show.c" -lncurses
}
t2_errors() {
    local rc out
    "$WORK/b/Show" > "$WORK/o1" 2> "$WORK/e1"; rc=$?
    [ "$rc" -ne 0 ] && [ ! -s "$WORK/o1" ] && [ -s "$WORK/e1" ] || return 1
    "$WORK/b/Show" /no/such/file > "$WORK/o2" 2> "$WORK/e2"; rc=$?
    out=$(cat "$WORK/e2")
    [ "$rc" -ne 0 ] && [ ! -s "$WORK/o2" ] && [[ "$out" == *"/no/such/file"* ]]
}
t2_pty() {
    mkdir -p "$WORK/p/sources" "$WORK/p/check"
    cp "$WORK/b/Show" "$WORK/p/sources/" && cp "$CHK/sample.txt" "$WORK/p/check/"
    pty_run "$WORK/p/sources" "stty rows 24 cols 80; stty -a > ../before; ./Show ../check/sample.txt; echo \"Show rc=\$?\"; stty -a > ../after" "$WORK/p/session" &&
    grep -aq 'Show rc=0' "$WORK/p/session" &&
    grep -aq 'File: ../check/sample.txt' "$WORK/p/session" &&
    grep -aqF "$(head -1 "$CHK/sample.txt")" "$WORK/p/session"
}
t2_stty() { diff "$WORK/p/before" "$WORK/p/after" && diff "$LOGS/02-stty-pty-before.txt" "$LOGS/02-stty-pty-after.txt"; }

# ---------- задание 3: make ----------
t3_make() {
    mkdir -p "$WORK/m" && cp "$SRC/show.c" "$SRC/Makefile" "$WORK/m/"
    make -C "$WORK/m" > "$WORK/m1" 2>&1 && [ -x "$WORK/m/Show" ]
}
t3_uptodate() {
    make -C "$WORK/m" > "$WORK/m2" 2>&1 && ! grep -q 'gcc' "$WORK/m2" || return 1
    touch "$WORK/m/show.c"
    make -C "$WORK/m" > "$WORK/m3" 2>&1 && grep -q 'gcc .* -c .*show.c' "$WORK/m3"
}
t3_clean() { make -C "$WORK/m" clean >/dev/null 2>&1 && [ ! -e "$WORK/m/Show" ] && [ ! -e "$WORK/m/show.o" ]; }
t3_tab() {
    [ "$(hexdump -C "$SRC/Makefile" | grep -c '0a 09')" -ge 1 ] &&
    [ "$(grep -c "^$TAB" "$SRC/Makefile")" -ge 3 ] && ! grep -Eq '^ +(\$\(CC\)|rm )' "$SRC/Makefile"
}
t3_spaces() {
    sed "s/^$TAB/        /" "$SRC/Makefile" > "$WORK/Makefile.spaces"
    ! make -f "$WORK/Makefile.spaces" -C "$WORK/m" > "$WORK/m4" 2>&1 &&
    grep -Eq 'missing separator|пропущен разделитель' "$WORK/m4" &&
    grep -Eq 'missing separator|пропущен разделитель' "$LOGS/03-make-spaces.txt"
}

# ---------- задание 4: сопровождающий (журналы) ----------
t4_no_packager() {
    grep -q 'check-packager ERROR' "$LOGS/04-hsh-no-packager.log" &&
    grep -q 'sisyphus_check failed' "$LOGS/04-hsh-no-packager.log"
}
t4_config() {
    local p
    p=$(sed -n 's/^packager="\(.*\)"$/\1/p' "$LAB/env/hasher-config")
    [ -n "$p" ] && grep -qF "%packager $p" "$LOGS/04-rpmmacros.txt" &&
    grep -qF "$p" "$LAB/specs/$NAME.spec" &&
    grep -q 'sisyphus_check passed' "$LOGS/04-hsh-with-packager.log"
}
t4_devel() {
    [ "$(grep -c '\.h$' "$LOGS/04-ql-libncurses-devel.txt")" -ge 1 ] &&
    grep -q '/usr/lib64/libform.so$' "$LOGS/04-ql-libncurses-devel.txt" &&
    { [ ! -e /usr/lib64/libform.so ] || [ -L /usr/lib64/libform.so ]; }
}

# ---------- задание 5: архив и сборка (журналы) ----------
t5_tarball() {
    local list
    sh "$SRC/make-tarball.sh" "$WORK" >/dev/null || return 1
    list=$(tar tzf "$WORK/$NAME-1.0.tar.gz" | sort | tr '\n' ' ')
    [ "$list" = "$NAME-1.0/ $NAME-1.0/Makefile $NAME-1.0/show.c " ]
}
t5_buildlog() {
    local l="$LOGS/05-rpmbuild-show.log"
    grep -q "gzip -dc .*/$NAME-1.0.tar.gz" "$l" && grep -q 'tar -xf' "$l" &&
    grep -q '+ make -j' "$l" && grep -q "Wrote: .*/$NVR.$ARCH.rpm" "$l"
}
t5_sessions() {
    diff <(pty_body "$LOGS/02-session-manual.txt") "$LOGS/05-session-hasher.txt" &&
    grep -qx '/usr/bin/Show' "$LOGS/05-installed.txt"
}

# ---------- задание 6: зависимости (журналы) ----------
t6_logs() {
    grep -q "libncurses.so.6()(64bit).*is needed by $NVR" "$LOGS/06-install-fail.txt" &&
    grep -qx 'rpm -i rc=1' "$LOGS/06-install-fail.txt" &&
    grep -q '^libncurses.so.6()(64bit)' "$LOGS/06-requires.txt"
}
t6_installed() {
    grep -qx 'rpm -i rc=0' "$LOGS/06-install-ok.txt" &&
    grep -qx "$NVR.$ARCH" "$LOGS/06-install-ok.txt" &&
    grep -q '^libncurses6-' "$LOGS/06-install-ok.txt" &&
    ! grep -q '^libncurses-devel-' "$LOGS/06-install-ok.txt" &&
    grep -aq 'Show rc=0' "$LOGS/06-session-no-devel.txt"
}

# ---------- стенд: собранный пакет ----------
s_one_file() { [ "$(rpm -qpl "$MANUAL_RPM")" = /usr/bin/Show ]; }
s_requires() {
    rpm -qp --requires "$MANUAL_RPM" > "$WORK/req" &&
    grep -q '^libncurses.so.6()(64bit)' "$WORK/req" && ! grep -q devel "$WORK/req" &&
    ! grep -Eiq '^(Requires|PreReq):' "$LAB/specs/$NAME.spec"
}

# ---------- hasher: локальный репозиторий ----------
nvr() { rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$1"; }
h_repo() {
    [ -f "$REPO/SRPMS.hasher/$NVR.src.rpm" ] && [ -f "$REPO/$ARCH/RPMS.hasher/$NVR.$ARCH.rpm" ] &&
    [ "$(nvr "$REPO/SRPMS.hasher/$NVR.src.rpm")" = "$(nvr "$REPO/$ARCH/RPMS.hasher/$NVR.$ARCH.rpm")" ]
}
h_debuginfo() { [ -f "$REPO/$ARCH/RPMS.hasher/$NAME-debuginfo-1.0-alt1.$ARCH.rpm" ]; }
h_comm() {
    rpm -qpl "$REPO/$ARCH/RPMS.hasher/$NVR.$ARCH.rpm" | sort > "$WORK/q1"
    rpm -qpl "$REPO/$ARCH/RPMS.hasher/$NAME-debuginfo-1.0-alt1.$ARCH.rpm" | sort > "$WORK/q2"
    [ -s "$WORK/q1" ] && [ -s "$WORK/q2" ] && [ -z "$(comm -12 "$WORK/q1" "$WORK/q2")" ]
}
h_arch() {
    local d dirs=""
    for d in "$REPO"/*/; do
        d=$(basename "$d")
        [ "$d" = SRPMS.hasher ] || dirs="$dirs$d "
    done
    [ "$dirs" = "$ARCH " ]
}
h_packager() {
    local p
    p=$(sed -n 's/^packager="\(.*\)"$/\1/p' "$LAB/env/hasher-config")
    [ "$(rpm -qp --qf '%{PACKAGER}' "$REPO/$ARCH/RPMS.hasher/$NVR.$ARCH.rpm")" = "$p" ]
}

echo "== Задание 1: терминал"
check "1.1 очистка экрана: printf и tput дают одни байты"       t1_clear
check "1.2 intr/erase/kill/eof в stty -a и их действие"          t1_stty
check "1.3 infocmp vt100 и xterm-256color различаются"          t1_infocmp
check "1.4 в man-странице есть X^HX и _^HX"                     t1_overstrike
check "1.5 неверный TERM даёт чужие последовательности"         t1_wrong_term

echo "== Задание 2: программа Show"
check "2.1 без -lncurses ошибка ссылок, с -lncurses сборка"     t2_link
check "2.2 ошибки: код != 0, сообщение в stderr"                t2_errors
check "2.3 псевдотерминал «пробел, пробел, q»: код 0"           t2_pty
check "2.4 stty -a до и после совпадают"                        t2_stty

echo "== Задание 3: make"
check "3.1 make в чистом каталоге создаёт Show"                 t3_make
check "3.2 повтор без пересборки, после touch - компиляция"     t3_uptodate
check "3.3 make clean удаляет Show и show.o"                    t3_clean
check "3.4 рецепты начинаются с байта 09"                        t3_tab
check "3.5 пробелы вместо TAB: missing separator"               t3_spaces

echo "== Задания 4-6: журналы сборки"
check "4.1 без сопровождающего sisyphus_check отказал"          t4_no_packager
check "4.2 packager в конфигурации, .rpmmacros и spec"          t4_config
check "4.3 libncurses-devel: заголовки и ссылки .so"            t4_devel
check "5.1 архив: один каталог $NAME-1.0"                       t5_tarball
check "5.2 журнал: распаковка архива и вызов make"              t5_buildlog
check "5.3 протоколы сеансов (стенд и hasher) совпадают"        t5_sessions
check "6.1 без libncurses6 установка отклонена"                 t6_logs
check "6.2 с libncurses6 без devel пакет работает"              t6_installed

echo "== Стенд: собранный пакет ($MANUAL_DIR)"
if [ -f "$MANUAL_RPM" ]; then
    check "5.4 в пакете ровно /usr/bin/Show"                    s_one_file
    check "6.3 Requires: libncurses.so.6, без devel"            s_requires
else
    skip "5.4 в пакете ровно /usr/bin/Show" "нет $MANUAL_RPM"
    skip "6.3 Requires: libncurses.so.6, без devel" "нет $MANUAL_RPM"
fi

echo "== Hasher: локальный репозиторий ($REPO)"
if command -v hsh >/dev/null 2>&1 && [ -d "$REPO" ]; then
    check "7.1 src.rpm и rpm с одинаковыми NVR"                 h_repo
    check "7.2 сформирован подпакет debuginfo"                   h_debuginfo
    check "7.3 файлы пакета и debuginfo не пересекаются"        h_comm
    check "7.4 каталог репозитория = uname -m ($ARCH)"           h_arch
    check "4.4 Packager собранного пакета из конфигурации"      h_packager
else
    for n in "7.1 src.rpm и rpm с одинаковыми NVR" "7.2 сформирован подпакет debuginfo" \
             "7.3 файлы пакета и debuginfo не пересекаются" "7.4 каталог репозитория = uname -m" \
             "4.4 Packager собранного пакета из конфигурации"; do
        skip "$n" "нет hasher или $REPO"
    done
fi

echo
echo "Пройдено: $pass, не пройдено: $fail, пропущено: $skip"
[ "$fail" -eq 0 ]
