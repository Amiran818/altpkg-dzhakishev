# Лабораторная работа №3. Многофайловая сборка

Студент: Джакишев А.М., группа КТ-22-04.
Стенд: ALT Workstation 11.1 (ветка p11), x86_64, gcc 13, GNU make.

## Структура каталога

```
lab03/
├── README.md
├── sources/
│   ├── main.c, output.c, counter.c, prog.h   проект dzhargs
│   ├── Makefile                              итоговый файл описания сборки
│   ├── steps/Makefile.*                      промежуточные варианты (задание 3, 4)
│   └── make-tarball.sh                       архив dzhakishev-args-1.0.tar.gz
├── specs/dzhakishev-args.spec
├── env/hasher-config, env/host-rpmmacros     сведения о сопровождающем
├── check/check-lab03.sh                      сценарий проверки
└── logs/                                     журналы (префикс = номер задания)
```

Проверка: `bash lab03/check/check-lab03.sh` (локальный репозиторий hasher —
переменная `HASHER_DIR`, по умолчанию `~/hasher-lab03`; без него — SKIP).

## Задание 1. Модули и этапы сборки

| Файл | Содержимое |
|---|---|
| `main.c` | точка входа `main` |
| `output.c` | `print_arg` (вывод параметра с номером), `print_help` (справка в stderr), `mark_begin[]` |
| `counter.c` | глобальная переменная-счётчик `int counter` |
| `prog.h` | объявления функций, `extern int counter`, `extern char mark_begin[]`, `PROG_VERSION` |

Без параметров справка уходит в stderr (при `> файл` stdout пуст), код 1.
С тремя параметрами — 5 строк: `=== begin ===`, три пронумерованных параметра,
`=== end: 3 ===`.

Этапы: `gcc -E main.c` — 835 строк вместо 18, в них текст `prog.h` и stdio.h;
`gcc -c` — три перемещаемых объектных файла (ELF relocatable);
`gcc -o dzhargs *.o` — компоновка. Трассировка `strace -f -e trace=execve`:
`gcc` → `x86_64-alt-linux-gcc` → для каждого модуля `cc1` (C → ассемблер) и
`as` (ассемблер → .o) → `collect2` → `ld` → `ld.default` (компоновщик).

Определение функции `twice` в `prog.h` компилируется без ошибок, но символ
`T twice` оказывается в каждом объектном файле, и на этапе компоновки
`ld` сообщает «повторное определение «twice»» (`logs/01-multiple-definition.txt`).

## Задание 2. Таблицы символов

| Символ | Тип | Определяет | Используют | Журнал |
|---|---|---|---|---|
| `main` | T — функция | main.o | — (вызывает crt) | 02-nm-main.txt |
| `print_arg` | T — функция | output.o | main.o | 02-nm-output.txt, 02-nm-main.txt |
| `print_help` | T — функция | output.o | main.o | 02-nm-output.txt |
| `mark_begin` | D — инициализированные данные | output.o | main.o | 02-readelf-output.txt |
| `counter` | B — неинициализированные данные | counter.o | main.o, output.o | 02-objdump-counter.txt |
| `printf`, `puts` | U | libc.so.6 | main.o, output.o | 02-external-libc.txt |
| `fprintf`, `stderr` | U | libc.so.6 | output.o | 02-external-libc.txt |

`comm -23` (неопределённые минус определённые в проекте) даёт `fprintf`,
`printf`, `puts`, `stderr` — все есть в `libc.so.6`. `ldd dzhargs`:
`linux-vdso.so.1`, `libc.so.6 => /lib64/libc.so.6`, `ld-linux-x86-64.so.2`.

## Задание 3. make

* `steps/Makefile.1-explicit` и `Makefile.2-pattern` (`%.o: %.c`, `$@ $< $^`) —
  одинаковый набор команд.
* `Makefile.3-builtin` — без шаблонного правила работает встроенное
  `%.o: %.c` → `$(COMPILE.c) $(OUTPUT_OPTION) $<`, где
  `COMPILE.c = $(CC) $(CFLAGS) $(CPPFLAGS) $(TARGET_ARCH) -c`: команда
  `gcc -O2 -Wall   -c -o main.o main.c` (другой порядок, пустые `CPPFLAGS`
  и `TARGET_ARCH` дают лишние пробелы).
* `touch output.c` → ровно 2 команды: компиляция `output.o` и компоновка.
* `touch prog.h` без явной зависимости → «не требует обновления»; с
  `$(OBJS): prog.h` (`Makefile.4-header`) пересобираются все три модуля.
* `clean`, `distclean` объявлены `.PHONY`: при файле `clean` цель выполняется,
  без объявления (`Makefile.5b-nophony`) — «clean не требует обновления».
* `make CFLAGS="-O0 -g -DDEBUG"` — флаги видны в командах.

## Задание 4. Статическая библиотека

`ar -rv libdzhargs.a output.o counter.o`; `gcc -o dzhargs-static main.o -L. -ldzhargs` —
вывод совпадает с вариантом из объектных файлов (cmp).
`gcc -static` без `glibc-devel-static` — «невозможно найти -lc»; после установки пакета:

| | обычный (`dzhargs-static`) | `-static` |
|---|---|---|
| размер | 18 832 байт | 3 048 120 байт (в 162 раза больше) |
| символов (`nm`) | 37 | 1 935 |
| `ldd` | vdso, libc.so.6, ld-linux | «не является динамическим исполняемым файлом» |

В Makefile библиотека описана правилом с членами архива
`libdzhargs.a: libdzhargs.a(output.o counter.o)` — встроенное правило `(%): %`
вызывает `$(AR) $(ARFLAGS) $@ $<`. Объектные файлы-члены объявлены `.SECONDARY`:
в минимальном `steps/Makefile.6-archive` make удаляет их как промежуточные
(`rm counter.o output.o`), с `.SECONDARY` — сохраняет. Итоговый вариант
подключает архив с `-Wl,-Bstatic`, иначе при наличии `libdzhargs.so` рядом
компоновщик выбрал бы динамическую библиотеку.

## Задание 5. Динамическая библиотека

gcc в ALT собирается с `--enable-default-pie`: объектные файлы по умолчанию —
PIE, обращение к глобальной `counter` идёт как `R_X86_64_PC32` (адрес считается
известным при компоновке), и `gcc -shared` выдаёт «перемещение R_X86_64_PC32 для
символ «counter» не может использоваться при создании общий объект; перекомпилируйте
с параметром -fPIC». С `-fno-pic` — то же для `R_X86_64_32`. С `-fPIC` обращение
идёт через GOT (`R_X86_64_REX_GOTPCRELX`), библиотека `libdzhargs.so.1`
(SONAME `libdzhargs.so.1`) собирается.

Динамическая таблица: экспорт `T print_arg`, `T print_help`, `D mark_begin`,
`B counter`; из libc — `printf`, `fprintf`, `stderr` (`GLIBC_2.2.5`).

Запуск `dzhargs-shared` без каталога поиска: «error while loading shared libraries:
libdzhargs.so.1: cannot open shared object file», код 127; `ldd` — `not found`.
Загрузчик ищет библиотеку в `DT_RPATH`/`DT_RUNPATH`, `LD_LIBRARY_PATH`, кэше
`ldconfig` (`/etc/ld.so.cache`) и стандартных каталогах `/lib64`, `/usr/lib64` —
текущего каталога среди них нет. С `LD_LIBRARY_PATH=.` всё разрешается, вывод
совпадает с вариантом со статической библиотекой.

## Задание 6. Цель тестирования

`make` собирает `dzhargs`, `dzhargs-static`, `dzhargs-shared`; `make test` запускает
каждый без параметров, с одним и с тремя параметрами (stdout+stderr и код возврата
в `*.out0|1|3`, всего 9 файлов) и сравнивает их `cmp`. Имя `./<файл>` в справке
заменяется на `PROG` через `sed`. Цель `test` не пересобирает программы, поэтому
после изменения `output.c` и `make dzhargs-static` выводы расходятся
(`dzhargs.out1 dzhargs-static.out1 differ`, код 2); после полной пересборки — снова 0.
`clean` удаляет объектные файлы, `distclean` — всё порождаемое, остаются исходники и Makefile.

## Задание 7. Пакет

`dzhakishev-args-1.0.tar.gz` → spec: `%setup`, `%make_build CFLAGS="%optflags"`,
установка `dzhargs-static`, `dzhargs-shared` в `%_bindir` и `libdzhargs.so.1`
в `%_libdir`. На x86_64 `%_libdir` = `/usr/lib64` (64-битные библиотеки;
`/usr/lib` — для 32-битных и архитектурно-независимых данных); абсолютные пути
не пишутся, чтобы spec подходил для любой архитектуры.

Сборка в `~/hasher-lab03` — `sisyphus_check passed`, в репозитории
`SRPMS.hasher/dzhakishev-args-1.0-alt1.src.rpm` и `x86_64/RPMS.hasher/`
с основным пакетом и `dzhakishev-args-debuginfo`. После установки оба файла
запускаются по имени без `LD_LIBRARY_PATH`, выводы совпадают, `ldd` указывает на
`libdzhargs.so.1` из пакета (`rpm -qf` → `dzhakishev-args`).

Зависимости: `Provides: libdzhargs.so.1()(64bit)`; в `Requires` — только libc,
`ld-linux`, `rtld(GNU_HASH)`. `lib.req` по `NEEDED` файла `dzhargs-shared`
вычисляет и `libdzhargs.so.1()(64bit)`, но rpm-build ALT исключает зависимости,
которые удовлетворяет сам пакет. `dzhargs-static` не зависит от библиотеки
проекта: её код скопирован в исполняемый файл при компоновке, в `NEEDED` только
`libc.so.6`. Подпакет debuginfo содержит `*.debug` для трёх ELF-файлов, ссылки
`.build-id` и исходники в `/usr/src/debug`.

## Выводы

* Сборка состоит из препроцессирования, компиляции в ассемблер, ассемблирования и
  компоновки; ошибки повторного определения видны только компоновщику.
* make строит граф по правилам и временам изменения; зависимости от заголовков
  нужно указывать явно, цели без файлов — объявлять `.PHONY`.
* Статическая библиотека копируется в исполняемый файл, динамическая
  подключается загрузчиком при запуске и должна лежать в известном ему каталоге.
* Для пакета библиотеку ставят в `%_libdir`, тогда программы работают без
  `LD_LIBRARY_PATH`.
