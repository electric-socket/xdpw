Program err003; // error test: F-format on Integer
{$show ident,narrow}
{$define zzzz:=Wait(1)}
{$define xdae}
{$dump define}
{$Show all,limit 5}
TYPE
    RPP = ^RP;
    RDP = ^RD;
    RP= Record
      Next: RPP;
      case boolean of
        true:(Data: Integer);
       False:(ptr: Pointer);
     End;
{$HIDE all}
     RD= Record
      Prev,
      Next: RDP;
      case boolean of
        true:(Data: Integer);
       False:(ptr: Pointer);
     End;

VAR
  A: Integer;
  s: STRING;
  pTR: pOINTER;
  PP: RPP;
  PD: RDP;
  R: Real;
  F: text;

  Procedure Dummy; Begin End;

begin

  A := 42;   // the answer to everything according to Douglas Adams
  R := 5.6;
  str(r,s,2,4);
  ptr := nIL;
  wRITELN('*',S,'*',ptr,'*');
  Writeln(R:2:4);   // This is legal
  Writeln(A:2:4);   // This is illegal; only legal for reals
(*
  Assign(F,'msg.txt');
  Rewrite(F);
  For A := 0 to 500 do
     Writeln(F,'{    ERR_',A,#9,'= ',A,' ; }');
  Close(F);
  Writeln('File msg.txt created.');
 *)

 // {$Show all,narrow}
 {$dump symtab,all}
  New(PD);
  Dummy;
  PP := NIL;
  PP:= PP^.Next;
  PD:=PD^.NEXT;
  {$Hide all}
  PP^.Data := A;
  XDP_NilPointer('pointe', 'proc', 'file.pas', True, 17304, A);

end.

