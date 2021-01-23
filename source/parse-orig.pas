// this is the original code before I tear it apart

type
 NodeType = (ArithOp, compareOp, bool, number, strng, error);
 Opertype = (opAdd, OpSub, OpMul, OpDiv,
             opAND, opOR, opNOT, opIN, opEQ,
             opNE,  opGT, opLT,  opGE, opLE);
 StringRec = record
     Len,
     Pos: Integer;
     S: String;
  end;

 pAstNode = ^tAstNode;
 tAstNode = record
             first, second: pAstNode;
             oper: OperType;
             str: stringrec ;
             case typ: NodeType of
             ArithOp:( operation: char);
              bool: (res: boolean);
              number: (value: integer );
              strng,
              CompareOp,
              error: ();
            end;


function EndOf(f:StringRec): Boolean;
begin
   EndOf  := F.Pos > f.Len;
end;

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

// function parseAddSub(var f: StringRec): pAstNode; forward;
function parseMulDiv(var f: StringRec): pAstNode; forward;
function parseValue( var f: StringRec): pAstNode; forward;

function parseAddSub(var f: StringRec): pAstNode;
var
    node1, node2: pAstNode;
    continu: boolean;
begin
    Writeln('called parseAddSub F.pos=',F.pos,' len-',f.Len);
    node1 := parseMulDiv(f);
    if node1^.typ <> error   then
    begin
        continu := true;
        while continu and not endOf(f) do
        begin
            skipWhitespace(f);
            Writeln('$$[1[ Pos=',f.pos,' Char=',f.s[F.Pos]);
            if f.s[F.Pos] in ['+', '-']  then
            begin
                node1 := newArithOp(f.s[F.Pos], node1);
                inc(f.pos);
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
    Writeln('ex parseAddSub  F.pos=',F.pos,' len-',f.Len);
end;

function parseMulDiv(var f: StringRec): pAstNode;
var
    node1, node2: pAstNode;
    continu: boolean;
begin
    Writeln('called parseMulDiv  F.pos=',F.pos,' len-',f.Len);
    node1 := parseValue(f);
    if node1^.typ <> error   then
    begin
        continu := true;
        while continu and not endOf(f) do
        begin
            skipWhitespace(f);
            Writeln('$$[2[ Pos=',f.pos,' Char=',f.s[F.Pos]);
            if f.S[f.pos] in ['*', '/'] then
            begin
                node1 := newArithOp(f.S[f.pos], node1);
                inc(f.pos);
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
            else
                continu := false
        end;
    end;
    parseMulDiv := node1;
    Writeln('ex parseMulDiv  F.pos=',F.pos,' len-',f.Len);
 end;

function parseValue( var f: StringRec): pAstNode;
var
    node:  pAstNode;
    value: integer;
    neg:   boolean;
begin
    Writeln('called parseValue  F.pos=',F.pos,' len-',f.Len);
    node := nil;
    skipWhitespace(f);
    Writeln('$$[3[ Pos=',f.pos,' Char=',f.s[F.Pos]);
    if f.s[f.pos] = '('   then
    begin
        inc(f.pos);
        node := parseAddSub(f);
        if node^.typ <> error  then
        begin
            skipWhitespace(f);
            Writeln('$$[4[ Pos=',f.pos,' Char=',f.s[F.Pos]);
            if f.s[f.pos] = ')' then
                inc(f.pos)
            else
            begin
                disposeTree(node);
//                new(node, error)
                  new(node);
                  node^.typ := error;
            end
        end
    end
    else if f.s[f.pos] in ['0' .. '9', '+', '-']    then
    begin
        Writeln('$$[5[ Pos=',f.pos,' Char=',f.s[F.Pos]);
        neg := f.s[f.pos] = '-';
        if f.s[f.pos] in ['+', '-']  then
            inc(f.pos);
        value := 0;
        Writeln('$$[6[ Pos=',f.pos,' Char=',f.s[F.Pos]);
        if f.s[f.pos] in ['0' .. '9']  then
        begin
            Writeln('$$[7[ Pos=',f.pos,' Char=',f.s[F.Pos]);
            while f.s[f.pos] in ['0' .. '9'] do
            begin
                value := 10 * value + (ord(f.s[f.pos]) - ord('0'));
                inc(f.pos);
            end;
//            new(node, number);
           new(node);
           node^.typ := number;

            if (neg) then
                node^.value := -value
            else
                node^.value := value
        end
    end
    else
    if node = nil  then
 //      new(node, error);
    begin
         new(node);
         node^.typ := error;
    end;
    parseValue := node;
    Writeln('ex parseValue F.pos=',F.pos,' len-',f.Len);
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
             '+': eval := eval(first) + eval(second);
             '-': eval := eval(first) - eval(second);
             '*': eval := eval(first) * eval(second);
             '/': begin
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

        ast := parseAddSub(K);
        if (ast^.typ = error) or not EndOf(k)   then
        begin
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
    end;
end;

begin
    ReadEvalPrintLoop;
end.

