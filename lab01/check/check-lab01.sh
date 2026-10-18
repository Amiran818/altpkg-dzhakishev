#!/bin/bash
# Функциональная проверка лабораторной работы 1 (задания 2-7).
# Запуск: bash lab01/check/check-lab01.sh
# Каталоги стенда можно переопределить переменными HASHER_DIR и MANUAL_DIR.

set -u

LAB="$(cd "$(dirname "$0")/.." && pwd)"
HASHER_DIR="${HASHER_DIR:-$HOME/hasher}"
MANUAL_DIR="${MANUAL_DIR:-$HOME/lab01-work/manual}"
LOGS="$LAB/logs"
ENV="$LAB/env"

PKG=dzhakishev-hello
NVR=$PKG-1.0-alt1
MANUAL_RPM="$MANUAL_DIR/$NVR.noarch.rpm"
MANUAL_SRPM="$MANUAL_DIR/$NVR.src.rpm"
AUTO_RPM="$HASHER_DIR/repo/x86_64/RPMS.hasher/$NVR.noarch.rpm"
AUTO_SRPM="$HASHER_DIR/repo/SRPMS.hasher/$NVR.src.rpm"

pass=0
fail=0

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

# ---------- задание 2 ----------
t2_repos() { apt-repo list | grep -q 'p11/branch'; }
t2_course_pkgs() { bash "$LAB/check/check-packages.sh"; }
t2_privd() { [ "$(systemctl is-enabled hasher-privd)" = enabled ] && [ "$(systemctl is-active hasher-privd)" = active ]; }
t2_env_files() {
    [ -s "$ENV/repos.txt" ] && [ -s "$ENV/host-packages.txt" ] &&
    [ "$(wc -l < "$ENV/host-packages.txt")" -eq "$(rpm -qa | wc -l)" ]
}

# ---------- задание 3 ----------
t3_devel_files() {
    local h l=0 f
    h=$(rpm -ql libjpeg-devel | grep -c '/include/.*\.h$')
    for f in $(rpm -ql libjpeg-devel | grep '\.so$'); do
        [ -L "$f" ] && l=$((l + 1))
    done
    [ "$h" -ge 1 ] && [ "$l" -ge 1 ]
}
t3_qf() { [ "$(rpm -qf --qf '%{NAME}' /usr/include/jpeglib.h)" = libjpeg-devel ]; }
t3_whatprovides() { [ "$(rpm -q --whatprovides --qf '%{NAME}' libjpeg)" = libjpeg ]; }
t3_logs() {
    local f
    for f in 03-libjpeg-requires.txt 03-libjpeg-provides.txt 03-libjpeg-whatrequires-soname.txt \
             03-libjpeg-devel-ql.txt 03-rpm-qf-jpeglib.txt 03-libjpeg-devel-requires.txt; do
        [ -s "$LOGS/$f" ] || return 1
    done
}

# ---------- задание 4 ----------
t4_groups() {
    local g
    g=" $(id -Gn "$(id -un)") "
    [[ "$g" == *" hashman "* && "$g" == *" $(id -un)_a "* && "$g" == *" $(id -un)_b "* ]]
}
t4_initroot_log() { grep -q 'Created RPM build directory tree' "$LOGS/04-hsh-initroot.log"; }
t4_users() {
    grep -qx 'builder' "$LOGS/04-hsh-shell-builder.txt" &&
    grep -qx 'root' "$LOGS/04-hsh-shell-rooter.txt"
}
t4_rpm_tree() {
    local d
    for d in BUILD SOURCES SPECS RPMS SRPMS; do
        [ -d "$HASHER_DIR/chroot/usr/src/RPM/$d" ] || return 1
    done
}
t4_which_tree() { grep -qx 'which rc=0' "$LOGS/04-hsh-shell-builder.txt"; }
t4_config() { [ -s "$ENV/hasher-config" ] && grep -q '^packager=' "$ENV/hasher-config"; }

# ---------- задание 5 ----------
t5_build() { grep -q 'Wrote: .*SRPMS/dzhakishev-null-1.0-alt1.src.rpm' "$LOGS/05-rpmbuild-null.log" &&
             grep -q 'Wrote: .*RPMS/noarch/dzhakishev-null-1.0-alt1.noarch.rpm' "$LOGS/05-rpmbuild-null.log"; }
t5_empty() { grep -q 'файлов в пакете: 0' "$LOGS/05-null-check.txt"; }
t5_meta() {
    local spec="$LAB/specs/dzhakishev-null.spec" k v
    for k in Name Version Release License; do
        v=$(sed -n "s/^$k: *//p" "$spec")
        grep -Eq "^$k +: $v\$" "$LOGS/05-null-check.txt" || return 1
    done
}
t5_installed() { grep -qx 'dzhakishev-null-1.0-alt1.noarch' "$LOGS/05-null-install.txt" &&
                 grep -qx 'which rc=1' "$LOGS/05-null-install.txt"; }

# ---------- задание 6 ----------
t6_one_file() { [ "$(rpm -qpl "$MANUAL_RPM")" = "/usr/bin/$PKG" ]; }
t6_output() { sh "$LAB/sources/$PKG.sh" | diff - "$LAB/check/expected.txt" &&
              grep -q 'diff: различий нет' "$LOGS/06-hello-install-run-remove.txt"; }
t6_requires() {
    [ "$(rpm -qp --requires "$MANUAL_RPM" | grep -v '^rpmlib(')" = /bin/sh ] &&
    ! grep -Eiq '^(Requires|PreReq)' "$LAB/specs/$PKG.spec"
}
t6_removed() { grep -qx 'which rc=1' "$LOGS/06-hello-install-run-remove.txt" &&
               grep -qx 'запуск после удаления rc=127' "$LOGS/06-hello-install-run-remove.txt"; }

# ---------- задание 7 ----------
nvr() { rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$1"; }
t7_auto() { [ -f "$AUTO_RPM" ] && [ "$(nvr "$AUTO_RPM")" = "$(nvr "$MANUAL_RPM")" ]; }
t7_files() { diff <(rpm -qpl "$MANUAL_RPM" | sort) <(rpm -qpl "$AUTO_RPM" | sort); }
t7_sha256() {
    local tmp a b
    tmp=$(mktemp -d)
    mkdir "$tmp/m" "$tmp/a"
    (cd "$tmp/m" && rpm2cpio "$MANUAL_SRPM" | cpio -id --quiet)
    (cd "$tmp/a" && rpm2cpio "$AUTO_SRPM" | cpio -id --quiet)
    a=$(sha256sum < "$tmp/m/$PKG.sh")
    b=$(sha256sum < "$tmp/a/$PKG.sh")
    rm -rf "$tmp"
    [ "$a" = "$b" ]
}
t7_envs() {
    [ "$(wc -l < "$LOGS/07-hasher-packages.txt")" -lt "$(wc -l < "$LOGS/07-host-packages.txt")" ] &&
    [ -s "$LOGS/07-only-host.txt" ] && grep -qx hasher "$LOGS/07-only-host.txt"
}

echo "== Задание 2: сборочное окружение хоста"
check "2.1 apt-repo содержит ветку p11"                  t2_repos
check "2.2 все пакеты курса установлены (rpm -q)"        t2_course_pkgs
check "2.3 hasher-privd enabled и active"                t2_privd
check "2.4 env/repos.txt, env/host-packages.txt"         t2_env_files

echo "== Задание 3: зависимости libjpeg"
check "3.1 в libjpeg-devel есть .h и ссылка на .so"      t3_devel_files
check "3.2 rpm -qf jpeglib.h -> libjpeg-devel"           t3_qf
check "3.3 rpm -q --whatprovides libjpeg -> libjpeg"     t3_whatprovides
check "3.4 журналы для таблицы классификации"            t3_logs

echo "== Задание 4: hasher"
check "4.1 пользователь в hashman, _a, _b"               t4_groups
check "4.2 журнал развёртывания hsh --initroot-only"     t4_initroot_log
check "4.3 сборщик builder и суперпользователь root"     t4_users
check "4.4 дерево RPM в окружении"                       t4_rpm_tree
check "4.5 утилита tree доступна в окружении"            t4_which_tree
check "4.6 конфигурация hasher сохранена"                t4_config

echo "== Задание 5: пакет без файлов"
check "5.1 собраны RPM и SRPM"                           t5_build
check "5.2 rpm -qpl пуст"                                t5_empty
check "5.3 метаданные совпадают со spec"                 t5_meta
check "5.4 пакет установлен, which не находит файл"      t5_installed

echo "== Задание 6: пакет со сценарием"
check "6.1 в пакете ровно /usr/bin/$PKG"                 t6_one_file
check "6.2 вывод совпадает с expected.txt"               t6_output
check "6.3 зависимости вычислены автоматически"          t6_requires
check "6.4 после удаления программа не находится"        t6_removed

echo "== Задание 7: воспроизводимость"
check "7.1 автосборка: тот же NVR"                       t7_auto
check "7.2 перечни файлов совпадают"                     t7_files
check "7.3 sha256 исходника совпадает"                   t7_sha256
check "7.4 в hasher пакетов меньше, чем на хосте"        t7_envs

echo
echo "Пройдено: $pass, не пройдено: $fail"
[ "$fail" -eq 0 ]
