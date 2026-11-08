/*
 * Show - постраничный просмотр текстового файла (ncurses).
 * Лабораторная работа 2, Джакишев А.М., КТ-22-04.
 *
 * Использование: Show <файл>
 *   пробел - следующая страница, q - выход.
 */
#include <curses.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* файл целиком в памяти: буфер и массив указателей на начала строк */
static char *text;
static char **lines;
static int nlines;

static int load_file(const char *name)
{
    FILE *f = fopen(name, "r");
    long size;
    int i;

    if (f == NULL)
        return -1;
    if (fseek(f, 0, SEEK_END) != 0 || (size = ftell(f)) < 0 ||
        fseek(f, 0, SEEK_SET) != 0) {
        fclose(f);
        return -1;
    }
    text = malloc(size + 1);
    if (text == NULL || fread(text, 1, size, f) != (size_t)size) {
        fclose(f);
        return -1;
    }
    fclose(f);
    text[size] = '\0';

    /* число строк = число '\n' (+1, если последняя строка без '\n') */
    nlines = 0;
    for (i = 0; i < size; i++)
        if (text[i] == '\n')
            nlines++;
    if (size > 0 && text[size - 1] != '\n')
        nlines++;

    lines = malloc(sizeof(char *) * (nlines + 1));
    if (lines == NULL)
        return -1;
    nlines = 0;
    if (size > 0)
        lines[nlines++] = text;
    for (i = 0; i < size; i++) {
        if (text[i] == '\n') {
            text[i] = '\0';            /* конец строки */
            if (i + 1 < size)
                lines[nlines++] = &text[i + 1];
        }
    }
    return 0;
}

/* вывести строку в текущую позицию окна, усекая по ширине окна */
static void put_line(WINDOW *win, int row, const char *s, int width)
{
    int col = 0;

    wmove(win, row, 0);
    for (; *s != '\0' && col < width; s++) {
        if (*s == '\t') {
            do
                waddch(win, ' ');
            while (++col % 8 != 0 && col < width);
        } else {
            waddch(win, (unsigned char)*s);
            col++;
        }
    }
}

int main(int argc, char *argv[])
{
    WINDOW *win;
    int top = 0, height, width, i, ch;

    if (argc != 2) {
        fprintf(stderr, "Usage: Show FILE\n");
        return 1;
    }
    if (load_file(argv[1]) != 0) {
        fprintf(stderr, "Show: %s: %s\n", argv[1], strerror(errno));
        return 2;
    }

    initscr();
    noecho();                 /* не отображать вводимые символы */
    cbreak();                 /* без построчной буферизации ввода */
    curs_set(0);

    mvprintw(0, 0, "File: %s", argv[1]);
    refresh();

    height = LINES - 1;
    width = COLS;
    win = newwin(height, width, 1, 0);   /* окно вывода под заголовком */
    keypad(win, TRUE);                   /* функциональные клавиши */

    for (;;) {
        werase(win);
        for (i = 0; i < height && top + i < nlines; i++)
            put_line(win, i, lines[top + i], width);
        wrefresh(win);

        ch = wgetch(win);
        if (ch == 'q' || ch == 'Q' || ch == 27)
            break;
        if (ch == ' ' && top + height < nlines)
            top += height;
    }

    delwin(win);
    endwin();                 /* восстановить режим терминала */
    free(lines);
    free(text);
    return 0;
}
