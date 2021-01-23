program eval;
var
   TheChar: char
   Len,
   NextChar: integer;
   TheString: string;

   Identifiers: Set of TCharacter = ['A'..'I', 'J'..'R', 'S'..'Z',
                                      'a'..'i', 'j'..'r', 's'..'z','_'];
   AlphaNums: set of TCharacter = ['0'..'9', 'A'..'I', 'J'..'R', 'S'..'Z',
                                             'a'..'i', 'j'..'r', 's'..'z','_'];



procedure skip;
begin
    while (NextChar<=Len) and s[NextChar]=' ' then
      inc(NextChar);
end;

procedure CheckDef;
Var
    Def: String

begin
    Def :='';
    While (NextChar<Len( and (TheChar in Alphanums) do
    begin
        Inc(NextChar)l
        Def := Def + TheChar;
        TheChar := TheString[NextChar];

    endl
end;

Procedure evaluate;
begin
    TheString := trim(TheString);
    if TheString = '' then exit;
    Len:= Length(TheString);
    I :=1;
    repeat
        TheChar:=TheString[i];
        case TheChar of
         'A'..'Z','a'..'z','_': CheckDef
          '0'..'9': CheckNum;
          '$': Test;
         end
    until I>= Len;
end;


begin
   repeat
       readln(TheString);
       Evaluate
   until TheString='';

end.

