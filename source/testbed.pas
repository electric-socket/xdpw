program testbed;

procedure writeHex(S:String; PrefixSize:Integer);
Const
    MaxLen = 35;

Var
   C:Byte;
   I,K,L: Integer;
   Line2:String;
   PP: Boolean;

begin

    L := Length(S);
    K := 0;
    PP := FALSE;
    For I := 1 to L do
    begin
         C := Ord(S[I]);
         if PP then
             write(' ':prefixsize);
         PP := false;
         if c<32 then
           Write(' ':2)
          else
              Write(' ',S[I]);
         Line2 := Line2+RadixString[((C and $F0) shr 4)];
         Line2 := Line2+RadixString[C and $0F];
         INC(k);
         IF K>MaxLen THEN
         BEGIN
             Writeln;
             write(' ':prefixsize);
             writeln(line2);
             PP := TRUE;
             K :=0;
             Line2 := '';
         END;
   end;
   Writeln;
   if k=0 then exit;
   write(' ':prefixsize);
   writeln(line2);
end;


begin
   Write('aaaa');
   writeHex('abc123456789qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM,./<>?;'':"{}[]_+|-=\~`',4);
end.

