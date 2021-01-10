// XD Pascal for Windows (XPDW) - a 32-bit compiler
// Copyright (c) 2009-2010, 2019-2020, Vasiliy Tereshkov
// Copyright 2020,2021 Paul Robnson

// Latest upgrade by Paul Robinson: Groundhog Day; Tuesday, February 2, 2021

// VERSION 0.16 {.0}

// scans the source code looking for tokens. The Parser (or the
// cross-reference tool) then determines what the tokens mean and
// whether they are appropriate in that context or not

{$I-}
{$H-}

unit Scanner;


interface

uses Common,
     Error,
     CompilerTrace,
     Conditional,
     Listing,
     Patch,
     Assembler,
     SysUtils;


procedure InitializeScanner(const Name: TString);
function SaveScanner: Boolean;
procedure NextTok(Passthru:Boolean=FALSE);
Procedure PeekTok;   // lookahead one token
procedure CheckTok(ExpectedTokKind: TTokenKind);
procedure CheckEitherTok(ExpectedFirst, ExpectedOtherwise: TTokenKind);
procedure EatTok(ExpectedTokKind: TTokenKind);
procedure EatEitherTok(ExpectedFirst, ExpectedOtherwise: TTokenKind);
procedure AssertIdent;
Procedure GetAssemblerStatement;
procedure DefineStaticString(const StrValue: TString; var Addr: LongInt; FixedAddr: LongInt = -1);
Procedure FlushChars;
//procedure SkipTo(This: TTokenKind; That: TTokenKind = EMPTYTOK; Next: TTokenKind = EMPTYTOK; Something: TTokenKind = EMPTYTOK; Other: TTokenKind = EMPTYTOK);
//Procedure SkipPast(This: TTokenKind; That: TTokenKind = EMPTYTOK; Next: TTokenKind = EMPTYTOK; Something: TTokenKind = EMPTYTOK; Other: TTokenKind = EMPTYTOK);


implementation
var
     AssemblerMode: boolean=FALSE;


Const

  Digits:    set of TCharacter = ['0'..'9'];
  HexDigits: set of TCharacter = ['0'..'9', 'A'..'F'];
  Spaces:    set of TCharacter = [#1..#31, ' '];

Var
   StringError: Boolean  = FALSE;

  procedure DefineStaticString(const StrValue: TString; var Addr: LongInt; FixedAddr: LongInt = -1);
  var
    Len: Integer;
  begin
  Len := Length(StrValue);

  if FixedAddr <> -1 then
    Addr := FixedAddr
  else
    begin
    if Len + 1 > MAXINITIALIZEDDATASIZE - InitializedGlobalDataSize then
      begin
          Catastrophic('Fatal: Not enough memory for static string');
          exit;
  	end;
    Addr := InitializedGlobalDataSize;  // Relocatable
    InitializedGlobalDataSize := InitializedGlobalDataSize + Len + 1;
    end;

  Move(StrValue[1], InitializedGlobalData[Addr], Len);
  InitializedGlobalData[Addr + Len] := 0;      // Add string termination character
  end;



procedure InitializeScanner(const Name: TString);
var
  F: TInFile;
  ActualSize: Integer;
  FolderIndex: Integer;

begin
ScannerState.Buffer.Ptr := nil;

// First search the source folder, then the units folder, then the folders specified in $UNITPATH
FolderIndex := 1;

repeat
  Assign(F, TGenericString(Folders[FolderIndex] + Name));
  FileMode :=0; // force read-only in case file is read only
  Reset(F, 1);
  if IOResult = 0 then Break;
  Inc(FolderIndex);
  FileMode := 1; // set filemode back to write only
until FolderIndex > NumFolders;

if FolderIndex > NumFolders then
   Catastrophic('Fatal: Unable to open source file "' + Name+'".');

with ScannerState do
  begin
  FileName := Name;
  Line := 1;
  Position := 0;
  ExtFunc := 0;          // Zero unit procedure and function counts
  ExtProc := 0;
  ProcCount := 0;
  FuncCount := 0;
  inComment := False;       // no comment yet
  
  with Buffer do
    begin
    Size := FileSize(F);
    Pos := 0;

    GetMem(Ptr, Size);

    ActualSize := 0;
    BlockRead(F, Ptr^, Size, ActualSize);
    Close(F);

    if ActualSize <> Size then
       Catastrophic('Fatal: Unable to read source file ' + Name);

  ch  := ' ';
  ch2 := ' ';
  EndOfUnit := FALSE;

  end;
end;
end;


// Used by Unit "Parser" when a new unit is
// being compiled. Probably when a unit being
// compiled calls a unit not yet compiled
// Also used when an $Include file is invoked
function SaveScanner: Boolean;
begin
Result := FALSE;
if ScannerStackTop < SCANNERSTACKSIZE then
  begin
  Inc(ScannerStackTop);
  ScannerStack[ScannerStackTop] := ScannerState;
  Result := TRUE;
  end;
end;


procedure AppendStrSafe(var s: TString; ch: TCharacter);
begin
if Length(s) >= MAXSTRLENGTH - 1 then
   begin
//     Fatal('String is too long');
       if not StringError then
          Err( ERR_StringTooLong);         // String is too long
       StringError := True;
       Exit;
   end;
 s := s + ch;
end;


// unwind $INCLUDE
Procedure UnInclude;
begin
    if not RestoreScanner then
        Catastrophic('Internal fault: Scanner state could not be restored'); {Fatal}
    inInclude := False;

end;


// the master read procedure. The optional
// Peek parameter allows us to look at the
// character we are about to read without
// advancing the buffer
procedure ReadChar(var ch: TCharacter;  peekch: boolean = FALSE );
VAR
   L:Integer;

begin
    if not patchflag then     // used for code insertion
    begin
    if not peekch then
        if ScannerState.ch = #10 then   // End of line found
        begin
            EOLListing;
            ShowTokenLine := False;
            Inc(ScannerState.Line);
            Scannerstate.Position  := 0;
            LineBlockStart := BlockCount;
            LineBlockEnd   := BlockCount;
            LineBlockChange := False;
            FirstStatement :=True;
            if (inputCTrace in TraceCompiler) or
               (InputHexCTrace in TraceCompiler)  then
                WriteInputTrace;
        end;

        ch := #0;
        with ScannerState.Buffer do
        begin
            if Pos < Size then
            begin
                ch := PCharacter(Integer(Ptr) + Pos)^;
                if not peekch then
                begin
                    WriteListing(Ch);
                    Inc(Pos);
                    Inc(ScannerState.Position);
                end;
            end
            else
               if not peekch then
                   if not inInclude then
                      ScannerState.EndOfUnit := TRUE
                   else
                   begin
                      UnInclude;      // exit include file back to calling file
                      ch := ' ';      // clear buffer
                   end;
        end;
    end
    else     // patchflag is on
// PatchFlag is turned on to allow the compiler to reprogram itself by
// inserting characters into the stream either before, in place of, or
// after, certain symbols or statements. It will be completely
// indistinguishablle from user-written code.
//
// Note to future editors: make *damn* surwe the inserted code is
// absolutely perfect, as there is no hope of recovery for the user
// if you screw up.
    begin
           L := Length(PrefixItem);
           if (L<>0) and (PrefixPos <= L ) then
           begin
              Ch := PrefixItem[PrefixPos];
              Inc(PrefixPos);
           end
           else
               If (PrefixPos > L) or (L=0) then
                 Begin
                     PatchFlag := False;
                     PrefixPos := 0;
                     PrefixItem :='';
                     if SuffixItem<>'' then
                        PatchTrap := True;
                     Ch := ' ';  // clear the buffer just in case
                 end;
    end;

    if (inputCTrace in TraceCompiler) or (inputHexCTrace in TraceCompiler) then
    begin
        Inc(LinebufPtr);
        LineBuf[LinebufPtr] := Ord(Ch);
        LineString := LineString + Ch;
    end;
end;



procedure ReadUppercaseChar(var ch: TCharacter);
begin
ReadChar(ch);
ch := UpCase(ch);
end;




procedure ReadLiteralChar(var ch: TCharacter);
begin
ReadChar(ch);
if (ch = #0) or (ch = #10) then
      Fatal('Unterminated string (from ' +
             Radix(ScannerState.Token.DeclaredLine,10)+
            ':'+Radix(ScannerState.Token.DeclaredPos,10)+')');
end;

// An include file replaces the comment it was in,
// therefore whatever was included must be legal
// at the point of insertion

Procedure IncludeFile(Name:TString);
VAR
    LastIoCheck: Boolean; // Include file inherits $I+/$I- from caller
Begin
    Notice('Including '+Name);
    LastIOCheck := Scannerstate.IOCheck;

    // we may need a modified version of
    // initializescanner if it messes things
    // up for the current file but it probably is OK
    // since it's used by CompileProgramOrUnit
    if savescanner then
      begin
          InitializeScanner(Name);
          // if we're here. file opened OK.
          inInclude := true;
          // If I am correct, scannerstate
          // now points to the included file
          // we can just exit and let the
          // scanner continue reading,
          // effectively treating the included
          // file as a replacement for the comment
          // ReadCh will handoff to Uninclude when
          // reachine EOF on the include file,
          // which should restore things back
          // "status quo ante."
      end
    else
      Catastrophic('Too many nested open files');
End;


   // when an integer number (such as in a comment) has to
   // be checked w/o changing the token
  Function GetInt:Integer;
  var
    Num, Digit: Integer;
    NumFound: Boolean;
  begin
  with ScannerState do
  begin
      Num := 0;
      NumFound := FALSE;
      while ch in spaces do
          ReadUppercaseChar(ch);
      If Ch='$' then
      begin
          ReadUppercaseChar(ch);
          while ch in HexDigits do
          begin
              if Num and $F0000000 <> 0 then
                 Fatal('Hexadecimal numeric constant is too large');

              if ch in Digits then
                 Digit := Ord(ch) - DigitZero
              else
                 Digit := Ord(ch) - Ord('A') + 10;
              Num := Num shl 4 or Digit;

              NumFound := TRUE;
              ReadUppercaseChar(ch);
           end;
       end
       else
       while ch in Digits do
           begin
               Digit := Ord(ch) - Ord('0');
               if Num > (HighBound(INTEGERTYPEINDEX) - Digit) div 10 then
                   Fatal('Decimal numeric constant is too large');
               Num := 10 * Num + Digit;

               NumFound := TRUE;
               ReadUppercaseChar(ch);
           end;
       end;
       if not NumFound then
           Fatal('Constant value not found');
        Result := Num;
  end;

procedure ReadSingleLineComment;
begin
    with ScannerState do
    begin
        while (ch <> #10) and not EndOfUnit do
            ReadChar(ch);
        If not  EndOfUnit then
            InComment := FALSE;
    end;
end;


// collects any alphanumeric identfier
// the SYSident var allows $ in an identifier, so user code
// cannot call it, only the compiler or system-level code
Procedure RawIdentifier(Var LCIdentifier, UCIdentifier:Tstring);
var
   ValidIdents: set of tcharacter;

begin
    ValidIdents :=  AlphaNums;
    if SysIdent  then
       ValidIdents := ValidIdents + ['$'];
    with ScannerState do
    begin
        LCIdentifier := '';
        UCIdentifier := '';
        StringError := False; // Flag error if it happens - Once
        repeat
             AppendStrSafe(LCIdentifier, ch);
             ch := UpCase(ch);
             AppendStrSafe(UCIdentifier, ch);
             ReadChar(ch);
        until not (ch in ValidIdents);
        StringError := False;         // Allow it again
    end;
end;


Procedure SkipleadingBlanks;
begin
     with Scannerstate do
     while (Ch IN Spaces) and not EndofUnit do
         ReadUppercaseChar(ch);
end;


procedure ReadMultiLineComment(OldSchool:Boolean = FALSE);
var
   Maybe,
   Done: Boolean;

begin
   with ScannerState do
   begin
       if not OldSchool then   // { comment
           while (ch <> '}') and not EndOfUnit do
               ReadChar(ch)
       else    // (* comment
       begin
          Maybe := False;
            // if we see an * say that we might
            // have a close of a (* comment so say
            // maybe and wait for the next character.
            // If it's an *  again, we were wrong
            // before, but the next character might be
            // a ) so set maybe again. If we see a )
            // AND maybe was on, then  it's definitely a
            // close and we're done. But if it's any
            // other character (or it was a ) but maybe
            // wasn't on) we clear the maybe flag
            // and keep trying.
            repeat
              If Ch = '*' then
                 Maybe := True  // Check next charaacter
              Else if (Ch =')') and Maybe then
                  break   // Now done
              Else
                  Maybe := False;
              ReadChar(ch);
          until  EndOfUnit;
       end;

   // We've exited the comment
      if not EndOfUnit then
          Incomment := False;    // Close } or (*
      if CommentCTrace in TraceCompiler then
          EmitToken('Multiline Comment end: '+IntToStr(Line)+':' +
                    IntToStr(Position)+' NextCh=('+IntToStr(Ord(cH))+', $' +
                    Radix(ord(ch),16)+')');
    end; // with
end;


procedure ReadDirective(OldSchool:Boolean = FALSE);
type
  MessageType = (MsgNote, MsgWarn, MsgStop, MsgFatal);

var
   Item: TString;
   Option: Char;
   Maybe: Boolean;          //   Maybe we're done

    // Take everything through end of comment
    Procedure GetRestOfOption(Const MakeUpperCase: Boolean; Skip:Boolean = False);
    begin
        If Skip then SkipLeadingBlanks;
        with ScannerState do
        begin
            Item := '';
            if not OldSchool then
                while (ch <> '}') and not EndOfUnit do
                begin
            // sincewe come back to returntok which reads
            // the next char, we must be careful not to
            // overeat
                   if MakeUpperCase then
                      AppendStrSafe(Item, UpCase(ch))
                   else
                      AppendStrSafe(Item, ch);
                   ReadChar(ch);
                 end
            else
            begin      // handle (* comment
               Maybe := False;
               Repeat
                // see ReadMultiLineComment for why this works
                   If Ch = '*' then
                      Maybe := True  // Check next charaacter
                   Else if (Ch =')') and Maybe then
                   begin
                       inComment := FALSE;    // Close (*
                       break;   // Now done
                   end
                   Else
                       Maybe := False;
                   ReadChar(ch);
               until  EndOfUnit;
            end;
            if not EndOfUnit then
              inComment := False;
            if CommentCTrace in TraceCompiler then
               EmitToken('Multiline Comment end: '+IntToStr(Line)+':' +
                         IntToStr(Position)+' NextCh=('+IntToStr(Ord(cH)) +
                         ', $'+Radix(ord(ch),16)+')');
        end;
    end;

   // allow $ in identifiers  {$SYSTEM ON
  Procedure OptionSystem;
  begin
      GetRestOfOption(False);
           if (item = 'IDENT') then      // these are conaidered system defined
           SysDef := True              // for the rest of the unit
      else If (Item <>'ON') and (Item<>'OFF') then
         Warning('Invalid $System option "'+Item+'"')
       else
         SysIdent := Item = 'ON';
  end;


  Procedure Messaging(const Msg:MessageType);
  begin
     Case Msg of
       MsgNote:  NoticePrefix_H('User Note: '+Item);
       MsgWarn:  NoticePrefix_H('User Warning: '+Item);
       MsgFatal: begin Notice(''); NoticePrefix_S('User Fatality: '+Item); TrapT; end;   {FATAL}
       MsgStop:  begin Notice(''); NoticePrefix_S('User Stop: '+Item); TrapT; end; {FATAL}
     end;
  end;

  Procedure OptionWarningNoteFatalStop(const Msg:MessageType);
  begin
      GetRestOfOption(False);
      Messaging(Msg);
  end;

  // read to end of identifier
  Procedure GetOptionParam(Skip:boolean);
  begin // GetOptionParam
       with ScannerState do
       begin
           Item := '';
           if Skip then SkipLeadingBlanks;
           repeat
               AppendStrSafe(Item, ch);
               ReadUppercaseChar(ch);
           until not (ch in AlphaNums);
       end;
   end; // GetOptionParam


// Specific option values

// {$DEBUG - Proogram debugging  *DUMMY routine
   Procedure OptionDebug;
   Var
      Enable: Boolean;
   begin
       GetOptionParam(True);
       If (Item='ON') or (Item='+') then
           Enable := TRUE
       else if (Item='-') or (Item='OFF') then
           Enable := FALSE
       else
       begin
           Warning('Invalid $DEBUG option "'+Item+'"');
           ReadMultiLineComment(OldSchool);
           exit;
       end;
       With scannerstate do
       while Ch = ',' do
       begin
           ReadUppercaseChar(Ch);    // eat the ,
           GetOptionParam(True);
          // process this option


       end;
       ReadMultiLineComment(OldSchool);    // discard rest of comment
   end;

// {$TRACE - Program tracing  *DUMMY routine
   Procedure OptionTrace;
   Var
      Enable: Boolean;
   begin
       GetOptionParam(True);
       If (Item='ON') or (Item='+') then
           Enable := TRUE
       else if (Item='-') or (Item='OFF') then
           Enable := FALSE
       else
       begin
           Warning('Invalid $TRACE option "'+Item+'"');
           ReadMultiLineComment(OldSchool);
           exit;
       end;
       With scannerstate do
       while Ch = ',' do
       begin
           ReadUppercaseChar(Ch);    // eat the ,
           GetOptionParam(True);
        // process this option


       end;
       ReadMultiLineComment(OldSchool);    // discard rest of comment
   end;


// {$SHOW - Compiler tracing
   procedure OptionShowHide(Show:Boolean);
   begin
   with Scannerstate do
   begin
        repeat
          GetOptionParam(True);
          if (Item = 'ACTIVITY') then
             if Show then
                 TraceCompiler := TraceCompiler + [ActivityCTrace]
             else
                 TraceCompiler := TraceCompiler - [ActivityCTrace]
          else if Item = 'ALL' then
             if Show then // "The Works"
                TraceCompiler := [BecomesCTrace, SymbolCTrace,  UnitCTrace,
                          TokenCTrace,   KeywordCTrace,    LoopCTrace,
                          CallCTrace,    ProcCTrace,       FuncCTrace,
                          FlagCTrace,    IdentCTrace,      BlockCTrace,
                          CodeCTrace,    CodeGenCTrace,    StatisticsCTrace,
                          ActivityCTrace]
              else // Hide all
                  TraceCompiler := []
           else if (Item = 'ASSIGN') or (Item = 'BECOMES') then
              if Show then
                  TraceCompiler := TraceCompiler + [BecomesCTrace]
              else
                  TraceCompiler := TraceCompiler - [BecomesCTrace]
           else if Item = 'BLOCK' then
              if Show then
                  TraceCompiler := TraceCompiler + [BlockCTrace]
              else
                  TraceCompiler := TraceCompiler - [BlockCTrace]
           else if Item = 'CALL' then
                      if Show then
                          TraceCompiler := TraceCompiler + [CallCTrace]
                      else
                          TraceCompiler := TraceCompiler - [CallCTrace]
           else if Item = 'CODE' then
               if Show then
                   TraceCompiler := TraceCompiler + [CodeCTrace]
               else
                   TraceCompiler := TraceCompiler - [CodeCTrace]
           else if Item = 'CODEGEN' then
                if Show then
                    TraceCompiler := TraceCompiler + [CodeGenCTrace]
                 else
                    TraceCompiler := TraceCompiler - [CodeGenCTrace]
           else if Item = 'FLAG' then
              if Show then
                  TraceCompiler := TraceCompiler + [FlagCTrace]
              else
                  TraceCompiler := TraceCompiler - [FlagCTrace]
          else if Item = 'FUNC' then
              if Show then
                  TraceCompiler := TraceCompiler + [FuncCTrace]
              else
                  TraceCompiler := TraceCompiler - [FuncCTrace]
            else if Item = 'IDENT' then
                if Show then
                   TraceCompiler := TraceCompiler + [IdentCTrace]
                else
                   TraceCompiler := TraceCompiler - [IdentCTrace]
            else if Item = 'INDEX' then
                if Show then
                    TraceCompiler := TraceCompiler + [IndexCTrace]
                else
                    TraceCompiler := TraceCompiler - [IndexCTrace]
            else if Item = 'INPUT' then
                if Show then
                    TraceCompiler := TraceCompiler + [InputCTrace]
                else
                    TraceCompiler := TraceCompiler - [InputCTrace]
            else if Item = 'INPUTHEX' then
                if Show then
                    TraceCompiler := TraceCompiler + [InputHexCTrace]
                else
                    TraceCompiler := TraceCompiler - [InputHexCTrace]
            else if Item = 'KEYWORD' then
                if Show then
                   TraceCompiler := TraceCompiler + [KeywordCTrace]
                else
                   TraceCompiler := TraceCompiler - [KeywordCTrace]
            else if Item = 'LIMIT' then
                if Show then // either sets limit
                   TraceLimit := GetInt  // show this many
                else
                   TraceLimit := -GetInt // hide this many
            else if Item = 'LOOP' then
                if Show then
                   TraceCompiler := TraceCompiler + [LoopCTrace]
                else
                   TraceCompiler := TraceCompiler - [LoopCTrace]
            else if Item = 'NARROW' then
                if Show then
                   TraceCompiler := TraceCompiler + [NarrowCTrace]
                 else
                 TraceCompiler := TraceCompiler - [NarrowCTrace]
            else if Item = 'PROC' then
                if Show then
                   TraceCompiler := TraceCompiler + [ProcCTrace]
                else
                   TraceCompiler := TraceCompiler - [ProcCTrace]
            else if (Item = 'PROCFUNC') or (Item = 'FUNCPROC') then
                if Show then
                   TraceCompiler := TraceCompiler + [ProcCTrace,FuncCTrace]
                else
                   TraceCompiler := TraceCompiler - [ProcCTrace,FuncCTrace]
            else if Item = 'STATISTICS' then
                if Show then
                   TraceCompiler := TraceCompiler + [StatisticsCTrace]
                 else
                   TraceCompiler := TraceCompiler - [StatisticsCTrace]
            else if Item = 'SYMBOL' then
                if Show then
                   TraceCompiler := TraceCompiler + [SymbolCTrace]
                else
                   TraceCompiler := TraceCompiler - [SymbolCTrace]
            else if Item = 'TOKEN' then
                if Show then
                   TraceCompiler := TraceCompiler + [TokenCTrace]
                else
                   TraceCompiler := TraceCompiler - [TokenCTrace]
            else if (Item = 'UNIT') or (Item = 'UNITS') then
                if Show then
                   TraceCompiler := TraceCompiler + [UnitCTrace]
                else
                   TraceCompiler := TraceCompiler - [UnitCTrace]
             else if Item = 'WIDE' then
                 if Show then
                    TraceCompiler := TraceCompiler - [NarrowCTrace]
                  else
                    TraceCompiler := TraceCompiler + [NarrowCTrace]

// Easter egg
             else if Item = 'FEELINGS' then
                 if Show then
                    Warning('XDPascal is a computer program. XDPW doesn''t have any feelings. I feel really bad that I don''t.')
              else
                    Warning('Okay, I won''t tell you my feelings then.')
              else
                begin
                    If TraceCompiler = [] then EmitStop;
                    Warning('Invalid $SHOW option "'+Item+'"');
                    ReadMultiLineComment(OldSchool);
                    Exit;
                end; // continue options
        if Ch<>',' then
        begin    // discard rest of comment
            If TraceCompiler = [] then EmitStop;
            ReadMultiLineComment(OldSchool);
            exit;
        end;
        ReadUpperCaseChar(Ch);           // get char after comma
                                         // and make sure it's capitalized
    until EndofUnit ;
    end;
   end;


   Procedure DumpSymbolTable;
   type

       DumpTypes = ( DumpUnk,      DumpConst,    DumpType,
                     DumpScalar,   DumpRecord,   DumpArray,
                     DumpVar,      DumpLabels,   DumpProc,
                     DumpFunc,     DumpExternal, DumpCompiler,
                     DumpSystem);

       DumpSet= Set of DumpTypes;

   Const
       DumpProcFunc = [DumpProc,   DumpFunc];
       DumpUser     = [DumpConst,  DumpType , DumpScalar,
                       DumpRecord, DumpArray, DumpVar,
                       DumpLabels, DumpProc,  DumpFunc];
       DumpAll      = [DumpUnk,      DumpConst,    DumpType,
                       DumpScalar,   DumpRecord,   DumpArray,
                       DumpVar,      DumpLabels,   DumpProc,
                       DumpFunc,     DumpExternal, DumpCompiler,
                       DumpSystem];

   Var
      K: Integer;
      S: String[4];
      M: DumpSet;
      AbsoluteFlag:Char;

      Procedure DumpFlag;      begin Write(K:4,' ',GetIDKindSpelling(ident[K].kind),AbsoluteFlag,' '); end;
      Procedure DumpNoType;    begin Write(' ':8); end;
      Procedure DumpTypeName;  begin Write(GetTypeSpelling(ident[K].DataType,FALSE):8); end;
      Procedure DumpAddress;   begin Write(ident[K].Address:7,' '); end;
      Procedure DumpNoAddress; begin Write(' ':8); end;
      Procedure DumpName;      begin Writeln(ident[K].Name );  end;

      procedure DumpTypeKind(q:TTypeKind);
      BEGIN
          S:='????';
//        case ident[K].Constval.kind of
          case Q of
                  EMPTYTYPE:      S:='empt';
                  ANYTYPE:        S:='any ';
                  INTEGERTYPE:    S:='I   ';
                  INT64TYPE:      S:='I64 ';
                  INT128TYPE:     S:='I128';
                  CURRENCYTYPE:   S:='curr';
                  SMALLINTTYPE:   S:='sml ';
                  SHORTINTTYPE:   S:='shrt';
                  WORDTYPE:       S:='Word';
                  BYTETYPE:       S:='Byte';
                  CHARTYPE:       S:='char';
                  BOOLEANTYPE:    S:='bool';
                  REALTYPE:       S:='real';
                  SINGLETYPE:     S:='Sngl';
                  POINTERTYPE:    S:='Ptr ';
                  FILETYPE:       S:='File';
                  ARRAYTYPE:      S:='arr ';
                  RECORDTYPE:     S:='rec ';
                  INTERFACETYPE:  S:='if  ';
                  SETTYPE:        S:='set ';
//                FUNCTYPE:       S:='fun ';
//                PROCTYPE:       S:='proc';
//                SYSTEMFUNCTYPE: S:='Syf ';
//                SYSTEMPROCTYPE: S:='Syp ';
                  ENUMERATEDTYPE: S:='enum';
                  SUBRANGETYPE:   S:='sbr ';
                  PROCEDURALTYPE: S:='p/f ';
                  METHODTYPE:     S:='meth';
                  FORWARDTYPE:    S:='fwd ';
          end;
          Write(S);
      end;

      Procedure DumpItem(Mode: DumpSet);
      Var
          isProc, isFunc, isPF: Boolean;
          DT:Integer;
      begin

 {

    DumpType
    DumpScalar
    DumpRecord
    DumpArray
    DumpVar

    DumpExternal
    DumpUser
    DumpCompiler
    DumpSystem
    DumpAll
}
                  isFunc := ident[K].kind = FUNC;  isProc := ident[K].kind = PROC;
                  isPF := isFunc or isProc;
                  DT := ident[K].DataType;

                  if ((ident[K].kind = EMPTYIDENT) and (DumpUnk    in mode)) or

                     ((ident[K].kind = GOTOLABEL)  and (dumplabels in mode)) or
                     ((ident[K].kind = CONSTANT)   and (DumpConst  in mode)) or
                                          (isFunc  and (DumpFunc   in mode)) or
                                          (isProc  and (DumpProc   in mode)) or
                                    // external
                     ((isProc or isFunc and ident[K].isAbsolute) and
                                                    (DumpExternal in mode))  OR


                     ((ident[K].kind = CONSTANT)   and (DumpConst  in mode))  OR
                     // Arrays
                    ((Types[DT].Kind = ARRAYTYPE)  and  (DumpArray  in mode))  OR


                     ((ident[K].kind = VARIABLE)   and (DumpVar    in mode))  then
                    begin
                        AbsoluteFlag:=' ';
                        if ident[K].isAbsolute then
                           if  isPF then
                               AbsoluteFlag:='X'
                           else
                               AbsoluteFlag :='A';
                        DumpFlag;
                        IF (ident[K].kind = USERTYPE) OR
                           (ident[K].kind = VARIABLE) THEN
                             DumpTypeName
                        else DumpNoType;
                        case ident[K].DeclaredPos of
                              System_Constant: write('cmpC');
                                  System_Type: write('cmpT');
                             System_Procedure: write('cmpP');
                              System_Function: write('cmpF');       // built-in functions
                           XDP_SystemDeclared: write(' SY ');       // defined by the System unit
                           else
                             Write(ident[K].DeclaredPos:4)              // User-defined

                           end;
                        if (ident[K].kind = USERTYPE) or (ident[K].kind = CONSTANT) or
                           (isFunc and (ident[K].DeclaredPos = System_Function))    or
                           (isProc and (ident[K].DeclaredPos = System_Procedure)) THEN
                             DumpNoAddress
                        else DumpAddress;
                        DumpName;
                     end;
{
         GetIDKindSpelling(ident[K].kind));
                 if ident[K].kind =USERTYPE
            else if ident[K].kind =CONSTANT THEN

}
        end;   // procedure dumpitem

   Begin
   m := [];
   with scannerstate do
   BEGIN
      if ( ch=',') or (ch in spaces) then
          readchar(ch);
      repeat
        GetOptionParam(TRUE);
        Writeln('$$ DumpSym item="',item,'"');
             if (Item='UNK')     then m:= m+[DumpUnk]
        else if (item='FUNC')    then m:= m+[DumpFunc]
        else if (item='PROC')    then m:= m+[DumpProc]
        else if (item='PROCFUNC') or (item='FUNCPROC') then m:= m+[DumpProc,DumpFunc]
        else if (item='LABEL')    or (item='LABELS')   then m:= m+[DumpLabels]
        else if (item='CONST')   then m:= m+[DumpConst]
        else if (item='RECORD')  then m:= m+[DumpRecord]
        else if (item='TYPE')    then m:= m+[DumpType]
        else if (item='SCALAR')  then m:= m+[DumpScalar]
        else if (item='VAR')     then m:= m+[DumpVar]
        else if (item='ARRAY')   then m:= m+[DumpArray]
        else if (item='EXTERNAL')then m:= m+[DumpExternal]
        else if (item='SYSTEM')  then m:= m+[DumpSystem]
        else if (item='COMPILER')then m:= m+[DumpCompiler]
        else if (item='USER')    then m:= m+DumpUser
        else if (item='ALL')     then m:= m+DumpAll;
        if Ch <> ',' then break;
        readchar(Ch);     // get start of next option
       until EndofUnit;
   END;
   Write ('Symbol table dump settings are: ');
   K:=0;
   write('[');
        if  DumpUnk      in M then begin inc(K); write(' DumpUnk');  end;
        if  DumpConst    in M then begin inc(K); write(' DumpConst');  end;
        if  DumpType     in M then begin inc(K); write(' DumpType');  end;
        if  DumpScalar   in M then begin inc(K); write(' DumpScalar'); If K>4 then begin writeln; write(' ':4);k:=0; end;  end;
        if  DumpRecord   in M then begin inc(K); write(' DumpRecord'); If K>4 then begin writeln; write(' ':4);k:=0; end; end;
        if  DumpArray    in M then begin inc(K); write(' DumpArray'); If K>4 then begin writeln; write(' ':4);k:=0; end;  end;
        if  DumpVar      in M then begin inc(K); write(' DumpVar'); If K>4 then begin writeln; write(' ':4);k:=0; end; end;
        if  DumpLabels   in M then begin inc(K); write(' DumpLabels'); If K>4 then begin writeln; write(' ':4);k:=0; end; end;
        if  DumpProc     in M then begin inc(K); write(' DumpProc'); If K>4 then begin writeln; write(' ':4);k:=0; end; end;
        if  DumpFunc     in M then begin inc(K); write(' DumpFunc'); If K>4 then begin writeln; write(' ':4);k:=0; end; end;
        if  DumpExternal in M then begin inc(K); write(' DumpExternal'); If K>4 then begin writeln; write(' ':4);k:=0; end; end;
        if  DumpCompiler in M then begin inc(K); write(' DumpCompiler'); If K>4 then begin writeln; write(' ':4);k:=0; end; end;
        if  DumpSystem   in M then begin inc(K); write(' DumpSystem'); end;
        writeln(' ]'); writeln;

        ReadMultiLineComment(OldSchool); // skip rest
        Writeln('Symbol Table');
m := DUMPALL;
        For K := 1 to NumIdent do
             DumpItem(M);
   end;

   Procedure OptionApptype;
    begin
       GetRestOfOption(True,True);
       if Item = 'CONSOLE' then
          IsConsoleProgram := TRUE
       else if Item = 'GUI' then
          IsConsoleProgram := FALSE
       else
           Fatal('Unknown application type ' + Item);
   end;

   procedure OptionUnitPath;
       begin
        GetRestOfOption(True);
        Inc(NumFolders);
        if NumFolders > MAXFOLDERS then
           begin
              Catastrophic('Maximum number of unit paths exceeded'); {fatal}
              Exit;
            end;
        Folders[NumFolders] := Folders[1] + Item;
    end;

   Procedure OptionMessage;
   begin
        GetOptionParam(TRUE);
        if      Item = 'WARNING' then OptionWarningNoteFatalStop(MsgWarn)
        else if Item = 'NOTE'    then OptionWarningNoteFatalStop(MsgNote)
        else if Item = 'FATAL'   then OptionWarningNoteFatalStop(MsgFatal)
        else
           begin
               Warning('Invalid $MESSAGE parameter "'+Item+'"');
               GetRestOfOption(FALSE);
           end
   end;

   Procedure OptionDump;
   begin
       with scannerstate do
       repeat
            GetOptionParam(TRUE);
            if (Item='SYMTAB') or (Item='SYMBOLS') or (Item='SYMBOL') then
                DumpSymbolTable
             else if (item='DEFINE') then
                DumpDefineList;
             if Ch <> ',' then break;
                readchar(Ch);
             readchar(Ch);     // get start of next option
       until EndofUnit;
       ReadMultiLineComment(OldSchool); // skip rest
   end;


   Procedure OptionI;  // {$I+/{$I- or {$I filename
   begin
       With Scannerstate do
       begin
          If Ch in ['+','-'] then
             IOCheck := CH='+'
          else
          if ch in spaces then
          begin
              GetRestOfOption(False,True); // skip leading blanks
              IncludeFile(Item);
              exit;
           end
           else
              Warning('Invalid $I option');
           ReadMultiLineComment(OldSchool); // skip rest on good or bad
        end;
     end;

   Procedure OptionInclude;  // {$INCLUDE filename
     begin
         With Scannerstate do
         begin
            ReadChar(Ch);
            if ch in spaces then
            begin
                GetRestOfOption(False,True);
                IncludeFile(Item);
                exit;
             end
             else
                Warning('Invalid $INCLUDE option');
             ReadMultiLineComment(OldSchool); // skip rest
          end;
       end;

     Procedure ConditionalStatement(Option:TTokenKind);
     begin
     with Scannerstate do
      begin
        RawIdentifier(Token.Name,Token.NonUppercaseName);
        GetRestOfOption(FALSE,FALSE);
        Token.Kind := Option;
        Token.NonUpperCaseName := Token.NonUpperCaseName + Item;
      end;
     end;

begin // ReadDirective
with ScannerState do
  begin
  GetOptionParam(False);
  if      Item = '$APPTYPE'  then OptionAppType      // Console/GUI application type directive
  else if Item = '$DEBUG'    then OptionDebug
  else if Item = '$FATAL'    then OptionWarningNoteFatalStop(MsgFatal)  // {$Fatal msg}(MsgFatal)
  else if Item = '$HIDE'     then OptionShowHide(False)
  else if Item = '$I'        then OptionI             // IOResult or include
  else if Item = '$INCLUDE'  then OptionInclude
  else If Item=  '$MESSAGE'  then OptionMessage      // Messages
  else if Item = '$NOTE'     then OptionWarningNoteFatalStop(MsgNote)
  else if Item = '$SHOW'     then OptionShowHide(True)     // Compiler tracing
  else if Item = '$DUMP'     then OptionDump               // Symbol and define table dump
  else if Item = '$STOP'     then OptionWarningNoteFatalStop(MsgStop)  // {$STOP msg}
  else if Item = '$SYSTEM'   then OptionSystem
  else if Item = '$TRACE'    then OptionTrace
  else If Item = '$UNITPATH' then OptionUnitPath     // Unit path directive
  else if Item = '$WARNING'  then OptionWarningNoteFatalStop(MsgWarn)

  // Conditional compiltion
  else if (Item = '$IF')     then ConditionalStatement(CCSIfTok)
  else if (Item = '$ENDIF')  then ConditionalStatement(CCSEndIfTok)
  else if (Item = '$ELSE')   then ConditionalStatement(CCSElseTok)
  else if (Item = '$ELSEIF') then ConditionalStatement(CCSElseIfTok)
  else if (Item = '$DEFINE') then ConditionalStatement(CCSDefineTok)
  else if (Item = '$IFDEF')  then ConditionalStatement(CCSIfDefTok)
  else if (Item = '$UNFDEF') then ConditionalStatement(CCSIFNdefTok)
  else if (Item = '$IFOPT')  then ConditionalStatement(CCSUndefTok)

  else        // All other directives are ignored
    ReadMultiLineComment(OldSchool);
  end;
end;

Procedure FlushChars;
begin
//skip until interrupted by blank or ;
    With Scannerstate do
        while not (ch in spaces+[';']) do
            readchar(ch);
end;


// hexadecimal numbers
procedure ReadHexadecimalNumber;
var
  Num, Digit: Integer;
  NumFound: Boolean;
begin
with ScannerState do
  begin
    Num := 0;

    NumFound := FALSE;
    while ch in HexDigits do
    begin
      if Num and $F0000000 <> 0 then
      begin
           Err(ERR_IntTooBig); // Integer constant exceeds range
           FlushChars;
           exit;
      end;
      if ch in Digits then
          Digit := Ord(ch) - Ord('0')
      else
          Digit := Ord(ch) - Ord('A') + 10;
      Num := Num shl 4 or Digit;

      NumFound := TRUE;
      ReadUppercaseChar(ch);
    end;
    if not NumFound then
//        Fatal('Hexadecimal constant is not found');

        Err( ERR_Constant); // Error in Constant

    Token.Kind := INTNUMBERTOK;
    Token.OrdValue := Num;
  end;
end;

Procedure ReadInteger;
var
  Num: Integer;
  Digit: Byte;
begin
  with ScannerState do
  begin
      while ch in Digits do
      begin
           Digit := Ord(ch) - Ord('0');
           if Num > (HighBound(INTEGERTYPEINDEX) - Digit) div 10 then
           begin
                Err(ERR_IntTooBig); // Integer constant exceeds range
                FlushChars;
                break;  // to avoid spurious second error of no value
           end;
           Num := 10 * Num + Digit;
           ReadChar(ch);
      end;
      Token.Kind := INTNUMBERTOK;
      Token.OrdValue := Num;

   end;
end;

// integers in any base 2..36
procedure ReadOtherBaseNumber;
var Base,
    Digit: Integer;
  BadNum:Boolean;


begin
   with scannerstate do
  begin
      if (token.Ordvalue < 2 ) or (token.ordvalue>36) then
      begin
          Err( ERR_BadBase); // base must be 2..36
          FlushChars;
          exit;
      end;
      Base := Token.ordvalue;
      Token.OrdValue := 0;
      BadNum := TRUE;
      while ch in RadixSet do
      begin
          For Digit := 0 to 36 do
             if Ch = RadixString[Digit] then
                Break;
          If  Digit > Base then
          begin
               Err2( ERR_BadBaseChar,Radix(Base,10),Ch); // Not valid for base N
               FlushChars;
               exit;
          end;
          if Token.OrdValue > (HighBound(INTEGERTYPEINDEX) - Digit) div base then
          begin
               Err(ERR_IntTooBig); // Integer constant exceeds range
               FlushChars;
               exit;
          end;
          Token.OrdValue  := Base * Token.OrdValue  + Digit;
          BadNum := FALSE;
          ReadUppercaseChar(ch);
      end;
      if BadNum then
      begin
          Err( ERR_Constant);    // error in constant
          FlushChars;
      end;
   end;
end;

// integers and floating-point numbers
procedure ReadDecimalNumber;
var
  DigitCount,
  Num, Expon, Digit: Integer;
  Frac, FracWeight: Double;
  NegExpon, RangeFound, ExponFound: Boolean;
begin
with ScannerState do
  begin
  Num := 0;
  Frac := 0;
  Expon := 0;
  DigitCount := 0;
  NegExpon := FALSE;

  while ch in Digits do
  begin
      inc(DigitCount);
      Digit := Ord(ch) - Ord('0');
      if Num > (HighBound(INTEGERTYPEINDEX) - Digit) div 10 then
      begin
           Err(ERR_IntTooBig); // Integer constant exceeds range
           FlushChars;
           Token.Kind := INTNUMBERTOK;   // To prevent spurious error later
           Token.OrdValue := Num;
           exit;
      end;;
      Num := 10 * Num + Digit;
      ReadUppercaseChar(ch);

      if (DigitCount = 1) and (Num=0) and (Ch='X') then    // abandon integer and read hex number
      begin
          ReadUppercaseChar(ch);    // Consume the X - it marks the spot
          ReadHexadecimalNumber;    // allow 0xNNNN constants
          exit;
      end;
      if (DigitCount <3) and (Ch='#') then    // abandon integer and read specific base number
      begin
          ReadUppercaseChar(ch);        // Consume the #
          Token.Kind := INTNUMBERTOK;
          Token.OrdValue := Num;        // save the radix in Token
          ReadOtherBaseNumber;          // allow radix#number constants
          exit;
      end;
   end;

  if (ch <> '.') and (ch <> 'E') then                                   // Integer number
    begin
    Token.Kind := INTNUMBERTOK;
    Token.OrdValue := Num;
    end
  else
    begin

    // Check for '..' token
    RangeFound := FALSE;
    if ch = '.' then
      begin
        ReadUppercaseChar(ch2);
        if ch2 = '.' then                                                 // Integer number followed by '..' token
        begin
            Token.Kind := INTNUMBERTOK;
            Token.OrdValue := Num;
            RangeFound := TRUE;
        end;
      if not EndOfUnit then Dec(Buffer.Pos);
      end; // if ch = '.'

    if not RangeFound then                 // Fractional number
      begin

      // Check for fractional part
      if ch = '.' then
        begin
        FracWeight := 0.1;
        ReadUppercaseChar(ch);

        while ch in Digits do
          begin
          Digit := Ord(ch) - Ord('0');
          Frac := Frac + FracWeight * Digit;
          FracWeight := FracWeight / 10;
          ReadUppercaseChar(ch);
          end;
        end; // if ch = '.'

      // Check for exponent
      if ch = 'E' then
        begin
        ReadUppercaseChar(ch);

        // Check for exponent sign
        if ch = '+' then
          ReadUppercaseChar(ch)
        else if ch = '-' then
          begin
          NegExpon := TRUE;
          ReadUppercaseChar(ch);
          end;

        ExponFound := FALSE;
        while ch in Digits do
          begin
          Digit := Ord(ch) - Ord('0');
          Expon := 10 * Expon + Digit;
          ReadUppercaseChar(ch);
          ExponFound := TRUE;
          end;

          if not ExponFound then
          begin
//              Fatal('Exponent is not found');
              Err( ERR_NoExponent); // Exponent expected
              FlushChars;
              Token.Kind := REALNUMBERTOK;   // To prevent spurious error later
              Token.RealValue := Pi;
              exit;
          end;
          if NegExpon then Expon := -Expon;
      end; // if ch = 'E'

      Token.Kind := REALNUMBERTOK;
      Token.RealValue := (Num + Frac) * exp(Expon * ln(10));
      end; // if not RangeFound
    end; // else
  end;
end;



// Determine type of number
procedure ReadNumber;
begin
with ScannerState do
  if ch = '$' then
    begin
    ReadUppercaseChar(ch);
    ReadHexadecimalNumber;
    end
  else
    ReadDecimalNumber;
end;



// read #nnn or #$nn char
procedure ReadCharCode;
begin
with ScannerState do
  begin
     ReadUppercaseChar(ch);
     if not (ch in Digits + ['$']) then
          Fatal('Character code is not found');
     ReadNumber;

     if (Token.Kind = REALNUMBERTOK) or (Token.OrdValue < 0) or (Token.OrdValue > 255) then
          Fatal('Illegal character code');
     Token.Kind := CHARLITERALTOK;
  end;
end;


// Called on a "BEGIN"
Procedure BeginCheck;
var
      EmitMessage: TString;

Begin
if skipping then
   emitmessage := '(skipping) '
else
   EmitMessage :='';
// here is where we check if it's
// the first begin in a procedure/function
   if beginCount = 0 then // It is
   begin
       PatchState := PatchProcBegin;
       If parserstate.IsUnit then
           EmitMessage := 'unit proc first '
       else
       if isMainProgram then
           EmitMessage := 'MAIN PROGRAM First '
       else
           EmitMessage := 'main proc first '
   end
   else   // This is a begin block inside of an earlier block
         ;    // nothing to do

   if (TokenCTrace in TraceCompiler) or
   (KeywordCTrace in TraceCompiler) or
   (BlockCTrace in TraceCompiler)   then
      with scannerstate do
      EmitToken(EmitMessage+'BEGIN('+IntToStr(Token.DeclaredLine)+':'+IntToStr(Token.DeclaredPos)+') BeginCount='+IntToStr(BeginCount));

   Inc(BeginCount);     // BEGIN
   Inc(BlockCount);    // increased on BEGIN, CASE, REPEAT, decreased on UNTIL, END
end;

// Is it a keyword or an identifier? Read more and find out!!

// This simply reads the text for an identifier or keyword
// and captures it. This proc does not do anything with the identifier
// except collect it for further processing

// SpecialProtected means the & qualifier immediately preceded
// the identifier, indicating it should be allowed even if it
// matches a keyword. It allows any identifier character so it
// allows identiifers like &STRING, &IF, or even &2

// the SYSident var allows $ in an identifier, so user code
// cannot reference it, only the compiler or system-level code

procedure ReadKeywordOrIdentifier(SpecialProtected: Boolean = FALSE);
var
  NonUppercaseText: TString;
  CurToken: TTokenKind;
  ProtectedIndicator:String[2];

begin
 ProtectedIndicator :='';
 if SpecialProtected then
    ProtectedIndicator :=',p';
 with ScannerState do
 begin
  LastIdentifier := '';            // used for modifier assignment
  NonUppercaseText := '';
  Token.DeclaredPos := Position;    // Start of the identifier or keyword,
  Token.DeclaredLine:= Line;        // not its end

  RawIdentifier(NonUppercaseText, LastIdentifier );
  CurToken := EMPTYTOK;
  if not SpecialProtected then   // Check for a keyword
      CurToken := GetKeyword(LastIdentifier);
  // Note we don't trace keywords here; the processor for each
  // keyword will do that, with the exception of BEGIN
  if CurToken <> EMPTYTOK then  // Keyword found
   begin
      Token.Kind := CurToken;
      If (CurToken = BEGINTOK) or (CurToken = REPEATTOK) or
         (CurToken = CASETOK) then
      Begin
         inc(BlockCount);
         LineBlockChange := TRUE;

         If (CurToken = BEGINTOK) then
             BeginCheck;
      end
      else if (CurToken = UNTILTOK) or
             ((Curtoken = ENDTOK) and  (BlockCount >0)) then
             begin
             Dec(BlockCount);
             Dec(LineBlockEnd);
             LineBlockChange := TRUE; // There has been an increase or
                                      // decrease in block level on this line
             end;

   end
  else
    begin                             // Identifier found
    Token.Kind := IDENTTOK;
    Token.Name := LastIdentifier ;
    Token.NonUppercaseName := NonUppercaseText;
     if (TokenCTrace in TraceCompiler) or
        (IdentCTrace in TraceCompiler)   then
        EmitToken('ident ' + LastIdentifier + ProtectedIndicator);

    end;
  end;
end;

// identifier prefixed by & means don't check keywords
 procedure ReadProtectedIdentifier;
 var
    c:char;
 begin
    ReadChar(c);  // get the identifier starting after the ampersand.
    ReadKeywordOrIdentifier(True);
  end;


 // get one character or a string
procedure ReadCharOrStringLiteral;
var
  Text: TString;
  EndOfLiteral: Boolean;
begin
with ScannerState do
  begin
  Text := '';
  EndOfLiteral := FALSE;
//
  repeat
    ReadLiteralChar(ch);
    if ch <> '''' then
      AppendStrSafe(Text, ch)
    else
      begin
      ReadChar(ch2);
      if ch2 = '''' then                                                   // Apostrophe character found
        AppendStrSafe(Text, ch)
      else
        begin
        if not EndOfUnit then Dec(Buffer.Pos);                             // Discard ch2
        EndOfLiteral := TRUE;
        end;
      end;
  until EndOfLiteral;

  if Length(Text) = 1 then
    begin
    Token.Kind := CHARLITERALTOK;
    Token.OrdValue := Ord(Text[1]);
    end
  else
    begin
    Token.Kind := STRINGLITERALTOK;
    Token.Name := Text;
    Token.StrLength := Length(Text);
    DefineStaticString(Text, Token.StrAddress);
    end;

  ReadUppercaseChar(ch);
  end;
end;




// NOTE TO FUTUR EDITORS (or myself):
//      This is one of the most critical pieces of code in the
//      compile part of the compiler. *Everything* goes through
//      here to process characters into tokens. Errors here will
//      cause unexpected results later. Use extreme caution when
//      adding or changing anything in this part of the program.
//      This is not the HEART of the program, but it is even
//      more citical, say, the left venticle. READCH is the
//      other half. Which this roiutine depends upon.

// pasthru means to pass through an end of line
// (used by the mini-assembler)

Procedure NextTok(Passthru:Boolean=FALSE);
var
   Suppress,
   bypass: Boolean;
   MSg: String;

  Procedure CheckTrace;
  begin
      If (SymbolCTrace in TraceCompiler) or (TokenCTrace in TraceCompiler) then
      BEGIN
          if skipping then
             MSG := '(Skipped) '
          else
             MSG := '';
          EmitToken(MSG+'Symbol '+GetTokSpelling(Scannerstate.Token.Kind));
      END;
  end;



   procedure OpenComment;
   begin
      With Scannerstate do
           EmitToken('Multiline Comment Open: '+
                     IntToStr(Token.DeclaredLine)+':' +
                     IntToStr(Token.DeclaredPos));
   end;


// return the next token in sequence
// This is the original NextTok

// This replaces the original NextTok to
// allow for conditional compilation

procedure ReturnTok;
begin
with ScannerState do
  begin
  Token.Kind := EMPTYTOK;
  // This marks the exact start of this token rather than the point where
  // we finish processing it. Helpful for  finding start of runaway comments,
  // unterminated strings, etc.
  Token.DeclaredLine:= Line;
  Token.DeclaredPos:=  Position;

  // The comment is  supposed to be invisible (except for line comments
  // which simply discard the rest of the line) nd if a comment is found,
  // we discard the cmment (except processing $ directives if $ immediately
  // follows the { or (* ) then after the comment is finished, check if
  // there is another comment (it's probably rare, but two comments in a row
  // can happen. "Two comments" meaning (* *)(* *),(* *){ }, { }{ } or { }(* *).
  // also, comments do not "nest" we do not see another comment (except
  // in the future when processing directives in open code

//   Note: Originally the three comment processors // , { , and (* were
  // in a separate loop above the main CASE statement, which ate spaces and
  // control characters as well as comments after a comment was found the
  // loop would pull the next character to be checked at the top of the loop
  // to see if it was another comment prefix ( { or /. Since if the comments
  // are moved from a separate loop above the token checker (which it has to
  // be to allow directives to be processed and skip over code in certain
  // casses) the multi-line comment processor must either read the extra
  // character after processing the comment or when execution resumes on
  // return we must do so.  This is a reminder to myself to watch the
  // compiler's appetie, it must be Goldilocks style: not too much or too
  // little, "just right." Either eat it there before returning, or eat it
  // here after returning. Must be done by one or the other, but not both

 // Note: there are two case statements here.
 // The first case handles tokens which are or
 // may be longer than one character. These must
 // also pick up (in Ch) the character immediately
 // following them.

 // The second case, in the ELSE clause of the
 // first one, pick up all single character tokens.
 // after they define the token, the next character
 // is loaded into Ch after them. Thus the
 // double-characxter tokens *must* read the next
 // character (but not do anything except store it)
 // while the single-character tokens *must not*
 // (and don't) read the next character.


  // Read character - first case: double- or multiple-character tokens
  case ch of
  // multiple character tokens: identifiers, keywords, comments,
  //                            numbers, strings
    '0'..'9', '$':
       Begin ReadNumber; CheckTrace; end;
    '#':
       begin ReadCharCode; CheckTrace; end;
       // to allow for EBCDIC OR ASCII this uses smaller blocks of chars
    'A'..'I', 'J'..'R', 'S'..'Z',
    'a'..'i', 'j'..'r', 's'..'z', '_':        // an identifier or keyword is not a symbol so we don't checktrace
         ReadKeywordOrIdentifier;
    '&': ReadProtectedIdentifier;
    '''':
        begin ReadCharOrStringLiteral; CheckTrace; end;
    ':':            // : or :=
      begin
      Token.Kind := COLONTOK; //presume it's :
      ReadChar(ch);
      if ch = '=' then
        begin
        Token.Kind := BECOMESTOK;   // no, it's :=
        ReadChar(ch);
        end;
        CheckTrace;
      end;    // case of :
    '*':   // *, **,, or *=
      begin
         Token.Kind := MULTOK;
         ReadChar(ch);
         if Ch = '*' then
          begin
              Token.Kind := EXPONTOK;
              ReadChar(ch);
          end
         else if Ch = '=' then
          begin
              Token.Kind := MULEQTOK;
              ReadChar(ch);
          end;
         CheckTrace;
       end; // case of *
    '+':
       BEGIN // + OR +=
           Token.Kind := PLUSTOK; // PRESUME +
           ReadChar(ch);
           if Ch = '=' then
           begin
               Token.Kind := PLUSEQTOK;  // No, +=
               ReadChar(ch);
           end;
           CheckTrace;
       end;  // case of +
    '-':
       BEGIN // - OR -=
           Token.Kind := MINUSTOK;
           ReadChar(ch);
           if Ch = '=' then
           begin
               Token.Kind := MINUSEQTOK;  // No, -=
               ReadChar(ch);
           end;
           CheckTrace;
       end;   // case of -
    ';':
       begin
           if AssemblerMode then // it's a ; comment
           begin
           // Note: we will "open" the comment. The end of
           // comment processor will close it
               Token.Kind:= COMMENTTOK;        // Open ; comment
               if CommentCTrace in TraceCompiler then
                   OpenComment;
               ReadSingleLineComment;
           end
           else
           begin
               if ch = '=' then // you blew it!
                   Token.Kind := ERRSEMIEQTOK    // ;= is invalid
               else
                   Token.Kind := SEMICOLONTOK; // presume ;
               CheckTrace;
           end;
           ReadChar(Ch);                   // pick up next char after symbol(s)
       end;   // case of  ;
    '>':         // > or >=
       begin
           Token.Kind := GTTOK;  // presume >
           ReadChar(ch);
           if ch = '=' then
           begin
               Token.Kind := GETOK;    // No, it's >=
               ReadChar(ch);
           end;
           CheckTrace;
       end;    // case of >
    '<':               // < , <> ,  or <=
      begin
         Token.Kind := LTTOK;     // presume <
         ReadChar(ch);
         if ch = '=' then
         begin
            Token.Kind := LETOK;     // no, it's <=
            ReadChar(ch);
         end
         else if ch = '>' then       // no, it's <>
         begin
            Token.Kind := NETOK;
            ReadChar(ch);
        end;
        CheckTrace;
      end;  // case of <
    '.':             // . , .. ,  .) , or assembler label
      begin
         Token.Kind := PERIODTOK;  // presume .
         ReadChar(ch);
         if ch = '.' then
         begin
             Token.Kind := RANGETOK;   // no, it's ..
             ReadChar(ch);
         end
         else if ch = ')' then // old .) for ]
         begin
             Token.Kind := CBRACKETTOK;  // no, .)  replace with ]
             ReadChar(ch);
         end
         else if AssemblerMode then
         begin

         end;
         CheckTrace;
      end;   // case of .
      '(':        // ( , old (. for [ , or  (* comment
        begin
            ReadChar(Ch);
            if ch = '*' then
            begin                     // Handle (* comment
            // Note: we will "open" the comment. The end of
            // comment processor will close it
                Token.Kind:= COMMENTTOK;
                InComment := TRUE;  // we are inside an Open (*
                if CommentCTrace in TraceCompiler then
                    OpenComment;
                ReadChar(ch);
                if ch = '$' then
                    ReadDirective(True) // "True" warns that routine that
                                        // the comment is terminated by
                                        // *) instead of }
                else
                    ReadMultiLineComment(True);   // Same, ends with *) rather than }
                ReadChar(ch);
            end // symbol (*
            else if (Ch='.') then   // old style (.  was used for [
            begin
                Token.Kind := OBRACKETTOK;
                CheckTrace;
                ReadChar(ch);
            end
            else
            begin
                 Token.Kind := OPARTOK;  // Plain (
                 // and we've already read the next character
                 CheckTrace;
            end;
          end;   // case of (

    '/':       // possible // comment
     begin
         ReadChar(Ch);
         if ch = '/' then
         begin
         // Note: we will "open" the comment. The end of
         // comment processor will close it
             Token.Kind:= COMMENTTOK;        // Open //
             if CommentCTrace in TraceCompiler then
                 OpenComment;
             ReadSingleLineComment;          // Double-slash comment (like me!)
             ReadChar(Ch);                   // pick up char after comment
         end
         else
         begin
             Token.Kind := DIVTOK;
             CheckTrace;
         end;
      end;

          '{':     // brace comment  -   Multi-line comment or directive
        begin
        // Note: we will "open" the comment. The end of
        // comment processor will close it
            Token.Kind:= COMMENTTOK;
            InComment := TRUE;    // Open {
            if CommentCTrace in TraceCompiler then
                OpenComment;
            ReadUppercaseChar(ch);
            if ch = '$' then ReadDirective else ReadMultiLineComment;
            ReadChar(ch);         // pick up char after comment
        end  // case of {

    else                  // single-character tokens
    case ch of
      '=': Token.Kind := EQTOK;
      ',': Token.Kind := COMMATOK;
      ')': Token.Kind := CPARTOK;
      '^': Token.Kind := DEREFERENCETOK;
      '@': Token.Kind := ADDRESSTOK;
      '[': Token.Kind := OBRACKETTOK;
      ']': Token.Kind := CBRACKETTOK;
      '%': Fatal('Currency and large constants not yet supported');
      '`': Fatal('Tick quote "`" not allowed; only single quotes "''" may enclose quoted text');
      '"': Fatal('Double quote ''"'' not allowed; only single quotes "''" may enclose quoted text');
      '}': Fatal('Closing comment } character found without opening {');
    else     // don;t know what the character is
       If InComment then  // The only way we can "see" a character here while a comment is still "open" is if
                          // we reached end of file
          Catastrophic('Fatal Runaway comment (from '+IntToStr(Token.DeclaredLine)+
                       ':'+IntToStr(Token.DeclaredPos)+')');
       Token.Kind:=JUNKTOK;        // else pass thru to nexttok
       Token.Name:= Ch;

    end; // second case
    // Note: we are still inside the ELSE block of the first case.
    // only single character tokens land here after being processed.

     ReadChar(ch);
     CheckTrace;
    end; // case

  Tok := ScannerState.Token;
  end
end; // Procedure ReturnTok


Begin   // procedure NextTok
    Skipping := FALSE;
    Suppress := FALSE;
    with scannerstate do
    Repeat
        while (ch in Spaces) and not EndOfUnit do
        begin
            ReadChar(ch);
            // the assembler is line oriented; we
            // have to tell it when the line ends
            if (Ch = #10) and passthru then
            begin
                Token.Kind := ENDOFLINETOK;
                break;
            end;
        end;
        // "bypass" says to ignore this one token and continue with
        // the next one. Used mostly for comments.
        Bypass := False;    
        ReturnTok;    // the old NextTok
        // We do pass comments thru to the mini-assembler
        if (Token.Kind = COMMENTTOK) and not PassThru  then bypass := true
        else if (Token.Kind = CCSIFTOK)     or
           (Token.Kind = CCSIFDEFTOK)  or
           (Token.Kind = CCSIFNDEFTOK) or
           (Token.Kind = CCSELSEIFTOK) or
           (Token.Kind = CCSELSETOK)   or
           (Token.Kind = CCSENDIFTOK)  or
           (Token.Kind = CCSDEFINETOK) or
           (Token.Kind = CCSUNDEFTOK) then
           begin
               Skipping := SkipConditionally;
               bypass := true;
           end
        else if Token.Kind =JUNKTOK then
        begin
            If Skipping then
               if not Suppress then
               begin
                   Warning('Junk character "' +
                           Ch + '" ('+IntToStr(Ord(Ch))+') found in conditionally skipped code.');
                   Notice('  Further warnings will be suppressed until code processing resumes.');
                   Suppress :=TRUE ;
               end
               else
                   Fatal('Unexpected character "' +
                         Ch + '" ('+IntToStr(Ord(Ch))+') or end of file');
       end;

     Until (not Skipping) and not Bypass;
End;    // procedure NextTok

Procedure PeekTok;   // lookahead one token
var
    Temp: TToken;
    OldPos: Integer;
begin
// If you watch the following sleight of hand, you might wonder
// where is the next token? Well, if you look at ReturnTok,
// the last thing it does is copy Token to TOK. So *that* is
// where the next token is.
    With Scannerstate do
    begin
         Temp := Token;
         OldPos := Buffer.Pos;
         NextTok;
         Token := Temp;
    end
end;



Procedure GetAssemblerStatement;
var
    I:Byte;
begin
    AssemblerMode := True;
    For I:= MaxTokens Downto 1 do
        TokenBuffer[I].Kind := EMPTYTOK;
    with Scannerstate do
    repeat
        NextTok(TRUE);  // enable pass-thru mode
        TokenBuffer[I] := Token;
        inc(I);

    until (Token.Kind=ENDOFLINETOK) or (Token.Kind=ENDTOK) or
          (Token.Kind=COMMENTTOK) or EndOfUnit;
end;


procedure CheckTok(ExpectedTokKind: TTokenKind);
VAR
    EN:Integer;

begin
with ScannerState do
  if Token.Kind <> ExpectedTokKind then
    begin
        Case ExpectedTokKind of
           CPARTOK: EN := Err_4;
          COLONTOK: EN := Err_5;
             OFTOK: EN := Err_8;
           OPARTOK: EN := Err_9;
       OBRACKETTOK: EN := Err_11;
       CBRACKETTOK: EN := Err_12;
            ENDTOK: EN := Err_13;
      SEMICOLONTOK: EN := ERR_SemiColonExpected;
          MINUSTOK: EN := Err_16;
          BEGINTOK: EN := Err_17;
        BECOMESTOK: EN := Err_51;
           THENTOK: EN := Err_52;
          UNTILTOK: EN := Err_53;
             DOTOK: EN := Err_54;
             TOTOK,
         DOWNTOTOk: EN := Err_55;
             INTOK: EN := Err_60;
        else
            Errors[1] := GetTokSpelling(ExpectedTokKind);
            Errors[2] := GetTokSpelling(Token.Kind);
            Err(30); Unrecoverable;;
        end;
        Errors[1] := GetTokSpelling(Token.Kind);;
        if Token.Kind = JUNKTOK then
        begin
            Errors[1] := 'Bad Char "';
            If Token.Name[1] <' '    then
                Errors[1] := Errors[2]+ ' '
            else
                Errors[1] := Errors[1]+Token.Name;
            Errors[1] := Errors[1]+'" ('+
                      Radix(Ord(Token.Name[1]),10)+', $'+
                      Radix(Ord(Token.Name[1]),16)+')';
         end;
         Err(EN);  Unrecoverable;
     end;
end;


procedure EatTok(ExpectedTokKind: TTokenKind);
begin
CheckTok(ExpectedTokKind);
NextTok;
end;

// Used in place of EATTOK to use STD error messages
Procedure ErrorIfNot(ExpectedTokKind: TTokenKind; Const ErrorNumber:Integer);
begin
   with ScannerState do
  if Token.Kind <> ExpectedTokKind then
     Fatal(GetTokSpelling(ExpectedTokKind) + ' expected but ' + GetTokSpelling(Token.Kind) + ' found');

end;


// When there are two possible choices
procedure CheckEitherTok(ExpectedFirst, ExpectedOtherwise: TTokenKind);
begin
with ScannerState do
    if (Token.Kind <> ExpectedFirst) and (Token.Kind <> ExpectedOtherwise) then
         Fatal('Expecting either '+GetTokSpelling(ExpectedFirst) + ' or ' +
               GetTokSpelling(ExpectedOtherwise)+' but found ' +
               GetTokSpelling(Token.Kind) + ' inatead');
end;


// Where we have two different symbols to step over
procedure EatEitherTok(ExpectedFirst, ExpectedOtherwise: TTokenKind);
begin
     CheckEitherTok(ExpectedFirst, ExpectedOtherwise);
NextTok;
end;





procedure AssertIdent;
var S: String[10];

begin
    S :='';
    If (FlagCtrace in TraceCompiler) and (ErrorFlag>0 ) then S:='['+Radix(ErrorFlag,10)+'] ';
    with ScannerState do
        if Token.Kind <> IDENTTOK then
            Fatal(S+'Identifier expected but ' + GetTokSpelling(Token.Kind) + ' found');
end;



end.
