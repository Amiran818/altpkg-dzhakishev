# trace.gdb - условная точка останова: каждый чётный элемент прогрессии
# Значимые строки помечены префиксом "LAB5 ", остальное - служебный вывод gdb.
set pagination off
set confirm off
break emit if idx % 2 == 0
commands
  silent
  printf "LAB5 trace idx=%ld value=%ld\n", idx, value
  backtrace
  continue
end
run 0 20 5 > /dev/null
