

Uses common, error, conditional;

type
     TCharacter = char;
 NodeType = (ArithOp, compareOp, bool, number, strng, error);
// Opertype = (opAdd, OpSub, OpMul, OpDiv,
//             opAND, opOR, opNOT, opIN, opEQ,
//             opNE,  opGT, opLT,  opGE, opLE);
 StringRec = record
     Len,
     Pos: Integer;
     S: String;
  end;

 pAstNode = ^tAstNode;
 tAstNode = record
             first, second: pAstNode;

             case typ: NodeType of
              bool: (res: boolean);
              number: (value: integer );
              ArithOp,CompareOp: (operation: ttokenkind);
// ArithOp,CompareOp: (operation: char);
              strng: ( str: stringrec );
              error: ();
            end;

 var

    Signs:  Set of TCharacter = ['+','-'];
    MulDiv: Set of  TCharacter = ['*','/'];
    Digits: set of TCharacter = ['0'..'9'];
    Bools: set of TCharacter = ['<','=','>'];

    CompareOperator: Char;
    lCh,
    CH:Char;
    TK: TToken;
    GetOut: Boolean;

Procedure GetInt(var Str:StringRec);
begin
    TK.OrdValue :=0;
    TK.Kind:=INTNUMBERTOK;
    while ( Str.Pos <= Str.Len ) and ( Str.S[Str.Pos] in Digits) do
    begin
        TK.OrdValue:= TK.OrdValue*10+(Ord(Str.S[Str.Pos])-DigitZero);
        Inc(Str.Pos);
    end;
end;   // getint

Procedure SkipSpaces(var Str:StringRec);
Begin
    While ( Str.Pos <= Str.Len ) and ( Str.S[Str.Pos] in spaces ) do
        Inc(Str.Pos);
end;

procedure GetCH(var Str:StringRec);
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

procedure GetString(var Str:StringRec);
VAR
 L: Integer;
begin
 TK.Name := '';
 l :=0;
 repeat
     if CH <> '''' then
     begin
         TK.Name := TK.name + CH;
         TK.NonUppercaseName := TK.NonUppercaseName + CH;
         Inc(L);
         GetCh(Str);
     end
     else
     begin
         GetCh(Str);
         if CH = '''' then
         begin
             TK.Name := TK.name + CH;
             TK.NonUppercaseName := TK.NonUppercaseName + CH;
             Inc(L);
             GetCh(Str);
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
     GetCh(Str);
 end;
end;

// "Cheap version" of GetIdentUnsafe but since
// we can't access the parser from here I need
// a simple alternative to query the symbol table
// and return YES/NO on whether a particular
// identifier is defined to the program

function isDeclared(ID:String):Boolean;
VAR I: Integer;
begin
 Result := true;
 For I := NumIdent downto 1 do
     If Ident[I].Name = ID then exit;
 Result := False;
end;

{This, in effect,is a "cut down" version of the scanner}


procedure GetTK(var Str:StringRec);
VAR
 Macro: String;
 isNumeric:Boolean;
 Value:Integer;

 procedure GetDefine;
 VAR
     Paren:boolean;

 begin
     SkipSpaces(Str);
     Paren:=false;
     if ch='(' then
     begin
        Paren := TRUE;
        GetCh(Str);
     end;
     if ch in Identifiers then
     begin
         GetIdent(Str);
         IF Paren THEN
             if CH <> ')' then
             begin // flag an error
                 Errors[1] := Copy(Str.S,1,Str.Pos);
                 Err(ERR_CondDirective);
                 GetOut := true;
                 exit;
             end;
         GetCh(Str); // step over ) or space following
         TK.Kind := BOOLEANTOK;
         if Defined(TK.Name) then
             TK.OrdValue := 1
         else
             TK.OrdValue := 0;
     end
     ELSE
     begin // flag an error
         Errors[1] := Copy(Str.S,1,Str.Pos);
         Err(ERR_CondDirective);
         GetOut := true;
     end;
 end;


 procedure GetDeclared;
 VAR
     Paren:boolean;

 begin
     SkipSpaces(str);
     Paren:=false;
     if ch='(' then
     begin
        Paren := TRUE;
        GetCh(Str);
     end;
     if ch in Identifiers then
     begin
         GetIdent(str);
         IF Paren THEN
             if CH <> ')' then
             begin // flag an error
                 Errors[1] := Copy(Str.S,1,Str.Pos);
                 Err(ERR_CondDirective);
                 GetOut := true;
                 exit;
             end;
         GetCh(Str); // step over ) or space following
         TK.Kind := BOOLEANTOK;
         if isDeclared(TK.Name) then
             TK.OrdValue := 1
         else
             TK.OrdValue := 0;
     end
     ELSE
     begin // flag an error
         Errors[1] := Copy(Str.S,1,Str.Pos);
         Err(ERR_CondDirective);
         GetOut := true;
     end;
 end;


begin   // GetTK
 SkipSpaces(str);
 GetCh(Str);
 TK.Name := '';
 case CH of
      'A'..'I',
      'J'..'R',
      'S'..'Z',
      '_':   begin
                  GetIdent(str);
                  if TK.Name='DEFINED' then
                  begin
                      GetDefine;
                      exit;
                  end
                  else if TK.Name='DECLARED' THEN
                     begin
                         GetDeclared;
                         Exit;
                     end
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
                              TK.Kind := STRINGLITERALTOK
                        // it's not, so use the chars as is
                      else
                          TK.Kind := STRINGLITERALTOK                 end;
               end;
      '0'..'9':GetInt(Str);
      '>':     begin
                   TK.Kind := GTTOK;
                   GetCh(Str);
                   if CH = '=' then
                   begin
                       TK.Kind := GETOK;
                       GetCh(Str);
                   end;
               end;
      '<':     begin
                   TK.Kind := LTTOK;
                   GetCh(Str);
                   if CH = '=' then
                   begin
                       TK.Kind := GETOK;
                       GetCh(Str);
                   end
                   ELSE if CH = '>' then
                   begin
                       TK.Kind := NETOK;
                       GetCh(Str);
                   end
               end;
      '=' :    begin
                   TK.Kind := EQTOK;
                   GetCh(Str);
               end;
      '+' :    begin
                   TK.Kind := PLUSTOK;
                   GetCh(Str);
                   if ch in digits then
                      Getint(Str);
               end;
      '-' :    begin
                   TK.Kind := MINUSTOK;
                   GetCh(Str);
                   if ch in digits then
                   BEGIN
                        Getint(Str);
                        TK.OrdValue := -TK.OrdValue;
                   END;
               end;
      '*' :    begin
                   TK.Kind := MULTOK;
                   GetCh(Str);
               end;
      '/' :    begin
                   TK.Kind := DIVTOK;
                   GetCh(Str);
               end;
      '''':    GetString(Str);
      OTHERWISE
               WRITE('BAD CHAR "',CH,'" ',Ord(CH),' $',radix(Ord(ch),16));
               TK.Kind := JUNKTOK;
  end;
end;


function EndOf(f:StringRec): Boolean;
begin
   EndOf  := F.Pos > f.Len;
end;

function newOp(Ty:NodeType; op: ttokenkind; left: pAstNode): pAstNode;
 var
  node: pAstNode;
 begin
  new(node);
  node^.typ := Ty;
  node^.operation := op;
  node^.first := left;
  node^.second := nil;
  newOp := node;
 end;

 {
//function newArithOp(op: ttokenkind; left: pAstNode): pAstNode;
function newArithOp(op: char; left: pAstNode): pAstNode;
 var
  node: pAstNode;
 begin
//  new(node, ArithOp);
  new(node);
  node^.typ := ArithOp;
  node^.operation := op;
  node^.first := left;
  node^.second := nil;
  newArithOp := node;
 end;
 }


procedure disposeTree(tree: pAstNode);
 begin
  if tree^.typ = ArithOp
   then
    begin
     if (tree^.first <> nil)
      then
       disposeTree(tree^.first);
     if (tree^.second <> nil)
      then
       disposeTree(tree^.second)
    end;
  dispose(tree);
 end;
{
procedure skipWhitespace(var f: StringRec);
 var
  ch:char;

 function isWhite: boolean;
 begin
     isWhite := false;
     if not (EndOf(F)) then
         if f.S[f.Pos] = ' ' then
            isWhite := true
  end;

 begin
     while isWhite do
         inc(f.Pos);
 end;
 }
function parseMulDiv(var f: StringRec): pAstNode; forward;
function parseValue( var f: StringRec): pAstNode; forward;

// handles prefix operators
function parseAddSub(var f: StringRec): pAstNode;
var
    node1, node2: pAstNode;
    continu: boolean;
    StartPoint:Integer;
    TestStr:String;

begin
    Writeln('called parseAddSub F.pos=',F.pos,' kind=',GetTokSpelling(TK.Kind),' len=',f.Len);
    node1 := parseMulDiv(f);
    if node1^.typ <> error   then
    begin
        continu := true;
        while continu and not endOf(f) do
        begin
//            skipWhitespace(f);
            GetTK(F);
            Writeln('$$[1[ Pos=',f.pos,' kind=',GetTokSpelling(TK.Kind),' Char=',f.s[F.Pos]);


//            if f.s[F.Pos] in ['+', '-']  then
            if (TK.Kind = PLUSTOK) or  (TK.Kind=MINUSTOK) then
            begin
//                node1 := newArithOp(f.s[F.Pos], node1);
                node1 := newOp(ArithOp,
                TK.Kind,
                node1);
//                inc(f.pos);
                node2 := parseMulDiv(f);
                if (node2^.typ = error) then
                begin
                    disposeTree(node1);
                    node1 := node2;
                    continu := false
                end
                else
                    node1^.second := node2
            end
            else
                continu := false;
        end;
    end;
    parseAddSub := node1;
    Writeln('ex parseAddSub  F.pos=',F.pos,' kind=',GetTokSpelling(TK.Kind),' len-',f.Len);
end;

{
// Sets up mult-character comparators / operators
function TestCompare(Var F: Stringrec): boolean;
Label
    NO;
Var
    StartPos:Integer;
    TestStr: String;
    Ch2: Char;

begin
    if (F.S[StartPos] in bools ) or
       (F.S[StartPos] in Identifiers) then
    begin
        if f.S[f.pos] in bools then
        begin
            CompareOperator := f.S[f.pos];
            inc(f.pos);
            skipwhitespace(F);
            Ch2 := f.S[f.pos];
            IF Ch2 in Bools then
            begin
                inc(f.pos);
                if (CompareOperator='<') and (Ch2='=') then
                    CompareOperator := 'L'  // <= LE
                else if (CompareOperator ='<') and (Ch2='>') then
                    CompareOperator := 'E'  // <> NE, NOT uses N
                 else if (CompareOperator ='>') and (Ch2='=') then
                    CompareOperator := 'G'  // >= GE
                ELSE
                    Goto NO;  // Not understood
            end;
        end
        else
        begin   // s[f.pos] in Identifiers
            TestStr :='';
            StartPos := f.pos;
            While f.s[f.pos] in AlphaNums do
            begin
                TestStr := UpCase(f.s[f.pos]);
                inc(f.pos);
            end;
            if (TestStr='AND') or (TestStr='OR') or
               (TestStr='NOT') then
               CompareOperator := TestStr[1]
            ELSE
               Goto NO;  // it's not one of the operators
        end;
        Result := True;
        Exit;
    end;
    // it isn't; rollback
NO:
    f.pos := StartPos;
end;
}

// handles infix operators
function parseMulDiv(var f: StringRec): pAstNode;
var
    node1, node2: pAstNode;
    continu: boolean;
begin
    Writeln('called parseMulDiv  F.pos=',F.pos,' kind=',GetTokSpelling(TK.Kind),' len-',f.Len);
    node1 := parseValue(f);
    if node1^.typ <> error   then
    begin
        continu := true;
        while continu and not endOf(f) do
        begin
            GetTk(F);
            Writeln('$$[2[ Pos=',f.pos,' kind=',GetTokSpelling(TK.Kind),' Char=',f.s[F.Pos]);
//            if f.S[f.pos] in ['*', '/'] then
            if (TK.Kind=MULTOK) or (TK.Kind=DIVTOK) then
            begin
                node1 := newOp(ArithOp,TK.Kind, node1);
//              inc(f.pos);
                node2 := parseValue(f);
                if (node2^.typ = error) then
                begin
                    disposeTree(node1);
                    node1 := node2;
                    continu := false;
                end
                else
                    node1^.second := node2
            end
{            else if TestCompare(F) then
            begin
                node1 := newCompareOp(CompareOperator, node1);
//                inc(f.pos);
                node2 := parseValue(f);
                if (node2^.typ = error) then
                begin
                    disposeTree(node1);
                    node1 := node2;
                    continu := false;
                end;
            end     }
            else
                continu := false
        end;
    end;
    parseMulDiv := node1;
    Writeln('ex parseMulDiv  F.pos=',F.pos,' kind=',GetTokSpelling(TK.Kind),' len=',f.Len);
 end;

function parseValue( var f: StringRec): pAstNode;
var
    node:  pAstNode;
    value: integer;
    neg:   boolean;
begin
    Writeln('called parseValue  F.pos=',F.pos,' kind=',GetTokSpelling(TK.Kind),' len-',f.Len);
    node := nil;
    GetTK(F);
    Writeln('$$[3[ Pos=',f.pos,' kind=',GetTokSpelling(TK.Kind),' Char=',f.s[F.Pos]);
//    if f.s[f.pos] = '('   then
    if TK.Kind = OPARTOK then
    begin
        node := parseAddSub(f);
        if node^.typ <> error  then
        begin
            GetTK(F);
            Writeln('$$[4[ Pos=',f.pos,' kind=',GetTokSpelling(TK.Kind),' Char=',f.s[F.Pos]);
//            if f.s[f.pos] = ')' then
            if TK.Kind = OPARTOK then
                GetTK(F)
            else
            begin
                disposeTree(node);
//                new(node, error)
                  new(node);
                  Node^.First := NIL;
                  Node^.second := NIL;
                  node^.typ := error;
            end
        end
    end
    else if TK.Kind = INTNUMBERTOK  then
    begin
{       neg := f.s[f.pos] = '-';
        if f.s[f.pos] in signs  then
            inc(f.pos);
        value := 0;
        Writeln('$$[6[ Pos=',f.pos,' Char=',f.s[F.Pos]);
        if f.s[f.pos] in digits  then
        begin
            Writeln('$$[7[ Pos=',f.pos,' Char=',f.s[F.Pos]);
            while f.s[f.pos] in digits do
            begin
                value := 10 * value + (ord(f.s[f.pos]) - ord('0'));
                inc(f.pos);
            end;
//            new(node, number);
}
           new(node);
           Node^.First := NIL;
           Node^.second := NIL;

           node^.typ := number;

{            if (neg) then
                node^.value := -value
            else
}
           node^.value := TK.OrdValue;

    end
    else if TK.Kind = STRINGLITERALTOK then
    begin
        new(node);
        Node^.First := NIL;
        Node^.second := NIL;
        node^.typ := strng;
        Node^.str.Len:= Length(TK.Name);
        Node^.str.Pos:= 1;
    end
    else
    if node = nil  then
 //      new(node, error);
        begin
           new(node);
           Node^.First := NIL;
           Node^.second := NIL;
           node^.typ := error;
         end;
     parseValue := node;
     Writeln('ex parseValue F.pos=',F.pos,' kind=',GetTokSpelling(TK.Kind),' len-',f.Len);
end;

function eval(ast: pAstNode): integer;
var
    temp1,temp2: Integer;

begin
    Writeln('called eval');
    with ast^ do
        case typ of
        number: eval := value;
        ArithOp:
             case operation of
             PLUSTOK: eval := eval(first) + eval(second);
             MINUSTOK: eval := eval(first) - eval(second);
             MULTOK: eval := eval(first) * eval(second);
             DIVTOK: begin
                 // see if you can guess why
                 // this was changed:
//              eval := eval(first) div eval(second);
                      temp1 := eval(first);
                      temp2 := eval(second);
                      if temp2 <> 0 then
                          eval := Temp1 div temp2
                      else   // avoid divide by zero error
                          eval := 0;
                   end;
             end;
        error: writeln('Oops! Program is buggy!')
    end;
    Writeln('ex eval');
end;

Procedure WriteOperator(OP: TTokenKind);
Var
     S:TString;
begin
    S:= GetTokSpelling(Op);
    Write(' ',S,' ');

end;

procedure showType(ast: pAstNode);
begin
    case ast^.typ of
             ArithOp:begin
 //                     Showtype(ast^.first);
                      Write('ar ');
 //                     WriteOperator(ast^.operation);
 //                     Showtype(ast^.second);
                     end;
             compareOp:Write('comp ');

             bool:begin Write('bool:'); if Ast^.res then write('T ') else write('F '); END;
             number:Write(ast^.value,' ');
             strng: write('str ');
             error: write('error ')
             otherwise
             write('Unk ');
     end;
end;

Procedure DumpAst(ast: pAstNode);
begin
     If Ast^.first <>nil then
        DumpAst(ast^.First);
     showType(ast);
     WriteOperator(ast^.operation);
     If Ast^.second <>nil then
        dumpast(ast^.second) ;
end;

procedure Cond(K: StringRec);
Var
    L,
    I:Integer;
begin
    If (upcase(k.s[2])='D') or (upcase(k.s[2])='U') then
    begin
         tok.name :='';
         tok.NonUppercaseName := '';
         While k.s[i]=' ' do
           inc(i);
         While k.s[i] in alphanums do
         begin
               tok.name := Tok.Name+k.s[i];
               inc(I);
         end;
         IF  (upcase(k.s[2])='D') THEN
         begin
         if k.s[i]=':' then
         begin
             inc(I);
             if k.s[i]='=' then
             begin
                 inc(I);

                 While I<= k.Len do
                 begin
                     tok.NonUppercaseName := tok.NonUppercaseName+K.s[i];
                     inc(I);
                 end;
             end;
         end;
         tok.kind := CCSDEFINETOK;
         end
         else
            tok.kind := CCSUNDEFTOK;
         SkipConditionally;
    end
    else if (upcase(k.s[2])='X') then
    DumpDefineList;
end;

procedure ReadEvalPrintLoop;
var
    ast: pAstNode;
    K: StringRec;
    S:String;

begin
    Readln(S);

    while s<>'' do
    begin
        K.S := S;
        K.Pos :=1;
        K.Len := Length(S);
        wHILE k.pOS <=k.lEN DO
        BEGIN
            gETtK(k);
            wRITE('pos=',k.pos,' kind=',GetTokSpelling(TK.Kind),' ');
            IF tk.kIND=INTNUMBERTOK then
               Write(Tk.OrdValue,' ');
            if Tk.Kind=BOOLEANTOK then
                if TK.OrdValue=0 then write('False ')
                else write('True ');
            WRITELN(' Char=',K.s[K.Pos]);
        end;
        WRITELN;
        readln(S);

{
        if k.s[1]='$' then
           Cond(K)
    else begin
        TK.Kind := EMPTYTOK;

        ast := parseAddSub(K);
        Writeln('*** TREE ***');
        dumpast(Ast);
        writeln;

        if (ast^.typ = error) or not EndOf(k)   then
        begin
            if ast^.typ = error then writeln('not defined error');
            writeln('k.pos=',k.pos,' K.Len=',k.len);
            writeln('Error in expression.');
            case ast^.typ of
             ArithOp:Write('arith ');
             compareOp:Write('comp');
             bool:Write('bool');
             number:write('number');
             strng: write('str');
             error: write('error')
             otherwise
             write('Unk');
            end ;
            Writeln(' pos=',K.pos,' len-',K.Len);
        end
        else
            writeln('Result: ', eval(ast));
        readln(S);
        disposeTree(ast);
        end
        }
    end;
end;

begin
    ReadEvalPrintLoop;
end.

