program exer10;
Const
     A = 0xBeef;
     A1= 0Xbeef;
     B = $BEEF;
     D = $beef;
     B1 = 8#05;
     C = 16#BEEF;
     X0= 2#1010; X1=4#10; X5=8#177362; X9=10#70944;



begin
    writeln('A = 0xBeef; A1= 0Xbeef; B = $BEEF; D = $beef; B1 = 8#05; C = 16#BEEF;');

     Writeln('A=',a,' a1=',a1,' b=',b,' d=',d,' b1=',b1,' c=',c);
     writeln;
     writeln(' X0= 2#1010; X1=4#10; X5=8#177362; X9=10#70944;');
     Writeln('X0=',X0,' X1=',X1,' X5=',X5,' X9=',X9);

end.

