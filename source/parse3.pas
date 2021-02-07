program parse3;

Uses common, error, conditional;



VAR
    STR:StringRec;
    TK:TToken;
    lCh,
    CH: Char;
    GetOut: Boolean;


Procedure NextChar;
begin
 if  Str.Pos  > Str.Len then
    lCh := #0
 else
 begin
     lCh := Str.S[Str.Pos];
     inc(Str.Pos);
 end;
 CH := Upcase(lCH);
end;


procedure GetTK;
Var
    Neg:Boolean;

    Procedure SkipSpaces;
    Begin
        While ( Str.Pos <= Str.Len ) and ( Str.S[Str.Pos] in spaces ) do
            Inc(Str.Pos);
    end;


   Procedure Settk(Value:TToken);
   begin
       TK := Value;
       NextChar;
   end;

   Procedure GetInt;
   begin
       TK.OrdValue :=0;
       TK.Kind:=INTNUMBERTOK;
       while ( Ch in Digits) do
       begin
           TK.OrdValue:= TK.OrdValue*10+(Ord(Ch)-DigitZero);
           NextChar;
       end;
   end;   // getint

   procedure GetString(var Str:StringRec);
   VAR
       L: Integer;

   begin
       TK.Name := '';
       L :=0;
       repeat
           if CH <> '''' then
           begin
               TK.Name := TK.name + CH;
               TK.NonUppercaseName := TK.NonUppercaseName + lCH;
               Inc(L);
               NextChar;
           end
           else
           begin
               NextChar;
               if CH = '''' then
               begin
                   TK.Name := TK.name + CH;
                   TK.NonUppercaseName := TK.NonUppercaseName + CH;
                   Inc(L);
                   NextChar;
               end
               else
                   Break;
               end;
           until Str.Pos > Str.Len;
           if Length(TK.Name) = 1 then
           begin
               TK.Kind := CHARLITERALTOK;
               TK.OrdValue := Ord(TK.NonUppercaseName[1]);
           end
           else
           begin
               TK.Kind := STRINGLITERALTOK;
               TK.StrLength := L;
           end;
       end;

   Procedure GetIdent(var Str:StringRec);
   begin
       TK.Name := '';                // all upper-case version
       TK.NonUppercaseName := '';    // as typed
       while (CH in AlphaNums) do
       begin
           TK.Name := TK.Name + CH;
           TK.NonUppercaseName := TK.NonUppercaseName +  lCh;
           NextChar;
       end;
   end;


    procedure GetDefineDeclare(useDefine:Boolean);
    VAR
        Test,
        Paren:boolean;

        Procedure FlagError;
        begin               // flag an error
            Errors[1] := Copy(Str.S,1,Str.Pos);
            Err(ERR_CondDirective);
            GetOut := true;
        end;

    begin
        Paren:=false;
        NextChar;
        if ch='(' then
            Paren := TRUE
        else if not (Ch in spaces) then
        begin
            FlagError;
            Exit;
        end;
        SkipSpaces;
        NextChar;
        if ch in Identifiers then
        begin
             GetIdent(Str);
             IF Paren THEN
             begin
                 if CH <> ')' then
                 begin
                     FlagError;
                     Exit;
                 end;
             end
             else if not (Ch in spaces) then
             begin
                 FlagError;
                 Exit;
             end;
             SkipSpaces;
             NextChar; // step over ) or space following
             TK.Kind := BOOLEANTOK;
             Case UseDefine of
                  True: Test := isDefined(TK.Name);
                 False: Test := isDeclared(TK.Name);
             end;
             if Test then
                 TK.OrdValue := 1
             else
                 TK.OrdValue := 0;
        end
        ELSE
            FlagError;
    end;

   Procedure ReadName;
   Var
       Macro:String;

   begin
       GetIdent(str);
       if TK.Name='DEFINED' then
           GetDefineDeclare(TRUE)
       else if TK.Name='DECLARED' THEN
           GetDefineDeclare(FALSE)
       else if TK.Name='AND' then
           TK.Kind := ANDTOK
       else if  TK.Name='OR' then
           TK.Kind := ORTOK
       else if TK.Name='NOT' then
           TK.Kind := NOTTOK
       else
       begin  // if it's a defined value, retrieve it
           if GetDefineValue(TK.Name, Macro, isNumeric, value) then
               if IsNumeric then
               begin
                   TK.Kind := INTNUMBERTOK;
                   TK.OrdValue := Value;
               end
               else
               begin
                   TK.NonUppercaseName:= := Macro;
                   TK.Kind := STRINGLITERALTOK;
                end
           // it's not, so use the chars as is
           else
                TK.Kind := STRINGLITERALTOK
       end;
   end;


begin   // procedure GetTK
  NextChar;
  SkipSpaces;
  TK.Kind := EMPTYTOK;
  If S.Pos >S.Len then exit;
  case ch of
    '0'..'9': GetInt;
    'A'..'I', 'J'..'R', 'S'..'Z',
    'a'..'i', 'j'..'r', 's'..'z', '_':      ReadName;
    '''': Readtring;
    '+','-':
       BEGIN
           Neg := Ch='-';
           IF CH='-' then TK.Kind := MINUSTOK
           else TK.Kind := PLUSTOK;
           NextChar;
           if Ch in digits then
           begin
               GetInt;
               if neg then
                  TK.OrdValue := -TK.ORDValue;
           end;
       end;  // case of +,-
    '>':         // > or >=
       begin
           SetTK( GTTOK);
           if ch = '=' then SetTK( GETOK);
       end;    // case of >
    '<':               // < , <> ,  or <=
      begin
         SetTK( LTTOK);
         if ch = '=' then SetTK( LETOK)
         else if ch = '>' then SetTK( NETOK);
      end;  // case of <
    OTHERWISE              // single-character tokens
    case ch of
      '*': Token.Kind := MULTOK;
      '(': Token.Kind := OPARTOK;  // Plain (
      '/': Token.Kind := DIVTOK;
      '=': Token.Kind := EQTOK;
      ',': Token.Kind := COMMATOK;
      ')': Token.Kind := CPARTOK;
    OTHERWISE     // don;t know what the character is
       Token.Kind:=JUNKTOK;
       Token.Name:= Ch;
    end; // second case
    ReadChar(ch);
    end; // case

end; // Procedure GetTK



Procedure Eval;
begin
    While Str.Pos<= S.Len do
    begin
       GetTK;
       Writeln(GetTokSpelling(TK));
    end;
    Writeln;
end;

begin
    Write('Enter string: ');
    Readln(Str.S);
    Str.Pos:= 1;
    Str.Len:=Length(Str.S);
    while Str.Len<>0 do
    begin

        Eval;
        Readln(Str.S);
        Str.Pos:= 1;
        Str.Len:=Length(Str.S);
    end;
end.

