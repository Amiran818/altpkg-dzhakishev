#!/bin/bash
# Функциональная проверка лабораторной работы 4 (задания 1-7).
# Запуск: bash lab04/check/check-lab04.sh
#
# Группы, которые пропускаются (SKIP) при недоступности ресурса:
#   hasher - локальный репозиторий HASHER_DIR/repo (по умолчанию ~/hasher-lab04);
#   gear   - локальный gear-репозиторий GEAR_DIR (~/lab04-work/gear/dzhakishev-todo);
#   сеть   - опубликованный gear-репозиторий GEAR_URL.

set -u

LAB="$(cd "$(dirname "$0")/.." && pwd)"
HASHER_DIR="${HASHER_DIR:-$HOME/hasher-lab04}"
GEAR_DIR="${GEAR_DIR:-$HOME/lab04-work/gear/dzhakishev-todo}"
GEAR_URL="${GEAR_URL:-https://github.com/Amiran818/dzhakishev-todo}"
LOGS="$LAB/logs"
SRC="$LAB/sources"
CHK="$LAB/check"
TODO="$SRC/dzh-todo"
PKG11="$HASHER_DIR/repo/x86_64/RPMS.hasher/dzhakishev-todo-1.1-alt1.noarch.rpm"

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

# ---------- задание 1: оболочка ----------
t1_types() {
    local out
    out=$(bash -c 'shopt -s expand_aliases; alias ll="ls -l"; type -t cd; type -t ll; type -t sed; type -t echo')
    [ "$(echo "$out" | tr '\n' ' ')" = "builtin alias file builtin " ] &&
    [ "$(rpm -qf --qf '%{NAME}' /bin/sed)" = sed ] &&
    [ "$(rpm -qf --qf '%{NAME}\n' /bin/grep | sort -u)" = grep ] &&
    grep -q 'встроенная команда' "$LOGS/01-type.txt" && grep -q 'псевдонимом' "$LOGS/01-type.txt"
}
# shellcheck disable=SC2030,SC2031  # переменные меняются в подоболочках намеренно
t1_export() {
    local a b
    a=$(LAB_X=; unset LAB_X; LAB_X=v; bash -c 'echo "[$LAB_X]"')
    b=$(export LAB_X=v; bash -c 'echo "[$LAB_X]"')
    [ "$a" = "[]" ] && [ "$b" = "[v]" ] &&
    [ "$(LAB_X=p; bash -c 'LAB_X=c; export LAB_X'; echo "$LAB_X")" = p ]
}
t1_expansions() {
    local S="/usr/share/doc/lab04/report.tar.gz"
    [ "${S#*/}" = "usr/share/doc/lab04/report.tar.gz" ] && [ "${S##*/}" = "report.tar.gz" ] &&
    [ "${S%.*}" = "/usr/share/doc/lab04/report.tar" ] && [ "${S%%.*}" = "/usr/share/doc/lab04/report" ] &&
    [ "$(cut -d= -f2- "$LOGS/01-expansions.txt" | sort -u | wc -l)" -eq 4 ]
}
t1_redirect() {
    ls -d /etc/hostname /nonexistent > "$WORK/a" 2>&1
    # shellcheck disable=SC2069  # обратный порядок перенаправлений - предмет проверки
    ls -d /etc/hostname /nonexistent 2>&1 > "$WORK/b"
    ! cmp -s "$WORK/a" "$WORK/b" && [ "$(wc -l < "$WORK/a")" -eq 2 ] && [ "$(wc -l < "$WORK/b")" -eq 1 ]
}
t1_pipeline() { sh "$SRC/pipeline.sh" > "$WORK/p" && diff "$WORK/p" "$CHK/expected-pipeline.txt"; }

# ---------- задание 2: временные файлы ----------
t2_unique() {
    TMPDEMO_NAME="$WORK/n1" sh "$SRC/tmpdemo.sh" && TMPDEMO_NAME="$WORK/n1" sh "$SRC/tmpdemo.sh" &&
    [ "$(sort -u "$WORK/n1" | wc -l)" -eq 2 ]
}
t2_perms() {
    local f d
    f=$(mktemp) && d=$(mktemp -d) || return 1
    [ "$(stat -c %a "$f")" = 600 ] && [ "$(stat -c %a "$d")" = 700 ]; local rc=$?
    rm -f "$f"; rmdir "$d"; return $rc
}
t2_removed() {
    local f
    while read -r f; do [ ! -e "$f" ] || return 1; done < "$WORK/n1"
    TMPDEMO_NAME="$WORK/n2" sh "$SRC/tmpdemo.sh" error; [ $? -eq 2 ] && [ ! -e "$(cat "$WORK/n2")" ]
}
t2_signals() {
    local pid rc
    TMPDEMO_NAME="$WORK/n3" sh "$SRC/tmpdemo.sh" wait 30 & pid=$!
    sleep 1; [ -e "$(cat "$WORK/n3")" ] || return 1
    kill -TERM $pid; wait $pid; rc=$?
    [ $rc -eq 143 ] && [ ! -e "$(cat "$WORK/n3")" ] || return 1
    (sleep 1; printf '\003') | TMPDEMO_NAME="$WORK/n4" script -qec "sh $SRC/tmpdemo.sh wait 30" /dev/null >/dev/null
    rc=$?
    [ $rc -eq 130 ] && [ -s "$WORK/n4" ] && [ ! -e "$(cat "$WORK/n4")" ]
}
t2_dryrun() {
    local u
    u=$(mktemp -u) && [ ! -e "$u" ] && ! mktemp -u "$WORK/lab.XX" && mktemp -u "$WORK/lab.XXX"
}

# ---------- задание 3: обработка текста ----------
t3_locale() {
    locale -a | grep -qi '^ru_RU.utf8$' || return 1
    LC_ALL=ru_RU.UTF-8 sort "$LOGS/03-pid-user.txt" > "$WORK/u"
    LC_ALL=ru_RU.UTF-8 sort "$LOGS/03-pid-comm.txt" > "$WORK/c"
    LC_ALL=ru_RU.UTF-8 join "$WORK/u" "$WORK/c" > /dev/null 2> "$WORK/err"
    grep -q 'not sorted\|не отсортирован' "$WORK/err" || return 1
    LC_ALL=C sort "$LOGS/03-pid-user.txt" > "$WORK/u"
    LC_ALL=C sort "$LOGS/03-pid-comm.txt" > "$WORK/c"
    LC_ALL=C join "$WORK/u" "$WORK/c" > "$WORK/j" 2> "$WORK/err" && [ ! -s "$WORK/err" ] || return 1
    local ids
    ids=$(LC_ALL=C comm -12 <(awk '{print $1}' "$WORK/u" | LC_ALL=C sort) <(awk '{print $1}' "$WORK/c" | LC_ALL=C sort) | wc -l)
    [ "$(wc -l < "$WORK/j")" -ge "$ids" ]
}
t3_hex() {
    local f="$LOGS/03-fragment.txt" a b c
    a=$(hexdump -C "$f" | cut -c11-58 | tr -s ' \n' ' ' | sed 's/^ //; s/ $//')
    b=$(od -A n -t x1 "$f" | tr -s ' \n' ' ' | sed 's/^ //; s/ $//')
    c=$(xxd -p "$f" | tr -d '\n' | sed 's/../& /g; s/ $//')
    [ -n "$a" ] && [ "$a" = "$b" ] && [ "$b" = "$c" ]
}
t3_owners() {
    local u
    u=$(for x in hexdump od xxd; do rpm -qf --qf '%{NAME}\n' "$(command -v $x)" | sort -u; done | sort -u | wc -l)
    [ "$u" -eq 3 ]
}
t3_sponge() {
    printf 'c\nb\na\n' > "$WORK/r"; printf 'c\nb\na\n' > "$WORK/s"
    # shellcheck disable=SC2094  # потеря данных при чтении и записи одного файла - предмет проверки
    sort "$WORK/r" > "$WORK/r"
    sort "$WORK/s" | sponge "$WORK/s"
    [ ! -s "$WORK/r" ] && [ "$(tr -d '\n' < "$WORK/s")" = abc ]
}

# ---------- задание 4: dzh-todo ----------
todo() { XDG_CONFIG_HOME="$WORK/cfg" sh "$TODO" "$@"; }
t4_init() {
    rm -rf "$WORK/cfg"
    todo list > /dev/null && [ -f "$WORK/cfg/dzh-todo/tasks" ] || return 1
    todo add "запись" > /dev/null && todo list > /dev/null
    [ "$(wc -l < "$WORK/cfg/dzh-todo/tasks")" -eq 1 ]
}
t4_sequence() {
    rm -rf "$WORK/cfg"
    { todo add "купить молоко"; todo add "сдать лабораторную работу 4"; todo add "позвонить"
      todo "done" 2; todo list; } > "$WORK/seq" && diff "$WORK/seq" "$CHK/expected-todo.txt"
}
t4_spaces() {
    [ "$(wc -l < "$WORK/cfg/dzh-todo/tasks")" -eq 3 ] &&
    grep -qx '1|сдать лабораторную работу 4' "$WORK/cfg/dzh-todo/tasks"
}
t4_dialog() {
    mkdir -p "$WORK/tmp"
    (sleep 1; printf e; sleep 0.3; printf '\r') |
        LC_ALL=C.UTF-8 TMPDIR="$WORK/tmp" XDG_CONFIG_HOME="$WORK/cfg" TERM=xterm-256color \
        script -qec "stty rows 24 cols 80; sh $TODO; echo \"dzh-todo rc=\$?\"" "$WORK/session" > /dev/null
    grep -aq 'dzh-todo rc=0' "$WORK/session" && grep -aq 'Список задач dzh-todo' "$WORK/session" &&
    [ -z "$(ls -A "$WORK/tmp")" ]
}

# ---------- задание 5: пакет сценария (журналы) ----------
t5_findreq() {
    grep -q 'FINDPACKAGE-COMMANDS:.* dialog ' "$LOGS/05-find-requires.txt" &&
    grep -q '^/bin/sh$' "$LOGS/05-requires.txt" &&
    [ "$(grep -cxE 'coreutils|dialog|grep|sed|termutils' "$LOGS/05-requires.txt")" -ge 2 ] &&
    ! grep -Eq '^(Requires|BuildRequires|PreReq):' "$LAB/specs/dzhakishev-todo.spec"
}
t5_no_builddep() {
    grep -q 'sisyphus_check passed' "$LOGS/05-hsh-build.log" &&
    ! grep -Eq 'dialog-[0-9]' "$LOGS/05-hsh-build.log"
}
t5_install() {
    grep -q 'dialog is needed by dzhakishev-todo-1.0-alt1' "$LOGS/05-install-fail.txt" &&
    grep -qx 'rpm -i rc=1' "$LOGS/05-install-fail.txt" && grep -qx 'rpm -i rc=0' "$LOGS/05-install-ok.txt" &&
    sed 1d "$LOGS/05-run-in-hasher.txt" | diff - "$CHK/expected-todo.txt"
}

# ---------- задания 6-7: журналы GEAR ----------
t6_logs() {
    [ "$(sort -u "$LOGS/06-nvr.txt")" = "dzhakishev-todo 1.0 alt1" ] && [ "$(wc -l < "$LOGS/06-nvr.txt")" -eq 2 ] &&
    grep -qx 'copy: dzh-todo' "$LAB/specs/gear-rules"
}
t7_logs() {
    grep -q 'Added "count" command' "$LOGS/07-commit-message.txt" &&
    grep -q '1.1-alt1' "$LOGS/07-changelog-1.1.txt" && grep -qx 'count: 1' "$LOGS/07-run-1.1.txt" &&
    grep -qx 'dzhakishev-todo 1.0-alt1' "$LOGS/07-old-nvr.txt" && grep -qx 'rc=1' "$LOGS/07-run-1.0.txt" &&
    grep -qx 'dzhakishev-todo 1.1-alt1' "$LOGS/07-clone-nvr.txt"
}

# ---------- gear: локальный репозиторий ----------
g_struct() {
    cd "$GEAR_DIR" || return 1
    [ -f .gear/rules ] && git rev-parse -q --verify refs/heads/master && git rev-parse -q --verify refs/heads/srpms &&
    git rev-parse -q --verify refs/tags/1.0-alt1 && git rev-parse -q --verify refs/tags/1.1-alt1
}
g_tree() {
    cd "$GEAR_DIR" || return 1
    [ "$(git ls-tree --name-only -r HEAD | LC_ALL=C sort | tr '\n' ' ')" = ".gear/rules dzh-todo dzhakishev-todo.spec " ] &&
    file dzh-todo | grep -q 'shell script'
}
g_commit() {
    cd "$GEAR_DIR" || return 1
    local msg log
    msg=$(git log -1 --format=%B 1.1-alt1)
    log=$(sed -n '/^%changelog/{n;n;p;q}' dzhakishev-todo.spec)
    [[ "$msg" == *"$log"* ]] && [ "$(git log -1 --format=%ae 1.1-alt1)" = dzhakishev@altlinux.org ]
}

# ---------- hasher ----------
h_new() {
    [ "$(rpm -qp --qf '%{VERSION}-%{RELEASE}' "$PKG11")" = 1.1-alt1 ] &&
    rpm -qp --changelog "$PKG11" | head -2 | grep -q 'count'
}

# ---------- сеть ----------
n_remote() {
    git ls-remote "$GEAR_URL" > "$WORK/ls" || return 1
    grep -q 'refs/heads/master$' "$WORK/ls" && grep -q 'refs/tags/1.0-alt1$' "$WORK/ls" && grep -q 'refs/tags/1.1-alt1$' "$WORK/ls"
}

echo "== Задание 1: оболочка"
check "1.1 классы команд: builtin, alias, file; пакеты"      t1_types
check "1.2 export: видимость в дочерней, нет обратной"      t1_export
check "1.3 четыре подстановки - четыре результата"          t1_expansions
check "1.4 порядок перенаправлений меняет результат"        t1_redirect
check "1.5 конвейер совпадает с эталоном"                   t1_pipeline

echo "== Задание 2: временные файлы"
check "2.1 два запуска - разные имена"                      t2_unique
check "2.2 права 600 (файл) и 700 (каталог)"                t2_perms
check "2.3 удаление после штатного и аварийного выхода"     t2_removed
check "2.4 удаление по SIGTERM и по ^C"                     t2_signals
check "2.5 mktemp -u не создаёт файл, XX отвергается"       t2_dryrun

echo "== Задание 3: обработка текста"
check "3.1 join: ошибка в ru_RU, без ошибок в C"            t3_locale
check "3.2 hexdump, od, xxd - одни и те же байты"           t3_hex
check "3.3 три разных пакета-владельца"                     t3_owners
check "3.4 sort f > f теряет данные, sponge - нет"          t3_sponge

echo "== Задание 4: dzh-todo"
check "4.1 первый запуск создаёт файл, повтор не стирает"   t4_init
check "4.2 последовательность совпадает с эталоном"         t4_sequence
check "4.3 запись с пробелами - одна запись"                t4_spaces
check "4.4 диалог в псевдотерминале: код 0, меню, нет tmp"  t4_dialog

echo "== Задания 5-7: журналы"
check "5.1 вычислены зависимости, в spec их нет"            t5_findreq
check "5.2 dialog не нужен для сборки"                      t5_no_builddep
check "5.3 без dialog отказ, с dialog работает"             t5_install
check "6.1 пакеты из spec и из gear совпадают"              t6_logs
check "7.1 новая версия, старый тег, сборка из клона"       t7_logs

echo "== Gear: локальный репозиторий ($GEAR_DIR)"
if [ -d "$GEAR_DIR/.git" ]; then
    check "6.2 .gear/rules, ветки master/srpms, теги"       g_struct
    check "6.3 сценарий и spec в несжатом виде"             g_tree
    check "7.2 сообщение коммита = запись changelog"        g_commit
else
    for n in "6.2 структура gear-репозитория" "6.3 файлы в несжатом виде" "7.2 сообщение коммита"; do
        skip "$n" "нет $GEAR_DIR"
    done
fi

echo "== Hasher ($HASHER_DIR/repo)"
if command -v hsh >/dev/null 2>&1 && [ -f "$PKG11" ]; then
    check "7.3 пакет 1.1-alt1 с новой записью changelog"    h_new
else
    skip "7.3 пакет 1.1-alt1" "нет $PKG11"
fi

echo "== Сеть ($GEAR_URL)"
if timeout 15 git ls-remote "$GEAR_URL" >/dev/null 2>&1; then
    check "7.4 опубликованы master и теги обеих версий"     n_remote
else
    skip "7.4 опубликованный gear-репозиторий" "нет доступа к $GEAR_URL"
fi

echo
echo "Пройдено: $pass, не пройдено: $fail, пропущено: $skip"
[ "$fail" -eq 0 ]
