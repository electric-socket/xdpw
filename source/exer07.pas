
Program exer07;
const
    C = 'This is a string';

VAR
  A, B: String;

begin
  A := B;
   Writeln(XDP_Unitname);
   Halt(99);
  Writeln(B);
{$Dump define}
{$define One}
{$define    Two;This is ignored}
{$define   Three    As is this}
{$Dump define}
{$define Four:=    This isn't ignored}
{$Dump define}
{$Undef Two;This should also be ignored}
{$Dump define}
end.
