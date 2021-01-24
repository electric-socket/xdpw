// tests the include statement
Program a;

CONST
    K =  $20;     // Dec  0010 0000
    L =   32;     // Hex  0010 0000
    M = 0x20;     // Hex  0010 0000
    N = 0X20;     // Hex  0010 0000
    KL = 8#40;    // Octal 00 100 000
    ML = &40;     // Octal 00 100 000

VAR
    QQ: Integer;

begin

    QQ := 4;
    Writeln(QQ);
{$Include B.inc}
    Writeln(QQ);
    writeln('K=',K,' L=',L,' M=',M,' N=',N,' KL=',KL,' ML=',ML);
{$SHOW statistics}
end.

