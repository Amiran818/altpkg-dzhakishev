# Лабораторная работа №1. Сборочное окружение и зависимости

Студент: Джакишев Амир Маратович, группа КТ-22-04

Стенд: ALT Workstation 11.1, ветка репозитория p11, x86_64 (VirtualBox, 2 ядра, 4 ГБ ОЗУ).
Работа выполнялась от непривилегированного пользователя `user`, привилегированные операции — через `sudo`.

## Структура каталога

| Каталог | Содержимое |
|---|---|
| `specs/` | `dzhakishev-null.spec` (пустой пакет), `dzhakishev-hello.spec` (пакет со сценарием) |
| `sources/` | `dzhakishev-hello.sh` — исходный сценарий |
| `env/` | `repos.txt`, `host-packages.txt`, `course-packages.txt`, `hasher-config` |
| `logs/` | журналы команд, файлы именуются по номеру задания (`03-…`, `04-…`) |
| `check/` | `check-lab01.sh`, `check-packages.sh`, эталон `expected.txt` |

Проверка: `bash lab01/check/check-lab01.sh` (из корня клона). Сценарий использует каталоги стенда
`~/hasher` и `~/lab01-work/manual` (пакеты ручной сборки), их можно переопределить
переменными `HASHER_DIR` и `MANUAL_DIR`.

## Порядок выполнения

### Задание 1. Репозиторий
Создан публичный репозиторий `altpkg-dzhakishev`, ветка `dev`. Репозиторий склонирован с ветки
`dev`, заданы `user.name` / `user.email`, создана структура `lab01/{specs,sources,env,logs,check}`
и `.gitignore` (исключает `*.rpm`, архивы исходников, каталоги `BUILD`, `RPMS`, `SRPMS` и т.п.).
Первый коммит опубликован, поставлен аннотированный тег `lab01-start`. Пустые каталоги
сохраняются в git через `.gitkeep`.

### Задание 2. Окружение хоста
`apt-repo list` показывает три источника ветки p11 (`x86_64`, `x86_64-i586`, `noarch`), `apt-repo list -a`
— также закомментированные зеркала. После `apt-get update` установлены пакеты курса
(`rpm-build`, `rpmdevtools`, `hasher`, `hasher-priv`, `git-core`, `gcc`, `make`, `tree`, `shellcheck` и др.,
см. `env/course-packages.txt`). Служба `hasher-privd` включена (`systemctl enable --now`).
Перечень репозиториев сохранён в `env/repos.txt`, перечень пакетов — в `env/host-packages.txt`
(2258 строк, совпадает с `rpm -qa | wc -l`).

Классы установленных групп пакетов:

| Группа пакетов | Класс | Обоснование |
|---|---|---|
| `hasher`, `hasher-priv`, `rpmdevtools`, `apt-repo` | инструментальная | нужны разработчику для организации сборки, в собираемый пакет и в сборочную среду не попадают |
| `git-core`, `openssh-clients` | инструментальная | ведение и публикация исходников, к сборке пакета не относятся |
| `tree`, `diffutils`, `shellcheck` | инструментальная | вспомогательные утилиты анализа и проверки |
| `rpm-build`, `gcc`, `make` | сборочная | выполняют саму сборку; ставятся в hasher как базовый набор `rpm-build` |
| `libjpeg-devel` | сборочная | заголовки и `.so`-ссылка нужны только при компиляции программ с libjpeg |
| `rpm`, `apt`, `glibc` | эксплуатационная | нужны во время работы установленной системы и программ |

### Задание 3. Зависимости libjpeg
Выбран пакет `libjpeg` (libjpeg-turbo 3.0.2) и парный `libjpeg-devel`.

- Эксплуатационные зависимости `libjpeg` (`rpm -q --requires`): `libc.so.6(GLIBC_*)`, `ld-linux-x86-64.so.2`,
  `rtld(GNU_HASH)` — библиотека слинкована с glibc; плюс служебные `rpmlib(...)`.
- Предоставляемые (`--provides`): `libjpeg.so.62()(64bit)` (soname библиотеки) и `libjpeg = 2:3.0.2-alt2.1`.
- Обратные зависимости: по имени пакета от него зависит только `libturbojpeg`, по soname
  `libjpeg.so.62()(64bit)` — 45 установленных пакетов (gdk-pixbuf, sane, netpbm, ghostscript, qt5/qt6-gui, chromium, …).
- `rpm -q --whatprovides libjpeg` возвращает `libjpeg-3.0.2-alt2.1`.

Состав пакетов (`logs/03-libjpeg-ql.txt`, `logs/03-libjpeg-devel-ql.txt`):

| Категория | libjpeg | libjpeg-devel |
|---|---|---|
| разделяемая библиотека | `libjpeg.so.62`, `libjpeg.so.62.4.0` | — |
| заголовочные файлы | — | 6 файлов: `jpeglib.h`, `jconfig.h`, `jerror.h`, `jmorecfg.h`, `jpegint.h`, `turbojpeg.h` |
| символические ссылки `.so` | — | `libjpeg.so -> libjpeg.so.62`, `libturbojpeg.so -> libturbojpeg.so.0` |
| описания для компоновки | — | `libjpeg.pc`, `libturbojpeg.pc`, 4 файла cmake `libjpeg-turbo*.cmake` |
| документация | `README.ijg`, `README.md` | `libjpeg.txt.bz2`, `usage.txt.bz2`, `structure.txt.bz2`, `wizard.txt`, … |

`rpm -qf /usr/include/jpeglib.h` → `libjpeg-devel`, и этот файл есть в `rpm -ql libjpeg-devel` — проверка замкнута.
`libjpeg-devel` требует `libturbojpeg` и `/usr/lib64/pkgconfig`, а `libturbojpeg` в свою очередь требует `libjpeg`.

Таблица классификации зависимостей (подтверждающие журналы в `logs/`):

| Класс | Пакет | Обоснование | Журнал |
|---|---|---|---|
| эксплуатационная | `glibc-core` (`libc.so.6`) | `libjpeg` требует `libc.so.6(GLIBC_2.14)(64bit)` и др. | `03-libjpeg-requires.txt` |
| эксплуатационная | `libjpeg` | нужна во время работы 45 пакетам через soname `libjpeg.so.62` | `03-libjpeg-whatrequires-soname.txt` |
| эксплуатационная | `/bin/sh` (`bash`) | вычисленная зависимость пакета `dzhakishev-hello` | `06-hello-deps.txt` |
| сборочная | `libjpeg-devel` | заголовки `jpeglib.h` и ссылка `libjpeg.so` нужны только при компиляции | `03-libjpeg-devel-ql.txt`, `03-rpm-qf-jpeglib.txt` |
| сборочная | `pkg-config` (`/usr/lib64/pkgconfig`) | требуется `libjpeg-devel` для `.pc`-файлов, используется при сборке | `03-libjpeg-devel-requires.txt` |
| сборочная | `rpm-build` | установлен в сборочную среду hasher, выполняет `rpmbuild` | `07-hasher-packages.txt`, `06-rpmbuild-hello.log` |
| инструментальная | `hasher` | только на хосте, разворачивает сборочную среду | `07-only-host.txt` |
| инструментальная | `git-core` | только на хосте, публикация работы | `07-only-host.txt` |
| инструментальная | `apt-repo` | только на хосте, управление источниками | `07-only-host.txt` |

### Задание 4. hasher
`hasher-useradd user` создал служебных пользователей `user_a`, `user_b` и добавил `user` в группы
`hashman`, `user_a`, `user_b`. Сеанс перезапущен через `su - user`, после чего `id -Gn` показывает новые группы.
Созданы `~/hasher` (рабочий каталог) и `~/.hasher/config`:

```
packager="Amir Dzhakishev <344528613+Amiran818@users.noreply.github.com>"
no_sisyphus_check="packager,gpg,changelog"
```

Отключены проверки sisyphus_check, которые требуют сопровождающего с адресом `@altlinux.org`
и подписи gpg — при локальной сборке они неприменимы (`changelog` пришлось добавить в задании 7, см. ниже).
Права файлов источников APT — `644 root:root`, читать их могут все, исправлять не потребовалось.
`hsh --initroot-only -v ~/hasher` завершился с кодом 0, журнал — `logs/04-hsh-initroot.log`, в конце
«Created RPM build directory tree» (каталоги `/usr/src/RPM/{BUILD,SOURCES,SPECS,RPMS,SRPMS}`).
`hsh-install` поставил в окружение `tree` и `nano`.

| Вход | `id -un` | Домашний каталог |
|---|---|---|
| `hsh-shell ~/hasher` | `builder` (uid 1002) | `/usr/src` |
| `hsh-shell --rooter ~/hasher` | `root` (uid 0) | `/root` |

Снаружи окружения им соответствуют служебные пользователи хоста `user_b` (сборщик) и `user_a` (rooter).

### Задание 5. Пакет без файлов
`specs/dzhakishev-null.spec`: обязательные поля `Name`, `Version`, `Release`, `Summary`, `License`, `Group`,
секции `%description`, `%files` (пустая) и `%changelog`; `BuildArch: noarch`.
`rpmbuild -ba` в окружении создал `RPMS/noarch/dzhakishev-null-1.0-alt1.noarch.rpm` и
`SRPMS/dzhakishev-null-1.0-alt1.src.rpm`. `rpm -qpl` → «(contains no files)», `rpm -qpi` содержит заявленные
имя, версию, релиз и лицензию. После `rpm -i` от rooter `rpm -q dzhakishev-null` находит пакет,
а `which dzhakishev-null` — нет (код 1): пакет есть в базе RPM, но функциональности не добавляет.

### Задание 6. Пакет со сценарием
Исходный файл назван по имени пакета — `dzhakishev-hello.sh` (`Source0: %name.sh`). Установка в
псевдокорень: `install -D -m 0755 %SOURCE0 %buildroot%_bindir/%name`, в `%files` — `%_bindir/%name`.

Этапы в журнале `logs/06-rpmbuild-hello.log`:

1. очистка псевдокорня — `rm -rf /usr/src/tmp/dzhakishev-hello-buildroot`;
2. установка файлов — `install -D ... buildroot/usr/bin/dzhakishev-hello`;
3. проверка дисциплины сборки — `brp-alt`: «Verifying and fixing files», «Checking contents», «Verifying ELF objects»;
4. вычисление зависимостей — «Finding Provides», «Finding Requires», `find-requires: running scripts (… shebang, shell …)`;
5. запись пакетов — `Wrote: .../SRPMS/...src.rpm`, `Wrote: .../RPMS/noarch/...noarch.rpm`.

Зависимости собранного пакета (`rpm -qp --requires / --provides`):

- `/bin/sh` — вычислена скриптом `shebang`/`shell` из первой строки `#!/bin/sh`;
- `rpmlib(PayloadIsLzma)` — добавляет сам rpm: содержимое пакета сжато lzma, установщик должен это уметь;
- provides `dzhakishev-hello = 1.0-alt1` — каждый пакет предоставляет своё имя с версией-релизом.

В spec-файле нет ни одной строки `Requires`. Программа после установки запускается по имени, вывод
совпадает с `check/expected.txt` (`diff` пуст). После `rpm -e` `which` возвращает 1, запуск — 127.

### Задание 7. Воспроизводимость
SRPM из задания 6 извлечён в `~/lab01-work/manual`. Автосборка: `hsh -v ~/hasher <src.rpm>`.
Первая попытка завершилась ошибкой (`logs/07-hsh-auto-build-fail-changelog.log`):
`sisyphus_check: check-changelog ERROR` — проверка требует адрес `@altlinux.org` в записи changelog.
После добавления `changelog` в `no_sisyphus_check` сборка прошла с кодом 0, результат в
`~/hasher/repo/SRPMS.hasher/` и `~/hasher/repo/x86_64/RPMS.hasher/`.

Ручная и автоматическая сборка совпадают по NVR (`dzhakishev-hello 1.0 alt1 noarch`), перечню файлов,
перечню зависимостей; sha256 исходника из обоих SRPM одинаковая (`logs/07-sha256-sources.txt`).

Сравнение окружений (по именам пакетов):

| | Число пакетов |
|---|---|
| хост | 2258 |
| hasher (после `--initroot-only`) | 180 |
| только на хосте (`comm -23`) | 2081 |
| только в hasher (`comm -13`) | 3 |
| общие | 177 |

Только на хосте находятся инструментальные пакеты (`hasher`, `hasher-priv`, `git-core`, `apt-repo`,
`rpmdevtools`, `shellcheck`, `tree`, `openssh-clients`), графическое окружение и прикладные программы,
а также сборочные зависимости других проектов (`libjpeg-devel`). В hasher — только минимальная система
и сборочный набор `rpm-build` (gcc, make, autoconf, …), то есть сборочные зависимости. Только в hasher
есть `sisyphus_check` и два служебных пакета базовой системы.

### Задание 8. Проверка и публикация
`check/check-lab01.sh` выполняет 26 проверок заданий 2–7 и печатает PASS/FAIL, в конце — число пройденных
и непройденных; при хотя бы одной ошибке код возврата 1. Синтаксис проверен `bash -n`, замечаний
`shellcheck` нет. Приёмочная проверка выполнена из свежего клона, проверка чувствительности —
временной порчей `check/expected.txt`.

## Выводы

1. Сборочное окружение хоста (p11) подготовлено, состав репозиториев и пакетов зафиксирован в `env/`.
2. Зависимости делятся на инструментальные (нужны разработчику: hasher, git), сборочные (нужны для сборки:
   rpm-build, gcc, devel-пакеты) и эксплуатационные (нужны при работе программы: glibc, `/bin/sh`).
   Средства RPM позволяют получить прямые, предоставляемые и обратные зависимости.
3. hasher разворачивает минимальную среду (180 пакетов против 2258 на хосте), сборка в ней идёт от
   непривилегированного `builder`, поэтому на результат не влияют лишние пакеты хоста.
4. Эксплуатационные зависимости пакета вычисляются автоматически по содержимому файлов.
5. Ручная и автоматическая сборка из одного SRPM дают одинаковый результат — сборка воспроизводима.
