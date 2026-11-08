# Лабораторная работа №2. Работа с терминалом и простой проект

Студент: Джакишев А.М., группа КТ-22-04.
Стенд: ALT Workstation 11.1 (ветка p11), x86_64, пользователь `user`,
эмулятор терминала GNOME Console (`TERM=xterm-256color`, 48×178).

## Структура каталога

```
lab02/
├── README.md                 отчёт
├── sources/
│   ├── show.c                программа Show (ncurses)
│   ├── Makefile              сборка Show
│   └── make-tarball.sh       формирование архива dzhakishev-show-1.0.tar.gz
├── specs/dzhakishev-show.spec
├── env/
│   ├── hasher-config         ~/.hasher/config (сведения о сопровождающем)
│   └── host-rpmmacros        ~/.rpmmacros хоста (%packager)
├── check/
│   ├── check-lab02.sh        сценарий функциональной проверки
│   └── sample.txt            контрольный файл для просмотра (60 строк)
└── logs/                     журналы и протоколы (префикс = номер задания)
```

Проверка: `bash lab02/check/check-lab02.sh`. Каталоги стенда задаются
переменными `HASHER_DIR` (по умолчанию `~/hasher-lab02`) и `MANUAL_DIR`
(`~/lab02-work/manual`); если их нет, соответствующие проверки пропускаются (SKIP).

## Порядок выполнения

### Задание 1. Терминал и управляющие последовательности

Параметры терминала сохранены в `logs/stty-before.txt` (`stty -a`).
Управляющие символы:

| Параметр | Клавиши | Код | Действие |
|---|---|---|---|
| intr  | Ctrl+C | 0x03 | посылает SIGINT процессам переднего плана |
| erase | Backspace | 0x7F (`^?`) | стирает последний символ вводимой строки |
| kill  | Ctrl+U | 0x15 | стирает всю вводимую строку |
| eof   | Ctrl+D | 0x04 | в начале строки — конец файла для читающей программы |

Действие проверено в псевдотерминале (`script`): ввод
`hello wor⌫⌫⌫pal⏎abc def^Uxyz⏎^D` дал программе `cat` строки `hello pal` и
`xyz`, а `^D` завершил её с кодом 0 (`logs/01-ctrl-erase-kill-eof.txt`);
`^C` прервал `sleep 30`, код возврата 130 = 128 + SIGINT (`logs/01-ctrl-intr.txt`).

Очистка экрана: `printf '\033[H\033[2J'` и `tput -x clear` дают одинаковые
7 байт `1b 5b 48 1b 5b 32 4a` (cmp — без различий). Обычный `tput clear`
добавляет `\E[3J` (расширенная возможность `E3` — очистка буфера прокрутки),
поэтому для сравнения использован ключ `-x`.

Сравнение terminfo `vt100` и `xterm-256color` (`logs/01-infocmp-*.txt`):
86 и 199 строк вывода `infocmp -1`; цветов нет / 256; функциональных клавиш
`kf*` 11 / 63; геометрия по описанию у обоих 24×80 (фактическая берётся у ядра).

Неверный тип `TERM=adm3a`: позиционирование курсора `\E=<строка><столбец>`
эмулятор не понимает, поэтому `top` выводит экран с потерянными строками заголовка
и обрезанными символами. С `TERM=xterm-256color` изображение корректно.

Страница `ls(1)`, преобразованная `nroff -man`, содержит 954 байта 0x08:
`4e 08 4e` (`N^HN`, двойная печать — жирный) и `5f 08 4f` (`_^HO`, подчёркивание).

### Задание 2. Программа Show

`sources/show.c`: читает файл целиком в память, имя файла выводит в первой
строке, текст — в отдельном окне `newwin`; пробел — страница вперёд, `q`/Esc —
выход; длинные строки усекаются по ширине окна, табуляции раскрываются.
Инициализация: `initscr`, `noecho`, `cbreak`, `keypad(win, TRUE)`;
завершение: `delwin`, `endwin`, освобождение памяти. Ошибки (нет параметра —
код 1, файл недоступен — код 2) выводятся в stderr до `initscr`.

* без `libncurses-devel`: `curses.h: No such file or directory`;
* без `-lncurses`: 19 сообщений `undefined reference` (`logs/02-build-no-lib.txt`);
* `/usr/lib64/libncurses.so` — сценарий компоновщика `GROUP(libncurses.so.6 -ltinfo)`.

Запуск в псевдотерминале с клавишами «пробел, пробел, q» — код 0, в протоколе
есть `File: ../check/sample.txt` и первая строка файла; `stty -a` до и после
совпадает — режим терминала восстановлен.

### Задание 3. make

`sources/Makefile`: переменные `CC`, `CFLAGS`, `LDLIBS`, шаблонное правило
`%.o: %.c`, цели `all` и `clean` объявлены `.PHONY`. Рецепты начинаются с
байта 09 (`cat -A` показывает `^I`).

* повторный `make` — «Цель «all» не требует выполнения команд»;
* после `touch show.c` — компиляция и компоновка заново (сравнение времён изменения);
* пробелы вместо TAB — `*** пропущен разделитель ... Останов.`, код 2;
* несуществующий реквизит — `Нет правила для сборки цели «util.o»`, код 2;
* `.RECIPEPREFIX = >` меняет символ начала рецепта.

### Задание 4. hasher и сведения о сопровождающем

Окружение `~/hasher-lab02`, в нём установлен `libncurses-devel`.
Состав пакетов (`logs/04-ql-*.txt`): `libncurses6` — 16 файлов
(`lib*.so.6.5` — ELF-библиотеки, `lib*.so.6` — ссылки по soname, документация);
`libncurses-devel` — 955 файлов: 14 заголовков, ссылки `lib*.so -> lib*.so.6`
для компоновщика, сценарий `libncurses.so`, 4 файла `.pc`, `ncurses6-config`,
921 страница руководства.

Пакет `sl` из репозитория p11 пересобирается без настроек — его Packager и
`%changelog` уже корректны. Собственный пакет без настроек отклонён
(`logs/04-hsh-no-packager.log`):

```
wrong packager in CHANGELOGNAME: Amir Dzhakishev <344528613+Amiran818@users.noreply.github.com> 1.0-alt1
sisyphus_check: check-changelog ERROR: changelog format violation
sisyphus_check: check-packager ERROR: packager name violation
```

Поле Packager пакета с исходным кодом было пустым (на хосте не задан `%packager`),
а автор записи `%changelog` не в формате дистрибутива `Имя <login@altlinux.org>`.
Исправлено: `packager=` в `~/.hasher/config` (→ `env/hasher-config`),
`%packager` в `~/.rpmmacros` хоста, запись `%changelog` в spec. После этого
`.rpmmacros` окружения содержит `%packager Amir Dzhakishev <dzhakishev@altlinux.org>`,
сборка проходит (`sisyphus_check passed`), Packager пакета — тот же.
Адрес служит только для локальной проверки формата.

### Задание 5. Архив и spec-файл

`sources/make-tarball.sh` собирает `dzhakishev-show-1.0.tar.gz` с единственным
каталогом `dzhakishev-show-1.0/` (show.c, Makefile), архивируя через `tar -C`.
Spec: `Source: %name-%version.tar.gz`, `BuildRequires: libncurses-devel`,
`%setup`, `%make_build CFLAGS="%optflags"`, установка
`install -D -m 0755 Show %buildroot%_bindir/Show`.

В журнале `logs/05-rpmbuild-show.log`: `%prep` — `gzip -dc ...tar.gz | tar -xf -`;
`%build` — `make -j2 'CFLAGS=-pipe -frecord-gcc-switches -Wall -g -O2 -flto=auto'`.
Пакет содержит один файл `/usr/bin/Show`. Установленная в окружении программа
запущена по имени через `hsh-run --pty`; протокол совпал с протоколом задания 2
(без строки-заголовка `script`, где различается только `./Show` / `Show`).

### Задание 6. Сборочные и эксплуатационные зависимости

`rpm -qp --requires` (`logs/06-requires.txt`) — только вычисленные зависимости:
`libncurses.so.6()(64bit)`, `libtinfo.so.6()(64bit)`, `libc.so.6(...)`,
`ld-linux-x86-64.so.2`, `rtld(GNU_HASH)`, `rpmlib(...)`. Явных `Requires` в spec
нет, devel-пакета в зависимостях нет: find-requires берёт их из NEEDED-записей ELF.
`libtinfo.so.6` вызван тем, что `-lncurses` раскрывается в `-ltinfo`.

В чистом окружении (без ncurses) установка отклонена:
`libncurses.so.6()(64bit) ... is needed by dzhakishev-show-1.0-alt1`, код 1
(`libtinfo6` уже входит в базовую систему). После `hsh-install libncurses6`
установка прошла, `Show` работает (код 0), `libncurses-devel` не установлен.

Devel-версия нужна только компилятору и компоновщику (заголовки, ссылка
`libncurses.so` без версии, `.pc`). Программа при запуске ищет `libncurses.so.6`
по soname — его даёт основной пакет. Правила именования ALT: основной пакет
библиотеки называется по soname с номером версии (`libncurses6`, `libtinfo6`),
файлы для разработки — `<имя>-devel`, статические — `<имя>-devel-static`,
32-битные сборки — с префиксом `i586-`.

### Задание 7. Локальный репозиторий и debuginfo

`hsh ~/hasher-lab02 dzhakishev-show-1.0-alt1.src.rpm` — код 0. Результат:

```
~/hasher-lab02/repo
├── SRPMS.hasher/dzhakishev-show-1.0-alt1.src.rpm
└── x86_64/RPMS.hasher/
    ├── dzhakishev-show-1.0-alt1.x86_64.rpm
    └── dzhakishev-show-debuginfo-1.0-alt1.x86_64.rpm
```

Каталог `x86_64` совпадает с `uname -m`. Подпакет `-debuginfo` создаётся
автоматически, потому что в пакете есть ELF-файл, собранный с `-g`: brp-скрипты
отделяют отладочную информацию (основной `Show` — stripped, 14600 байт).
Состав debuginfo: `/usr/lib/debug/usr/bin/Show.debug` (with debug_info),
ссылки `/usr/lib/debug/.build-id/...`, исходник `/usr/src/debug/dzhakishev-show-1.0/show.c`.
Общих файлов с основным пакетом нет (`comm -12` пуст). Нужен для отладки
(gdb, разбор core-файлов) без утяжеления основного пакета.

### Задание 8. Проверка и публикация

`check/check-lab02.sh` выполняет 29 проверок заданий 1–7 и печатает PASS/FAIL/SKIP
и итог; код возврата 1, если есть FAIL. Интерактивные проверки идут в
псевдотерминале (`script -qec` с подачей клавиш), группы «стенд» и «hasher»
пропускаются при отсутствии каталогов.

## Выводы

* Терминал интерпретирует часть байтов как управляющие символы, а управление
  экраном — последовательностями, различными для разных типов; terminfo и
  ncurses скрывают эти различия, если `TERM` указан верно.
* Для сборки программы на ncurses нужен `libncurses-devel`, для работы —
  только `libncurses6`; эксплуатационные зависимости вычисляются автоматически.
* make пересобирает только устаревшие цели по времени изменения файлов.
* sisyphus_check требует корректные сведения о сопровождающем в Packager и в
  `%changelog`; hasher записывает их в `.rpmmacros` окружения.
* Автосборка в hasher кладёт результат в локальный репозиторий, разделённый на
  SRPMS и архитектуру, и выделяет отладочную информацию в подпакет debuginfo.
