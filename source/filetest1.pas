program filetest1;
Var F: Text;
    I,
    R,
    W: Integer;
    S: String;

    function GetLastError: LongInt stdcall; external 'KERNEL32.DLL';


Begin
     Assign(F,'FileTest1.pas');
     Reset(F);
     For i := 1 to 100 do
     begin
         Readln(F,S);
         R := IOResult;
         W := GetLastError;
         Writeln('I=',I:3,' IOR=',R:3,' WI=',W:3,' ',S);
     end;
     Writeln;
     writeln('Completed/');
     readln;

End.
