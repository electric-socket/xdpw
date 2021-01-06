// 2020-12-09
Program NumberTest;
Const
     RadixString: Array[0..35] of char=('0','1','2','3','4','5','6','7','8','9',
                           'A','B','C','D','E','F','G','H','I','J',
                              'K','L','M','N','O','P','Q','R','S','T',
                           'U','V','W','X','Y','Z');
     NegativeZero = $7fffffff+1;
     D = $7fffffff;
     MX =D div 10;
{$DUMP symtab,user}
{$show all,narrow}
var
   q0:array[0..1] of integer;
   q1:array[1..2] of integer;
{$hide all}
   A,b,c:LongInt;
   G,H: Currency;
   X,x1,x2:Double;
   I64: Int64;
   i128: Int128;
   I : integer;

  // INT64: array[1..2] of Integer;


   // Paul Robinson 2020-11-08 - My own version of
   // InttoStr, but works for any radix, e.g. 2, 8, 10, 16,
   // or any others up to 36. This only works for
   // non-negative numbers.
   Function Radix( N:LongInt; theRadix:LongInt):string;
   VAR
      S: String;
      rem, Num:integer;
   begin
       S :='';
       Num := N;
     if num = 0 then
        S := '0';
      while(num>0)  DO
      begin
         rem := num mod theRadix;
         S := RadixString[ rem ]+S;
         num := num DIV theRadix;
       end;
      Radix := S;
  end;

// Paul Robinson 2020-11-08 - Outputs numbers nicely formatted
// with separators which don't have to be commas
//    Function Comma(K:Longint; Sep:char =','):string;
     Function Comma(K:Longint):string;
     CONST  Sep:char =',';
     var

        i:integer;
        s: string;
     begin
          S := Radix(K,10);
          i := length(s)-3;
          while i>0 do
          begin
               S := Copy(S,1,i) +Sep+copy(s,i+1,length(s));
               I := I-3;
          end;
          Comma := S;
     end;
// $show code}

//Function F64: Int128; begin end;

Procedure ICInt(var A: currency; I:Integer);
begin
//    A := I;
end;

   Procedure Test1;
   begin
       q1[1] := 0;
       q1[2] := 0;

       Q1[1] := NegativeZero;
       Writeln(Q1[1]);

       Dec(Q1[1]);
       Writeln(Q1[1]);

       Q1[1] := NegativeZero +NegativeZero ;
       Writeln('NO=',Q1[1]);

//       QQ[1] := -1 + -1 ;
       Writeln('NN=',Q1[1]);

       Q1[1] := -1 +NegativeZero ;
       Writeln('NZ=',Q1[1]);

   end;

    Procedure Test2;
    VAR
       Q:array[1..2] of integer;
    begin
        Q[1] := 0;
    end;
{$hide code}
{
Function RealToStr(D:Double):String;
VAR

   S: String;
   N:integer;
   Frac:Double;

begin
     N := Trunc(D);
     Frac := N - D;
     while frac<> trunc(frac) do
       frac := Frac*10;
     S :=  Radix(N,10);
     N := Trunc(D);
     S :=  S+'.'+Radix(N,10);
     Result := S;
 end;
 }


{ $dump symtab}
begin
//    G := G+H;
//    I128Int(,1);
{ $show keyword,ident,narrow}
      q0[0] := 0;

{$hide all}
{$dump symtab,all}
WRITELN('Integer ',SizeOf(Integer) ,';  ',
'SmallInt ', SizeOf(SmallInt),';  ',
'ShortInt ', SizeOf(ShortInt),';  ',
'Word ', SizeOf(Word),';  ',
'Byte ', SizeOf(Byte),';  ',
'Character ',  SizeOf(Char),';  ',
'BOOLEAN ',  SizeOf(Boolean),';  ',
'REAL ',  SizeOf(Double),';  ',
'SINGLE ',  SizeOf(Single),';  ',
'POINTER ',  SizeOf(Pointer),';  ');


    X :=33.40662;
    X1 := Trunc(X);
    a := tRUNC(x);
    Writeln('X=',X,' x1=',x1);
    Writeln('A=',A,' or ',comma(a), ' or $',Radix(A,16));
    DEC(A);
    Writeln('A=',A,' or ',comma(a), ' or $',Radix(A,16));
    Writeln('MX=',MX,' or ',radix(MX,10),' or $',radix(MX,16));
    Writeln('D=',D,' or ',radix(B,10));
    Writeln('B=',radix(B,10));
    A := Maxint;
 //   Writeln('A=',A,' or ',comma(a), ' or $',Radix(A,16));
    B := A;
    writeln('Part2');
    inc(a);
    If A <0 then writeln( 'Neg')
     else if a = 0 then writeln('zero')
     else if a >0 then write('pos')
     else writeln('Unknown');;
    Writeln('A=',A,' or ',comma(a), ' or $',Radix(A,16));
     Test2;
     Test1;


end.

