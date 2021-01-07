// XD Pascal for Windows (XPDW) - a 32-bit compiler

// VERSION 0.16 {.0}

// Program to test whether I can create an oversize string, e.g over 255 chars

program exer12;
Var
//    RealLong: String[600];   // doing thiscauses illegal string length
    A,
    B,
    C: String;
    I: Integer;

begin
    B := 'ABCDE';
    Write('Length(B)=');
    Write(Length(B),' ');
    Write('B="',B,'"');
    Writeln;
    For I := 1 to 249 do
      A:= a+'Z';
    Write('Length(a)=',Length(a),' ');
    Write('Length(B)=');
    Write(Length(B),' ');
    Write('B="',B,'"');
    Writeln;
    For I:= 0 to 9 do
       A :=A+Chr(I+ord('0'));
    Write('Length(a)=',Length(a),' ');
    Write('Length(B)=');
    Write(Length(B),' ');
    Write('B="',B,'"');
    Writeln;
    For I := 240 to 260 do
       Write(A[i],' ');
    writeln;
    Write('Length(a)=',Length(a),' ');
    Write('Length(B)=');
    Write(Length(B),' ');
    Write('B="',B,'"');
    Writeln;
    B := 'ABCDE';
    Write('Length(a)=',Length(a),' ');
    Write('Length(B)=');
    Write(Length(B),' ');
    Write('B="',B,'"');
    Writeln;
end.

