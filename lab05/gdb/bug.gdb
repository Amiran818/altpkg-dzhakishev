# bug.gdb - поиск ошибки записи по неинициализированному указателю (задание 3)
set pagination off
break show_balance
break add_bonus
info breakpoints
run
next
echo == show_balance: адрес и значение локальной переменной field\n
print &field
print field
print &acc.balance
print/x $sp
continue
echo == add_bonus: адрес и значение неинициализированного указателя bonus\n
print &bonus
print bonus
print/x $sp
x/6gx $sp - 16
echo == стек вызовов\n
backtrace
info args
up
info args
up
info args
down
down
delete
continue
