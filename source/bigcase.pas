// This program, from page 364 of the HP Standard Pascal Reference
// Manual (10/87) for the HP9000 minicompter, according to
// Hewlett Packard themselvers, will crash that compiler, because
// it tries to create every case from 0 to MAXINT, about 2 billion
// case selectors (to be precise, 2,147,483,647).
//
// Will it crash XDPW? Let's find out!
program bigcase;
var
i : integer;
begin
    I := Maxint - 1;
case i of
(* the original had a syntax error, which was
   no colon after Maxint:

0: ;
maxint
end

 It has been correted to: *)
   0: Writeln ('0');
   maxint: Writeln(Maxint)
   otherwise
    writeln ('Neither high nor low');
   end;
end.
