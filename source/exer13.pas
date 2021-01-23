{#DEFINE Z}
program exer13;
Const
{$IFNDEF X}
     X = 4;
{$ELSE}
     X = 2;
{$ENDIF}
     Y = 3;
{$IFNDEF X}
     Z = 7;
{$ELSE}
     Z = 6;
{$ENDIF}


Var
    K: Integer;


begin
     Writeln('If X is defined,     X=4, Y=3, Z=6');
     Writeln('If X is not defined, X=2, Y=3  Z=7');
     Writeln('Our results:');

     Write('X=',X,' Y=',y,' Z=',Z);

end.

