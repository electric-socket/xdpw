// this is the original code before I tear it apart

type
 NodeType = (binop, number, strng, error);

  StringRec = record
     Len,
     Pos: Integer;
     S: String;
  end;

 pAstNode = ^tAstNode;
 tAstNode = record
             case typ: NodeType of
              binop:
              (
                res: boolean;
                operation: char;
                first, second: pAstNode;
              );
              number: (value: integer );
              strng: (str:stringrec );
              error: ();
            end;

function EndOf(f:StringRec): Boolean;
begin
   EndOf  := F.Pos > f.Len;
end;

function newBinOp(op: char; left: pAstNode): pAstNode;
 var
  node: pAstNode;
 begin
  new(node, binop);
  node^.operation := op;
  node^.first := left;
  node^.second := nil;
  newBinOp := node;
 end;

procedure disposeTree(tree: pAstNode);
 begin
  if tree^.typ = binop
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

function parseAddSub(var f: StringRec): pAstNode; forward;
function parseMulDiv(var f: StringRec): pAstNode; forward;
function parseValue( var f: StringRec): pAstNode; forward;

function parseAddSub;
 var
  node1, node2: pAstNode;
  continu: boolean;
 begin
     node1 := parseMulDiv(f);
     if node1^.typ <> error   then
     begin
         continu := true;
         while continu and not endOf(f) do
         begin
             skipWhitespace(f);
             if f.s[F.Pos] in ['+', '-']  then
             begin
                 node1 := newBinop(f^, node1);
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
 end;

function parseMulDiv;
var
    node1, node2: pAstNode;
    continu: boolean;
begin
    node1 := parseValue(f);
    if node1^.typ <> error   then
    begin
        continu := true;
        while continu and not endOf(f) do
        begin
            skipWhitespace(f);
            if f.S[f.pos] in ['*', '/'] then
            begin
                node1 := newBinop(f^, node1);
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
 end;

function parseValue;
var
    node:  pAstNode;
    value: integer;
    neg:   boolean;
begin
    node := nil;
    skipWhitespace(f);
    if f.s[f/pos] = '('   then
    begin
        inc(f.pos);
        node := parseAddSub(f);
        if node^.typ <> error  then
        begin
            skipWhitespace(f);
            if f.s[f.pos] = ')' then
                inc(f.pos)
            else
            begin
                disposeTree(node);
                new(node, error)
            end
        end
    end
    else if f.s[f.pos] in ['0' .. '9', '+', '-']    then
    begin
        neg := f.s[f.pos] = '-';
        if f.s[f.pos] in ['+', '-']  then
            inc(f.pos);
        value := 0;
        if f.s[f.pos] in ['0' .. '9']  then
        begin
            while f.s[f.pos] in ['0' .. '9'] do
            begin
                value := 10 * value + (ord(f^) - ord('0'));
                inc(f.pos);
            end;
            new(node, number);
            if (neg) then
                node^.value := -value
            else
                node^.value := value
        end
    end;
    if node = nil  then
       new(node, error);
    parseValue := node
end;

function eval(ast: pAstNode): integer;
var
    temp1,temp2: Integer;

begin
    with ast^ do
        case typ of
        number: eval := value;
        binop:
             case operation of
             '+': eval := eval(first) + eval(second);
             '-': eval := eval(first) - eval(second);
             '*': eval := eval(first) * eval(second);
             '/': begin
                 // see if you can guess why
                 // this was changed:
//              eval := eval(first) div eval(second);
v                     temp1 := eval(first);
                      temp2 := eval(second);
                      if temp2 <> 0 then
                          eval := Temp1 div temp2
                      else   // avoid divide by zero error
                          eval := 0;
                   end;
             end;
        error: writeln('Oops! Program is buggy!')
    end;
end;

procedure ReadEvalPrintLoop;
var
    ast: pAstNode;
    K: StringRec;
    S:String

begin
    Readln(S)
    while s<>'' do
    begin

        K.S := S;
        K.Pos :=1;
        K.Len := Length(S);

        ast := parseAddSub(K);
        if (ast^.typ = error) or not EndOf(k)   then
            writeln('Error in expression.')
        else
            writeln('Result: ', eval(ast));
        readln(S);;
        disposeTree(ast)
    end;
end;

begin
    ReadEvalPrintLoop
nd.

