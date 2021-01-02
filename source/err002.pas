Program err002; // error test: Else not part of if
VAR
  B: Boolean;
  A: Integer;

Procedure Dummy;
begin
end;

begin
  If B then
     dummy;
  A := 2;
  else         // should cause "end expected"
      dummy;
end.

