# range.gdb - значения только для элементов с номерами 3..5
set pagination off
set confirm off
break emit if idx >= 3 && idx <= 5
commands
  silent
  printf "LAB5 range idx=%ld value=%ld\n", idx, value
  continue
end
run 10 0 -2 > /dev/null
