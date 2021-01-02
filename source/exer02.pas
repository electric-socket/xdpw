Program Exer02;

Type
  RecP = ^Rec;
  Rec = Record
   Prev,Next: RecP;
   A:Char;
   B: Integer;
  end;

VAR
  RecA, RecB, RecC: RecP;

begin
  New(RecA);
  New(RecB);
  RecA^.B := 5;
  RecB^.B := 6;


  RecC := RecB;

  Writeln(RecC^.B);
    New(RecC);

  RecC^ := RecA^;

  Writeln(RecC^.B);


  readln;
end.
