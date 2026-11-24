# variants.gdb - сравнение вариантов сборки (задание 2)
set pagination off
list run
break run
run 3 > /dev/null
info locals
next
next
next
next
info locals
