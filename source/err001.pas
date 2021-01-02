Program Err001; // error test
VAR
  B: Boolean;

Procedure Dummy;
begin
end;

begin
  If B then
     dummy;     // ; is error here
  else         // should cause "end expected"
      dummy;
end.

