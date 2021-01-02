{$Define A}
{$define C:=Hello there}
{$undef b}
{$define D:=177362}
{$Dump define}
Program exer11;
VAR
    A: integer;

BEGIN
   A := 10;
{$ifndef a}
   a :=11;
   a := 13;
{$ELSE}
   a := 12;
//{$ENDIF}
   wRITELN(A);
end.
