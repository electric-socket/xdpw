// XD Pascal for Windows (XPDW) - a 32-bit compiler
// Copyright 2020 Paul Robnson

// Latest upgrade by Paul Robinson: New Years Eve; Thursday, December 31, 2020

// VERSION 0.15 {.0}

// Will be used to implement conditional compilation
// {$3E  {$ELSE   {$ELSEIF  {$ENDIF   {$IF   {$IFDEF,  {$UNDEF
// Ths is a stub for now

unit Conditional;

{
 The Rules:
 1. A conditional compilation statement ("CCS") must be closed
    by the equivalent symbol that opened it., e.g. close brace
    if opened with brace, star paren if opened by paren star,
    Obviously,
    failure to do this will either cause a text overflow and
    fail thecompile, or a "runaway comment" and, guess what?
    It will cause the compole to fail.
 2. The CCS must close within 255 characters ofwhen it opened,
    or the compile will fail
 3. CCS commands (like $IF or $ELSE) are not case sensitive. A CCS
    can only be invoked by a paren star or brace comment, line
    comments (//) cannot issue a CCS. A CCS can be started
    with a brace or paren star but the following $END does not have
    to use the same comment format.
 4. An $IF, $ELSE,or  $ELSEIF must be eventually followed by an
    $ENDIF before the end of the file it was within, or the
    compile will fail. CCS blocks cannot cross file or unit
    boundaries.
 5. A CCS may be enclosed in an include file. If a CCS is in a unit,
    It may include a file.
 6. Either there will be a limit of one include file, or if more than
    one is allowed, to prevent "crock recursion" (an included file
    directly or indirectly including itself) no file currently open
    can be included, Violation of these rules will fail the compile.
 7. $ELSE or $ELSEIF must follow a $IF, $IFDEF or $IFNDEF. Violation
    of this rule will, of course, fail the compiler.
}

interface
uses  Common, SysUtils, Error;



Const
    CMax = 100;

TYPE

    CSkip = (Undefined,  // No definition
             CContinue,  // SCAN; continue scanning until $ELSE, $ELSEIF or $ENDIF
             CElse,      // SKIP; The IF or ELSEIF failed, skip until $ELSE, $ELSEIF or $ENDIF
             CEndOnly,   // SCAN; in the $ELSE part of $IF statement,
                         // continue scanning but only accept $ENDIF
                         // another $ELSE or $ELSEIF Fatal
             CEndIf);    // SKIP; we are in $ELSEIF continue scanning until $ENDIF
                         // ignore $ELSE or $ELSEIF



     CS = record
              Skip: CSkip;
              Line,
              Pos: Integer; // Where they started
         end;

     DefIneP = ^Define;
     Define = record
         Next: DefineP;
         inUse: Boolean;    // to prevent crock recursion
         Name: String;
         Case isNumber:Boolean of
            False:(Value: String);    // if a macro,the replacement text
            True: (Number: Integer);  // or numeric value
     end;

     StringRec = record
         Len,
         Pos: Integer;
         S: String;
     end;

VAR
     CTable: Array[1..CMax] of  CS; // If you need more than 100 nested IF/ELSE
                                      // conditional blocks, you probably need a
                                      // a full-service compiler
     CIndex: Integer = 0;             // Where we are in CCSTable: UP on IF,

     Function SkipConditionally: boolean;
     Function isDefined(X:String):boolean;
     function isDeclared(ID:String):Boolean;
     Procedure DumpDefineList;
     Procedure DefineCond(Define, Macro:String; isNumber: Boolean; Amount:Integer );
     Function isMacro(Define: string; Var Macro:String):boolean;
     function GetDefineValue(Define:String; Var Macro:String;
                             var isNumeric:Boolean;
                             var Amount:Integer):Boolean;


  implementation

VAR

     // down on ENDIF
     DefineBase: DefineP; //= NIL;       // list of define items
     LastElseLine,                    // Prior $ELSE
     LastElsePos,
     WL,                              // Current Length of workstring
     ScanPoint,                       // Current char scanned in workstring
     TempInt,                         // for unneeded value
     WorkValue:Integer;
     WorkBool: Boolean;
     WDefine,
     WValue,
     TempString,                      // for unneded strings
     WorkString: String;

   // If a macro is defined, all identifiers have to be searched to see if they
   // match, for substitution purposes. This may slow things down, so, if no
   // macro defines are used or the last one is deleted, Macrodefined is false
     MacroDefined: Boolean = FALSE;

   // Once created, these are the initial definitions:
   // XDP               Defined for $IFDEF/$IFNDEF test
   // XDP_FULLVERSION	An integer version number of the compiler.
   // XDP_VERSION       The version number of the compiler.
   // XDP_RELEASE       The release number of the compiler.
   // XDP_PATCH         The patch level of the compiler`
   //
   // since the XDP_ identifiers are pure integers,
   // they do not count as macros

 // New order of procedures and functions:
 //
 // 1. P/F that provide services to a p/f
 // 2. Processors of the $ options
 //     $DEFINE
 //     $ELSE
 //     $ELSEIF
 //     $IF
 //     $IFDEF
 //     $IFNDEF
 //     $UNDEF
 // 3. Handler SkipConditionally


 // 1. Routines that provide services


 // Usage:
 // Dump define symbol table
 // A. Called by $DUMP DEFINE from Scanner
  Procedure DumpDefineList;
  Var
     P: DefineP;

  begin
     Writeln('Define List:');
     If DefineBase = NIL then
        Writeln(' ':4,'EMPTY')
     else
     begin
        P := DefineBase;
        While P<> Nil do
        begin
             Write(' ':4,'Name="',P^.Name,'" ');
             if P^.isNumber then
                Writeln('Value ',P^.Number)
             else
                Writeln('Value="',P^.Value,'"');
             P := P^.Next;
        end;
     end;
     Writeln;
  end;

  // At the start of a test or macro substitution,
  // clear the "inUse" flag on each defined item

  Procedure ClearInUseFlag;
    Var
     P: DefineP;

  begin
      P := DefineBase;
      While P<> Nil do
      begin
           P^.inUse := False;
           P := P^.Next;
      end;
  end;


   // DefineBase always points to the First entry (or to NIL)

   // USAGE:
   // A. Called by parser when program is first initialized to
   //    define compiler symbols
   // B. Called when comment issues $DEFINE
Procedure DefineCond(Define, Macro:String; isNumber: Boolean; Amount:Integer );
Var
    AddItem,
    NextItem: DefineP;
    Sum,
    I:Integer;
    isNumeric:Boolean;
    M:String;

begin
    M := Trim(Macro);
    Sum := 0;
    // test if the value is numeric or string
    if not isNumber then { We don't have to check if it already is a number}
    begin
    For I := 1 to Length(M) do
       If M[I] in Digits then
       begin
           isNumeric := TRUE;
           Sum := Sum*10+(ord(M[I])-DigitZero)
       end
       else
       begin
           isNumeric := FALSE;
           break;
       end;
    end
else
    begin // use the number they supplied
        isNumeric := True;
        Sum := Amount;
    end;
    If DefineBase = NIL then
    begin
        New(DefineBase);
        NextItem := Definebase;
    end
    else
    begin
        NextItem := Definebase;
        While NextItem^.Next <> NIL do
           NextItem := NextItem^.Next;      // find last item
        New(NextItem^.Next);                // Add one more
        NextItem := NextItem^.Next;         // move to new item
    end;
    NextItem^.Next := NIL;              // no more
    NextItem^.Name := Define;
    NextItem^.inUse:= FALSE;
    NextItem^.isNumber :=isNumeric;
    IF isNumeric then
        NextItem^.Number:= Sum
    else
    begin
        NextItem^.Value := M;
        If (Macro<> '') then
            MacroDefined  := true;
    end;
end;

// is the conditionally defined
// symbol a macro?
// if no value or not found, return false
// otherwise return true
// macro set to null if not found or no value

// Usage:
// A. Not yet used, will be when Macro substitution
//    becomes available.
Function isMacro(Define: string; Var Macro:String):boolean;
Var
    NextItem: DefineP;
begin
    NextItem := DefineBase;
    Macro :='';
    If NextItem <> nil then    // no items are defined
    repeat
        If NextItem^.Name=Define then
        begin
           Macro := NextItem^.Value;
           If not (NextItem^.isNumber or (Macro = '')) then
           begin
               Result := True;
               MacroDefined := True; // at least one macro is defined
               exit;
           end
           else
               break;
        end;
        NextItem := NextItem^.Next;
    until NextItem = NIL;
    MacroDefined := false; // "Yes, we have no macros"
    Result := False;
end;

// Usage:
// A. used by $UNDEF to reset the state after a definition
//    is deleted in case all macros are deleted
Procedure CheckForMacros;
Var
    NextItem: DefineP;
begin
    NextItem := DefineBase;
    MacroDefined := True;
    while Nextitem<>NIL do
    begin
       If not (NextItem^.isNumber or (Nextitem^.value= '')  ) then
           exit
       else
           NextItem := NextItem^.Next;
    end;
    MacroDefined := False; // "Yes, we have no macros"
end;


// USAGE:
//       Called by any routine that wants to check
//       to see if we are in skip mode or are scanning
Function Active: Boolean; // are we active?
begin
    Result := (CIndex =0) or                 // Open Code
              (CTable[CIndex].Skip=CContinue) or // In an $IF or $ELSEIF that succeeded
              (CTable[CIndex].Skip=CEndOnly);    // in an $ELSE where $IF fails
end;

// Get the Define key and define value passed to us in TOK
// from Conditional processor in unit Scanner.
// Note: this extracts the value to store in the define list,
// this does not retrieve the value from the list
// USAGE:
//       $DEFINE, $ELSEIF, $IF, $IFDEF, $IFNDEF, $UNDEF.
Procedure RetrieveDef(Var Define, Value:String);
Begin
    Define := trim(tok.Name);
    if  Define <>'' then
    begin
        WorkString  := Trim(tok.NonUppercaseName);
        WL := Length(WorkString);
        If WL<3 then exit; // no value
        if (WorkString[1]<>':') AND (WorkString[2]<>'=') then
            exit; // again, no value
        Value := Trim(Copy(WorkString,3,WL));
        exit;
    end;
    Err(Err_802); // Null $DEFINE (Warning)
end;


Function GetSkipName(S:  CSkip):String;
begin
   case S of
       Undefined: Result := 'Undefined';
       CContinue: Result := 'Continue';
           CElse: Result := 'Else';
        CEndOnly: Result := 'End Only';
          CEndIf: Result := 'End If';
   end;
end;



// is this in defines list? if so, retrieve value
// USAGE:
//      Not used yet; will be used on Macro expansion
//      or on $IF/$ELSEIF test when implemented
function GetDefineValue(Define:String; Var Macro:String;
                        var isNumeric:Boolean;
                        var Amount:Integer):Boolean;
Var
    NextItem: DefineP;

begin
    Result := False;
    NextItem := DefineBase;
    While NextItem<>nil do
    begin
        if NextItem^.Name=Define then
        begin
            isNumeric := NextItem^.isNumber;
            if isNumeric then
                Amount := NextItem^.Number
            else
                Macro := NextItem^.Value;
            Result := True;
            exit;
        end;
        NextItem := NextItem^.Next;
    end;
end;


// "Cheap version" of GetIdentUnsafe but since
// we can't access the parser from here I need
// a simple alternative to query the symbol table
// and return YES/NO on whether a particular
// identifier is defined to the program
// USAGE:
//        by $IF DECLARED(ident)
function isDeclared(ID:String):Boolean;
VAR
    I: Integer;

begin
    Result := true;
    For I := NumIdent downto 1 do
        If Ident[I].Name = ID then exit;
    Result := False;
end;



Function isDefined(X:String):boolean;
VAR
    NextItem: DefineP;

begin
    Result := False;
    NextItem := DefineBase;
    While NextItem  <> NIL do
        If NextItem^.Name = X then
        begin
            Result := TRUE;
            exit;
        end
        else
            NextItem := NextItem^.Next;
End;

          Function ParseValue:boolean;  // Analysis of argument
          Type
              LSymbol = (EQ,GE,GT,LE,LT,NE);
          Var
              Sum: Integer;
              isNumeric :boolean;
              TempString: String;
              SY: LSymbol;



          // at Workstring[ScanPoint] extract identifier
          Function ExtractIdent :String;
          begin
             Result := UpCase(WorkString[ScanPoint]);
             Inc(ScanPoint);
             For ScanPoint := ScanPoint to WL do
                if WorkString[ScanPoint] in AlphaNums then
                   Result := Result + UpCase(WorkString[ScanPoint])
                 else
                    break;
          end; // extracident

          Procedure SkipSpaces;
          Begin
              While WorkString[Scanpoint] in spaces do
                  Inc(ScanPoint);
          end;   // passoaces


          Procedure TestDefined2;
          Begin

              Inc(ScanPoint);
              WDefine := ExtractIdent ;

              if isDefined(WDefine) then
                 Tok.OrdValue:=1
              else
                 Tok.OrdValue:=0;
              Tok.Kind := BOOLEANTOK ;
              Inc(ScanPoint);
          end;    // testdefine

          Procedure TestDefined;
          begin // Next item should be DEFINED(Sym)
              SkipSpaces;
              IF (ScanPoint > WL-10) then  // not enough room for DEFINED( plus 1 char and )
              begin
                  Err( ERR_CondDirective); // Conditional not understood
                  tok.Kind := ERRSTMTTOK;
                  Exit;
              end;
              WDefine := ExtractIdent;
              if (WDefine<>'DEFINED') or (Workstring[ScanPoint]<>'(') then
              begin
                  Err( ERR_CondDirective); // Conditional not understood
                  tok.Kind := ERRSTMTTOK;
                  Exit;
              END;
              TestDefined2;
          end;  // testdefined


          // This procedure is becoming too large
          // and needs to be further split into
          // smaller procs to do this
          Procedure ParseArg;
          begin

// working on this
           end;
          begin

          end;

Procedure _Define;
Begin
    if not active then exit;    // we're skipping this code (1.10,1.11)
    RetrieveDef(WDefine,WValue);
    DefineCond(WDefine,WValue,FALSE,0);
end;  //$DEFINE


Procedure _Else;      //            $ELSE
Begin
    if CIndex = 0 then     {3.10}
    begin
       Err1(Err_803,'$ELSE');  // $ELSE in open code (Warning)
       exit;
    end;
    if CTable[CIndex].Skip=CEndOnly then   {3.20}
    begin
       Err4(Err_804,'$ELSE','$ELSE',Radix(LastElseLine,10),Radix(LastElsePos,10));  // $ELSE after $ELSE (Warning)
       exit;
    end;
    if CTable[CIndex].Skip=CContinue then   // In an $IF that succeeded
       CTable[CIndex].Skip := CEndIf // Skip to $ENDIF
    else if CTable[CIndex].Skip=CEndIf then // ignore
       exit       // we're at an $else inside a skipped if
    else if CTable[CIndex].Skip=CElse then  // in an $IF/$ELSEIF that failed
    begin
       CTable[CIndex].Skip := CEndOnly;      // scan until $ENDIF
       // in case they forget $ENDIF, where we were
       CTable[CIndex].Line:= Tok.DeclaredLine;
       CTable[CIndex].Pos:= Tok.DeclaredPos;
    end;

    LastElseLine := Tok.DeclaredLine; // record our location in case of error
    LastElsePos  := Tok.DeclaredPos;
end; // $ELSE


Procedure _ElseIf;
Begin
    if CIndex = 0 then     {3.10}
    begin
        Err1(Err_803, '$ELSEIF'); // in open code   (warning)
        Exit;
    end;
    ClearInUseFlag;
    // Right now this is not implemented, so say so
    Err(Err_72); exit;     // "Feature not implemented

    if CTable[CIndex].Skip=CEndOnly then    {3.20}
    begin
        Err4(Err_804,'$ELSEIF','$ELSE',Radix(Tok.DeclaredLine,10),Radix(tok.DeclaredPos,10));
        Exit;
    end;
    if CTable[CIndex].Skip=CContinue then
    // This is an $ELSEIF after the IF was successful
    // so skip to endif
        CTable[CIndex].Skip:=CEndIf
    else if CTable[CIndex].Skip=CElse then  // $ELSEIF after IF failed
    begin
        if ParseValue then
           CTable[CIndex].Skip:=CContinue    // scan
        else
           CTable[CIndex].Skip:=CElse;  // Skip until next $ELSE or $ELSEIF or $ENDIF
    end;
end; // $ELSEIF


Procedure _EndIf;
Begin
    if CIndex = 0 then     {5.19}
    begin
        Err1(Err_803,'$ENDIF'); // $ENDIF in open code (warning)
        Exit;
    end;
    Dec(CIndex);   // pop the if stack; caller will process
end; // $ENDIF


Procedure _If;        // Check when $IF occurs
Begin
   iF CIndex = CMax then
      Begin
          Err1(Err_805,'$IF'); // Too many $IF statements (Warning)
          Exit;
   end;
   ClearInUseFlag;
   // Right now this is not implemented, so say so
   Err(Err_72); exit;     // "Feature not implemented
   If not Active then // we don't process the if
   begin              // We just increment the IF counter
      Inc(CIndex);
      // ignore everything except another $IF
      // until  $ENDIF
      CTable[CIndex].skip := CEndIf;
      CTable[CIndex].Line := Tok.DeclaredLine;
      CTable[CIndex].Pos  := Tok.DeclaredPos;
   end
   else
   begin //  process the $IF
      Inc(CIndex);
      if parsevalue then
          CTable[CIndex].skip := CContinue  // keep scanning
      else
          CTable[CIndex].skip := CElse;     // skip to $ELSE/$ELSEIF/$ENDIF
      CTable[CIndex].Line := Tok.DeclaredLine;
      CTable[CIndex].Pos  := Tok.DeclaredPos;
   end;
end;


Procedure _IfDef;     //            $IFDEF
VAR
   Define,
   Dummy: TString;

Begin
    if CIndex = CMax then
    begin
        Err1(Err_805,'$IFDEF'); // Too many $IFDEF statements (Warning)
        Exit;
    end;
    If not Active then
    begin    // we don't process but skip to $ENDIF
        Inc(CIndex);
      // ignore everything except another $IF/$IFDEF/$IFNDEF until  $ENDIF
        CTable[CIndex].skip := CEndIf;
    end
    else
    begin   //  process the $IFDEF
       Inc(CIndex);
       RetrieveDef(WDefine,TempString);
       if isDefined(WDefine) then        // keep scanning
           CTable[CIndex].skip := CContinue
       else                           // skip until $ELSE/$ELSEIF/$ENDIF
           CTable[CIndex].skip := CElse;
   end;
   CTable[CIndex].Line := Tok.DeclaredLine;
   CTable[CIndex].Pos  := Tok.DeclaredPos;
end;    //$IFDEF


Procedure _IfNdef;
Begin
    if CIndex = CMax then
    begin
        Err1(Err_805,'$IFNDEF'); // Too many $IFNDEF statements (Warning)
        Exit;
    end;
    If not Active then
    begin    // we don't process but skip to $ENDIF
        Inc(CIndex);
            // ignore everything except another $IF/$IFDEF/$IFNDEF until  $ENDIF
        CTable[CIndex].skip := CEndIf;
    end
    else
    begin   //  process the $IFNDEF
        Inc(CIndex);
        RetrieveDef(WDefine,TempString);
        if not isDefined(WDefine) then
            CTable[CIndex].skip := CContinue   // keep scanning
        else
            CTable[CIndex].skip := CElse;      // skip until $ELSE/$ELSEIF/$ENDIF
    end;
    CTable[CIndex].Line := Tok.DeclaredLine;
    CTable[CIndex].Pos  := Tok.DeclaredPos;
end; // $IFNDEF


Procedure _Undef;
VAR
   PrevItem,
   NextItem: DefineP;

Begin
    // if skipping or no defines, quit
    If not (Active and (DefineBase<>NIL)) then exit; // (1.10,1.11)
    // definition removal may proceed
    RetrieveDef(WDefine,WValue); // don't care about value

    if WDefine = '' then exit;          // nothing to undefine
    NextItem := DefineBase^.Next;
    If DefineBase^.Name = WDefine then  // item to be deleted at base of list
    begin
        Dispose(DefineBase);
        DefineBase := NextItem;  // new base item or nil
        Exit;
    end;
    PrevItem := NIL;
    While NextItem<> NIL do     // follow the chain, link by link
    begin
        if NextItem^.Name = WDefine then
        begin
            If PrevItem<>NIL then               //Hook the next link
                PrevItem^.Next := NextItem^.Next;   // to previous
            Dispose(NextItem);                  // discard this one
            CheckForMacros;                         // if last macro deleted, turn flag off
            exit;
         end;
         PrevItem := NextItem;                 // hold prior link
         NextItem := NextItem^.Next;           // go for next link
     end;
 end;  // $UNDEF



Function SkipConditionally: boolean;
       {
        This is sort of a state machine.

         At this point, procedure HandleConditional
         passes us two pieces of information
         CCSMode - Which conditional statement it was
         Argument - The remainder of the comment excluding the end of commenr mark

         Our job is to make a GO/NOGO decision: either
            ignore the comment: continue scanning source
            skip over source: until a new directive is found

         Rules - Check each for compliance  ☐ 🗹    X
               $DEFINE,  $UNDEF:
      X  1.10       if index is 0 (open code) or
      X  1.11          CCSTable[ index ].skip  = continue, endonly
      X  1.12            Create, Delete, or ignore the definition

                $IF, $IFDEF, $IFNDEF:
         2.10 O O O    if (skip is continue, eendonly) or  open code  .
                 // currently not skipping
         2.11 O O O   inc ccpIndex
         2.20 O O O   If the condition succeeds  .
         2.21 O O O       set skip to continue    .
         2.22 O O O       stop skipping     .
                      else
         2.30 O O O       set skip to skipelse ,
         2.31 O O O      keep skipping
                      endif
                  else   // currently skipping
         2.40 O O O     inc ccpIndex
         2.41 O O O     set skip to skipendif
         2.42 O O O     keep skipping
                  endif

                  $ELSE, $ELSEIF
                     if open code
      X  3.10            TRAP out for conditional directive when conditional was not in effect
                    if skip is endonly
      X  3 20            trap for else after prior else
                    if skip is endif
         3.30 O O         if this is $ELSE
         3.31 O O             set skip to endonly
         3.32 O O           SKIP
                     else
                        if skip is skipelse
                           if this is $ELSE
         3.40 O O             set skip to endonly
         3.41 O O             SCAN
                           else  (this is $ELSEIF)
         3.50 O O             set skip to skipelseif
         3.51 O O             CALL $IF  (Let it decide if succeeds)
                           endif
                   endif
                   $ENDIF
                        if open code
      X   5.10             TRAP out for conditional directive when conditional was not in effectt
          5.20 O        decrease index
                        if index = 0
          5.30 O            SCAN

                        else
                          if skip is continue
          5.40 O            stop skipping
                          else
          5.50 O             keep skipping

                     ELSE
                         If not skipping
          6.10 O           set skip mode to ENDIFonly
          5.11 O           keep skipping


            So what we will do is interpret the directive and
            make a decision; result is returned with
            one of two states:
             Do nothing:
                DEFINE,  UNDEF, ENDIF - Nothing neds to be done
                IF and statement was successful
                ELSEIF and this condition succeded
                ELSE and prior condition failed
             Skip all text until next Conditional:
                IF where condition failed
                ELSE where prior condition succeeded
                ELSEIF where prior condition succeeded
                ELSEIF where this condition fails
         }

         { Conditional compilation:
       1.   Value: ['NOT'] Defined variable | integer
            Operator: < <= = > >= AND OR
            value
            If the defined variable does not exist it is treated as a null string
            if it starts with digits it is considered a number

       2. "defined(variable)" AND| OR [NOT] "defined(variable)"
          if any argument is a string, it is a string comparison
          if all arguments are numbers, it is a numeric comparison

          Thus 11 < 101 but I11 > I101

         }

     Begin // SkipConditionally
{      // testbed used to debug conditional code processing
        Write('$$ Cond, N="',tok.Name,'" nu="',tok.NonUppercaseName,'"');
        writeln(' Tok="',GetTokSpelling(Tok.Kind),'"');
        Write('$$ initial state ');
        if Active then write('active ') else write ('NOT active ');
        if CIndex =0 then write('Open code ')
         else Write('Cindex=',cindex, ' Skip=',GetSkipName(CTable[CIndex].Skip));
        writeln(' at ',tok.DeclaredLine,':',tok.DeclaredPos);
}
        Case Tok.Kind of
            CCSDEFINETOK : _Define;
            CCSELSETOK   : _Else;
            CCSELSEIFTOK : _ElseIf;
            CCSENDIFTOK  : _EndIf;
            CCSIFTOK     : _If;
            CCSIFDEFTOK  : _IfDef;
            CCSIFNDEFTOK : _IfNdef;
            CCSUNDEFTOK  : _Undef;
        end;
        if Active then
             Result := FALSE                // Continue scanning
        else
        begin
            if (CTable[CIndex].Skip= CElse) or
               (CTable[CIndex].Skip= CEndIf) then
                Result := TRUE              // Skip until state changes;
            else
             Catastrophic('Internal error: Unexpected conditional state at '+  {Fatal}
                          Radix(Tok.DeclaredLine,10)+':'+Radix(Tok.DeclaredPos,10)+
                          '. This is a compiler error and should be reported.');

        end;

     end; // skipconditionally

end.

