// tests the include statement
Program a;

CONST
    K =  $20;
    L =   32;
    M = 0x20;
    N = 0X20;
    KL = 8 ;//#40;

VAR
    QQ: Integer;

begin

    QQ := 4;
    Writeln(QQ);
{$Include B.inc}
    Writeln(QQ);
    writeln('K=',K,' L=',L,' M=',M,' N=',N,' KL=',KL);
{$SHOW statistics}
end.

