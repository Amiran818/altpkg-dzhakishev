/* bug.c - преднамеренная ошибка: запись по неинициализированному указателю */
#include <stdio.h>

struct account {
    int balance;
    int bonus;
};

static struct account acc = { 1000, 0 };

static void show_balance(void)
{
    int *field = &acc.balance;          /* локальной переменной присвоено значение */

    printf("balance before: %d\n", *field);
}

static void add_bonus(int percent)
{
    int *bonus;                          /* ОШИБКА: указатель не инициализирован */

    *bonus = acc.balance * percent / 100;
}

static void process(int percent)
{
    show_balance();
    add_bonus(percent);
}

int main(void)
{
    process(10);
    printf("balance: %d, bonus: %d\n", acc.balance, acc.bonus);
    return 0;
}
