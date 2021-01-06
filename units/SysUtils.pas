// XD Pascal for Windows (XPDW) - a 32-bit compiler
// Copyright (c) 2009-2010, 2019-2020, Vasiliy Tereshkov
// Copyright 2020 Paul Robnson

// Latest upgrade by Paul Robinson: Sometime in 2021

// VERSION 0.16 {.0}

// Similar to Delphi / free pascal Sysutils unit, with
// items routinely used by user programs (and sometimes by the compiler)

{
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to
  deal in the Software without restriction, including without limitation the
  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
  sell copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
  IN THE SOFTWARE.
}

unit SysUtils;


interface


type
  TFloatFormat = (ffGeneral, ffFixed);

  AnsiChar = Char;
  PAnsiChar = PChar;
  
  WideChar = Word;
  PWideChar = ^WideChar;
  WideString = array [1..MaxStrLength + 1] of WideChar;

  TSystemTime = record
     Year,
     Month,
     DayOfWeek,
     Day : word;
     Hour,
     Minute,
     Second,
     MilliSecond: word;
  end;

  TFileTime = Record
    LowDateTime,
    HighDateTime: integer;
   end;


function IntToStr(n: Integer): string;
function StrToInt(const s: string): Integer;
function FloatToStr(x: Real): string;
function FloatToStrF(x: Real; Format: TFloatFormat; Precision, Digits: Integer): string;
function StrToFloat(const s: string): Real; 
function StrToPWideChar(const s: string): PWideChar;
function PWideCharToStr(p: PWideChar): string;
function Trim(const S: string):string;
function RTrim(const S: string):string;
function LTrim(const S: string):string;

procedure GetLocalTime(var SystemTime: TSYSTEMTIME) stdcall; external 'kernel32.dll'; // name 'GetLocalTime';
//function FindFirstFileExA(lpfilename : LPCStr;fInfoLevelId:FINDEX_INFO_LEVELS ;lpFindFileData:pointer;
//         fSearchOp : FINDEX_SEARCH_OPS;lpSearchFilter:pointer;dwAdditionalFlags:dword):Handle; stdcall;
//         external 'kernel32' // name 'FindFirstFileExA';


implementation


var
  WideStringBuf: WideString;
  


function IntToStr(n: Integer): string;
begin
IStr(n, Result);
end;




function StrToInt(const s: string): Integer;
var
  Code: Integer;
begin
IVal(s, Result, Code);
if Code <> 0 then Halt(1);
end;




function FloatToStr(x: Real): string;
begin
if abs(ln(abs(x)) / ln(10)) > 9 then
  Str(x, Result)
else
  Str(x, Result, 0, 16);  
end;




function FloatToStrF(x: Real; Format: TFloatFormat; Precision, Digits: Integer): string;
begin
case Format of
  ffGeneral: 
    Result := FloatToStr(x);
    
  ffFixed:       
    if Digits > Precision then
      Str(x, Result)
    else  
      Str(x, Result, 0, Digits);
end;               
end;




function StrToFloat(const s: string): Real;
var
  Code: Integer;
begin
Val(s, Result, Code);
if Code <> 0 then Halt(1);
end;


  
  
function StrToPWideChar(const s: string): PWideChar;
var
  i: Integer;  
begin
i := 0;
repeat
  Inc(i);
  WideStringBuf[i] := Ord(s[i]);
until s[i] = #0;
Result := @WideStringBuf[1];  
end;




function PWideCharToStr(p: PWideChar): string;
var
  i: Integer;
begin
i := 0;
repeat
  Inc(i);
  Result[i] := Char(p^);
  p := PWideChar(Integer(p) + SizeOf(WideChar));
until Result[i] = #0;
end;


// trim leading and trailing blanks
function Trim(const S: string):string;
VAR
    I,L: Byte;

Begin
    L:= Length(S);
    I:=1;
    Result :='';
    // Trim from front
    while (I<= L) and (S[i]=' ') do
       inc(I);
    // trim from end
    While (L>I) and (S[L]=' ') do
       dec(L);
    If I <=L then   // copy the rest of the string
        For I := I to L do
           Result := Result+S[I]
end;

// Trim leading blanks - trim from left
function LTrim(const S: string):string;
VAR
    I,L: Byte;

Begin
    L:= Length(S);
    I:=1;
    Result :='';
    // Trim from front
    while (I<= L) and (S[i]=' ') do
       inc(I);
    If I <=L then   // copy the rest of the string
        For I := I to L do
           Result := Result+S[I]
end;

// Trim trailing blanks - Trim from right
function RTrim(const S: string):string;
VAR
    I,L: Byte;

Begin
    L:= Length(S);
    I:=1;
    Result :='';
    // trim from end
    While (L>I) and (S[L]=' ') do
       dec(L);
    If I <=L then   // copy the rest of the string
        For I := I to L do
           Result := Result+S[I]
end;



end.
  
