cd C:\Users\Paul\Documents\Programming\Pascal\xdpw
cd K:\repositories\xdpw\temp
K:
copy /y C:
copy /y C:units\* units
copy /y C:source\* source
del *.bak
del source\*.bak
del units\*.bak
del source\*.o
git add * source\* units\*
git commit -m rev_237
exit
