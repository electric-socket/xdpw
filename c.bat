rem Run test compile
source\upd
xdpw source\XDPW.pas
if ERRORLEVEL gtr 0 GOTO bad
move /y source\xdpw.exe x.exe
x  source\XDPW.pas
if ERRORLEVEL gtr 0 GOTO bad2
del x.exe
move /y source\xdpw.exe
start bk.bat
rem successful
goto :EOF
:bad
rem Compiler has errors
goto :EOF
:bad2
rem compiler not working
