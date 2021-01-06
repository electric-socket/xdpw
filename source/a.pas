Program a;

CONST
    K =  $20;
    L =   32;
    M = 0x20;
    N = 0X20;

VAR
    QQ: Integer;

begin

    QQ := 4;
    Writeln(QQ);
{$I B.inc}
    Writeln(QQ);
    writeln('K=',K,' L=',L,' M=',M,' N=',N);
end.

