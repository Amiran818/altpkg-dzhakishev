# Лабораторная работа №5. Отладка

Студент: Джакишев А.М., группа КТ-22-04.
Стенд: ALT Workstation 11.1 (p11), gcc 13, gdb/gdbserver 14.1, hasher 1.7.7.

## Структура каталога

```
lab05/
├── sources/   main.c, seq.c, seq.h (progression), bug.c, bug-fixed.c, Makefile
├── gdb/       variants.gdb, bug.gdb, trace.gdb, range.gdb, local-gdbinit, home-gdbinit
├── env/       prepare-hasher.sh, hasher-config, hasher-priv-fstab, hasher-priv-system
├── check/     check-lab05.sh, expected-bug.txt, expected-trace.txt, expected-range.txt
└── logs/      журналы и протоколы сеансов (префикс = номер задания)
```

Проверка: `bash lab05/check/check-lab05.sh` (группы «стенд» и «hasher» — SKIP
при отсутствии пакета, debuginfod или окружения `HASHER_DIR`).

## Задание 1. Формат ELF

`progression [FROM] TO [STEP]` — арифметическая прогрессия (без параметров —
справка, код 1). Три объекта:

| Файл | file | readelf -h Type |
|---|---|---|
| `main.o` (`gcc -c`) | ELF 64-bit LSB relocatable | REL (перемещаемый файл) |
| `libseq.so` (`-fPIC -shared`) | ELF 64-bit LSB shared object | DYN (совместно используемый объект) |
| `progression` | ELF 64-bit LSB pie executable | DYN (Position-Independent Executable) |

PIE-исполняемый файл в ELF тоже имеет тип DYN — он загружается по
произвольному адресу как разделяемый объект, отличается наличием `INTERP` и
точки входа. Заголовок: ELF64, little endian, точка входа `0x1080`,
13 заголовков программ (PHDR, INTERP, 4×LOAD, DYNAMIC, 2×NOTE, GNU_PROPERTY,
GNU_EH_FRAME, GNU_STACK, GNU_RELRO) и 39 разделов — совпадает с фактическим
подсчётом. Build ID `ec2ab98f…4dc0` одинаков у `file` и `readelf -n`.
Разделы отладки: `.debug_aranges .debug_info .debug_abbrev .debug_line .debug_str
.debug_line_str`. Адрес `0x1080` в `objdump -d` — функция `_start`.

## Задание 2. Сборка для отладки

| Вариант | Размер | Исходник в gdb | Локальные переменные | Порядок строк |
|---|---|---|---|---|
| без ключей | 18 816 | нет (`list` пусто, «no line number information») | нет | — |
| `-O0 -g` | 22 056 | есть | все доступны | 13 → 15 → 16 → 17 → 15 |
| `-O2 -g` | 24 512 | есть | `value = <optimized out>` | 15 → 17 → 17 → 15 → 17 |

В варианте без ключей `file` тоже пишет `with debug_info`: это DWARF стартового
объекта glibc (`abi-note.c`), для `main.c` и `seq.c` его нет. `-O2 -g` больше
`-O0 -g`: оптимизированный код и описания размещения переменных (location lists)
занимают больше места. Путь к исходникам хранится в DWARF: `DW_AT_name` (seq.c)
и `DW_AT_comp_dir` (каталог сборки); gdb ищет по `$cdir:$cwd`. Файл, собранный во
временном каталоге и перенесённый после его удаления, исходник не находит
(«seq.c: Нет такого файла»), а в каталоге с `seq.c` — находит.

## Задание 3. Поиск ошибки

`bug.c`: `show_balance()` кладёт в локальный `int *field` адрес `acc.balance`;
`add_bonus()` пишет по неинициализированному `int *bonus`. `-Wall`: «'bonus' is
used uninitialized». Обе функции вызываются из `process()` подряд, кадры
стека занимают одно место: `&field = &bonus = 0x7fffffffe478`, а «мусорное»
значение `bonus = 0x555555558008 <acc>` осталось от `field`. Запись
`*bonus = 1000*10/100` портит `acc.balance`: вывод «balance: 100, bonus: 0»
вместо «balance: 1000, bonus: 100». Стек: `add_bonus(percent=10)` ←
`process(percent=10)` ← `main()`, перемещение `up`/`down`. Исправление
`int *bonus = &acc.bonus;` — вывод совпадает с `check/expected-bug.txt`.

## Задание 4. Отладочная информация

`strip`: 22 056 → 14 936 байт, `not stripped` → `stripped`, разделов `.debug_*`
и `.symtab` нет, gdb: «No debugging symbols found». Отладочная информация
дистрибутива — пакеты `<пакет>-debuginfo` в компоненте `debuginfo` ветки
(`p11/branch/x86_64 classic debuginfo` — одной строкой: отдельная строка с тем же
`release` ломает apt-rpm). После подключения в индексах 15 585 пакетов
`*-debuginfo`; `glibc-core-debuginfo` содержит 29 файлов `.debug` и исходники в
`/usr/src/debug`, gdb показывает `__GI___libc_write … at write.c:26`.

Сервер: `debuginfod-urls` задаёт `DEBUGINFOD_URLS=https://debuginfod.altlinux.org/`,
но сборки p11 там отсутствуют (`/buildid/<id>/debuginfo` → 404 для libc, zlib,
ncurses). Механизм показан на локальном `debuginfod -F`: с пустой переменной
загрузки нет, с `http://127.0.0.1:8002` gdb пишет «Downloading separate debug
info», файл появляется в `~/.cache/debuginfod_client/<build-id>/debuginfo`.

devel-пакет — заголовки и ссылки для сборки программ с библиотекой; debuginfo —
отделённые отладочные секции и исходники для отладки уже собранных файлов. Для
разбора сбоя, просмотра стека и переменных в библиотеке достаточно debuginfo.

## Задание 5. Сценарии gdb

`trace.gdb`: `break emit if idx % 2 == 0` + `commands … backtrace … continue`;
`range.gdb`: только элементы 3..5. Значимые строки помечены `LAB5 `, вывод
программы — в `/dev/null`, `set pagination off`, запуск `gdb --batch --quiet --nx -x`
с `< /dev/null`. Адреса (`argv=0x7fff…`) меняются между запусками и в
выделенные строки не входят; три запуска дают одинаковые строки. `make check`
сравнивает их с эталонами (порча эталона → код 2). `./.gdbinit` без разрешения
не загружается («auto-loading has been declined by your auto-load safe-path»),
после `add-auto-load-safe-path` в `~/.gdbinit` команда `lab5hello` доступна.

## Задание 6. Отладка в hasher

Без `/proc`: «/proc is not accessible», «Cannot insert breakpoint 1»;
`--mountpoints=/proc` без настройки: «mount point is not allowed». Четыре условия:

1. `/etc/hasher-priv/fstab`: `proc /proc proc rw,nosuid,nodev,noexec 0 0`
   (опция `relatime` даёт `mount: Invalid argument`);
2. `/etc/hasher-priv/system`: `allowed_mountpoints=/proc`;
3. `systemctl restart hasher-privd`;
4. `~/.hasher/config`: `known_mountpoints=/proc` или ключ `--mountpoints=/proc`.

После этого `/proc` смонтирован, сеанс gdb в окружении штатный. При сборке
пакета требование задаётся `BuildRequires: /proc`: `hsh-install`/`hsh-rebuild`
вычисляют точки монтирования из файловых зависимостей пакетов. Сценарий
`env/prepare-hasher.sh [-w DIR] [-n N] [-p PKGS] [-r] [-N] [-c CMD]` создаёт окружение
при отсутствии, копирует `/etc/resolv.conf` и `/etc/hosts` (через `hsh-run --rooter`:
`hsh-copy` не принимает значение у `--number`), ставит пакеты, монтирует `/proc` и
входит (`hsh-shell`) или выполняет команду (`hsh-run`).

## Задание 7. Удалённая отладка и подключение к процессу

Вторая пара `hasher-useradd --names=user_c:user_d --number=2 user` (подконфигурация
`/etc/hasher-priv/user.d/1000:2`): один пользователь-сборщик не может одновременно
обслуживать два окружения — hasher-priv завершает процессы «своих» служебных
пользователей при входе. Окружение 1 (`~/hasher-lab05`, gdbserver) и 2
(`~/hasher-lab05b`, `--number=2`, gdb), сеть — `share_network=1`. gdbserver:
«Listening on port 2345» → «Remote debugging from host 127.0.0.1»; gdb:
`target remote`, `break emit`, `list` — исходник нужен на стороне gdb (там читается
DWARF и файлы), gdbserver лишь управляет процессом.

`gdb -p` к `sleep 3600` при `kernel.yama.ptrace_scope=1`: «ptrace: Операция не
позволена»; при 0 — подключение и стек `clock_nanosleep`; после возврата 1 —
снова отказ. Значения: 0 — любой процесс того же пользователя; 1 — только потомки
(или разрешённые `PR_SET_PTRACER`); 2 — только с `CAP_SYS_PTRACE`; 3 — запрещено
до перезагрузки.

Зеркало `ftp.altlinux.org` 24.11.2026 не отвечало, поэтому hasher использует
`mirror.yandex.ru/altlinux` (`apt_config` в `~/.hasher/config`).

## Выводы

* ELF различает перемещаемые, разделяемые и исполняемые файлы; PIE — тип DYN.
* Для отладки нужны `-g` и `-O0`; оптимизация прячет переменные и меняет порядок.
* Отладочная информация отделяется `strip`/debuginfo-пакетами и может приходить
  с сервера debuginfod по Build ID.
* Отладка в hasher требует `/proc` и согласованной настройки hasher-priv.
* Подключение к чужому процессу ограничено Yama `ptrace_scope`.
