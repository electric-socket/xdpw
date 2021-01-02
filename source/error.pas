// XD Pascal for Windows (XPDW) - a 32-bit compiler
// Copyright 2020 Paul Robnson

// Latest upgrade by Paul Robinson: New Years Eve; Thursday, December 31, 2020

// VERSION 0.15  {.0}

// Anything to do with errors

unit error;

interface

Uses Common;

CONST

{    ERR_0	= 0 ; }  // No error
{    ERR_1	= 1 ; }
{    ERR_2	= 2 ; }
{    ERR_3	= 3 ; }
     ERR_4	= 4 ;
     ERR_5	= 5 ;
     ERR_6	= 6 ;  // Unknown character
{    ERR_7	= 7 ; }
     ERR_8	= 8 ;
     ERR_9	= 9 ;
     ERR_10	= 10 ;  // Type name expected
     ERR_11	= 11 ;
     ERR_12	= 12 ;
     ERR_13	= 13 ;
     ERR_14	= 14 ; // ; expected
{    ERR_15	= 15 ; }
     ERR_16	= 16 ;
     ERR_17	= 17 ;
{    ERR_31	= 31 ; }
     ERR_32	= 32 ;   // incompatible no. of params
{    ERR_50	= 50 ; }
     ERR_51	= 51 ;
     ERR_52	= 52 ;
     ERR_53	= 53 ;
     ERR_54	= 54 ;
     ERR_55	= 55 ;
{    ERR_59	= 59 ; }
     ERR_60	= 60 ;
{    ERR_61	= 61 ; }
{    ERR_69	= 69 ; }
     ERR_70	= 70 ;  //  ; inadvertently used before ELSE
     ERR_71	= 71 ;  // Runaway conditional code block
     ERR_72     = 72 ;  // Feature not yet working (non-fatal version of 399)
     ERR_73	= 73 ;  // $DEBUG must be enabled at start of PROGRAM or UNIT
{    ERR_100	= 100 ; }
     ERR_101	= 101 ;  // identifier previously declared
{    ERR_102	= 102 ; }
{    ERR_103	= 103 ; }
     ERR_104	= 104 ;   // Identifier not declared
{    ERR_105	= 105 ; }
{    ERR_121	= 121 ; }
     ERR_122	= 122 ;   // Format specifiers only allowed for untyped or text files
{    ERR_123	= 123 ; }
     ERR_124	= 124 ;   // F-format for Real Only
{    ERR_125	= 125 ; }
{    ERR_174	= 174 ; }
     ERR_175	= 175 ;  // too many files in program header
{    ERR_176	= 176 ; }
{    ERR_200	= 200 ; }
{    ERR_300	= 300 ; }
     ERR_301	= 301 ; // Error in Conditional compilation expression
{    ERR_304	= 304 ; }
     ERR_305	= 305 ;    // NIL is the only pointer initialization
{    ERR_306	= 306 ; }
     ERR_398	= 398 ;    // Cannot nest $INCLUDE files
{    ERR_399	= 399 ; }
     ERR_400	= 400 ;   // unspecified compiler error
{    ERR_401	= 401 ; }
{    ERR_402	= 402 ; }
{    ERR_403	= 403 ; }
     ERR_404	= 404 ; // No such error number
     ERR_800	= 800 ; // Var never used (warning)
     ERR_801    = 801 ; // Procedure defined in INTERFACE
     ERR_802    = 802 ; // null $DEFINE
     ERR_803	= 803 ; // $ELSE/$ENDIF in open code
     ERR_804	= 804 ; // $ELSE/ELSEIF used after $ELSE
     ERR_805	= 805 ; // Too many $IF/$IFDEF/$IFNDEF statements
     ERR_806    = 806 ; // $ENABLE debug must be issued before USES stmt
     ERR_807    = 807 ; // Invalid $DEBUG option "Item"

     ERR_899    = 899 ; // "Nothing happens."

    MissingErrorMessage = '*MISSING ERROR MESSAGE*';

TYPE

  // error messages
  Presumptive = (YouMeant, YouUsed, Either, ThreeOf, NotBefore,
                 NotHere, DidntMean, SkipUntil);

  // this would allow "stacking" of current state; push
  // on begin, repeat, case.. else, pop    on until, end
  // when errors occur we can detect and recover from them
  // by knowiing what should be there when wrong item is
  // used, e.g if a statement in FOR is followed by anything
  // except ; or terminator (END/ELSE/UNTIL) it's an error
  // probably a missing ;

  ErrBlockType = (BlockBegin, BlockRepeat, BlockCaseElse);
  ErrEndType = (BlockEnd, BlockUntil);
  ErrStackP = ^ErrStackType;
  ErrStackType = Record
      Prev: ErrStackP;
      BlockStart: ErrBlockType;
      BlockEnd:   ErrEndType;
  end;


VAR

     ErrStack: ErrStackP ; // = NIL;    // anything except NIL **ERROR  ** ERROR
     ErrorCount: Integer  =0;      // number of errors detected in source files
     ErrorMax: Integer = 2;        // maximum number of (non-fatal) errors tolerated
     ErrorPrint: Boolean = FALSE;  // haave any errors been printed
     ErrorWarned: Boolean = FALSE; // Were they given the longer warning?
     Errors: Array [1..ErrorMsgMax] of TString = ( MissingErrorMessage,
                                         MissingErrorMessage,
                                         MissingErrorMessage,
                                         MissingErrorMessage,
                                         MissingErrorMessage,
                                         MissingErrorMessage);


    function LowBound(DataType: Integer): Integer;
    function HighBound(DataType: Integer): Integer;
    Procedure Unrecoverable;
    procedure Presume(What: Presumptive; One: TTokenKind = EMPTYTOK; Two: TTokenKind = EMPTYTOK; Three: TTokenKind = EMPTYTOK; Four: TTokenKind = EMPTYTOK);
    procedure ErrIfNot(This: TTokenKind;ErrNumber:Integer);
    Procedure ItsWrongIf(ErrTok,GoodTok: TTokenKind; ErrNumber:Integer);
    Procedure NoticePrefix(Msg:Tstring);
    Procedure NoticePrefix_H(Msg:Tstring);
    Procedure NoticePrefix_S(Msg:Tstring);
    procedure Trap;
    procedure TrapT;
    procedure Fatal(const Msg: TString);
    Procedure Err(ErrNum: Integer);
    Procedure Err1(ErrNum: Integer; Param1: String);
    Procedure Err2(ErrNum: Integer; Param1: String; Param2: String);
    Procedure Err3(ErrNum: Integer; Param1: String; Param2: String; Param3: String);
    Procedure Err4(ErrNum: Integer; Param1: String; Param2: String; Param3: String; Param4: String);
    Procedure Err5(ErrNum: Integer; Param1: String; Param2: String; Param3: String; Param4: String; Param5: String);
    Procedure Err6(ErrNum: Integer; Param1: String; Param2: String; Param3: String; Param4: String; Param5: String; Param6: String);
    procedure Catastrophic(Msg:TString);
    function  RestoreScanner: Boolean;
    procedure FinalizeScanner;
    procedure writeInputTrace;


implementation


// these two proceduresare here because they
// have error messages, and are called by
// scaaer, parser, and codegen. They can't be in Common
// because they have error processing

function LowBound(DataType: Integer): Integer;
begin
     Result := 0;
     case Types[DataType].Kind of
         INTEGERTYPE:    Result := -2147483647 - 1;
         SMALLINTTYPE:   Result := -32768;
         SHORTINTTYPE:   Result := -128;
         WORDTYPE:       Result :=  0;
         BYTETYPE:       Result :=  0;
         CHARTYPE:       Result :=  0;
         BOOLEANTYPE:    Result :=  0;
         SUBRANGETYPE:   Result :=  Types[DataType].Low;
         ENUMERATEDTYPE: Result :=  Types[DataType].Low
     else
	begin
        Fatal('Ordinal type expected for low value');
  	    exit;
  	end;
     end;// case
end;

function HighBound(DataType: Integer): Integer;
begin
     Result := 0;
case Types[DataType].Kind of
  INTEGERTYPE:    Result := 2147483647;
  SMALLINTTYPE:   Result := 32767;
  SHORTINTTYPE:   Result := 127;
  WORDTYPE:       Result := 65535;
  BYTETYPE:       Result := 255;
  CHARTYPE:       Result := 255;
  BOOLEANTYPE:    Result := 1;
  SUBRANGETYPE:   Result := Types[DataType].High;
  ENUMERATEDTYPE: Result := Types[DataType].High
else
	begin
  		Fatal('Ordinal type expected for high value');
  		exit;
  	end;
end;// case
end;

// The following "wind down" the compiler after error
function RestoreScanner: Boolean;
begin
Result := FALSE;
if ScannerStackTop > 0 then
  begin
  ScannerState := ScannerStack[ScannerStackTop];
  Dec(ScannerStackTop);
  Tok := ScannerState.Token;
  Result := TRUE;
  end;
end;

procedure FinalizeScanner;
begin
ScannerState.EndOfUnit := TRUE;
with ScannerState.Buffer do
  if Ptr <> nil then
    begin
    FreeMem(Ptr);
    Ptr := nil;
    end;
end;



// Used to "Trap" the compiler, return all dynamic memory
// and exit, generally in an abort
procedure Trap;
begin
    repeat
        FinalizeScanner
    until not RestoreScanner;
    FinalizeCommon;
    Halt(1);
end;

procedure TrapT;
Begin
     Notice('** Compilation terminated **');
     Notice('');
     Trap;
end;


Procedure NoticePrefix(Msg:Tstring);
begin
   Writeln(ScannerState.FileName + ' (' + Radix(ScannerState.Line,10) +
                                   ':' + Radix(ScannerState.Position,10) + ') '+Msg);
end;


Procedure NoticePrefix_S(Msg:Tstring); // Stars
begin
   Writeln(' ** ',ScannerState.FileName + ' (' + Radix(ScannerState.Line,10) +
                                         ':' + Radix(ScannerState.Position,10) + ') '+Msg);
end;

Procedure NoticePrefix_H(Msg:Tstring);   // Hash mark
begin
   Writeln(' ## ',ScannerState.FileName + ' (' + Radix(ScannerState.Line,10) +
                                      ':' + Radix(ScannerState.Position,10) + ') '+Msg);
end;




// If I figure out how to have errors be recverable
// this procedure reports truly unrecoverable errors
Procedure Catastrophic(Msg:Tstring);
begin
    Errors[1] := Msg;
    Err(999);
end;

Procedure Unrecoverable;
VAR
    HowMany:String;

begin
    Notice('');
    Notice('** Too many errors detected, compilation terminated.');
    Notice('');
    Notice('    This means you exceeded the maximum number of errors permitted');
    Notice('    before I stop processing your program. You will need to');
    If ErrorCount =1 then
      HowMany :='the error'
    else
      HowMany := 'the '+Comma(ErrorCount)+' errors';
    Notice('    fix '+HowMany+' already detected so far, and try again.');
    Trap;

end;

// This replaces the old "Error" procedure, which has
// been renamed to better indicate it is a fatal error
// and compilation cannot continue. It is also moved from
// the main program as the scanner information is now
// moved here to common
procedure Fatal(const Msg: TString);
Var
    E:Tstring;

begin
    Notice('');
    Inc(ErrorCount);
    if Skipping then   // Warn this is in Conditional code
        E := '[in skipped Conditional Code] Fatal Error'
    else
        E:='Fatal Error';
    if NumUnits >= 1 then
        NoticePrefix_S(E+' : ' + Msg)
    else
        Notice('** '+E+' : ' + Msg);
    if (InputHexCTrace in TraceCompiler) or (InputCTrace in TraceCompiler) then
          WriteInputTrace;
    Unrecoverable;
end;

// "This" is expected but if not, Err1(ErrNumber,This)
procedure ErrIfNot(This: TTokenKind; ErrNumber:Integer);
begin
if Tok.Kind <> This then
    begin
        Err1(ErrNumber,GetTokSpelling(Tok.Kind));
        Presume(YouMeant,This);
    end;
end;

Procedure ItsWrongIf(ErrTok,GoodTok: TTokenKind; ErrNumber:Integer);
begin
    IF (Tok.Kind = ErrTok) then
          begin
              Err1(ErrNumber,GetTokSpelling(ErrTok));
              Presume(YouMeant,Goodtok);
          end;

end;



// This is called on reparable errors to tell them what I presume to fix
procedure Presume(What: Presumptive;  One: TTokenKind = EMPTYTOK;  Two: TTokenKind = EMPTYTOK;
                                    Three: TTokenKind = EMPTYTOK; Four: TTokenKind = EMPTYTOK);
begin
    Case What of
        YouMeant:
        begin
            Notice('** I will presume you meant to use "'+
            GetTokSpelling(One)+'" and');
         end;
        YouUsed:
        begin
            Notice('** I notice you used "'+
                   GetTokSpelling(One) + '" and what you probably meant to use was "'+
                   GetTokSpelling(Two) + '" so I will');
         end;
        Either:
        begin
            Notice('** I will presume you meant to use either "'+
            GetTokSpelling(One) + '" or "'+
            GetTokSpelling(Two) + '" and');
        end;
        NotHere:
        begin
            Notice('** A "'+
            GetTokSpelling(One) + '" is not used after "'+
            GetTokSpelling(Two) + '", but I will');
        end;
        NotBefore:
        begin
            Notice('** A "'+
            GetTokSpelling(One) + '" is not used before "'+
            GetTokSpelling(Two) + '", but I will');
        end;

        ThreeOf:
        begin
            Notice('** I will presume you meant to use "'+
                   GetTokSpelling(One)   + '", "'+
                   GetTokSpelling(Two)   + '", or "'+
                   GetTokSpelling(Three) + '", and');
        end;
        DidnTMean:
        Begin
            Notice('** I will presume you didn''t meant to include "'+
                   GetTokSpelling(One) + '" before "' + GetTokSpelling(Two) + '" and');
        end;
        SkipUntil:
        begin
            Notice('** I am not exactly sure how to handle this, so I will skip to the');
            Notice('   next "'+GetTokSpelling(One)+'" in the program, and');
        end;
        { // Forget ignore, just do it, (or not do it, take your pick.)
        Ignore:
            Notice('** I will tentatively ignore this, and');
        }
     end; // case
     Notice('   continue scanning for more errors.');
     if not ErrorWarned then
     begin
         Notice('    This may result in spurious additional errors. You will need');
         Notice('    to fix this error (in addition to any others I might find)');
         Notice('    in order to successfully compile or run your program.');
         ErrorWarned := True;
     end;
     If ErrorCount > ErrorMax then
         Unrecoverable;
   end;

Procedure Err(ErrNum: Integer);
VAR
    E: String;
    ErrCount: Integer;
    Fail:Boolean;

Begin
   If Not errorwarned then
     Notice('');
   ErrorWarned := True;
   Fail := False;
   If (ErrNum<800) or (errNum>899) then // 800-899 are warnings
       Inc(ErrorCount);

   If (ErrNum < 0) or (Errnum>999) then
   begin
       Errors[1] := Radix(Errnum,10);
       ErrNum := 404;
   end;
   Fail := (ErrNum > 384) and (errNum<416);


// Now display the error message with appropriate fillers
// The ones marked by // or above 400 are new or modified


Case ErrNum of // By the way, there is  nolimit on the number of case selector

  1: NoticePrefix_S('Error 1: Error in Simple Type.');
  2: NoticePrefix_S('Error 2: Identifier Expected, found "'+Errors[1]+'".');
  3: NoticePrefix_S('Error 3: ''Program'' or ''Unit'' Expected'); //
  4: NoticePrefix_S('Error 4: '')'' Expected, found '''+Errors[1]+'''.');       //
  5: NoticePrefix_S('Error 5: Colon '':'' Expected, found '''+Errors[1]+'''.');   //
  6: NoticePrefix_S('Error 6: Illegal Symbol ('''+Errors[1]+''', '+Errors[2]+' $'+Errors[3]+').'); //
  7: NoticePrefix_S('Error 7: Error in Parameter List');
  8: NoticePrefix_S('Error 8: ''Of'' Expected, found "'+Errors[1]+'" .');
  9: NoticePrefix_S('Error 9: ''('' Expected, found "'+Errors[1]+'".');
 10: NoticePrefix_S('Error 10: Type name expected');  //
 11: NoticePrefix_S('Error 11: ''['' Expected, found "'+Errors[1]+'".');
 12: NoticePrefix_S('Error 12: '']'' Expected, found "'+Errors[1]+'".');
 13: NoticePrefix_S('Error 13: ''End'' Expected, found "'+Errors[1]+'".');
 14: NoticePrefix_S('Error 14: Semicolon '';'' Expected, found "'+Errors[1]+'".'); // used
 15: NoticePrefix_S('Error 15: Integer Expected');
 16: NoticePrefix_S('Error 16: ''-'' Expected, found '+Errors[1]+'''.');
 17: NoticePrefix_S('Error 17: ''Begin'' Expected, found '+Errors[1]+'''.');
 18: NoticePrefix_S('Error 18: Error in Declaration Part');
 19: NoticePrefix_S('Error 19: Error in Field-list');
 30: NoticePrefix_S('Error 30: Expecting '''+Errors[1]+''', Found '''+Errors[2]+'''.');  //
 31: NoticePrefix_S('Error 31: Operator '''+Errors[1]+''' Is Not Applicable to '''+Errors[2]+'''.');  //
 32: NoticePrefix_S('Error 32: Incompatible Number of Parameters in "'+Errors[1]+'", '+Errors[2]+' vs. '+Errors[3]+'.');  // used
 50: NoticePrefix_S('Error 50: Error in Constant');
 51: NoticePrefix_S('Error 51: '':='' Expected, found "'+Errors[1]+'".');
 52: NoticePrefix_S('Error 52: ''Then'' Expected, found "'+Errors[1]+'".');
 53: NoticePrefix_S('Error 53: ''Until'' Expected, found "'+Errors[1]+'".');
 54: NoticePrefix_S('Error 54: ''Do'' Expected, found "'+Errors[1]+'".');
 55: NoticePrefix_S('Error 55: ''To''/''Downto'' Expected, found "'+Errors[1]+'".');
 58: NoticePrefix_S('Error 58: Error in Factor');
 59: NoticePrefix_S('Error 59: Error in Variable');
 60: NoticePrefix_S('Error 60: ''In'' Expected, found '+Errors[1]+'''.');
 70: NoticePrefix_S('Error 70: Semicolon ";" inadvertently used before ELSE.'); //
 71: NoticePrefix_S('Error 71: Runaway Conditional Code segment (From '+Errors[1]+':'+Errors[2]+').');
 72: NoticePrefix_S('Error 72: Feature incomplete, unimplemented or unfinished.'); // non-fatal version of 399
 73: NoticePrefix_S('Error 73: DEBUG must be enabled at the start of a PROGRAM or UNIT.'); //
100: NoticePrefix_S('Error 100: '+Errors[1]+' "' +Errors[2]+'", previously declared at '+Errors[3]+':'+Errors[4]+'.'); //
101: NoticePrefix_S('Error 101: Identifier "' +Errors[1]+'", previously declared at '+Errors[2]+':'+Errors[3]+'.'); // used, was Identifier Declared Twice
102: NoticePrefix_S('Error 102: Low Bound Exceeds High Bound.');
103: NoticePrefix_S('Error 103: Identifier '+Errors[1]+' Is Not of Appropriate Class.');
104: NoticePrefix_S('Error 104: Identifier '+Errors[1]+' Not Declared.');
105: NoticePrefix_S('Error 105: Sign Not Allowed.');
106: NoticePrefix_S('Error 106: Number Expected.');
107: NoticePrefix_S('Error 107: Incompatible Subrange Types.');
108: NoticePrefix_S('Error 108: File Not Allowed Here.');
109: NoticePrefix_S('Error 109: Type must Not Be Real.');
110: NoticePrefix_S('Error 110: Tagfield Type must Be Scalar or Subrange.');
111: NoticePrefix_S('Error 111: Incompatible with Tagfield Type.');
112: NoticePrefix_S('Error 112: Index Type must Not Be Real.');
113: NoticePrefix_S('Error 113: Index Type must Be Scalar or Subrange.');
114: NoticePrefix_S('Error 114: Base Type must Not Be Real.');
115: NoticePrefix_S('Error 115: Base Type must Be Scalar or Subrange.');
116: NoticePrefix_S('Error 116: Error in Type of Standard Procedure Parameter.');
117: NoticePrefix_S('Error 117: Unsatisfied Forward Reference '+Errors[1]+' (From '+Errors[2]+').');
118: NoticePrefix_S('Error 118: Unpacking/packing Is of No Use; Check Array Elements.');
// 119: NoticePrefix('Error 119: Forward Declared: Repetition of Parameter List Not Allowed');// now allowed
119: NoticePrefix_S('Error 119: .'); {Available}
120: NoticePrefix_S('Error 120: Function Result Type must Be Scalar, Subrange, String or Pointer.');  //
121: NoticePrefix_S('Error 121: File Value Parameter Not Allowed.');
// 122: NoticePrefix('Error 122: Forward Declared Function: Do Not Repeat Result Type'); // This is allowed now
122: NoticePrefix_S('Error 122: Format specifiers only allowed for untyped or text files.');     {Used}
123: NoticePrefix_S('Error 123: Missing Result Type in Function Declaration.');
124: NoticePrefix_S('Error 124: F-format for Real Only.');       {Used}
125: NoticePrefix_S('Error 125: Error in Type of Standard Function Parameter.');
126: NoticePrefix_S('Error 126: Number of Parameters Does Not Agree with Declaration.');
127: NoticePrefix_S('Error 127: Illegal Parameter Substitution.');
128: NoticePrefix_S('Error 128: Result Type of Parameter Function Doesn''t Agree with Declaration.');
129: NoticePrefix_S('Error 129: Type Conflict of Operands.');
130: NoticePrefix_S('Error 130: Expression Is Not of Set Type.');
131: NoticePrefix_S('Error 131: Tests on Equality Allowed Only.');
132: NoticePrefix_S('Error 132: Strict Inclusion Not Allowed.');
133: NoticePrefix_S('Error 133: File Comparison Not Allowed.');
134: NoticePrefix_S('Error 134: Illegal Type of Operand(s).');
135: NoticePrefix_S('Error 135: Type of Operand must Be Boolean.');
136: NoticePrefix_S('Error 136: Set Element Type must Be Scalar or Subrange.');
137: NoticePrefix_S('Error 137: Set Element Types Not Compatible.');
138: NoticePrefix_S('Error 138: Type of Variable Is Not Array.');
139: NoticePrefix_S('Error 139: Index Type Is Not Compatible with Declaration.');
140: NoticePrefix_S('Error 140: Type of Variable Is Not Record.');
141: NoticePrefix_S('Error 141: Type of Variable must Be File or Pointer.');
142: NoticePrefix_S('Error 142: Type Conflict on Parameters.');
143: NoticePrefix_S('Error 143: Illegal Type of Loop Control Variable.');
144: NoticePrefix_S('Error 144: Selector Type must Be Scalar or Subrange.');
145: NoticePrefix_S('Error 145: Type Conflict with Control Variable.');
146: NoticePrefix_S('Error 146: Assignment of Files Not Allowed.');
147: NoticePrefix_S('Error 147: Label Type Incompatible with Selecting Expression.');
148: NoticePrefix_S('Error 148: Subrange Bounds must Be Scalar.');
149: NoticePrefix_S('Error 149: Index Type must Not Be Integer.');
150: NoticePrefix_S('Error 150: Assignment to Standard Function Is Not Allowed.');
151: NoticePrefix_S('Error 151: Assignment to Formal Function Is Not Allowed.');
152: NoticePrefix_S('Error 152: No Such Field in this Record.');
153: NoticePrefix_S('Error 153: Type Error in Read.');
154: NoticePrefix_S('Error 154: Actual Parameter must Be a Variable.');
155: NoticePrefix_S('Error 155: Control Variable must Not Be Formal.');
156: NoticePrefix_S('Error 156: Multidefined Case Label.');
158: NoticePrefix_S('Error 158: Missing Corresponding Variant Declaration.');
159: NoticePrefix_S('Error 159: Real or String Tagfields Not Allowed.');
160: NoticePrefix_S('Error 160: Mismatch to Forward Declaration.');
161: NoticePrefix_S('Error 161: Again Forward Declared.');
162: NoticePrefix_S('Error 162: External Routines Cannot Be Forward.');
164: NoticePrefix_S('Error 164: Substitution of Standard Proc/func Not Allowed.');
165: NoticePrefix_S('Error 165: Multidefined Label.');
166: NoticePrefix_S('Error 166: Multideclared Label.');
167: NoticePrefix_S('Error 167: Undeclared Label.');
168: NoticePrefix_S('Error 168: Undefined Label.');
169: NoticePrefix_S('Error 169: Error in Base Type.');
170: NoticePrefix_S('Error 170: Procedure/function Parameter must Have Value Parameters Only.');
172: NoticePrefix_S('Error 172: Undeclared External File.');
175: NoticePrefix_S('Error 175: Too Many Files in Program Header.'); // used, was Missing File ''Input'' in Program Heading
176: NoticePrefix_S('Error 176: .'); // available, was Missing File ''Output'' in Program Heading
180: NoticePrefix_S('Error 180: .');  // available, was Too Long Source Line
181: NoticePrefix_S('Error 181: Tagfield Value out of Range.');
182: NoticePrefix_S('Error 182: Assignment to Subordinate Function Name Not Allowed.');
184: NoticePrefix_S('Error 184: Too Long File Component.');
186: NoticePrefix_S('Error 186: Mismatch to Procedure Skeleton.');
187: NoticePrefix_S('Error 187: Packed Variable Is Not Allowed in Variable Parameter.');
201: NoticePrefix_S('Error 201: Error in Real Constant: Digit Expected.');
202: NoticePrefix_S('Error 202: String Constant must Not Exceed Source Line.');
203: NoticePrefix_S('Error 203: Integer Constant Exceeds Range.');
210: NoticePrefix_S('Error 210: Invalid Base &1 Digit ''&2''.');  //
211: NoticePrefix_S('Error 211: Binary Numeric Constant Is Too Large.');  //
212: NoticePrefix_S('Error 212: Octal Numeric Constant Is Too Large.');   //
213: NoticePrefix_S('Error 213: Decimal Numeric Constant Is Too Large.');  //
214: NoticePrefix_S('Error 214: Hexadecimal Numeric Constant Is Too Large.');  //
215: NoticePrefix_S('Error 215: Real Number Constant Is Too Large.');  //
216: NoticePrefix_S('Error 216: &1 Constant Is Too Large.');  //
219: NoticePrefix_S('Error 219: Only 1 Variable May Be Initialized at a time..');
220: NoticePrefix_S('Error 220: Variable Initialization Only Allowed in body of unit or Main Program.');  //
221: NoticePrefix_S('Error 221: Type Conflict in Variable Initialization..');
222: NoticePrefix_S('Error 222: No. Of Components of Struc. Constant Doesn''t Agree with Declaration.');
223: NoticePrefix_S('Error 223: Type of Components of Struc. Const. Doesn''t Agree with Declaration.');
224: NoticePrefix_S('Error 224: Illegal Format in Structured Constant.');
225: NoticePrefix_S('Error 225: Runaway Comment from '+Errors[1]+' .');  //
226: NoticePrefix_S('Error 226: Unallowed Type in Structured Constant.');
227: NoticePrefix_S('Error 227: Record with Variants Not Allowed in Structured Constant.');
250: NoticePrefix_S('Error 250: Too Many Nested Scopes of Identifiers.');
251: NoticePrefix_S('Error 251: Too Many Nested Procedures And/or Functions.');
253: NoticePrefix_S('Error 253: Procedure Too Long.');
255: NoticePrefix_S('Error 255: Too Many Errors on this Source Line.');
261: NoticePrefix_S('Error 261: Too Many Procedures or Long Jumps.');
280: NoticePrefix_S('Error 280: .'); // available, was Event Name Not Declared
281: NoticePrefix_S('Error 281: .');  // available, was No Postlude Statement Allowed for the Event ''Exit''
282: NoticePrefix_S('Error 282: .'); // available, was Multidefined Postlude Statement
291: NoticePrefix_S('Error 291: Extension to ''Standard'' Pascal; Be Warned.');
292: NoticePrefix_S('Error 292: Cannot Change Type of Constant. Sorry.');
300: NoticePrefix_S('Error 300: .'); // availabkle, was "Value" Statement Not Allowed for External Compilation');
301: NoticePrefix_S('Error 301: Conditional expression incorrect.'); // used, new
302: NoticePrefix_S('Error 302: Index Expression out of Bounds');
303: NoticePrefix_S('Error 303: Value to Be Assigned Is out of Bounds');
304: NoticePrefix_S('Error 304: Element Expression out of Range');
305: NoticePrefix_S('Error 305: "Nil" Is the Only Pointer Initialization Allowed.');    // used
380: NoticePrefix_S('Error 380: Cannot Pass Procs/functs to Externally Compiled Routines.');
381: NoticePrefix_S('Error 381: Illegal Result Type for External Function');
382: NoticePrefix_S('Error 382: Cannot Reset the '+Errors[1]+' Option Once Set.'); //

// Warnings: 800-899
800: NoticePrefix_H('Warning 800: Variable "' +Errors[1]+ '", declared at ' +
                Errors[2]+':'+Errors[3] +' is not used.');
801: begin
         NoticePrefix_H('Warning 801: '+Errors[1]+' "'+Errors[2]+
                        '" Was previously declared at line '+
                        Errors[3]+'. While defining a');
         NoticePrefix_H('    '+Errors[1]+
                        ' in the implementation section is legal, it is');
         NoticePrefix_H('    usually an accidental double declaration.');
         // "Procedure Xray was at line 162" (or)
         // "Function Zenith was..." etc.
     end;
802: NoticePrefix_H('Warning 802: Null $DEFINE');
803: NoticePrefix_H('Warning 803: '+Errors[1]+' in open code (Outside of a Conditional compile block).');
804: NoticePrefix_H('Warning 804: '+Errors[1]+' used after '+Errors[2]+' (at '+Errors[3]+':'+Errors[4]+').');
805: NoticePrefix_H('Warning 805: Too many '+Errors[1]+' conditional statements.');
806: NoticePrefix_H('Warning 806: $ENABLE debug must be issued before USES statement. Ignored.');
807: NoticePrefix_H('Warning 807: Invalid '+Errors[1]+' option "'+Errors[2]+'".');

899: NoticePrefix_H('Warning 899: Nothing happens.');

// Catastrophic errors: 385-415 and 900-999
385: NoticePrefix_S('Error 385: Compiler error XXXXX'); //
386: NoticePrefix_S('Error 386: Compiler error XXXXX'); //
387: NoticePrefix_S('Error 387: Compiler error XXXXX'); //
388: NoticePrefix_S('Error 388: Compiler error XXXXX'); //
389: NoticePrefix_S('Error 389: Compiler error XXXXX'); //
390: NoticePrefix_S('Error 390: Compiler error XXXXX'); //
391: NoticePrefix_S('Error 391: Compiler error XXXXX'); //
392: NoticePrefix_S('Error 392: Compiler error XXXXX'); //
393: NoticePrefix_S('Error 393: Compiler error XXXXX'); //
394: NoticePrefix_S('Error 394: Compiler error XXXXX'); //
395: NoticePrefix_S('Error 395: Compiler error XXXXX'); //
396: NoticePrefix_S('Error 396: Compiler error XXXXX'); //
397: NoticePrefix_S('Error 397: Compiler error XXXXX'); //
398: NoticePrefix_S('Error 398: Cannot nest $INCLUDE files'); //
399: NoticePrefix_S('Error 399: Not Implemented');
400: NoticePrefix_S('Error 400: Compiler Error - unspecified'); //
401: NoticePrefix_S('Error 401: Compiler error XXXXX'); //
403: NoticePrefix_S('Error 402: Compiler error XXXXX'); //
403: NoticePrefix_S('Error 403: Compiler error XXXXX'); //
// Not by accident s the "missing error message" error #404
404: NoticePrefix_S('Error 404: Fatal Compiler error: Invalid error message #' +
       Errors[1]); //
405: NoticePrefix_S('Error 395: Compiler error XXXXX'); //
406: NoticePrefix_S('Error 406: Compiler error XXXXX'); //
407: NoticePrefix_S('Error 407: Compiler error XXXXX'); //
408: NoticePrefix_S('Error 408: Compiler error XXXXX'); //
409: NoticePrefix_S('Error 409: Compiler error XXXXX'); //
410: NoticePrefix_S('Error 410: Compiler error XXXXX'); //
411: NoticePrefix_S('Error 411: Compiler error XXXXX'); //
412: NoticePrefix_S('Error 412: Compiler error XXXXX'); //
413: NoticePrefix_S('Error 413: Compiler error XXXXX'); //
414: NoticePrefix_S('Error 414: Compiler error XXXXX'); //
415: NoticePrefix_S('Error 415: Compiler error XXXXX'); //
999: Begin  // Error so bad the number isn't shown
         Notice('');
         E:='Catastrophic Error ';
         if Skipping then   // Warn this is in Conditional code
             E := E+'[in skipped Conditional Code] ';
         E := E+': ';
         if NumUnits >= 1 then
             NoticePrefix_S(E+ Errors[1])
         else
             Notice('** '+E + Errors[1]);
         Fail := True;
     end; // Error 999
   end; // case

   if fail then
   begin
       Notice('    This means something has gone horribly wrong, and is probably');
       Notice('    a compiler error that needs to be reported, or is an error that');
       Notice('    was caused because you exceeded a compiler limit. If the latter,');
       Notice('    a refactor or rewrite of your program to use fewer of whatever ');
       Notice('    resources we ran out may permit successful compilation.');

       Trap;    // we ain't never comin' back
  end;  // IF FAIL

  if ((ErrNum<800) or (errNum>899)) then
     if ErrorCount > ErrorMax  then
         UnRecoverable;


// Next error, reset all errors not given
   For ErrCount:= 1 to 6 do Errors[ErrCount] := MissingErrorMessage;
End;

Procedure Err1(ErrNum: Integer;
                       Param1: String);
Begin
    Errors[ 1 ] := Param1;
    Err(ErrNum);              // Err1()
End;

Procedure Err2(ErrNum: Integer;
                       Param1: String;
                       Param2: String);
Begin
    Errors[ 1 ] := Param1;
    Errors[ 2 ] := Param2;
    Err(ErrNum);              // Err2()
End;

Procedure Err3(ErrNum: Integer;
                       Param1: String;
                       Param2: String;
                       Param3: String);
Begin
    Errors[ 1 ] := Param1;
    Errors[ 2 ] := Param2;
    Errors[ 3 ] := Param3;
    Err(ErrNum);              // Err3()
End;

Procedure Err4(ErrNum: Integer; Param1, Param2, Param3, Param4: String);
Begin
    Errors[ 1 ] := Param1;
    Errors[ 2 ] := Param2;
    Errors[ 3 ] := Param3;
    Errors[ 4 ] := Param4;
    Err(ErrNum);              // Err4()
End;

Procedure Err5(ErrNum: Integer;
                       Param1: String;
                       Param2: String;
                       Param3: String;
                       Param4: String;
                       Param5: String);
begin
    Errors[ 1 ] := Param1;
    Errors[ 2 ] := Param2;
    Errors[ 3 ] := Param3;
    Errors[ 4 ] := Param4;
    Errors[ 5 ] := Param5;
    Err(ErrNum);              // Err5()
end;

Procedure Err6(ErrNum: Integer;
                       Param1: String;
                       Param2: String;
                       Param3: String;
                       Param4: String;
                       Param5: String;
                       Param6: String);
begin
    Errors[ 1 ] := Param1;
    Errors[ 2 ] := Param2;
    Errors[ 3 ] := Param3;
    Errors[ 4 ] := Param4;
    Errors[ 5 ] := Param5;
    Errors[ 6 ] := Param6;
    Err(ErrNum);              // Err6()
end;


// print the line then print its hex character value below
procedure writeInputTrace;
Var
   I,K,L,LS: Integer;
   Line: Array[1..4] of string;
   C,
   maxlen: byte;



begin
    Maxlen := 70;
    if (InputHexCTrace in TraceCompiler) then
        maxlen := 35;
    K := 0;
    LS := Length(LineString);
    L := LS;
    if LineBufPtr >L then
        L := LineBufPtr;
    write(LinePrefix);
    Line[1] := ' L: ';
    Line[2] := ' L$ ';
    Line[3] := ' B: ';
    Line[4] := ' B$ ';

    For I := 1 to L do
    begin
             // first process the collected string
        if (InputHexCTrace in TraceCompiler) then
           Line[1] := Line[1]+' ';
        if I>LS then
        begin
           Line[1] := Line[1]+'\';
           Line[2] := Line[2]+'__';
        end
        else
        begin
            if LineString[I]<' ' then
               Line[1] := Line[1]+'~'
            else
               Line[1] := Line[1]+LineString[I];
            Line[2] := Line[2]+RadixString[((Ord(LineString[I]) and $F0) shr 4)];
            Line[2] := Line[2]+RadixString[Ord(LineString[I]) and $0F];
        end;

        // now process the byte buffer
        if (InputHexCTrace in TraceCompiler) then
           Line[3] := Line[3]+' ';
        if I>LinebufPtr then
        begin
           Line[3] := Line[3]+'\';
           Line[4] := Line[4]+'__';
        end
        else
        begin
            if LineBuf[I]<Ord(' ') then
               Line[3] := Line[3]+'~'
        else
               Line[3] := Line[3]+Chr(LineBuf[I]);
            Line[4] := Line[4]+RadixString[(LineBuf[I] and $F0) shr 4];
            Line[4] := Line[4]+RadixString[LineBuf[I] and $0F];
        end;
        INC(k);

        // print when ready
        IF K>MaxLen THEN
        BEGIN
            Writeln(Line[1]);
            Line[1] := ' L: ';
            if (InputHexCTrace in TraceCompiler) then
               Writeln(Line[2]);
            Line[2] := ' L$ ';
            Writeln(Line[3]);
            Line[3] := ' B: ';
            if (InputHexCTrace in TraceCompiler) then
                Writeln(Line[4]);
            Line[4] := ' B$ ';
            writeln;
            K := 0;
         END;
   end;
   Writeln;
   if k<>0 then
   begin
       Writeln(Line[1]);
       Line[1] := ' L: ';
       if (InputHexCTrace in TraceCompiler) then
          Writeln(Line[2]);
       Line[2] := ' L$ ';
       Writeln(Line[3]);
       Line[3] := ' B: ';
       if (InputHexCTrace in TraceCompiler) then
           Writeln(Line[4]);
       Line[4] := ' B$ ';
       writeln;
   end;
   LinebufPtr :=0;
   LineString :='';
end;




end.

