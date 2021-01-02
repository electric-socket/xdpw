{$Show all,code,narrow,codegen}
Program exer06;
const
    C = 'This is a string';

VAR
  A, B: String;

begin
  A := B;
   Writeln(XDP_Unitname);
   Halt(99);
  Writeln(B);
{$Dunp symtab,all}
end.
