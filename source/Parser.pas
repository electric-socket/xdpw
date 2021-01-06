// XD Pascal for Windows (XPDW) - a 32-bit compiler
// Copyright (c) 2009-2010, 2019-2020, Vasiliy Tereshkov
// Copyright 2020 Paul Robnson

// Latest upgrade by Paul Robinson: New Years Eve; Thursday, December 31, 2020

// VERSION 0.15 {.0}

// The scanner reads the source code, translating it into
// tokens for us to consume. We parse the tokens that the
// source code was translated into to determine how to
// construct the program and its functions.

{$I-}
{$H-}

unit Parser;


interface


uses SysUtils, Common, Error,  Conditional, Assembler, Patch,
     Scanner, CodeGen, CompilerTrace, Linker;


function CompileProgramOrUnit(const Name: TString): Integer;


implementation




// TPARSERSTATE mved to common

procedure CompileConstExpression(var ConstVal: TConst; var ConstValType: Integer); forward;
function CompileDesignator(var ValType: Integer; AllowConst: Boolean = TRUE): Boolean; forward;
procedure CompileExpression(var ValType: Integer); forward;
procedure CompileStatement(LoopNesting: Integer); forward;
procedure CompileType(var DataType: Integer); forward;
procedure DefineStaticSet(const SetValue: TByteSet; var Addr: LongInt; FixedAddr: LongInt = -1); forward;
function GetIdentUnsafe(const IdentName: TString; AllowForwardReference: Boolean = FALSE; RecType: Integer = 0): Integer;  forward;
function FieldOrMethodInsideWithFound(const Name: TString): Boolean; forward;
function GetCompatibleRefType(LeftType, RightType: Integer): Integer;  forward;
function GetMethod(RecType: Integer; const MethodName: TString): Integer; forward;
procedure DeclareIdent(const IdentName: TString;
                             IdentKind: TIdentKind;
                             TotalParamDataSize: Integer;
                             IdentIsInCStack: Boolean;
                             IdentDataType: Integer;
                             IdentPassMethod: TPassMethod;
                             IdentOrdConstValue: LongInt;
                             IdentRealConstValue: Double;
                       const IdentStrConstValue: TString;
                       const IdentSetConstValue: TByteSet;
                             IdentPredefProc: TPredefProc;
                       const IdentReceiverName: TString;
                             IdentReceiverType: Integer;
                       const SourceLineNumber,           // position on line where declared
                             SourcePos:Integer);     // line in file where declared
var
  i, AdditionalStackItems, IdentTypeSize: Integer;
  IdentScope: TScope;

  
begin  // Declare identifier

    If  (ActivityCTrace in TraceCompiler) then EmitHint('P DeclareIdent');

     if BlockStack[BlockStackTop].Index = 1 then IdentScope := GLOBAL else IdentScope := LOCAL;
     i := GetIdentUnsafe(IdentName, FALSE, IdentReceiverType);

// You can't declare two identifiers of the same name at the unit leval or in the
// same block level (Procedure/Function)

if (i > 0) and (Ident[i].UnitIndex = ParserState.UnitStatus.Index) and
   (Ident[i].Block = BlockStack[BlockStackTop].Index) then
      // allow a duplicate identifier, with error
    Err3(Err_101,IdentName,Radix(Ident[i].DeclaredLine,10),Radix(Ident[i].DeclaredPos,10));;


Inc(NumIdent);   // current top of table

Inc(Totalident);      // identifiers used in program
Inc(UnitTotalIdent);  // identifiers used in this unit
if islocal then
    inc(UnitLocalIdent)       // identifier in a proc or func
else
    inc(UnitGlobalIdent);     // identifier at unit level

if numident > MaxIdentCount then
   MaxIdentCount := numident ;
if NumIdent > MAXIDENTS then
     Catastrophic('Maximum number of identifiers exceeded'); {Fatal}

with Ident[NumIdent] do
  begin
  Kind                := IdentKind;
  Name                := IdentName;
  Address             := 0;  
  Scope               := IdentScope;
  RelocType           := UNINITDATARELOC;
  DataType            := IdentDataType;
  UnitIndex           := ParserState.UnitStatus.Index;
  Block               := BlockStack[BlockStackTop].Index;
  NestingLevel        := BlockStackTop;
  ReceiverName        := IdentReceiverName;
  ReceiverType        := IdentReceiverType;
  Signature.NumParams := 0;
  Signature.CallConv  := DEFAULTCONV;
  PassMethod          := IdentPassMethod;
  isAbsolute          := FALSE;

  IsUsed              := FALSE;
  IsUnresolvedForward := FALSE;
  if SysDef and (SourceLineNumber >0) then  // system defined
     DeclaredPos      := XDP_SystemDeclared
  else
     DeclaredPos      := SourcePOS;       // location in file where
  DeclaredLine	      := SourceLineNumber;     // identifier was declared
  IsExported          := ParserState.IsInterfaceSection and (IdentScope = GLOBAL);
  IsTypedConst        := FALSE;
  IsInCStack          := IdentIsInCStack;

  ForLoopNesting      := 0;

  if (TokenCTrace in TraceCompiler) or
     (IdentCTrace in TraceCompiler)   then
      BEGIN
          EMITInt := Ident[NumIdent].DeclaredLine;
          if EMITInt <1 then
             EMITString :=' CmpGen'
          else
             EMITString :=' LN='+ Radix( EmitInt,10);
          EmitHint( GetScopeSpelling(IdentScope)+' ident '+ IdentName+EmitString, FALSE,TRUE,FALSE ); // start, more coming
      END;

  end;

case IdentKind of
  PROC, FUNC:
    begin
        if IdentKind=FUNC then
         begin
                inc(ScannerState.FuncCount);
                inc(TotalFuncCount);
            end
        else
            begin
                inc(ScannerState.ProcCount);
                inc(TotalProcCount);
            end;



    Ident[NumIdent].Signature.ResultType := IdentDataType;
    if IdentPredefProc = EMPTYPROC then
      begin
      Ident[NumIdent].Address := GetCodeSize;                            // Routine entry point address
      Ident[NumIdent].PredefProc := EMPTYPROC;
      end
    else
      begin
      Ident[NumIdent].Address := 0;
      Ident[NumIdent].PredefProc := IdentPredefProc;                     // Predefined routine index
      end;
    end;  

  VARIABLE:
    case IdentScope of
     GLOBAL:
       begin
       IdentTypeSize := TypeSize(IdentDataType);
       if IdentTypeSize > MAXUNINITIALIZEDDATASIZE -
           UninitializedGlobalDataSize then
          Catastrophic('Not enough memory for global variable'); {Fatal}

       Ident[NumIdent].Address := UninitializedGlobalDataSize;                                 // Variable address (relocatable)
       UninitializedGlobalDataSize := UninitializedGlobalDataSize + IdentTypeSize;
       end;// else

     LOCAL:
       if TotalParamDataSize > 0 then               // Declare parameter (always 4 bytes, except structures in the C stack and doubles)
         begin          
         if Ident[NumIdent].NestingLevel = 2 then                                            // Inside a non-nested routine
           AdditionalStackItems := 1                                                         // Return address
         else                                                                                // Inside a nested routine
           AdditionalStackItems := 2;                                                        // Return address, static link (hidden parameter)  

         with BlockStack[BlockStackTop] do
           begin
           if (IdentIsInCStack or (Types[IdentDataType].Kind = REALTYPE)) and
               (IdentPassMethod = VALPASSING) then
             IdentTypeSize := Align(TypeSize(IdentDataType), SizeOf(LongInt))
           else
             IdentTypeSize := SizeOf(LongInt);
  
           if IdentTypeSize > MAXSTACKSIZE - ParamDataSize then
                 Catastrophic('Not enough memory for parameter'); {Fatal}

           Ident[NumIdent].Address := AdditionalStackItems * SizeOf(LongInt) + TotalParamDataSize - ParamDataSize - (IdentTypeSize - SizeOf(LongInt));  // Parameter offset from EBP (>0)
           ParamDataSize := ParamDataSize + IdentTypeSize;
           end
         end
   else
   with BlockStack[BlockStackTop] do          // Declare local variable
       begin
           IdentTypeSize := TypeSize(IdentDataType);
           if IdentTypeSize > MAXSTACKSIZE - LocalDataSize then
                Catastrophic('Fatal error: Not enough memory for local variable');

           Ident[NumIdent].Address := -LocalDataSize - IdentTypeSize;                          // Local variable offset from EBP (<0)
           LocalDataSize := LocalDataSize + IdentTypeSize;
       end; // with
    end; // case


  CONSTANT:
    if IdentPassMethod = EMPTYPASSING then                              // Untyped constant
      case Types[IdentDataType].Kind of
        SETTYPE:    begin
                    Ident[NumIdent].ConstVal.SetValue := IdentSetConstValue;
                    DefineStaticSet(Ident[NumIdent].ConstVal.SetValue, Ident[NumIdent].Address);                      
                    end;
                    
        ARRAYTYPE:  begin     // I guess the only constant array is a string
                    Ident[NumIdent].ConstVal.StrValue := IdentStrConstValue;
                    DefineStaticString(Ident[NumIdent].ConstVal.StrValue, Ident[NumIdent].Address);
                    end;
                    
        REALTYPE:   Ident[NumIdent].ConstVal.RealValue := IdentRealConstValue;       // Real constant value        
        else        Ident[NumIdent].ConstVal.OrdValue := IdentOrdConstValue;         // Ordinal constant value
      end    
    else                                                                // Typed constant (actually an initialized global variable)    
      begin
      with Ident[NumIdent] do
        begin
        Kind         := VARIABLE;
        Scope        := GLOBAL;
        RelocType    := INITDATARELOC;
        PassMethod   := EMPTYPASSING;
        IsTypedConst := TRUE; 
        end;
      
      IdentTypeSize := TypeSize(IdentDataType);
      if IdentTypeSize > MAXINITIALIZEDDATASIZE - InitializedGlobalDataSize then
             Catastrophic('Fatal Error: Not enough memory for initialized global variable');

      Ident[NumIdent].Address := InitializedGlobalDataSize;               // Typed constant address (relocatable)
      InitializedGlobalDataSize := InitializedGlobalDataSize + IdentTypeSize;      
      end;
      
  GOTOLABEL:
       Ident[NumIdent].IsUnresolvedForward := TRUE;


end;// case

if (TokenCTrace in TraceCompiler) or
   (IdentCTrace in TraceCompiler)   then
  begin
    EmitHint(' @'+ Radix(Ident[NumIdent].address,10),FALSE,FALSE,FALSE); // intermediate
    EmitHint(' block:'+ Radix(Ident[NumIdent].block,10),FALSE,FALSE,FALSE); // intermediate
    EmitHint(' nest:'+ Radix(Ident[NumIdent].nestinglevel,10),FALSE,FALSE,FALSE); // intermediate

    if Types[IdentDataType].Kind = ARRAYTYPE then
      begin
         if (Types[Types[IdentDataType].BaseType].kind=CHARTYPE) then
           // don't print anything, "string" will show last
         else
             EmitHint(' array of '+
             GetTypeSpelling(Types[IdentDataType].BaseType),FALSE,FALSE,FALSE );  // intermediate
      end;
    if Ident[NumIdent].IsUnresolvedForward  then
       EmitHint(' fwd',FALSE,FALSE,FALSE); // intermediate
    EmitHint(' '+ GetTypeSpelling(Ident[NumIdent].DataType),FALSE,FALSE,TRUE); // final
  end;
end; // DeclareIdent

// check for token which is erroneous
Function ItIs(ErrorTok: TTokenKind):Boolean;
begin
  If  (ActivityCTrace in TraceCompiler) then  EmitHint('f Itis');
  Result := Tok.Kind = ErrorTok;
end;

// Procedure to initialize a new unit
Procedure NewUnit;
begin
  If  (ActivityCTrace in TraceCompiler) then EmitHint('P NewUnit');
     Inc(NumUnits);
     if NumUnits > MAXUNITS then
         Catastrophic('Maximum number of units exceeded'); {Fatal}
     ParserState.UnitStatus.Index := NumUnits;
end;



// Searches list of units for this one or none
function GetUnitUnsafe(const UnitName: TString): Integer;
var
  UnitIndex: Integer;
begin
for UnitIndex := 1 to NumUnits do
  if Units[UnitIndex].Name = UnitName then
    begin
    Result := UnitIndex;
    Exit;
    end;

Result := 0;
end;




function GetUnit(const UnitName: TString): Integer;
begin
     If  (ActivityCTrace in TraceCompiler)   then      EmitHint('f GetUnit');
Result := GetUnitUnsafe(UnitName);
if Result = 0 then
    Catastrophic('Fatal: Unknown unit ' + UnitName);
end;




procedure DefineStaticSet(const SetValue: TByteSet; var Addr: LongInt; FixedAddr: LongInt = -1);
var
  i: Integer;
  ElementPtr: ^Byte;
begin
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P DefineStaticSet');

     if FixedAddr <> -1 then
        Addr := FixedAddr
     else
     begin
          if MAXSETELEMENTS div 8 >
             MAXINITIALIZEDDATASIZE - InitializedGlobalDataSize then
    	       Catastrophic('Fatal: Not enough memory for static set'); {fatal}

           Addr := InitializedGlobalDataSize;
           InitializedGlobalDataSize := InitializedGlobalDataSize + MAXSETELEMENTS div 8;
       end;

       for i := 0 to MAXSETELEMENTS - 1 do
            if i in SetValue then
               begin
                   ElementPtr := @InitializedGlobalData[Addr + i shr 3];
                   ElementPtr^ := ElementPtr^ or (1 shl (i and 7));
                end;
end;


 // fixme if using pointers
procedure DeclareType(TypeKind: TTypeKind);
begin
          If  (ActivityCTrace in TraceCompiler) then EmitHint('P DeclareType');

Inc(NumTypes);
if NumTypes > MAXTYPES then
  begin
      Fatal('Maximum number of types exceeded');
      Exit;
  end;

with Types[NumTypes] do
  begin
  Kind := TypeKind;
  Block := BlockStack[BlockStackTop].Index;
  end;
end; // DeclareType  



//  DeclareIdent(Name, Kind, Size, InCStack?, DataType,PassMethod,
//               Ord Value, Real Value, StringValue, SetValue,
//               PredefProc, ReceiverName,;ReceiverType);
//  Kind:  (EMPTYIDENT, GOTOLABEL, CONSTANT, USERTYPE, VARIABLE, PROC, FUNC)
//  DataType (names all end with TYPEINDEX):  ANY, INTEGER, SMALLINT, SHORTINT,
//                      INT64, INT128, WORD, BYTE, CHAR, BOOLEAN, REAL,
//                      CURRENCY, SINGLE, POINTER, FILE, STRING
//  Pass method: (EMPTYPASSING, VALPASSING, CONSTPASSING, VARPASSING)

procedure DeclarePredefinedIdents;
begin
     If  (ActivityCTrace in TraceCompiler) then EmitHint('P DeclarePredefinedIdents');
// Constants
DeclareIdent('TRUE',          CONSTANT, 0, FALSE, BOOLEANTYPEINDEX, EMPTYPASSING,         1, 0.0, '', [], EMPTYPROC, '', 0, Compiler_Defined, System_Constant);
DeclareIdent('FALSE',         CONSTANT, 0, FALSE, BOOLEANTYPEINDEX, EMPTYPASSING,         0, 0.0, '', [], EMPTYPROC, '', 0, Compiler_Defined, System_Constant);
DeclareIdent('MAXINT',        CONSTANT, 0, FALSE, INTEGERTYPEINDEX, EMPTYPASSING, $7FFFFFFF, 0.0, '', [], EMPTYPROC, '', 0, Compiler_Defined, System_Constant);
DeclareIdent('MAXSTRLENGTH',  CONSTANT, 0, FALSE, INTEGERTYPEINDEX, EMPTYPASSING,       255, 0.0, '', [], EMPTYPROC, '', 0, Compiler_Defined, System_Constant);
DeclareIdent('MAXSETELEMENTS',CONSTANT, 0, FALSE, INTEGERTYPEINDEX, EMPTYPASSING,       256, 0.0, '', [], EMPTYPROC, '', 0, Compiler_Defined, System_Constant);

// Conditional compilation values
DefineCond('XDP',             '', false, 0);              // define XDP as a symbol w/no  value
DefineCond('XDP_FULLVERSION', '', true, VERSION_FULL);    // An integer version number of the compiler.
DefineCond('XDP_VERSION',     '', true, VERSION_MAJOR);   // The version number of the compiler.
DefineCond('XDP_RELEASE',     '', true, VERSION_RELEASE); // The release number of the compiler.
DefineCond('XDP_PATCH',       '', true, VERSION_PATCH);   // The patch level of the compiler.


// Types
DeclareIdent('INTEGER',  USERTYPE, 0, FALSE, INTEGERTYPEINDEX,  EMPTYPASSING, 0, 0.0, '', [], EMPTYPROC, '', 0, Compiler_Defined, System_Type);
DeclareIdent('LONG',     USERTYPE, 0, FALSE, INTEGERTYPEINDEX,  EMPTYPASSING, 0, 0.0, '', [], EMPTYPROC, '', 0, Compiler_Defined, System_Type);
DeclareIdent('SMALLINT', USERTYPE, 0, FALSE, SMALLINTTYPEINDEX, EMPTYPASSING, 0, 0.0, '', [], EMPTYPROC, '', 0, Compiler_Defined, System_Type);
DeclareIdent('SHORTINT', USERTYPE, 0, FALSE, SHORTINTTYPEINDEX, EMPTYPASSING, 0, 0.0, '', [], EMPTYPROC, '', 0, Compiler_Defined, System_Type);
DeclareIdent('WORD',     USERTYPE, 0, FALSE, WORDTYPEINDEX,     EMPTYPASSING, 0, 0.0, '', [], EMPTYPROC, '', 0, Compiler_Defined, System_Type);
DeclareIdent('BYTE',     USERTYPE, 0, FALSE, BYTETYPEINDEX,     EMPTYPASSING, 0, 0.0, '', [], EMPTYPROC, '', 0, Compiler_Defined, System_Type);  
DeclareIdent('CHAR',     USERTYPE, 0, FALSE, CHARTYPEINDEX,     EMPTYPASSING, 0, 0.0, '', [], EMPTYPROC, '', 0, Compiler_Defined, System_Type);
DeclareIdent('BOOLEAN',  USERTYPE, 0, FALSE, BOOLEANTYPEINDEX,  EMPTYPASSING, 0, 0.0, '', [], EMPTYPROC, '', 0, Compiler_Defined, System_Type);
DeclareIdent('REAL',     USERTYPE, 0, FALSE, REALTYPEINDEX,     EMPTYPASSING, 0, 0.0, '', [], EMPTYPROC, '', 0, Compiler_Defined, System_Type);
DeclareIdent('SINGLE',   USERTYPE, 0, FALSE, SINGLETYPEINDEX,   EMPTYPASSING, 0, 0.0, '', [], EMPTYPROC, '', 0, Compiler_Defined, System_Type);
DeclareIdent('POINTER',  USERTYPE, 0, FALSE, POINTERTYPEINDEX,  EMPTYPASSING, 0, 0.0, '', [], EMPTYPROC, '', 0, Compiler_Defined, System_Type);
DeclareIdent('INT64',    USERTYPE, 0, FALSE, INT64TYPEINDEX,    EMPTYPASSING, 0, 0.0, '', [], EMPTYPROC, '', 0, Compiler_Defined, System_Type);
DeclareIdent('LONGLONG', USERTYPE, 0, FALSE, INT64TYPEINDEX,    EMPTYPASSING, 0, 0.0, '', [], EMPTYPROC, '', 0, Compiler_Defined, System_Type);
DeclareIdent('INT128',   USERTYPE, 0, FALSE, INT128TYPEINDEX,   EMPTYPASSING, 0, 0.0, '', [], EMPTYPROC, '', 0, Compiler_Defined, System_Type);
DeclareIdent('QWORD',    USERTYPE, 0, FALSE, INT128TYPEINDEX,   EMPTYPASSING, 0, 0.0, '', [], EMPTYPROC, '', 0, Compiler_Defined, System_Type);
DeclareIdent('CURRENCY', USERTYPE, 0, FALSE, CURRENCYTYPEINDEX, EMPTYPASSING, 0, 0.0, '', [], EMPTYPROC, '', 0, Compiler_Defined, System_Type);

// Procedures
DeclareIdent('INC',      PROC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], INCPROC,      '', 0, Compiler_Defined,System_Procedure);
DeclareIdent('DEC',      PROC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], DECPROC,      '', 0, Compiler_Defined,System_Procedure);
DeclareIdent('READ',     PROC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], READPROC,     '', 0, Compiler_Defined,System_Procedure);
DeclareIdent('WRITE',    PROC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], WRITEPROC,    '', 0, Compiler_Defined,System_Procedure);
DeclareIdent('READLN',   PROC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], READLNPROC,   '', 0, Compiler_Defined,System_Procedure);
DeclareIdent('WRITELN',  PROC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], WRITELNPROC,  '', 0, Compiler_Defined,System_Procedure);
DeclareIdent('INLINE',   PROC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], INLINEPROC,   '', 0, Compiler_Defined,System_Procedure);
DeclareIdent('NEW',      PROC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], NEWPROC,      '', 0, Compiler_Defined,System_Procedure);
DeclareIdent('DISPOSE',  PROC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], DISPOSEPROC,  '', 0, Compiler_Defined,System_Procedure);
DeclareIdent('BREAK',    PROC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], BREAKPROC,    '', 0, Compiler_Defined,System_Procedure);
DeclareIdent('CONTINUE', PROC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], CONTINUEPROC, '', 0, Compiler_Defined,System_Procedure);  
DeclareIdent('EXIT',     PROC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], EXITPROC,     '', 0, Compiler_Defined,System_Procedure);
DeclareIdent('HALT',     PROC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], HALTPROC,     '', 0, Compiler_Defined,System_Procedure);

// Functions
DeclareIdent('SIZEOF', FUNC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], SIZEOFFUNC, '', 0, Compiler_Defined,System_Function);
DeclareIdent('ORD',    FUNC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], ORDFUNC,    '', 0, Compiler_Defined,System_Function);
DeclareIdent('CHR',    FUNC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], CHRFUNC,    '', 0, Compiler_Defined,System_Function);
DeclareIdent('LOW',    FUNC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], LOWFUNC,    '', 0, Compiler_Defined,System_Function);
DeclareIdent('HIGH',   FUNC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], HIGHFUNC,   '', 0, Compiler_Defined,System_Function);
DeclareIdent('PRED',   FUNC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], PREDFUNC,   '', 0, Compiler_Defined,System_Function);
DeclareIdent('SUCC',   FUNC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], SUCCFUNC,   '', 0, Compiler_Defined,System_Function);
DeclareIdent('ROUND',  FUNC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], ROUNDFUNC,  '', 0, Compiler_Defined,System_Function);
DeclareIdent('TRUNC',  FUNC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], TRUNCFUNC,  '', 0, Compiler_Defined,System_Function);
DeclareIdent('ABS',    FUNC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], ABSFUNC,    '', 0, Compiler_Defined,System_Function);
DeclareIdent('SQR',    FUNC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], SQRFUNC,    '', 0, Compiler_Defined,System_Function);
DeclareIdent('SIN',    FUNC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], SINFUNC,    '', 0, Compiler_Defined,System_Function);
DeclareIdent('COS',    FUNC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], COSFUNC,    '', 0, Compiler_Defined,System_Function);
DeclareIdent('ARCTAN', FUNC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], ARCTANFUNC, '', 0, Compiler_Defined,System_Function);
DeclareIdent('EXP',    FUNC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], EXPFUNC,    '', 0, Compiler_Defined,System_Function);
DeclareIdent('LN',     FUNC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], LNFUNC,     '', 0, Compiler_Defined,System_Function);
DeclareIdent('SQRT',   FUNC, 0, FALSE, 0, EMPTYPASSING, 0, 0.0, '', [], SQRTFUNC,   '', 0, Compiler_Defined,System_Function);
end;// DeclarePredefinedIdents



// if adding a new type, be sure to check:
//    "predefined type indexes"
//    procedure DeclarePredefinedTypes
//    TTypeKind
//    function GetTypeSpelling

procedure DeclarePredefinedTypes;
begin
         If  (ActivityCTrace in TraceCompiler) then EmitHint('P DeclarePredefinedTypes');
NumTypes := STRINGTYPEINDEX;

Types[ANYTYPEINDEX].Kind      := ANYTYPE;
Types[INTEGERTYPEINDEX].Kind  := INTEGERTYPE;
Types[INT64TYPEINDEX].Kind    := INT64TYPE;
Types[INT128TYPEINDEX].Kind   := INT128TYPE;
Types[CURRENCYTYPEINDEX].Kind := CURRENCYTYPE;
Types[SMALLINTTYPEINDEX].Kind := SMALLINTTYPE;
Types[SHORTINTTYPEINDEX].Kind := SHORTINTTYPE;
Types[WORDTYPEINDEX].Kind     := WORDTYPE;  
Types[BYTETYPEINDEX].Kind     := BYTETYPE;  
Types[CHARTYPEINDEX].Kind     := CHARTYPE;
Types[BOOLEANTYPEINDEX].Kind  := BOOLEANTYPE;
Types[REALTYPEINDEX].Kind     := REALTYPE;
Types[SINGLETYPEINDEX].Kind   := SINGLETYPE;
Types[POINTERTYPEINDEX].Kind  := POINTERTYPE;
Types[FILETYPEINDEX].Kind     := FILETYPE;
Types[STRINGTYPEINDEX].Kind   := ARRAYTYPE;

Types[POINTERTYPEINDEX].BaseType := ANYTYPEINDEX;
Types[FILETYPEINDEX].BaseType    := ANYTYPEINDEX;

// Add new anonymous type: 1 .. MAXSTRLENGTH + 1
DeclareType(SUBRANGETYPE);

Types[NumTypes].BaseType := INTEGERTYPEINDEX;
Types[NumTypes].Low      := 1;
Types[NumTypes].High     := MAXSTRLENGTH + 1;

Types[STRINGTYPEINDEX].BaseType    := CHARTYPEINDEX;
Types[STRINGTYPEINDEX].IndexType   := NumTypes;
Types[STRINGTYPEINDEX].IsOpenArray := FALSE;
end;// DeclarePredefinedTypes




function AllocateTempStorage(Size: Integer): Integer;
begin
If  (ActivityCTrace in TraceCompiler)   then  EmitHint('f AllocateTempStorage');
with BlockStack[BlockStackTop] do
  begin
  TempDataSize := TempDataSize + Size;    
  Result := -LocalDataSize - TempDataSize;
  end;
end; // AllocateTempStorage




procedure PushTempStoragePtr(Addr: Integer);
begin
             If  (ActivityCTrace in TraceCompiler) then EmitHint('P PushTempStoragePtr');
PushVarPtr(Addr, LOCAL, 0, UNINITDATARELOC);
end; // PushTempStoragePtr



// FIXME when using pointers for identifier tanle
procedure PushVarIdentPtr(IdentIndex: Integer);
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P PushVarIdentPtr');
PushVarPtr(Ident[IdentIndex].Address, Ident[IdentIndex].Scope, BlockStackTop - Ident[IdentIndex].NestingLevel, Ident[IdentIndex].RelocType);
Ident[IdentIndex].IsUsed := TRUE;
end; // PushVarIdentPtr




procedure ConvertConstIntegerToReal(DestType: Integer; var SrcType: Integer; var ConstVal: TConst);
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P ConvertConstIntegerToReal');
// Try to convert an integer (right-hand side) into a real
if (Types[DestType].Kind in [REALTYPE, SINGLETYPE]) and
   ((Types[SrcType].Kind in IntegerTypes) or 
   ((Types[SrcType].Kind = SUBRANGETYPE) and (Types[Types[SrcType].BaseType].Kind in IntegerTypes)))
then
  begin
  ConstVal.RealValue := ConstVal.OrdValue;
  SrcType := REALTYPEINDEX;
  end;   
end; // ConvertConstIntegerToReal




procedure ConvertIntegerToReal(DestType: Integer; var SrcType: Integer; Depth: Integer);
begin
     If  (ActivityCTrace in TraceCompiler) then EmitHint('P ConvertIntegerToReal');
// Try to convert an integer (right-hand side) into a real
if (Types[DestType].Kind in [REALTYPE, SINGLETYPE]) and
   ((Types[SrcType].Kind in IntegerTypes) or 
   ((Types[SrcType].Kind = SUBRANGETYPE) and (Types[Types[SrcType].BaseType].Kind in IntegerTypes)))
then
  begin
  GenerateDoubleFromInteger(Depth);
  SrcType := REALTYPEINDEX;
  end;   
end; // ConvertIntegerToReal




procedure ConvertConstRealToReal(DestType: Integer; var SrcType: Integer; var ConstVal: TConst);
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P ConvertConstRealToReal');
// Try to convert a single (right-hand side) into a double or vice versa
if (Types[DestType].Kind = REALTYPE) and (Types[SrcType].Kind = SINGLETYPE) then
  begin
  ConstVal.RealValue := ConstVal.SingleValue;
  SrcType := REALTYPEINDEX;
  end
else if (Types[DestType].Kind = SINGLETYPE) and (Types[SrcType].Kind = REALTYPE) then
  begin
  ConstVal.SingleValue := ConstVal.RealValue;
  SrcType := SINGLETYPEINDEX;
  end  
end; // ConvertConstRealToReal




procedure ConvertRealToReal(DestType: Integer; var SrcType: Integer);
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P ConvertRealToReal');
// Try to convert a single (right-hand side) into a double or vice versa
if (Types[DestType].Kind = REALTYPE) and (Types[SrcType].Kind = SINGLETYPE) then
  begin
  GenerateDoubleFromSingle;
  SrcType := REALTYPEINDEX;
  end
else if (Types[DestType].Kind = SINGLETYPE) and (Types[SrcType].Kind = REALTYPE) then
  begin
  GenerateSingleFromDouble;
  SrcType := SINGLETYPEINDEX;
  end  
end; // ConvertRealToReal




procedure ConvertConstCharToString(DestType: Integer; var SrcType: Integer; var ConstVal: TConst);
var
  ch: TCharacter;
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P ConvertConstCharToString');
if IsString(DestType) and 
   ((Types[SrcType].Kind = CHARTYPE) or 
   ((Types[SrcType].Kind = SUBRANGETYPE) and (Types[Types[SrcType].BaseType].Kind = CHARTYPE))) 
then
  begin
  ch := Char(ConstVal.OrdValue);
  ConstVal.StrValue := ch;
  SrcType := STRINGTYPEINDEX;
  end;   
end; // ConvertConstCharToString




procedure ConvertCharToString(DestType: Integer; var SrcType: Integer; Depth: Integer);
var
  TempStorageAddr: LongInt;
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P ConvertCharToString');
// Try to convert a character (right-hand side) into a 2-character temporary string
if IsString(DestType) and 
   ((Types[SrcType].Kind = CHARTYPE) or 
   ((Types[SrcType].Kind = SUBRANGETYPE) and (Types[Types[SrcType].BaseType].Kind = CHARTYPE))) 
then
  begin
  TempStorageAddr := AllocateTempStorage(2 * SizeOf(TCharacter));    
  PushTempStoragePtr(TempStorageAddr);  
  GetCharAsTempString(Depth);    
  SrcType := STRINGTYPEINDEX;
  end;
end; // ConvertCharToString




procedure ConvertStringToPChar(DestType: Integer; var SrcType: Integer);
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P ConvertStringToPChar');
// Try to convert a string (right-hand side) into a pointer to character
if (Types[DestType].Kind = POINTERTYPE) and (Types[Types[DestType].BaseType].Kind = CHARTYPE) and IsString(SrcType) then    
  SrcType := DestType;
end; // ConvertStringToPChar


procedure CheckSignatures(var Signature1, Signature2: TSignature; const ErrorType: TString; CheckParamNames: Boolean = TRUE);
var
  i: Integer;
  SV1,SV2:String;
begin
        If  (ActivityCTrace in TraceCompiler) then EmitHint('P CheckSignatures');
// must have same number of parameters
if Signature1.NumParams <> Signature2.NumParams then
    Err3(Err_32, ErrorType, Radix(Signature1.NumParams,10),
                 Radix(Signature2.NumParams,10)); //Incompatible number of parameters

// must have same number of default parameters
if Signature1.NumDefaultParams <> Signature2.NumDefaultParams then
	begin
  		Fatal('Incompatible number of default parameters in ' + ErrorType+
                       Radix(Signature1.NumDefaultParams,10)+' vs. '+
                       Radix(Signature1.NumDefaultParams,10));
  		exit;
  	end;
// must all have the same name
for i := 1 to Signature1.NumParams do
  begin
  if (Signature1.Param[i]^.Name <> Signature2.Param[i]^.Name) and CheckParamNames then
  	begin
  		Fatal('Incompatible parameter ('+ Radix(i,10)+') names "'+
                      Signature1.Param[i]^.Name + '" vs. "' +
                      Signature2.Param[i]^.Name + '") in ' + ErrorType );
  		exit;
  	end;

// parameters must be compatible
  if Signature1.Param[i]^.DataType <> Signature2.Param[i]^.DataType then
    if not Types[Signature1.Param[i]^.DataType].IsOpenArray or
       not Types[Signature2.Param[i]^.DataType].IsOpenArray or
       (Types[Signature1.Param[i]^.DataType].BaseType <> Types[Signature2.Param[i]^.DataType].BaseType)
    then
    	begin
      		Fatal('Incompatible parameter types in ' + ErrorType +
                      ' (argument '+ Radix(i,10)+', "'+
                       Signature1.Param[i]^.Name + '"): ' +
                       GetTypeSpelling(Signature1.Param[i]^.DataType) + ' and ' +
                       GetTypeSpelling(Signature2.Param[i]^.DataType));
      		exit;
      	end;

  if Signature1.Param[i]^.PassMethod <>
  	 Signature2.Param[i]^.PassMethod then
  	 begin
    	Fatal('Incompatible CONST/VAR modifiers (argument '+
               Radix(i,10)+', "'+  Signature2.Param[i]^.Name + '"): ' +
              ' in ' + ErrorType);
    	exit;
     end;

  if Signature1.Param[i]^.Default.OrdValue <> Signature2.Param[i]^.Default.OrdValue then
  	begin
            istr(Signature1.Param[i]^.Default.OrdValue,SV1);
            istr(Signature2.Param[i]^.Default.OrdValue,SV2);
    	Fatal('Incompatible default values (argument '+ Radix(i,10)+
              ', '+ SV1 +' vs. '+ SV2 +') in '+ ErrorType);
    	exit;
    end;
  end; // for

if Signature1.ResultType <> Signature2.ResultType then
begin
    Fatal('Incompatible result types in ' + ErrorType + ': ' +
           GetTypeSpelling(Signature1.ResultType) + ' and ' + GetTypeSpelling(Signature2.ResultType));
    exit;
end;

if Signature1.CallConv <> Signature2.CallConv then
begin
    Fatal('Incompatible calling convention in ' + ErrorType);
    exit;
end;

end; // CheckSignatures


procedure ConvertToInterface(DestType: Integer; var SrcType: Integer);
var
  SrcField, DestField: PField;
  TempStorageAddr: LongInt;
  FieldIndex, MethodIndex: Integer;
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P ConvertToInterface');
// Try to convert a concrete or interface type to an interface type
if (Types[DestType].Kind = INTERFACETYPE) and (DestType <> SrcType) then
  begin
  // Allocate new interface variable
  TempStorageAddr := AllocateTempStorage(TypeSize(DestType));

  // Set interface's Self pointer (offset 0) to the concrete/interface data
  if Types[SrcType].Kind = INTERFACETYPE then
    begin
    DuplicateStackTop;
    DerefPtr(POINTERTYPEINDEX);
    GenerateInterfaceFieldAssignment(TempStorageAddr, TRUE, 0, UNINITDATARELOC);
    DiscardStackTop(1);
    end
  else
    GenerateInterfaceFieldAssignment(TempStorageAddr, TRUE, 0, UNINITDATARELOC);  

  // Set interface's procedure pointers to the concrete/interface methods
  for FieldIndex := 2 to Types[DestType].NumFields do
    begin
    DestField := Types[DestType].Field[FieldIndex];
    
    if Types[SrcType].Kind = INTERFACETYPE then       // Interface to interface 
      begin
      SrcField := Types[SrcType].Field[GetField(SrcType, DestField^.Name)];
      CheckSignatures(Types[SrcField^.DataType].Signature, Types[DestField^.DataType].Signature, SrcField^.Name, FALSE);
      DuplicateStackTop;
      GetFieldPtr(SrcField^.Offset);
      DerefPtr(POINTERTYPEINDEX);
      GenerateInterfaceFieldAssignment(TempStorageAddr + (FieldIndex - 1) * SizeOf(Pointer), TRUE, 0, CODERELOC);
      DiscardStackTop(1);
      end
    else                                              // Concrete to interface
      begin  
      MethodIndex := GetMethod(SrcType, DestField^.Name);
      CheckSignatures(Ident[MethodIndex].Signature, Types[DestField^.DataType].Signature, Ident[MethodIndex].Name, FALSE);
      GenerateInterfaceFieldAssignment(TempStorageAddr + (FieldIndex - 1) * SizeOf(Pointer), FALSE, Ident[MethodIndex].Address, CODERELOC);
      end;
    end; // for  
  
  DiscardStackTop(1);                                       // Remove source pointer
  PushTempStoragePtr(TempStorageAddr);   // Push destination pointer
  SrcType := DestType;
  end;
end; // ConvertToInterface



function GetCompatibleType(LeftType, RightType: Integer): Integer;
begin
If  (ActivityCTrace in TraceCompiler)   then    EmitHint('f GetCompatibleType');
Result := 0;

// General rule
if LeftType = RightType then
  Result := LeftType

// Special cases
// All types are compatible with their aliases
else if Types[LeftType].AliasType <> 0 then
  Result := GetCompatibleType(Types[LeftType].AliasType, RightType)
else if Types[RightType].AliasType <> 0 then
  Result := GetCompatibleType(LeftType, Types[RightType].AliasType)

// Sets are compatible with other sets having a compatible base type, or with an empty set constructor
else if (Types[LeftType].Kind = SETTYPE) and (Types[RightType].Kind = SETTYPE) then
  begin
  if Types[RightType].BaseType = ANYTYPEINDEX then
    Result := LeftType
  else if Types[LeftType].BaseType = ANYTYPEINDEX then
    Result := RightType
  else
    begin
    GetCompatibleType(Types[LeftType].BaseType, Types[RightType].BaseType);
    Result := LeftType;
    end;
  end

// Strings are compatible with any other strings
else if IsString(LeftType) and IsString(RightType) then
  Result := LeftType

// Untyped pointers are compatible with any pointers or procedural types
else if (Types[LeftType].Kind = POINTERTYPE) and (Types[LeftType].BaseType = ANYTYPEINDEX) and
        (Types[RightType].Kind in [POINTERTYPE, PROCEDURALTYPE]) then
  Result := LeftType
else if (Types[RightType].Kind = POINTERTYPE) and (Types[RightType].BaseType = ANYTYPEINDEX) and
        (Types[LeftType].Kind in [POINTERTYPE, PROCEDURALTYPE]) then
  Result := RightType

// Typed pointers are compatible with any pointers to a reference-compatible type
else if (Types[LeftType].Kind = POINTERTYPE) and (Types[RightType].Kind = POINTERTYPE) then
  Result := GetCompatibleRefType(Types[LeftType].BaseType, Types[RightType].BaseType)

// Procedural types are compatible if their Self pointer offsets are equal and their signatures are compatible
else if (Types[LeftType].Kind = PROCEDURALTYPE) and (Types[RightType].Kind = PROCEDURALTYPE) and
        (Types[LeftType].SelfPointerOffset = Types[RightType].SelfPointerOffset) then
  begin
  CheckSignatures(Types[LeftType].Signature, Types[RightType].Signature, 'procedural variable', FALSE);
  Result := LeftType;
  end

// Subranges are compatible with their host types
else if Types[LeftType].Kind = SUBRANGETYPE then
  Result := GetCompatibleType(Types[LeftType].BaseType, RightType)
else if Types[RightType].Kind = SUBRANGETYPE then
  Result := GetCompatibleType(LeftType, Types[RightType].BaseType)

// Integers
else if (Types[LeftType].Kind in IntegerTypes) and (Types[RightType].Kind in IntegerTypes) then
  Result := LeftType

// Int64
else if (Types[LeftType].Kind = Int64Type) and  (Types[RightType].Kind in Int64Types) then
    Result := LeftType
else if (Types[LeftType].Kind in Int64Types) and  (Types[RightType].Kind  = Int64Type) then
    Result := RightType

// Int128
else if (Types[LeftType].Kind = Int128Type) and  (Types[RightType].Kind in Int128Types) then
  Result := LeftType
else if (Types[LeftType].Kind in Int128Types) and  (Types[RightType].Kind  = Int128Type) then
  Result := RightType

// Currency
else if (Types[LeftType].Kind = CurrencyType) and  (Types[RightType].Kind in CurrencyTypes) then
  Result := LeftType
else if (Types[LeftType].Kind in CurrencyTypes) and  (Types[RightType].Kind = CurrencyType) then
  Result := RightType

// Booleans
else if (Types[LeftType].Kind = BOOLEANTYPE) and (Types[RightType].Kind = BOOLEANTYPE) then
  Result := LeftType

// Characters
else if (Types[LeftType].Kind = CHARTYPE) and  (Types[RightType].Kind = CHARTYPE) then
  Result := LeftType;

if Result = 0 then
	begin
  		Fatal('Incompatible types: ' + GetTypeSpelling(LeftType) + ' and ' + GetTypeSpelling(RightType));
  		exit;
  	end;
end; // GetCompatibleType



function GetTotalParamSize(const Signature: TSignature; IsMethod, AlwaysTreatStructuresAsReferences: Boolean): Integer;
var
  i: Integer;
begin
If  (ActivityCTrace in TraceCompiler) then  EmitHint('f GetTotalParamSize');
if (Signature.CallConv <> DEFAULTCONV) and IsMethod then
	begin
            Catastrophic('Internal fault: Methods cannot be STDCALL/CDECL'); {Fatal}
  	    exit;
  	end;

Result := 0;

// For a method, Self is a first (hidden) VAR parameter
if IsMethod then
  Result := Result + SizeOf(LongInt);

// Allocate space for structured Result as a hidden VAR parameter (except STDCALL/CDECL functions returning small structures in EDX:EAX)
with Signature do
  if (ResultType <> 0) and (Types[ResultType].Kind in StructuredTypes) and
    ((CallConv = DEFAULTCONV) or (TypeSize(ResultType) > 2 * SizeOf(LongInt))) then
    Result := Result + SizeOf(LongInt);

// Any parameter occupies 4 bytes (except structures in the C stack)
if (Signature.CallConv <> DEFAULTCONV) and not AlwaysTreatStructuresAsReferences then
  for i := 1 to Signature.NumParams do
    if Signature.Param[i]^.PassMethod = VALPASSING then
      Result := Result + Align(TypeSize(Signature.Param[i]^.DataType), SizeOf(LongInt))
    else
      Result := Result + SizeOf(LongInt)
else
  for i := 1 to Signature.NumParams do
    if (Signature.Param[i]^.PassMethod = VALPASSING) and (Types[Signature.Param[i]^.DataType].Kind = REALTYPE) then
      Result := Result + SizeOf(Double)
    else
      Result := Result + SizeOf(LongInt);

end; // GetTotalParamSize


function GetCompatibleRefType(LeftType, RightType: Integer): Integer;
begin
If  (ActivityCTrace in TraceCompiler) then  EmitHint('f GetCompatibleRefType');
// This function is asymmetric and implies Variable(LeftType) := Variable(RightType)
Result := 0;

// General rule
if LeftType = RightType then
  Result := RightType

// Special cases
// All types are compatible with their aliases
else if Types[LeftType].AliasType <> 0 then
  Result := GetCompatibleRefType(Types[LeftType].AliasType, RightType)
else if Types[RightType].AliasType <> 0 then
  Result := GetCompatibleRefType(LeftType, Types[RightType].AliasType)

// Open arrays are compatible with any other arrays of the same base type
else if (Types[LeftType].Kind = ARRAYTYPE) and (Types[RightType].Kind = ARRAYTYPE) and
         Types[LeftType].IsOpenArray and (Types[LeftType].BaseType = Types[RightType].BaseType) then
  Result := RightType

// Untyped pointers are compatible with any other pointers
else if (Types[LeftType].Kind = POINTERTYPE) and (Types[RightType].Kind = POINTERTYPE) and
       ((Types[LeftType].BaseType = Types[RightType].BaseType) or (Types[LeftType].BaseType = ANYTYPEINDEX)) then
  Result := RightType

// Untyped files are compatible with any other files
else if (Types[LeftType].Kind = FILETYPE) and (Types[RightType].Kind = FILETYPE) and
        (Types[LeftType].BaseType = ANYTYPEINDEX) then
  Result := RightType

// Untyped parameters are compatible with any type
else if Types[LeftType].Kind = ANYTYPE then
  Result := RightType;

if Result = 0 then
	begin
  		Fatal('Incompatible types: ' + GetTypeSpelling(LeftType) + ' and ' + GetTypeSpelling(RightType));
  		exit;
  	end;
end;



procedure CheckOperator(const Tok: TToken; DataType: Integer);
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P CheckOperator');
with Types[DataType] do
  if Kind = SUBRANGETYPE then
    CheckOperator(Tok, BaseType)
  else
    begin
    if not (Kind in OrdinalTypes) and
    	   (Kind <> REALTYPE) and (Kind <> POINTERTYPE) and
    	   (Kind <> PROCEDURALTYPE) then
    	begin
      		Fatal('Operator ' + GetTokSpelling(Tok.Kind) + ' is not applicable to ' + GetTypeSpelling(DataType));
      		exit
      	end;

    if ((Kind in IntegerTypes)  and not (Tok.Kind in OperatorsForIntegers)) or
       ((Kind = REALTYPE)       and not (Tok.Kind in OperatorsForReals)) or
       ((Kind = CHARTYPE)       and not (Tok.Kind in RelationOperators)) or
       ((Kind = BOOLEANTYPE)    and not (Tok.Kind in OperatorsForBooleans)) or
       ((Kind = POINTERTYPE)    and not (Tok.Kind in RelationOperators)) or
       ((Kind = ENUMERATEDTYPE) and not (Tok.Kind in RelationOperators)) or
       ((Kind = PROCEDURALTYPE) and not (Tok.Kind in RelationOperators))
    then
    	begin
      		Fatal('Operator ' + GetTokSpelling(Tok.Kind) + ' is not applicable to ' + GetTypeSpelling(DataType));
      		exit;
      	end;
    end;
end;



// CHANGEME: If we switch to pointers, NIL needs to be used instead of 0
// Difference between GetIdent and GetidentUnsafe is that returns 0 if not found,
// this throws an error
function GetIdent(const IdentName: TString; AllowForwardReference: Boolean = FALSE; RecType: Integer = 0): Integer;
begin
If  (ActivityCTrace in TraceCompiler) then EmitHint('f GetIdent');
Result := GetIdentUnsafe(IdentName, AllowForwardReference, RecType);
if Result = 0 then
	begin
  		Fatal('Unknown identifier ' + IdentName);
  		exit;
  	end;
end;




  // FIXME when using pointers for identifier tanle
procedure CompileConstPredefinedFunc(func: TPredefProc; var ConstVal: TConst; var ConstValType: Integer);
var
  IdentIndex: Integer;
  ProcName:String;

begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileConstPredefinedFunc');
NextTok;
EatTok(OPARTOK);

case func of

  SIZEOFFUNC:
    begin
    AssertIdent;
    IdentIndex := GetIdentUnsafe(Tok.Name);
    if (IdentIndex <> 0) and (Ident[IdentIndex].Kind = USERTYPE) then   // Type name
      begin
      NextTok;
      ConstVal.OrdValue := TypeSize(Ident[IdentIndex].DataType);
      end
    else                                                                // Variable name
      begin
          if IdentIndex = 0 then
               Err1(Err_104,Tok.Name); // identifier not declared
           Err(Err_10); // Type name expected
      end;
    ConstValType := INTEGERTYPEINDEX;
    end;
    

  ROUNDFUNC, TRUNCFUNC:
    begin
    CompileConstExpression(ConstVal, ConstValType);

    if not (Types[ConstValType].Kind in IntegerTypes) then
      begin     
      GetCompatibleType(ConstValType, REALTYPEINDEX);
      if func = TRUNCFUNC then
        ConstVal.OrdValue := Trunc(ConstVal.RealValue)
      else
        ConstVal.OrdValue := Round(ConstVal.RealValue);
      end;
    ConstValType := INTEGERTYPEINDEX;
    end;
    

  ORDFUNC:
    begin
    CompileConstExpression(ConstVal, ConstValType);
    if not (Types[ConstValType].Kind in OrdinalTypes) then
      begin
           Fatal('Ordinal type expected for ORD function');
           exit;
       end;
    ConstValType := INTEGERTYPEINDEX;
    end;
    

  CHRFUNC:
    begin
    CompileConstExpression(ConstVal, ConstValType);
    GetCompatibleType(ConstValType, INTEGERTYPEINDEX);
    ConstValType := CHARTYPEINDEX;
    end;    


  LOWFUNC, HIGHFUNC:
    begin
    AssertIdent;
    IdentIndex := GetIdentUnsafe(Tok.Name);
    if (IdentIndex <> 0) and (Ident[IdentIndex].Kind = USERTYPE) then   // Type name
      begin
      NextTok;
      ConstValType := Ident[IdentIndex].DataType;
      end
    else    // Variable name
      Begin
         if func = HIGHFUNC then procName :='HIGH' else procName :='LOW';
         Fatal('Type name expected for '+procName+' function');
         Exit
      End;
          
    if (Types[ConstValType].Kind = ARRAYTYPE) and not Types[ConstValType].IsOpenArray then
      ConstValType := Types[ConstValType].IndexType;
    if func = HIGHFUNC then  
      ConstVal.OrdValue := HighBound(ConstValType)
    else
      ConstVal.OrdValue := LowBound(ConstValType); 
    end;


  PREDFUNC, SUCCFUNC:
    begin
    CompileConstExpression(ConstVal, ConstValType);
    if not (Types[ConstValType].Kind in OrdinalTypes) then
      begin
          if  func = PREDFUNC then procName :='PRED' else procName :='SUCC';
          Fatal('Ordinal type expected for '+procName+' function');
          Exit;
      end;
    if func = SUCCFUNC then
      Inc(ConstVal.OrdValue)
    else
      Dec(ConstVal.OrdValue);
    end;
    

  ABSFUNC, SQRFUNC, SINFUNC, COSFUNC, ARCTANFUNC, EXPFUNC, LNFUNC, SQRTFUNC:
    begin
    CompileConstExpression(ConstVal, ConstValType);
    if (func = ABSFUNC) or (func = SQRFUNC) then                          // Abs and Sqr accept real or integer parameters
      begin
      if not ((Types[ConstValType].Kind in NumericTypes) or
             ((Types[ConstValType].Kind = SUBRANGETYPE) and (Types[Types[ConstValType].BaseType].Kind in NumericTypes))) then
         begin
             Fatal('Numeric type expected');
             Exit;
         End;

      if Types[ConstValType].Kind = REALTYPE then
        if func = ABSFUNC then
          ConstVal.RealValue := abs(ConstVal.RealValue)
        else
          ConstVal.RealValue := sqr(ConstVal.RealValue)
      else
        if func = ABSFUNC then
          ConstVal.OrdValue := abs(ConstVal.OrdValue)
        else
          ConstVal.OrdValue := sqr(ConstVal.OrdValue);
      end
    else
      Begin
           Fatal('Function is not allowed in constant expressions');
           Exit;
      end;
  end;  
end;// case

EatTok(CPARTOK);
end;// CompileConstPredefinedFunc




procedure CompileConstSetConstructor(var ConstVal: TConst; var ConstValType: Integer);
var
  ElementVal, ElementVal2: TConst;
  ElementValType: Integer;
  ElementIndex: Integer;
  
    
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileConstSetConstructor');
ConstVal.SetValue := [];

// Add new anonymous type
DeclareType(SETTYPE);
Types[NumTypes].BaseType := ANYTYPEINDEX;
ConstValType := NumTypes;

// Compile constructor
EatTok(OBRACKETTOK);

if Tok.Kind <> CBRACKETTOK then
  repeat      
    CompileConstExpression(ElementVal, ElementValType);

    if Types[ConstValType].BaseType = ANYTYPEINDEX then
      begin
      if not (Types[ElementValType].Kind in OrdinalTypes) then
        begin
            Fatal('Ordinal type expected for set');
            Exit;
         end;
      Types[ConstValType].BaseType := ElementValType;
      end  
    else  
      GetCompatibleType(ElementValType, Types[ConstValType].BaseType);

    if Tok.Kind = RANGETOK then
      begin
      NextTok;
      CompileConstExpression(ElementVal2, ElementValType);    
      GetCompatibleType(ElementValType, Types[ConstValType].BaseType);
      end
    else
      ElementVal2 := ElementVal;
      
    if (ElementVal.OrdValue < 0) or (ElementVal.OrdValue >= MAXSETELEMENTS) or
       (ElementVal2.OrdValue < 0) or (ElementVal2.OrdValue >= MAXSETELEMENTS)
    then
      begin
          Fatal('Set elements must be between 0 and ' + IntToStr(MAXSETELEMENTS - 1));
          Exit;
      end;
    for ElementIndex := ElementVal.OrdValue to ElementVal2.OrdValue do
      ConstVal.SetValue := ConstVal.SetValue + [ElementIndex];

    if Tok.Kind <> COMMATOK then Break;
    NextTok;
  until FALSE;

EatTok(CBRACKETTOK);
end; // CompileConstSetConstructor



   // FIXME when using pointers for identifier tanle
procedure CompileConstFactor(var ConstVal: TConst; var ConstValType: Integer);
var
  NotOpTok: TToken;
  IdentIndex: Integer;
  
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileConstFactor');

case Tok.Kind of
  IDENTTOK:
    begin
    IdentIndex := GetIdent(Tok.Name);

    case Ident[IdentIndex].Kind of
    
      GOTOLABEL:
        begin
             Fatal('Constant expression expected but label ' + Ident[IdentIndex].Name + ' found');
             Exit;
         end;
    
      PROC:
        begin
            Fatal('Constant expression expected but procedure ' + Ident[IdentIndex].Name + ' found');
            Exit;
        end;
        
      FUNC:
        if Ident[IdentIndex].PredefProc <> EMPTYPROC then
          CompileConstPredefinedFunc(Ident[IdentIndex].PredefProc, ConstVal, ConstValType)
        else
          Begin
              Fatal('Function ' + Ident[IdentIndex].Name + ' is not allowed in constant expressions');
              Exit
          End;

      VARIABLE:
        Begin
            Fatal('Constant expression expected but variable ' + Ident[IdentIndex].Name + ' found');
            EXIT;
         END;
    
      CONSTANT:
        begin
        ConstValType := Ident[IdentIndex].DataType;
        
        case Types[ConstValType].Kind of
          SETTYPE:   ConstVal.SetValue  := Ident[IdentIndex].ConstVal.SetValue;
          ARRAYTYPE: ConstVal.StrValue  := Ident[IdentIndex].ConstVal.StrValue; 
          REALTYPE:  ConstVal.RealValue := Ident[IdentIndex].ConstVal.RealValue;
          else       ConstVal.OrdValue  := Ident[IdentIndex].ConstVal.OrdValue;
        end;
        
        NextTok;
        end;
        
      USERTYPE:
        BEGIN
            Fatal('Constant expression expected but type ' + Ident[IdentIndex].Name + ' found');
            Exit
        End;

      else
        Begin
            Fatal('Internal fault: Illegal identifier');
            Exit;
         end;
      end; // case Ident[IdentIndex].Kind           
    end;


  INTNUMBERTOK:
    begin
    ConstVal.OrdValue := Tok.OrdValue;
    ConstValType := INTEGERTYPEINDEX;
    NextTok;
    end;


  REALNUMBERTOK:
    begin
    ConstVal.RealValue := Tok.RealValue;
    ConstValType := REALTYPEINDEX;
    NextTok;
    end;


  CHARLITERALTOK:
    begin
    ConstVal.OrdValue := Tok.OrdValue;
    ConstValType := CHARTYPEINDEX;
    NextTok;
    end;
    
    
  STRINGLITERALTOK:
    begin
    ConstVal.StrValue := Tok.Name;
    ConstValType := STRINGTYPEINDEX;
    NextTok;
    end;    


  OPARTOK:
    begin
    NextTok;
    CompileConstExpression(ConstVal, ConstValType);
    EatTok(CPARTOK);
    end;


  NOTTOK:
    begin
    NotOpTok := Tok;
    NextTok;
    CompileConstFactor(ConstVal, ConstValType);
    CheckOperator(NotOpTok, ConstValType);        
    ConstVal.OrdValue := not ConstVal.OrdValue;
    
    if Types[ConstValType].Kind = BOOLEANTYPE then
      ConstVal.OrdValue := ConstVal.OrdValue and 1;
    end;


  OBRACKETTOK:  
    CompileConstSetConstructor(ConstVal, ConstValType); 

else
  Begin
      Fatal('Expression expected but ' + GetTokSpelling(Tok.Kind) + ' found');
      Exit;
  End;
end;// case

end;// CompileConstFactor




procedure CompileConstTerm(var ConstVal: TConst; var ConstValType: Integer);
var
  OpTok: TToken;
  RightConstVal: TConst;
  RightConstValType: Integer;

begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileConstTerm');
CompileConstFactor(ConstVal, ConstValType);

while Tok.Kind in MultiplicativeOperators do
  begin
  OpTok := Tok;
  NextTok;
  CompileConstFactor(RightConstVal, RightConstValType);

  // Try to convert integer to real
  ConvertConstIntegerToReal(RightConstValType, ConstValType, ConstVal);
  ConvertConstIntegerToReal(ConstValType, RightConstValType, RightConstVal);
  
  // Special case: real division of two integers
  if OpTok.Kind = DIVTOK then
    begin
    ConvertConstIntegerToReal(REALTYPEINDEX, ConstValType, ConstVal);
    ConvertConstIntegerToReal(REALTYPEINDEX, RightConstValType, RightConstVal);
    end;
    
  ConstValType := GetCompatibleType(ConstValType, RightConstValType);  
    
  // Special case: set intersection  
  if (OpTok.Kind = MULTOK) and (Types[ConstValType].Kind = SETTYPE) then  
    ConstVal.SetValue := ConstVal.SetValue * RightConstVal.SetValue
  // General rule  
  else
    begin    
    CheckOperator(OpTok, ConstValType);

    if Types[ConstValType].Kind = REALTYPE then        // Real constants
      case OpTok.Kind of
        MULTOK:  ConstVal.RealValue := ConstVal.RealValue * RightConstVal.RealValue;
        DIVTOK:  if RightConstVal.RealValue <> 0 then
                   ConstVal.RealValue := ConstVal.RealValue / RightConstVal.RealValue
                 else
                   Begin
                      Fatal('Constant division by zero');
                      Exit;
                   End;
      end
    else                                               // Integer constants
      begin
      case OpTok.Kind of             
        MULTOK:  ConstVal.OrdValue := ConstVal.OrdValue * RightConstVal.OrdValue;
        IDIVTOK: if RightConstVal.OrdValue <> 0 then
                   ConstVal.OrdValue := ConstVal.OrdValue div RightConstVal.OrdValue
                 else
                   Begin
                       Fatal('Constant division by zero');
                       Exit;
                    end;
        MODTOK:  if RightConstVal.OrdValue <> 0 then
                   ConstVal.OrdValue := ConstVal.OrdValue mod RightConstVal.OrdValue
                 else
                   Begin
                       Fatal('Constant division by zero');
                       Exit;
                   end;

        SHLTOK:  ConstVal.OrdValue := ConstVal.OrdValue shl RightConstVal.OrdValue;
        SHRTOK:  ConstVal.OrdValue := ConstVal.OrdValue shr RightConstVal.OrdValue;
        ANDTOK:  ConstVal.OrdValue := ConstVal.OrdValue and RightConstVal.OrdValue;
      end;
      
      if Types[ConstValType].Kind = BOOLEANTYPE then
        ConstVal.OrdValue := ConstVal.OrdValue and 1;
      end // else  
    end; // else
  end;// while

end;// CompileConstTerm



procedure CompileSimpleConstExpression(var ConstVal: TConst; var ConstValType: Integer);
var
  UnaryOpTok, OpTok: TToken;
  RightConstVal: TConst;
  RightConstValType: Integer;

begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileSimpleConstExpression');
UnaryOpTok := Tok;
if UnaryOpTok.Kind in UnaryOperators then
  NextTok;

CompileConstTerm(ConstVal, ConstValType);

if UnaryOpTok.Kind in UnaryOperators then
  CheckOperator(UnaryOpTok, ConstValType);

if UnaryOpTok.Kind = MINUSTOK then      // Unary minus
  if Types[ConstValType].Kind = REALTYPE then
    ConstVal.RealValue := -ConstVal.RealValue
  else
    ConstVal.OrdValue := -ConstVal.OrdValue;

while Tok.Kind in AdditiveOperators do
  begin
  OpTok := Tok;
  NextTok;
  CompileConstTerm(RightConstVal, RightConstValType);

  // Try to convert integer to real
  ConvertConstIntegerToReal(RightConstValType, ConstValType, ConstVal);
  ConvertConstIntegerToReal(ConstValType, RightConstValType, RightConstVal);
  
  // Try to convert character to string
  ConvertConstCharToString(RightConstValType, ConstValType, ConstVal);
  ConvertConstCharToString(ConstValType, RightConstValType, RightConstVal);

  ConstValType := GetCompatibleType(ConstValType, RightConstValType); 
      
  // Special case: string concatenation
  if (OpTok.Kind = PLUSTOK) and IsString(ConstValType) and IsString(RightConstValType) then
    ConstVal.StrValue := ConstVal.StrValue + RightConstVal.StrValue
  // Special case: set union or difference  
  else if (OpTok.Kind in [PLUSTOK, MINUSTOK]) and (Types[ConstValType].Kind = SETTYPE) then
    ConstVal.SetValue := ConstVal.SetValue + RightConstVal.SetValue  
  // General rule
  else
    begin  
    CheckOperator(OpTok, ConstValType);

    if Types[ConstValType].Kind = REALTYPE then       // Real constants
      case OpTok.Kind of
        PLUSTOK:  ConstVal.RealValue := ConstVal.RealValue + RightConstVal.RealValue;
        MINUSTOK: ConstVal.RealValue := ConstVal.RealValue - RightConstVal.RealValue;
      end
    else                                                  // Integer constants
      begin
      case OpTok.Kind of
        PLUSTOK:  ConstVal.OrdValue := ConstVal.OrdValue  +  RightConstVal.OrdValue;
        MINUSTOK: ConstVal.OrdValue := ConstVal.OrdValue  -  RightConstVal.OrdValue;
        ORTOK:    ConstVal.OrdValue := ConstVal.OrdValue  or RightConstVal.OrdValue;
        XORTOK:   ConstVal.OrdValue := ConstVal.OrdValue xor RightConstVal.OrdValue;
      end;
      
      if Types[ConstValType].Kind = BOOLEANTYPE then
        ConstVal.OrdValue := ConstVal.OrdValue and 1;
      end;  
    end;

  end;// while

end;// CompileSimpleConstExpression



procedure CompileConstExpression(var ConstVal: TConst; var ConstValType: Integer);
var
  OpTok: TToken;
  RightConstVal: TConst;
  RightConstValType: Integer;
  Yes: Boolean;

begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileConstExpression');
Yes := FALSE;
CompileSimpleConstExpression(ConstVal, ConstValType);

if Tok.Kind in RelationOperators then
  begin
  OpTok := Tok;
  NextTok;
  CompileSimpleConstExpression(RightConstVal, RightConstValType);

  // Try to convert integer to real
  ConvertConstIntegerToReal(RightConstValType, ConstValType, ConstVal);
  ConvertConstIntegerToReal(ConstValType, RightConstValType, RightConstVal);
  
  // Try to convert character to string
  ConvertConstCharToString(RightConstValType, ConstValType, ConstVal);
  ConvertConstCharToString(ConstValType, RightConstValType, RightConstVal); 

  GetCompatibleType(ConstValType, RightConstValType);    
    
  // Special case: string comparison
  if IsString(ConstValType) and IsString(RightConstValType) then
    case OpTok.Kind of 
      EQTOK: Yes := ConstVal.StrValue =  RightConstVal.StrValue;
      NETOK: Yes := ConstVal.StrValue <> RightConstVal.StrValue;
      LTTOK: Yes := ConstVal.StrValue <  RightConstVal.StrValue;
      LETOK: Yes := ConstVal.StrValue <= RightConstVal.StrValue;
      GTTOK: Yes := ConstVal.StrValue >  RightConstVal.StrValue;
      GETOK: Yes := ConstVal.StrValue >= RightConstVal.StrValue;    
    end
  // Special case: set comparison
  else if (OpTok.Kind in [EQTOK, NETOK, GETOK, LETOK]) and (Types[ConstValType].Kind = SETTYPE) then
    case OpTok.Kind of 
      EQTOK: Yes := ConstVal.SetValue =  RightConstVal.SetValue;
      NETOK: Yes := ConstVal.SetValue <> RightConstVal.SetValue;
      LETOK: Yes := ConstVal.SetValue <= RightConstVal.SetValue;
      GETOK: Yes := ConstVal.SetValue >= RightConstVal.SetValue;    
    end 
  // General rule  
  else
    begin
    CheckOperator(OpTok, ConstValType);

    if Types[ConstValType].Kind = REALTYPE then
      case OpTok.Kind of
        EQTOK: Yes := ConstVal.RealValue =  RightConstVal.RealValue;
        NETOK: Yes := ConstVal.RealValue <> RightConstVal.RealValue;
        LTTOK: Yes := ConstVal.RealValue <  RightConstVal.RealValue;
        LETOK: Yes := ConstVal.RealValue <= RightConstVal.RealValue;
        GTTOK: Yes := ConstVal.RealValue >  RightConstVal.RealValue;
        GETOK: Yes := ConstVal.RealValue >= RightConstVal.RealValue;
      end
    else
      case OpTok.Kind of
        EQTOK: Yes := ConstVal.OrdValue =  RightConstVal.OrdValue;
        NETOK: Yes := ConstVal.OrdValue <> RightConstVal.OrdValue;
        LTTOK: Yes := ConstVal.OrdValue <  RightConstVal.OrdValue;
        LETOK: Yes := ConstVal.OrdValue <= RightConstVal.OrdValue;
        GTTOK: Yes := ConstVal.OrdValue >  RightConstVal.OrdValue;
        GETOK: Yes := ConstVal.OrdValue >= RightConstVal.OrdValue;
      end;
    end;
    
  if Yes then ConstVal.OrdValue := 1 else ConstVal.OrdValue := 0;    
  ConstValType := BOOLEANTYPEINDEX;      
  end;  

end;// CompileConstExpression




procedure CompilePredefinedProc(proc: TPredefProc; LoopNesting: Integer);

  // CHANGEME: If we switch to pointers, NIL needs to be used instead of 0
  function GetReadProcIdent(DataType: Integer): Integer;
  begin
      If  (ActivityCTrace in TraceCompiler) then EmitHint('f GetReadProcIdent');
  Result := 0;
  
  with Types[DataType] do
    if (Kind = INT128TYPE) or ((Kind = SUBRANGETYPE) and (Types[BaseType].Kind = INT128TYPE)) then
      Result := GetIdent('XDP_READINT128')                 // Integer argument

    else if (Kind = INT64TYPE) or ((Kind = SUBRANGETYPE) and (Types[BaseType].Kind = INT64TYPE)) then
      Result := GetIdent('XDP_READINT64')                 // 64-bit Integer argument

    else if (Kind = INTEGERTYPE) or ((Kind = SUBRANGETYPE) and (Types[BaseType].Kind = INTEGERTYPE)) then
        Result := GetIdent('XDP_READINT')                 // Integer argument

    else if (Kind = SMALLINTTYPE) or ((Kind = SUBRANGETYPE) and (Types[BaseType].Kind = SMALLINTTYPE)) then
      Result := GetIdent('XDP_READSMALLINT')            // Small integer argument
          
    else if (Kind = SHORTINTTYPE) or ((Kind = SUBRANGETYPE) and (Types[BaseType].Kind = SHORTINTTYPE)) then
      Result := GetIdent('XDP_READSHORTINT')            // Short integer argument
          
    else if (Kind = WORDTYPE) or ((Kind = SUBRANGETYPE) and (Types[BaseType].Kind = WORDTYPE)) then
      Result := GetIdent('XDP_READWORD')                // Word argument

    else if (Kind = BYTETYPE) or ((Kind = SUBRANGETYPE) and (Types[BaseType].Kind = BYTETYPE)) then
      Result := GetIdent('XDP_READBYTE')                // Byte argument
         
    else if (Kind = BOOLEANTYPE) or ((Kind = SUBRANGETYPE) and (Types[BaseType].Kind = BOOLEANTYPE)) then
      Result := GetIdent('XDP_READBOOLEAN')             // Boolean argument
    
    else if (Kind = CHARTYPE) or ((Kind = SUBRANGETYPE) and (Types[BaseType].Kind = CHARTYPE)) then
      Result := GetIdent('XDP_READCH')                  // Character argument
          
    else if (Kind = CURRENCYTYPE)  or ((Kind = SUBRANGETYPE) and (Types[BaseType].Kind = CURRENCYTYPE)) then
      Result := GetIdent('XDP_READCURRENCY')                // Real argument

    else if Kind = REALTYPE then
      Result := GetIdent('XDP_READREAL')                // Real argument
      
    else if Kind = SINGLETYPE then
      Result := GetIdent('XDP_READSINGLE')              // Single argument      
          
    else if (Kind = ARRAYTYPE) and (BaseType = CHARTYPEINDEX) then
      Result := GetIdent('XDP_READSTRING')              // String argument
          
    else
      Begin
          Fatal('Cannot read ' + GetTypeSpelling(DataType));
          Exit;
       End;
 
  end; // GetReadProcIdent
  
  
  
  function GetWriteProcIdent(DataType: Integer): Integer;
  begin
      If  (ActivityCTrace in TraceCompiler) then EmitHint('f GetWriteProcIdent');
  Result := 0;
  
  with Types[DataType] do
    if (Kind in IntegerTypes) or ((Kind = SUBRANGETYPE) and (Types[BaseType].Kind in IntegerTypes)) then
      Result := GetIdent('XDP_WRITEINTF')                 // Integer argument
          
    else if (Kind = BOOLEANTYPE) or ((Kind = SUBRANGETYPE) and (Types[BaseType].Kind = BOOLEANTYPE)) then
      Result := GetIdent('XDP_WRITEBOOLEANF')             // Boolean argument
          
    else if Kind = REALTYPE then
      Result := GetIdent('XDP_WRITEREALF')                // Real argument
          
    else if Kind = POINTERTYPE then
      Result := GetIdent('XDP_WRITEPOINTERF')             // Pointer argument

    else if Kind = INT64TYPE then                     // 64-bit integer
      Result := GetIdent('XDP_WRITEINT64F')

    else if Kind = INT128TYPE then                     // 128-bit integer
      Result := GetIdent('XDP_WRITEINT128F')

    else if Kind = CURRENCYTYPE then                   // 31-DIGIT REAL
      Result := GetIdent('XDP_WRITECURRENCYF')

    else if (Kind = ARRAYTYPE) and (BaseType = CHARTYPEINDEX) then
      Result := GetIdent('XDP_WRITESTRINGF')              // String argument
          
    else
      Begin
          Fatal('Cannot write ' + GetTypeSpelling(DataType));
          Exit;
      End;
  end; // GetWriteProcIdentIndex
  
 

var
  DesignatorType, FileVarType, ExpressionType, FormatterType: Integer;
  LibProcIdentIndex, ConsoleIndex: Integer;
  IsFirstParam: Boolean;

  
begin // CompilePredefinedProc
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompilePredefinedProc');
NextTok;

case proc of
  INCPROC, DECPROC:
    begin
    EatTok(OPARTOK);
    CompileDesignator(DesignatorType, FALSE);
    
    if (Types[DesignatorType].Kind = POINTERTYPE) and (Types[DesignatorType].BaseType <> ANYTYPEINDEX) then     // Special case: typed pointer
      GenerateIncDec(proc, TypeSize(DesignatorType), TypeSize(Types[DesignatorType].BaseType))
    else                                                                                                        // General rule
      begin  
      GetCompatibleType(DesignatorType, INTEGERTYPEINDEX);
      GenerateIncDec(proc, TypeSize(DesignatorType));
      end;
      
    EatTok(CPARTOK);
    end;


  READPROC, READLNPROC:
    begin
    ConsoleIndex := GetIdent('INPUT');
    FileVarType := ANYTYPEINDEX;
    IsFirstParam := TRUE;

    if Tok.Kind = OPARTOK then
    begin
      repeat
        // 1st argument - file handle
        if FileVarType <> ANYTYPEINDEX then
          DuplicateStackTop
        else
          PushVarIdentPtr(ConsoleIndex);

        // 2nd argument - stream handle
        PushConst(0);
        
        // 3rd argument - designator
        CompileDesignator(DesignatorType, FALSE);

        if Types[DesignatorType].Kind = FILETYPE then               // File handle
          begin
          if not IsFirstParam or ((proc = READLNPROC) and
                (Types[DesignatorType].BaseType <> ANYTYPEINDEX)) then
            Begin
                Fatal('Cannot read ' + GetTypeSpelling(DesignatorType));
                Exit;
            end;
          FileVarType := DesignatorType;          
          end
        else                                                        // Any input variable
          begin
          // Select input subroutine
          if (Types[FileVarType].Kind = FILETYPE) and (Types[FileVarType].BaseType <> ANYTYPEINDEX) then      // Read from typed file
            begin            
            GetCompatibleRefType(Types[FileVarType].BaseType, DesignatorType);
            
            // 4th argument - record length 
            PushConst(TypeSize(Types[FileVarType].BaseType));
 
            LibProcIdentIndex := GetIdent('XDP_READREC');
            end
          else                                                                                                // Read from text file 
            LibProcIdentIndex := GetReadProcIdent(DesignatorType);  
            
          // Call selected input subroutine. Interface: FileHandle; StreamHandle; var Designator [; Length]  
          GenerateCall(Ident[LibProcIdentIndex].Address, BlockStackTop - 1, Ident[LibProcIdentIndex].NestingLevel);
          end; // else

        IsFirstParam := FALSE;

        if Tok.Kind <> COMMATOK then Break;
        NextTok;
      until FALSE;
      EatTok(CPARTOK);
      end; // if OPARTOR
      
      
    // Add CR+LF, if necessary
    if proc = READLNPROC then
      begin
      // 1st argument - file handle
      if FileVarType <> ANYTYPEINDEX then
        DuplicateStackTop
      else
        PushVarIdentPtr(ConsoleIndex);
        
      // 2nd argument - stream handle
      PushConst(0);  
      
      LibProcIdentIndex := GetIdent('XDP_READNEWLINE');
      GenerateCall(Ident[LibProcIdentIndex].Address, BlockStackTop - 1, Ident[LibProcIdentIndex].NestingLevel);

      end;
      
    // Remove first 3 arguments if they correspond to a file variable 
    if FileVarType <> ANYTYPEINDEX then
      DiscardStackTop(3);


    end;// READPROC, READLNPROC


  WRITEPROC, WRITELNPROC:
    begin
    ConsoleIndex := GetIdent('OUTPUT');
    FileVarType := ANYTYPEINDEX;
    IsFirstParam := TRUE;

    if Tok.Kind = OPARTOK then
      begin
      NextTok;

      repeat
        // 1st argument - file handle
        if FileVarType <> ANYTYPEINDEX then
          DuplicateStackTop
        else
          PushVarIdentPtr(ConsoleIndex);

        // 2nd argument - stream handle
        PushConst(0);
        
        // 3rd argument - expression (for untyped/text files) or designator (for typed files)
        if (Types[FileVarType].Kind = FILETYPE) and (Types[FileVarType].BaseType <> ANYTYPEINDEX) then
          CompileDesignator(ExpressionType)
        else
          begin
          CompileExpression(ExpressionType);
          
          // Try to convert single to double
          ConvertRealToReal(REALTYPEINDEX, ExpressionType);
          
          // Try to convert character to string
          ConvertCharToString(STRINGTYPEINDEX, ExpressionType, 0);
          end;
        
        if Types[ExpressionType].Kind = FILETYPE then           // File handle
          begin
          if not IsFirstParam or ((proc = WRITELNPROC) and
                (Types[ExpressionType].BaseType <> ANYTYPEINDEX)) then
               Begin
                  Fatal('Cannot write ' + GetTypeSpelling(ExpressionType));
                  Exit;
               end;
          FileVarType := ExpressionType;
          end
        else                                                    // Any output expression
          begin
          // 4th argument - minimum width
          if Tok.Kind = COLONTOK then
            begin                         // 4th argument
            // allow explicit "file of char"
            if (Types[FileVarType].Kind = FILETYPE) and
               ((Types[FileVarType].BaseType <> ANYTYPEINDEX) or
                (Types[FileVarType].BaseType <> CHARTYPEINDEX))  then
                Err(ERR_122);        // Format specifiers only allowed for untyped or file of char

            NextTok;                       // 4th argument value
            CompileExpression(FormatterType);
            GetCompatibleType(FormatterType, INTEGERTYPEINDEX);
            
            // 5th argument - number of decimal places
            // reserved for real only, but I'm going to cheat
//          if (Tok.Kind = COLONTOK) and (Types[ExpressionType].Kind = REALTYPE) then
            if (Tok.Kind = COLONTOK) then
              begin
              if (Types[ExpressionType].Kind <> REALTYPE) then
                  Err(ERR_124);  // F-format for real only
              NextTok;
              CompileExpression(FormatterType);
              GetCompatibleType(FormatterType, INTEGERTYPEINDEX);
              end
            else                 // no 5th
              PushConst(0);
 
            end            
          else
            begin   // No 4th or 5th argument
            PushConst(0);
            PushConst(0);
            end;            
          
          // Select output subroutine
          if (Types[FileVarType].Kind = FILETYPE) and (Types[FileVarType].BaseType <> ANYTYPEINDEX) then      // Write to typed file                                                     
            begin           
            GetCompatibleRefType(Types[FileVarType].BaseType, ExpressionType);
            
            // Discard 4th and 5th arguments - format specifiers
            DiscardStackTop(2); 
  
            // 4th argument - record length 
            PushConst(TypeSize(Types[FileVarType].BaseType));
            
            LibProcIdentIndex := GetIdent('XDP_WRITEREC');
            end 
          else                                                                                                // Write to text file
            LibProcIdentIndex := GetWriteProcIdent(ExpressionType);
            
          // Call selected output subroutine. Interface: FileHandle; StreamHandle; (Designator | Expression); (Length; | MinWidth; DecPlaces)
          GenerateCall(Ident[LibProcIdentIndex].Address, BlockStackTop - 1, Ident[LibProcIdentIndex].NestingLevel);
          end; // else

        IsFirstParam := FALSE;

        if Tok.Kind <> COMMATOK then Break;
        NextTok;
      until FALSE;
      
      EatTok(CPARTOK);
      end; // if OPARTOR
      
      
    // Add CR+LF, if necessary
    if proc = WRITELNPROC then
      begin
      LibProcIdentIndex := GetIdent('XDP_WRITENEWLINE');
      
      // 1st argument - file handle
      if FileVarType <> ANYTYPEINDEX then
        DuplicateStackTop
      else
        PushVarIdentPtr(ConsoleIndex);
        
      // 2nd argument - stream handle
      PushConst(0);         

      GenerateCall(Ident[LibProcIdentIndex].Address, BlockStackTop - 1, Ident[LibProcIdentIndex].NestingLevel);
      end;

    // Remove first 3 arguments if they correspond to a file variable 
    if FileVarType <> ANYTYPEINDEX then
      DiscardStackTop(3);
    
    end;// WRITEPROC, WRITELNPROC
    

  NEWPROC, DISPOSEPROC:
    begin
    EatTok(OPARTOK);
    CompileDesignator(DesignatorType, FALSE);
    GetCompatibleType(DesignatorType, POINTERTYPEINDEX);
    
    if proc = NEWPROC then
      begin
      PushConst(TypeSize(Types[DesignatorType].BaseType));
      LibProcIdentIndex := GetIdent('GETMEM');
      end
    else
      LibProcIdentIndex := GetIdent('FREEMEM');
 
    GenerateCall(Ident[LibProcIdentIndex].Address, BlockStackTop - 1, Ident[LibProcIdentIndex].NestingLevel);
    
    EatTok(CPARTOK);
    end;
    
    
  BREAKPROC:
    begin
    if LoopNesting < 1 then
      begin
          Fatal('BREAK outside of loop is not allowed');
          Exit;
      end;    
    GenerateBreakCall(LoopNesting);
    end;
  

  CONTINUEPROC:      // loop CONTINUE
    begin
    if LoopNesting < 1 then
       Begin
           Fatal('CONTINUE outside of loop is not allowed');
           Exit;
       end;    
    GenerateContinueCall(LoopNesting);
    end;
    
    
  EXITPROC:             // Procedure EXIT
    GenerateExitCall;
  

  HALTPROC:               // HALT program
    begin
    if Tok.Kind = OPARTOK then   // Halt( integer )
      begin
      NextTok;
      CompileExpression(ExpressionType);
      GetCompatibleType(ExpressionType, INTEGERTYPEINDEX);
      EatTok(CPARTOK);
      end
    else
      PushConst(0);           // HALT(0)
      
    LibProcIdentIndex := GetIdent('EXITPROCESS');
    GenerateCall(Ident[LibProcIdentIndex].Address, 1, 1);
    end;

    INLINEPROC:
      BEGIN
          EatTok(OPARTOK);
         // MORE LATER: THERE WILL BE FOUR OPTIONS:
         // PUT BYTE, PUT WORD, PUT INTEGER, PUT ADDRESS
         // ARGS ARE SEPARATED BY /
         repeat
              nexttok ;

         until (tok.kind = CPARTOK) or Scannerstate.EndOfUnit;
         Err(Err_72);   // not implemented, (just error, not fatal)
{

          REPEAT
               NextTok;
               CompileExpression(ExpressionType);
               GetCompatibleType(ExpressionType, INTEGERTYPEINDEX);



              NextTok;
              // process some kind of argument
              if Tok.kind=IDENTTOK then
              begin
                   if tok.Name='WORD' then
                   begin
                       EatTok(OPARTOK);


                       EatTok(CPARTOK);
                   end
                   else if  tok.Name='BYTE' then
                   begin
                       EatTok(OPARTOK);


                       EatTok(CPARTOK);
                   end
                   else if tok.name='INT' THEN
                   BEGIN
                       EatTok(OPARTOK);


                       EatTok(CPARTOK);
                   end
                   ELSE // USE ADDRESS OF IDENTIFIER
                   BEGIN

                   end;
              end;

          until Tok.Kind<>DIVTOK ;
}
          EatTok(CPARTOK);

      end;

end;// case

end;// CompilePredefinedProc



 // FIXME when using pointers for identifier tanle
procedure CompilePredefinedFunc(func: TPredefProc; var ValType: Integer);
var
  IdentIndex: Integer;
  ProcType:String[5];

begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompilePredefinedFunc');
NextTok;
EatTok(OPARTOK);

case func of

  SIZEOFFUNC:                 // SizeOf(
    begin
    AssertIdent;
    IdentIndex := GetIdentUnsafe(Tok.Name);
    if (IdentIndex <> 0) and (Ident[IdentIndex].Kind = USERTYPE) then   // Type name
      begin
      NextTok;
      PushConst(TypeSize(Ident[IdentIndex].DataType));
      end
    else                                                                // Variable name
      begin
      CompileDesignator(ValType);
      DiscardStackTop(1);
      PushConst(TypeSize(ValType));
      end;
    ValType := INTEGERTYPEINDEX;
    end;
    

  ROUNDFUNC, TRUNCFUNC:                // Round(, Trunc(
    begin
    CompileExpression(ValType);

    // Try to convert integer to real
    ConvertIntegerToReal(REALTYPEINDEX, ValType, 0);
    
    GetCompatibleType(ValType, REALTYPEINDEX);
    GenerateRound(func = TRUNCFUNC);
    ValType := INTEGERTYPEINDEX;
    end;
    

  ORDFUNC:                              // ORD(
    begin
    CompileExpression(ValType);
    if not (Types[ValType].Kind in OrdinalTypes) then
      Begin
          Fatal('Ordinal type expected for ORD function');
          Exit;
       end;   
    ValType := INTEGERTYPEINDEX;
    end;
    

  CHRFUNC:                            // CHR(
    begin
    CompileExpression(ValType);
    GetCompatibleType(ValType, INTEGERTYPEINDEX);
    ValType := CHARTYPEINDEX;
    end;    


  LOWFUNC, HIGHFUNC:                   // Lo(, High(
    begin
    AssertIdent;
    IdentIndex := GetIdentUnsafe(Tok.Name);
    if (IdentIndex <> 0) and (Ident[IdentIndex].Kind = USERTYPE) then   // Type name
      begin
      NextTok;
      ValType := Ident[IdentIndex].DataType;
      end
    else                                                                // Variable name
      begin
      CompileDesignator(ValType);
      DiscardStackTop(1);
      end;
          
    if (Types[ValType].Kind = ARRAYTYPE) and not Types[ValType].IsOpenArray then
      ValType := Types[ValType].IndexType;
    if func = HIGHFUNC then  
      PushConst(HighBound(ValType))
    else
      PushConst(LowBound(ValType)); 
    end;


  PREDFUNC, SUCCFUNC:                    // Pred(, Succ(
    begin
    CompileExpression(ValType);
    if not (Types[ValType].Kind in OrdinalTypes) then
      begin
         if func = PREDFUNC then procType := 'pred' else procType := 'succ';
         Fatal('Ordinal type expected for '+procType+' Function');
         Exit;
       end;  
    if func = SUCCFUNC then
      PushConst(1)
    else
      PushConst(-1);
    GenerateBinaryOperator(PLUSTOK, INTEGERTYPEINDEX);
    end;
    

  ABSFUNC,    SQRFUNC, SINFUNC, COSFUNC,  //  ABS(, SQR(, SIN(, COS(
  ARCTANFUNC, EXPFUNC, LNFUNC,  SQRTFUNC: //  ARCTAN(, EXP(, LN(, SQRT(
    begin
    CompileExpression(ValType);
    if (func = ABSFUNC) or (func = SQRFUNC) then                          // Abs and Sqr accept real or integer parameters
      begin
      if not ((Types[ValType].Kind in NumericTypes) or
             ((Types[ValType].Kind = SUBRANGETYPE) and 
             (Types[Types[ValType].BaseType].Kind in NumericTypes))) then
         Begin
             if func = ABSFUNC then procType := 'abs' else procType := 'sqr';
             Fatal('Numeric type expected for '+procType+' function');
             Exit;
         end;    
      end
    else
      begin
      // Try to convert integer to real
      ConvertIntegerToReal(REALTYPEINDEX, ValType, 0);
      GetCompatibleType(ValType, REALTYPEINDEX);
      end;

    GenerateMathFunction(func, ValType);
    end;
    
end;// case

EatTok(CPARTOK);
end;// CompilePredefinedFunc




procedure CompileTypeIdent(var DataType: Integer; AllowForwardReference: Boolean);
var
  IdentIndex: Integer;
begin
     If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileTypeIdent');
// STRING, FILE or type name allowed
case Tok.Kind of
  STRINGTOK:
    DataType := STRINGTYPEINDEX;
  FILETOK:
    DataType := FILETYPEINDEX
else
  AssertIdent;
  
  if AllowForwardReference then
    IdentIndex := GetIdentUnsafe(Tok.Name, AllowForwardReference)
  else
    IdentIndex := GetIdent(Tok.Name, AllowForwardReference);                         
  
  if AllowForwardReference and ((IdentIndex = 0) or (Ident[IdentIndex].Block <> BlockStack[BlockStackTop].Index)) then
    begin
    // Add new forward-referenced type
    DeclareType(FORWARDTYPE);
    Types[NumTypes].TypeIdentName := Tok.Name;
    DataType := NumTypes;
    end
  else
    begin
    // Use existing type
    if Ident[IdentIndex].Kind <> USERTYPE then
      Begin
          Fatal('Type name expected');
          Exit;
       end;
    DataType := Ident[IdentIndex].DataType;
    end;
end; // case

NextTok;
end; // CompileTypeIdent
  



procedure CompileFormalParametersAndResult(IsFunction: Boolean; var Signature: TSignature);
var
  IdentInListName: array [1..MAXPARAMS] of TString;
  NumIdentInList, IdentInListIndex: Integer;  
  ParamType, DefaultValueType: Integer;    
  ListPassMethod: TPassMethod;
  IsOpenArrayList, StringByValFound: Boolean;
  Default: TConst;
  
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileFormalParametersAndResult');
Signature.NumParams := 0;
Signature.NumDefaultParams := 0;

StringByValFound := FALSE;
  
if Tok.Kind = OPARTOK then    // procedure or function template as in Type x = Procedure(a:integer...
  begin
  NextTok;
  repeat
    NumIdentInList := 0;
    ListPassMethod := VALPASSING;

    if Tok.Kind = CONSTTOK then      // CONST in Procedure a(const
      begin
      ListPassMethod := CONSTPASSING;
      NextTok;
      end
    else if Tok.Kind = VARTOK then    // VAR in Procedure a(var ...
      begin
      ListPassMethod := VARPASSING;
      NextTok;
      end;

    repeat
      AssertIdent;

      Inc(NumIdentInList);
      IdentInListName[NumIdentInList] := Tok.Name;

      NextTok;

      if Tok.Kind <> COMMATOK then Break;
      NextTok;
    until FALSE;

    
    // Formal parameter list type
    if Tok.Kind = COLONTOK then                       // Typed parameters 
      begin
      NextTok;
    
      // Special case: open array parameters
      if Tok.Kind = ARRAYTOK then
        begin
        NextTok;
        EatTok(OFTOK);           // OF in (open) ARRAY OF
        if (TokenCTrace in TraceCompiler) or (KeywordCTrace in TraceCompiler) then
           EmitToken('OF');
        IsOpenArrayList := TRUE;
        end
      else
        IsOpenArrayList := FALSE;
 
      // Type itself
      CompileTypeIdent(ParamType, FALSE);          
                 
      // Special case: open array parameters
      if IsOpenArrayList then
        begin
        // Add new anonymous type 0..0 for array index
        DeclareType(SUBRANGETYPE);
        
        Types[NumTypes].BaseType    := INTEGERTYPEINDEX;
        Types[NumTypes].Low         := 0;
        Types[NumTypes].High        := 0;
        
        // Add new anonymous type for array itself
        DeclareType(ARRAYTYPE);
        
        Types[NumTypes].BaseType    := ParamType;
        Types[NumTypes].IndexType   := NumTypes - 1;
        Types[NumTypes].IsOpenArray := TRUE;
        
        ParamType := NumTypes;
        end;  
      end
    else                                              // Untyped parameters (CONST or VAR only) 
      ParamType := ANYTYPEINDEX;

    
    if (ListPassMethod <> VARPASSING) and 
       (ParamType = ANYTYPEINDEX) then
       Begin
           Fatal('Untyped parameters require VAR');
           Exit;
        end;
    if (ListPassMethod = VALPASSING) and IsString(ParamType) then
      StringByValFound := TRUE;
      

    // Default parameter value
    if (Tok.Kind = EQTOK) or (Signature.NumDefaultParams > 0) then
      begin
      EatTok(EQTOK);
      
      if not (Types[ParamType].Kind in 
             OrdinalTypes + [REALTYPE]) then
          Begin   
             Fatal('Ordinal or real type expected for default parameter');
             Exit;
          End;
      if ListPassMethod <> VALPASSING then
         Begin
             Fatal('Default parameters (in '+
                   Parserstate.ProcFuncName +
                   ') cannot be passed by reference');
             Exit;
          End;
      CompileConstExpression(Default, DefaultValueType);
      GetCompatibleType(ParamType, DefaultValueType);
        
      Inc(Signature.NumDefaultParams);
      end;
      

    for IdentInListIndex := 1 to NumIdentInList do
      begin
      Inc(Signature.NumParams);

      if Signature.NumParams > MAXPARAMS then
        Begin
            Fatal('Too many formal parameters');
            Exit;
	End;
      New(Signature.Param[Signature.NumParams]);

      with Signature, Param[NumParams]^ do
        begin
        Name             := IdentInListName[IdentInListIndex];
        DataType         := ParamType;
        PassMethod       := ListPassMethod;
        Default.OrdValue := 0;
        end;
      
      // Default parameter value
      if (Signature.NumDefaultParams > 0) and (IdentInListIndex = 1) then
        begin
        if NumIdentInList > 1 then
          Begin
              Fatal('Default parameters cannot be grouped');          
              Exit;
           end;   
        Signature.Param[Signature.NumParams]^.Default := Default; 
        end;
        
      end;// for
      

    if Tok.Kind <> SEMICOLONTOK then Break;
    NextTok;
  until FALSE;

  EatTok(CPARTOK);
  end;// if Tok.Kind = OPARTOK


// Function result type
Signature.ResultType := 0;

if IsFunction then
  begin
  EatTok(COLONTOK);  
  CompileTypeIdent(Signature.ResultType, FALSE);
  end;
  
  
// Call modifier
if (Tok.Kind = IDENTTOK) and (Tok.Name = 'STDCALL') then
  begin    
  Signature.CallConv := STDCALLCONV;
  NextTok;
  end
else if (Tok.Kind = IDENTTOK) and (Tok.Name = 'CDECL') then
  begin    
  Signature.CallConv := CDECLCONV;
  NextTok;
  end  
else  
  Signature.CallConv := DEFAULTCONV;
  
if (Signature.CallConv <> DEFAULTCONV) and 
    StringByValFound then
    Begin
        Fatal('Strings cannot be passed by value to STDCALL/CDECL procedures');  
        Exit;
    End;    
  
end; // CompileFormalParametersAndResult




procedure CompileActualParameters(const Signature: TSignature; var StructuredResultAddr: LongInt);


  procedure CompileExpressionCopy(var ValType: Integer; CallConv: TCallConv);
  var
    TempStorageAddr: Integer;
    LibProcIdentIndex: Integer;

  begin
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileExpressionCopy');
  CompileExpression(ValType);
  
  // Copy structured parameter passed by value (for STDCALL/CDECL functions there is no need to do it here since it will be done in MakeCStack)
  if (Types[ValType].Kind in StructuredTypes) and (CallConv = DEFAULTCONV) then
    begin
    SaveStackTopToEAX; 
    TempStorageAddr := AllocateTempStorage(TypeSize(ValType));
    PushTempStoragePtr(TempStorageAddr);
    RestoreStackTopFromEAX;
    
    if IsString(ValType) then
      begin 
      LibProcIdentIndex := GetIdent('ASSIGNSTR');    
      GenerateCall(Ident[LibProcIdentIndex].Address, BlockStackTop - 1, Ident[LibProcIdentIndex].NestingLevel);    
      end
    else
      GenerateStructuredAssignment(ValType);

    PushTempStoragePtr(TempStorageAddr);
    end;
    
  end; // CompileExpressionCopy
    

var
  NumActualParams: Integer;
  ActualParamType: Integer;
  DefaultParamIndex: Integer;
  CurParam: PParam;
  
begin    // CompileActualParameters
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileActualParameters');
// Allocate space for structured Result as a hidden VAR parameter (except STDCALL/CDECL functions returning small structures in EDX:EAX)
with Signature do
  if (ResultType <> 0) and (Types[ResultType].Kind in StructuredTypes) and ((CallConv = DEFAULTCONV) or (TypeSize(ResultType) > 2 * SizeOf(LongInt))) then
    begin
    StructuredResultAddr := AllocateTempStorage(TypeSize(ResultType));
    PushTempStoragePtr(StructuredResultAddr);
    end
  else
    StructuredResultAddr := 0;  

NumActualParams := 0;

if Tok.Kind = OPARTOK then                            // Actual parameter list found
  begin
  NextTok;
  
  if Tok.Kind <> CPARTOK then
    repeat
      if NumActualParams + 1 > Signature.NumParams then
        begin
            Fatal('Too many actual parameters (in call to '+Parserstate.ProcFuncName+')');
            Exit;
         end;
      CurParam := Signature.Param[NumActualParams + 1];

      case CurParam^.PassMethod of
        VALPASSING:   CompileExpressionCopy(ActualParamType, Signature.CallConv);
        CONSTPASSING: CompileExpression(ActualParamType);
        VARPASSING:   CompileDesignator(ActualParamType, CurParam^.DataType = ANYTYPEINDEX);
      else
        Begin
           Fatal('Internal fault: Illegal parameter passing method (in call to '+Parserstate.ProcFuncName+')');
           Exit;
         end;  
      end;

      Inc(NumActualParams);

      // Try to convert integer to double, single to double or double to single 
      if CurParam^.PassMethod <> VARPASSING then
        begin
        ConvertIntegerToReal(CurParam^.DataType, ActualParamType, 0);
        ConvertRealToReal(CurParam^.DataType, ActualParamType);
        end;        
       
      // Try to convert character to string
      ConvertCharToString(CurParam^.DataType, ActualParamType, 0);

      // Try to convert string to pointer to character
      ConvertStringToPChar(CurParam^.DataType, ActualParamType);      
        
      // Try to convert a concrete type to an interface type
      ConvertToInterface(CurParam^.DataType, ActualParamType);
      
      if CurParam^.PassMethod = VARPASSING then  
        GetCompatibleRefType(CurParam^.DataType, ActualParamType)  // Strict type checking for parameters passed by reference, except for open array parameters and untyped parameters
      else      
        GetCompatibleType(CurParam^.DataType, ActualParamType);    // Relaxed type checking for parameters passed by value
         
      if Tok.Kind <> COMMATOK then Break;
      NextTok;
    until FALSE;

  EatTok(CPARTOK);
  end;// if Tok.Kind = OPARTOK
  

if NumActualParams < 
  Signature.NumParams - Signature.NumDefaultParams then
  begin
      Fatal('Too few actual parameters (in call to '+Parserstate.ProcFuncName+')');
      Exit;
  end;
  
// Push default parameters
for DefaultParamIndex := NumActualParams + 1 to Signature.NumParams do
  begin
  CurParam := Signature.Param[DefaultParamIndex];
  PushConst(CurParam^.Default.OrdValue);
  end; // for
  
end;// CompileActualParameters




procedure MakeCStack(const Signature: TSignature);
var
  ParamIndex: Integer;
  SourceStackDepth: Integer;
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P MakeCStack');
InitializeCStack;

// Push explicit parameters
SourceStackDepth := 0;
for ParamIndex := Signature.NumParams downto 1 do
  with Signature.Param[ParamIndex]^ do
    begin
    PushToCStack(SourceStackDepth, DataType, PassMethod = VALPASSING);
    
    if (Types[DataType].Kind = REALTYPE) and (PassMethod = VALPASSING) then           
      SourceStackDepth := SourceStackDepth + Align(TypeSize(DataType), SizeOf(LongInt))
    else
      SourceStackDepth := SourceStackDepth + SizeOf(LongInt);
    end;

// Push structured Result onto the C stack, except STDCALL/CDECL functions returning small structures in EDX:EAX
with Signature do 
  if (ResultType <> 0) and (Types[ResultType].Kind in StructuredTypes) and ((CallConv = DEFAULTCONV) or (TypeSize(ResultType) > 2 * SizeOf(LongInt))) then
    PushToCStack(NumParams * SizeOf(LongInt), ResultType, FALSE);
end; // MakeCStack


procedure SetUnitStatus(var NewUnitStatus: TUnitStatus);
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P SetUnitStatus');
    UnitStatus := NewUnitStatus;
    isLocal := False;      // in Unit definitions, not local
end;



// CHANGEME: If we switch to pointers, NIL needs to be used instead of 0
// CHANGEME  Conversion of arrays to pointers - when
//   identifiers are pointers instead of an array index,
//   this procedure/function will need to be revised
// Difference between GetidentUnsafe and GetIdent is this returns 0 if not found,
// GetIdent throws an error
function GetIdentUnsafe(const IdentName: TString; AllowForwardReference: Boolean = FALSE; RecType: Integer = 0): Integer;
var
  IdentIndex: Integer;
begin  // FIXME when using pointers
    If  (ActivityCTrace in TraceCompiler) then EmitHint('f GetIdentUnsafe');
for IdentIndex := NumIdent downto 1 do
  with Ident[IdentIndex] do
    if ((UnitIndex = UnitStatus.Index) or (IsExported and (UnitIndex in UnitStatus.UsedUnits))) and
       (AllowForwardReference or (Kind <> USERTYPE) or (Types[DataType].Kind <> FORWARDTYPE)) and
       (ReceiverType = RecType) and  // Receiver type for methods, 0 otherwise
       (Name = IdentName)
    then
      begin
      Result := IdentIndex;
      Exit;
      end;

Result := 0;
end;

function GetMethodUnsafe(RecType: Integer; const MethodName: TString): Integer;
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('f GetMethodUnsafe');
Result := GetIdentUnsafe(MethodName, FALSE, RecType);
end;

function GetMethod(RecType: Integer; const MethodName: TString): Integer;
begin
        If  (ActivityCTrace in TraceCompiler) then EmitHint('f GetMethod');
Result := GetIdent(MethodName, FALSE, RecType);
if (Ident[Result].Kind <> PROC) and (Ident[Result].Kind <> FUNC) then
	begin
  		Fatal('Method expected');
  		exit;
  	end;
end;

function GetFieldInsideWith(var RecPointer: Integer; var RecType: Integer; var IsConst: Boolean; const FieldName: TString): Integer;
var
  FieldIndex, WithIndex: Integer;
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('f GetFieldInsideWith');
for WithIndex := WithNesting downto 1 do
  begin
  RecType := WithStack[WithIndex].DataType;
  FieldIndex := GetFieldUnsafe(RecType, FieldName);

  if FieldIndex <> 0 then
    begin
    RecPointer := WithStack[WithIndex].TempPointer;
    IsConst := WithStack[WithIndex].IsConst;
    Result := FieldIndex;
    Exit;
    end;
  end;

Result := 0;
end;


function GetMethodInsideWith(var RecPointer: Integer;
                             var RecType: Integer;
                             var IsConst: Boolean;
                             const MethodName: TString): Integer;
var
  MethodIndex, WithIndex: Integer;
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('f GetMethodInsideWith');
for WithIndex := WithNesting downto 1 do
  begin
  RecType := WithStack[WithIndex].DataType;
  MethodIndex := GetMethodUnsafe(RecType, MethodName);

  if MethodIndex <> 0 then
    begin
    RecPointer := WithStack[WithIndex].TempPointer;
    IsConst := WithStack[WithIndex].IsConst;
    Result := MethodIndex;
    Exit;
    end;
  end;

Result := 0;
end;


function FieldOrMethodInsideWithFound(const Name: TString): Boolean;
var
  RecPointer: Integer;
  RecType: Integer;
  IsConst: Boolean;
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('f FieldOrMethodInsideWithFound');
Result := (GetFieldInsideWith(RecPointer, RecType, IsConst, Name) <> 0) or
          (GetMethodInsideWith(RecPointer, RecType, IsConst, Name) <> 0);
end;






procedure ConvertResultFromCToPascal(const Signature: TSignature; StructuredResultAddr: LongInt);
begin
        If  (ActivityCTrace in TraceCompiler) then EmitHint('P ConvertResultFromCToPascal');
with Signature do
  if (ResultType <> 0) and (CallConv <> DEFAULTCONV) then
    if Types[ResultType].Kind in StructuredTypes then
      if TypeSize(ResultType) <= 2 * SizeOf(LongInt) then
        begin     
        // For small structures returned by STDCALL/CDECL functions, allocate structured result pointer and load structure from EDX:EAX
        StructuredResultAddr := AllocateTempStorage(TypeSize(ResultType));
        ConvertSmallStructureToPointer(StructuredResultAddr, TypeSize(ResultType));
        end
      else  
        begin
        // Save structured result pointer to EAX (not all external functions do it themselves)
        PushTempStoragePtr(StructuredResultAddr);
        SaveStackTopToEAX;
        end
    else if Types[ResultType].Kind in [REALTYPE, SINGLETYPE] then
      // STDCALL/CDECL functions generally return real result in ST(0), but we do it in EAX or EDX:EAX 
      MoveFunctionResultFromFPUToEDXEAX(ResultType);
end; // ConvertResultFromCToPascal




procedure ConvertResultFromPascalToC(const Signature: TSignature);
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P ConvertResultFromPascalToC');
with Signature do
  if (ResultType <> 0) and (CallConv <> DEFAULTCONV) then
    if (Types[ResultType].Kind in StructuredTypes) and (TypeSize(ResultType) <= 2 * SizeOf(LongInt)) then
      // In STDCALL/CDECL functions, return small structure in EDX:EAX
      ConvertPointerToSmallStructure(TypeSize(ResultType))
    else if Types[ResultType].Kind in [REALTYPE, SINGLETYPE] then
      // STDCALL/CDECL functions generally return real result in ST(0), but we do it in EAX or EDX:EAX 
      MoveFunctionResultFromEDXEAXToFPU(ResultType);          
end; // ConvertResultFromCPascalToC



 // FIXME when using pointers for identifier tanle
procedure CompileCall(IdentIndex: Integer);
var
  TotalPascalParamSize, TotalCParamSize: Integer;
  StructuredResultAddr: LongInt;  
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileCall');
TotalPascalParamSize := GetTotalParamSize(Ident[IdentIndex].Signature, FALSE, TRUE); 
TotalCParamSize      := GetTotalParamSize(Ident[IdentIndex].Signature, FALSE, FALSE);

CompileActualParameters(Ident[IdentIndex].Signature, StructuredResultAddr);

// Convert stack to C format
if (Ident[IdentIndex].Signature.CallConv <> DEFAULTCONV) and (TotalPascalParamSize > 0) then
  MakeCStack(Ident[IdentIndex].Signature);
  
GenerateCall(Ident[IdentIndex].Address, BlockStackTop - 1, Ident[IdentIndex].NestingLevel);

// Free C stack for a CDECL function
if (Ident[IdentIndex].Signature.CallConv = CDECLCONV) and (TotalPascalParamSize > 0) then
  DiscardStackTop(TotalCParamSize div SizeOf(LongInt));

// Free original stack
if (Ident[IdentIndex].Signature.CallConv <> DEFAULTCONV) and (TotalPascalParamSize > 0) then
  DiscardStackTop(TotalPascalParamSize div SizeOf(LongInt));

// Treat special cases in STDCALL/CDECL functions
ConvertResultFromCToPascal(Ident[IdentIndex].Signature, StructuredResultAddr);     
end; // CompileCall




procedure CompileMethodCall(ProcVarType: Integer);
var
  MethodIndex: Integer;
  StructuredResultAddr: LongInt;
  
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileMethodCall');
MethodIndex := Types[ProcVarType].MethodIdentIndex;  
 
// Self pointer has already been passed as the first (hidden) argument
CompileActualParameters(Ident[MethodIndex].Signature, StructuredResultAddr);

GenerateCall(Ident[MethodIndex].Address, BlockStackTop - 1, Ident[MethodIndex].NestingLevel);
end; // CompileMethodCall




procedure CompileIndirectCall(ProcVarType: Integer);
var
  TotalPascalParamSize, TotalCParamSize, CallAddrDepth: Integer;
  StructuredResultAddr: LongInt;
  
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileIndirectCall');
TotalPascalParamSize := GetTotalParamSize(Types[ProcVarType].Signature, Types[ProcVarType].SelfPointerOffset <> 0, TRUE);
TotalCParamSize      := GetTotalParamSize(Types[ProcVarType].Signature, Types[ProcVarType].SelfPointerOffset <> 0, FALSE);

if Types[ProcVarType].SelfPointerOffset <> 0 then   // Interface method found
  begin
  if Types[ProcVarType].Signature.CallConv <> DEFAULTCONV then
    Begin
        Fatal('STDCALL/CDECL is not allowed for methods');
        Exit;
     end;
  // Push Self pointer as a first (hidden) VAR parameter
  DuplicateStackTop;
  GetFieldPtr(Types[ProcVarType].SelfPointerOffset);
  DerefPtr(POINTERTYPEINDEX);
  end;
  
CompileActualParameters(Types[ProcVarType].Signature, StructuredResultAddr);

// Convert stack to C format
if (Types[ProcVarType].Signature.CallConv <> DEFAULTCONV) and (TotalPascalParamSize > 0) then
  begin
  MakeCStack(Types[ProcVarType].Signature); 
  CallAddrDepth := TotalPascalParamSize + TotalCParamSize;
  end
else
  CallAddrDepth := TotalPascalParamSize;  

GenerateIndirectCall(CallAddrDepth);

// Free C stack for a CDECL function
if (Types[ProcVarType].Signature.CallConv = CDECLCONV) and (TotalPascalParamSize > 0) then
  DiscardStackTop(TotalCParamSize div SizeOf(LongInt));

// Free original stack
if (Types[ProcVarType].Signature.CallConv <> DEFAULTCONV) and (TotalPascalParamSize > 0) then
  DiscardStackTop(TotalPascalParamSize div SizeOf(LongInt));
  
// Remove call address
DiscardStackTop(1);  

// Treat special cases in STDCALL/CDECL functions
ConvertResultFromCToPascal(Types[ProcVarType].Signature, StructuredResultAddr);      
end; // CompileIndirectCall




function CompileMethodOrProceduralVariableCall(var ValType: Integer; FunctionOnly, DesignatorOnly: Boolean): Boolean;
var
  ResultType: Integer;
  
begin
If  (ActivityCTrace in TraceCompiler) then EmitHint('f CompileMethodOrProceduralVariableCall');
if Types[ValType].Kind = METHODTYPE then
  ResultType := Ident[Types[ValType].MethodIdentIndex].Signature.ResultType
else if Types[ValType].Kind = PROCEDURALTYPE then
  ResultType := Types[ValType].Signature.ResultType
else
  begin
  ResultType := 0;
  Fatal('Procedure or function expected'); 
  Exit;
  end; 

Result := FALSE; 
   
if not DesignatorOnly or ((ResultType <> 0) and (Types[ResultType].Kind in StructuredTypes)) then 
  begin
  if FunctionOnly and (ResultType = 0) then
    Begin
       Fatal('Function expected');
       Exit;
     end;
  if Types[ValType].Kind = METHODTYPE then  
    CompileMethodCall(ValType)
  else
    CompileIndirectCall(ValType);
  
  ValType := ResultType;
  Result := TRUE; 
  end; 
end; // CompileMethodOrProceduralVariableCall




procedure CompileFieldOrMethodInsideWith(var ValType: Integer; var IsConst: Boolean);
var
  FieldIndex, MethodIndex: Integer;
  RecType: Integer;
  TempStorageAddr: Integer;
  
begin
        If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileFieldOrMethodInsideWith');
AssertIdent; 
FieldIndex := GetFieldInsideWith(TempStorageAddr, RecType, IsConst, Tok.Name);
  
if FieldIndex <> 0 then
  begin
  PushTempStoragePtr(TempStorageAddr);
  DerefPtr(POINTERTYPEINDEX);
  
  GetFieldPtr(Types[RecType].Field[FieldIndex]^.Offset);
  ValType := Types[RecType].Field[FieldIndex]^.DataType;    
  
  Exit;
  end;
  
MethodIndex := GetMethodInsideWith(TempStorageAddr, RecType, IsConst, Tok.Name);
  
if MethodIndex <> 0 then
  begin
  PushTempStoragePtr(TempStorageAddr);
  DerefPtr(POINTERTYPEINDEX);
  
  // Add new anonymous 'method' type
  DeclareType(METHODTYPE);
  Types[NumTypes].MethodIdentIndex := MethodIndex; 
  ValType := NumTypes;

  Exit;   
  end;  

ValType := 0;  
end; // CompileFieldOrMethodInsideWith




procedure CompileSetConstructor(var ValType: Integer);
var
  ElementType: Integer;
  LibProcIdentIndex: Integer;
  TempStorageAddr: Integer;
  
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileSetConstructor');
// Add new anonymous type
DeclareType(SETTYPE);
Types[NumTypes].BaseType := ANYTYPEINDEX;
ValType := NumTypes;

// Allocate temporary storage
TempStorageAddr := AllocateTempStorage(TypeSize(ValType));
PushTempStoragePtr(TempStorageAddr);

// Initialize set
LibProcIdentIndex := GetIdent('XDP_INITSET');
GenerateCall(Ident[LibProcIdentIndex].Address, BlockStackTop - 1, Ident[LibProcIdentIndex].NestingLevel); 

// Compile constructor
LibProcIdentIndex := GetIdent('XDP_ADDTOSET');
NextTok;

if Tok.Kind <> CBRACKETTOK then
  repeat
    PushTempStoragePtr(TempStorageAddr);
    
    CompileExpression(ElementType);
    
    if Types[ValType].BaseType = ANYTYPEINDEX then
      begin
      if not (Types[ElementType].Kind in OrdinalTypes) then
        Begin
            Fatal('Ordinal type expected for set');
            Exit;
        end;    
      Types[ValType].BaseType := ElementType;
      end  
    else  
      GetCompatibleType(ElementType, Types[ValType].BaseType);

    if Tok.Kind = RANGETOK then
      begin
      NextTok;
      CompileExpression(ElementType);    
      GetCompatibleType(ElementType, Types[ValType].BaseType);
      end
    else
      PushConst(-1);
      
    GenerateCall(Ident[LibProcIdentIndex].Address, BlockStackTop - 1, Ident[LibProcIdentIndex].NestingLevel);        
      
    if Tok.Kind <> COMMATOK then Break;
    NextTok;
  until FALSE;
  
EatTok(CBRACKETTOK);

PushTempStoragePtr(TempStorageAddr);
end; // CompileSetConstructor




function DereferencePointerAsDesignator(var ValType: Integer; MustDereferenceAnyPointer: Boolean): Boolean;
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('f DereferencePointerAsDesignator');
// If a pointer-type result is immediately followed by dereferencing, treat it as a designator that has the pointer's base type
Result := FALSE;

if Types[ValType].Kind = POINTERTYPE then                      
  if Types[ValType].BaseType <> ANYTYPEINDEX then
    begin
    if Tok.Kind = DEREFERENCETOK then
      begin
      ValType := Types[ValType].BaseType;
      Result := TRUE;
      NextTok;
      end
    else if MustDereferenceAnyPointer then 
      CheckTok(DEREFERENCETOK)
    end    
  else if MustDereferenceAnyPointer then
    begin
       Fatal('Typed pointer expected');
       Exit;
    end;  
end; // DereferencePointerAsDesignator




function CompileSelectors(var ValType: Integer; BasicDesignatorIsStatement: Boolean = FALSE): Boolean;
var
  FieldIndex, MethodIndex: Integer;
  ArrayIndexType: Integer;
  Field: PField;   

begin
        If  (ActivityCTrace in TraceCompiler) then EmitHint('f CompileSelectors');
// A selector is only applicable to a memory location
// A function call can be part of a selector only if it returns an address (i.e. a structured result), not an immediate value
// All other calls are part of a factor or a statement

// Returns TRUE if constitutes a statement, i.e., ends with a function call
Result := BasicDesignatorIsStatement;

while Tok.Kind in [DEREFERENCETOK, OBRACKETTOK, PERIODTOK, OPARTOK] do
  begin
  Result := FALSE;
  
  case Tok.Kind of
  
    DEREFERENCETOK:                                   // Pointer dereferencing
      begin
      if (Types[ValType].Kind <> POINTERTYPE) or 
         (Types[ValType].BaseType = ANYTYPEINDEX) then
         begin
            Fatal('Typed pointer expected');
            exit;
         end;   
      DerefPtr(ValType);
      ValType := Types[ValType].BaseType;
      NextTok;
      end;
      
    
    OBRACKETTOK:                                      // Array element access
      begin
      repeat
        // Convert a pointer to an array if needed (C style)
        if (Types[ValType].Kind = POINTERTYPE) and (Types[ValType].BaseType <> ANYTYPEINDEX) then
          begin
          DerefPtr(ValType);
          
          // Add new anonymous type 0..0 for array index
          DeclareType(SUBRANGETYPE);
          
          Types[NumTypes].BaseType    := INTEGERTYPEINDEX;
          Types[NumTypes].Low         := 0;
          Types[NumTypes].High        := 0;
          
          // Add new anonymous type for array itself
          DeclareType(ARRAYTYPE);
          
          Types[NumTypes].BaseType    := Types[ValType].BaseType;
          Types[NumTypes].IndexType   := NumTypes - 1;

          ValType := NumTypes;   
          end;
          
        if Types[ValType].Kind <> ARRAYTYPE then
          begin
              Fatal('Array expected');
              exit;
           end;   
        NextTok;
        CompileExpression(ArrayIndexType);            // Array index
        GetCompatibleType(ArrayIndexType, Types[ValType].IndexType);
        GetArrayElementPtr(ValType);
        ValType := Types[ValType].BaseType;
      until Tok.Kind <> COMMATOK;
      
      EatTok(CBRACKETTOK);
      end;
      
      
    PERIODTOK:                                        // Method or record field access
      begin
      NextTok;
      AssertIdent;
      
      // First search for a method
      MethodIndex := GetMethodUnsafe(ValType, Tok.Name); 
      if MethodIndex <> 0 then
        begin
        // Add new anonymous 'method' type
        DeclareType(METHODTYPE);
        Types[NumTypes].MethodIdentIndex := MethodIndex;       
        ValType := NumTypes;
        end  
      // If unsuccessful, search for a record field  
      else
        begin          
        if not (Types[ValType].Kind in 
               [RECORDTYPE, INTERFACETYPE]) then
           begin    
               Fatal('Record or interface expected');
               Exit;
           end;    
        FieldIndex := GetField(ValType, Tok.Name);
        Field := Types[ValType].Field[FieldIndex];        
        GetFieldPtr(Field^.Offset);
        ValType := Field^.DataType;                
        end;
        
      NextTok;   
      end;
      
    
    OPARTOK: 
      begin
      if not CompileMethodOrProceduralVariableCall(ValType, TRUE, TRUE) then Break;  // Not a designator 
      PushFunctionResult(ValType);
      Result := TRUE; 
      end;
      
  end; // case
  
  end; // while
 
end; // CompileSelectors



// FIXME when using pointers for identifier tanle
function CompileBasicDesignator(var ValType: Integer; var IsConst: Boolean): Boolean;
var
  ResultType: Integer;
  IdentIndex: Integer;  
  
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('f CompileBasicDesignator');

// A designator always designates a memory location
// A function call can be part of a designator only if
// it returns an address (i.e. a structured result or
// a pointer), not an immediate value
// All other calls are part of a factor or a statement

// Returns TRUE if constitutes a statement, i.e., ends with a function call
Result := FALSE;
IsConst := FALSE;
   
AssertIdent;

// First search among records in WITH blocks
CompileFieldOrMethodInsideWith(ValType, IsConst);

// If unsuccessful, search among ordinary identifiers
if ValType = 0 then
  begin
  IdentIndex := GetIdent(Tok.Name);
  
  case Ident[IdentIndex].Kind of
  
    FUNC:
      begin
      Parserstate.ProcFuncName := Tok.Name;
      ResultType := Ident[IdentIndex].Signature.ResultType;

      if not (Types[ResultType].Kind in 
              StructuredTypes + [POINTERTYPE]) then   // Only allow a function that returns a designator
           begin   
               Fatal('Function ('+Parserstate.ProcFuncName+') must return pointer or structured result');
               exit;
			end;
      NextTok;
      CompileCall(IdentIndex);
      PushFunctionResult(ResultType);
      Result := TRUE;        
      ValType := ResultType;
      
      if DereferencePointerAsDesignator(ValType, TRUE) then
        Result := FALSE;
      end;  
             
    VARIABLE:                                  
      begin   
      PushVarIdentPtr(IdentIndex);      
      ValType := Ident[IdentIndex].DataType;
      IsConst := Ident[IdentIndex].IsTypedConst or (Ident[IdentIndex].PassMethod = CONSTPASSING);         
      
      // Structured CONST parameters are passed by reference, scalar CONST parameters are passed by value
      if (Ident[IdentIndex].PassMethod = VARPASSING) or
        ((Ident[IdentIndex].PassMethod <> VALPASSING) and (Types[ValType].Kind in StructuredTypes) and Ident[IdentIndex].IsInCStack) or
        ((Ident[IdentIndex].PassMethod <> EMPTYPASSING) and (Types[ValType].Kind in StructuredTypes) and not Ident[IdentIndex].IsInCStack)
      then
        DerefPtr(POINTERTYPEINDEX);
     
      NextTok;
      end;
      
    USERTYPE:                                                                       // Type cast
      begin                                                                      
      NextTok;
      
      EatTok(OPARTOK);
      CompileExpression(ValType);
      EatTok(CPARTOK);

      if not (Types[Ident[IdentIndex].DataType].Kind in 
              StructuredTypes + [POINTERTYPE]) then   // Only allow a typecast that returns a designator
          begin    
             Fatal('Typecast must return pointer or structured result');      
             exit;
           end;  
      
      if (Ident[IdentIndex].DataType <> ValType) and 
        not ((Types[Ident[IdentIndex].DataType].Kind in CastableTypes) and (Types[ValType].Kind in CastableTypes)) 
      then 
        begin
            Fatal('Invalid typecast');            
            exit;
        end;
      ValType := Ident[IdentIndex].DataType;
      
      DereferencePointerAsDesignator(ValType, TRUE);      
      end  
    
  else
    begin
        Fatal('Variable or function expected but ' + GetTokSpelling(Tok.Kind) + ' found');
        exit;
     end;   
  end; // case
    
  end
else
  NextTok;  
end; // CompileBasicDesignator




function CompileDesignator(var ValType: Integer; AllowConst: Boolean = TRUE): Boolean;
var
  IsConst: Boolean;
begin
    If  (ActivityCTrace in TraceCompiler) then  EmitHint('f CompileDesignator');
// Returns TRUE if constitutes a statement, i.e., ends with a function call
Result := CompileBasicDesignator(ValType, IsConst);

if IsConst and not AllowConst then
  begin
      Fatal('Constant value cannot be modified');
      exit
  end;
Result := CompileSelectors(ValType, Result);
end; // CompileDesignator



// FIXME when using pointers for identifier tanle
procedure CompileFactor(var ValType: Integer);


  procedure CompileDereferenceOrCall(var ValType: Integer);
  begin
          If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileDereferenceOrCall');
  if Tok.Kind = OPARTOK then   // Method or procedural variable call (parentheses are required even for empty parameter list)                                     
    begin
    CompileMethodOrProceduralVariableCall(ValType, TRUE, FALSE);
    PushFunctionResult(ValType);
    end       
  else                         // Usual variable
    if not (Types[ValType].Kind in StructuredTypes) then  // Structured expressions are stored as pointers to them
      DerefPtr(ValType);
      
  ConvertRealToReal(REALTYPEINDEX, ValType);              // Real expressions must be double, not single            
  end; // CompileDereferenceOrCall
  
  
var
  IdentIndex: Integer;
  NotOpTok: TToken;

  
begin // CompileFactor
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileFactor');
case Tok.Kind of

  IDENTTOK:
    if FieldOrMethodInsideWithFound(Tok.Name) then                                      // Record field or method inside a WITH block
      begin
      CompileDesignator(ValType);
      CompileDereferenceOrCall(ValType);
      end      
    else                                                                                // Ordinary identifier
      begin
      IdentIndex := GetIdent(Tok.Name);

      case Ident[IdentIndex].Kind of
      
        GOTOLABEL:
          begin Fatal('Expression expected but label ' + Ident[IdentIndex].Name + ' found'); exit; end;
      
        PROC:
          begin Fatal('Expression expected but procedure ' + Ident[IdentIndex].Name + ' found');  exit; end;
          
        FUNC:                                                                           // Function call
          if Ident[IdentIndex].PredefProc <> EMPTYPROC then                             // Predefined function call
            CompilePredefinedFunc(Ident[IdentIndex].PredefProc, ValType)
          else                                                                          // User-defined function call
            begin
            NextTok;
            ValType := Ident[IdentIndex].Signature.ResultType;

            ParserState.ProcFuncName := Ident[IdentIndex].Name;
            CompileCall(IdentIndex);
            PushFunctionResult(ValType);
            ConvertRealToReal(REALTYPEINDEX, ValType);              // Real expressions must be double, not single            

            if (Types[ValType].Kind in StructuredTypes) or DereferencePointerAsDesignator(ValType, FALSE) then
              begin
              CompileSelectors(ValType);
              CompileDereferenceOrCall(ValType);
              end; 
            end;
            
        VARIABLE:                                                                       // Variable
          begin
          CompileDesignator(ValType);
          CompileDereferenceOrCall(ValType);   
          end;
          
        CONSTANT:                                                                       // Constant
          begin
          if Types[Ident[IdentIndex].DataType].Kind in StructuredTypes then
            PushVarPtr(Ident[IdentIndex].Address, GLOBAL, 0, INITDATARELOC)
          else if Types[Ident[IdentIndex].DataType].Kind = REALTYPE then
            begin
            PushRealConst(Ident[IdentIndex].ConstVal.RealValue);
            If CodeGenCTrace in TraceCompiler then EmitGen(' Push Double');
            end
          else
            PushConst(Ident[IdentIndex].ConstVal.OrdValue);
            
          ValType := Ident[IdentIndex].DataType;
          NextTok;
          
          if Types[Ident[IdentIndex].DataType].Kind in StructuredTypes then
            begin
            CompileSelectors(ValType);
            CompileDereferenceOrCall(ValType);
            end;            
          end;
          
        USERTYPE:                                                                       // Type cast
          begin                                                                      
          NextTok;
          
          EatTok(OPARTOK);
          CompileExpression(ValType);
          EatTok(CPARTOK);

          if (Ident[IdentIndex].DataType <> ValType) and 
             not ((Types[Ident[IdentIndex].DataType].Kind in CastableTypes) and (Types[ValType].Kind in CastableTypes)) 
          then 
            begin
            	Fatal('Invalid typecast');            
            	exit;
             end;        
          ValType := Ident[IdentIndex].DataType;
          
          if (Types[ValType].Kind = POINTERTYPE) and (Types[Types[ValType].BaseType].Kind in StructuredTypes) then
            begin
            if DereferencePointerAsDesignator(ValType, FALSE) then
              begin
              CompileSelectors(ValType);
              CompileDereferenceOrCall(ValType);
              end
            end             
          else  
            CompileSelectors(ValType); 
          end
          
      else
        begin
            Fatal('Internal fault: Illegal identifier');  
            exit;
         end;   
      end; // case Ident[IdentIndex].Kind
      end; // else  


  ADDRESSTOK:
    begin
    NextTok;
    
    if FieldOrMethodInsideWithFound(Tok.Name) then         // Record field inside a WITH block
      begin
      CompileDesignator(ValType);
      DeclareType(POINTERTYPE);
      Types[NumTypes].BaseType := ValType;
      end      
    else                                                    // Ordinary identifier
      begin  
      IdentIndex := GetIdent(Tok.Name);
      
      if Ident[IdentIndex].Kind in [PROC, FUNC] then
        begin
        if (Ident[IdentIndex].PredefProc <> EMPTYPROC) or 
           (Ident[IdentIndex].Block <> 1) then
           begin
          	   Fatal('Procedure or function cannot be predefined or nested');
          	   exit;
           end;   
          
        PushRelocConst(Ident[IdentIndex].Address, CODERELOC); // To be resolved later when the code section origin is known        
        NextTok;
        
        DeclareType(PROCEDURALTYPE);
        Types[NumTypes].Signature := Ident[IdentIndex].Signature;
        CopyParams(Types[NumTypes].Signature, Ident[IdentIndex].Signature);
        end
      else
        begin  
        CompileDesignator(ValType);
        DeclareType(POINTERTYPE);
        Types[NumTypes].BaseType := ValType;
        end;
      end;  
    
    ValType := NumTypes;  
    end;


  INTNUMBERTOK:
    begin
    PushConst(Tok.OrdValue);
    ValType := INTEGERTYPEINDEX;
    NextTok;
    end;


  REALNUMBERTOK:
    begin
    PushRealConst(Tok.RealValue);
    If CodeGenCTrace in TraceCompiler then EmitGen('Push Double');
    ValType := REALTYPEINDEX;
    NextTok;
    end;


  CHARLITERALTOK:
    begin
    PushConst(Tok.OrdValue);
    ValType := CHARTYPEINDEX;
    NextTok;
    end;


  STRINGLITERALTOK:
    begin
    PushVarPtr(Tok.StrAddress, GLOBAL, 0, INITDATARELOC);
    ValType := STRINGTYPEINDEX;
    NextTok;
    end;


  OPARTOK:
    begin
    NextTok;
    CompileExpression(ValType);
    EatTok(CPARTOK);
    end;


  NOTTOK:
    begin
    NotOpTok := Tok;
    NextTok;
    CompileFactor(ValType);
    CheckOperator(NotOpTok, ValType);
    GenerateUnaryOperator(NOTTOK, ValType);
    end;
    
    
  OBRACKETTOK:  
    CompileSetConstructor(ValType);
    

  NILTOK:
    begin
    PushConst(0);
    ValType := POINTERTYPEINDEX;
    NextTok;
    end

else
  begin
      Fatal('Expression expected but ' + GetTokSpelling(Tok.Kind) + ' found');
      exit;
   end;   
end;// case

end;// CompileFactor




procedure CompileTerm(var ValType: Integer);
var
  OpTok: TToken;
  RightValType: Integer;
  LibProcIdentIndex: Integer;
  TempStorageAddr: Integer;
  UseShortCircuit: Boolean; 
  
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileTerm');
CompileFactor(ValType);

while Tok.Kind in MultiplicativeOperators do
  begin
  OpTok := Tok;
  NextTok;
  
  UseShortCircuit := (OpTok.Kind = ANDTOK) and (Types[ValType].Kind = BOOLEANTYPE);
  if UseShortCircuit then 
    GenerateShortCircuitProlog(OpTok.Kind);  
  
  CompileFactor(RightValType);

  // Try to convert integer to real
  ConvertIntegerToReal(ValType, RightValType, 0);
  ConvertIntegerToReal(RightValType, ValType, SizeOf(Double));
  
  // Special case: real division of two integers
  if OpTok.Kind = DIVTOK then
    begin
    ConvertIntegerToReal(REALTYPEINDEX, RightValType, 0);
    ConvertIntegerToReal(REALTYPEINDEX, ValType, SizeOf(Double));
    end;
    
  // Special case: set intersection  
  if (OpTok.Kind = MULTOK) and (Types[ValType].Kind = SETTYPE) then  
    begin
    ValType := GetCompatibleType(ValType, RightValType);
    
    LibProcIdentIndex := GetIdent('SETINTERSECTION');
      
    TempStorageAddr := AllocateTempStorage(TypeSize(ValType));    
    PushTempStoragePtr(TempStorageAddr);

    GenerateCall(Ident[LibProcIdentIndex].Address, BlockStackTop - 1, Ident[LibProcIdentIndex].NestingLevel);    
    PushTempStoragePtr(TempStorageAddr);
    end
  // General rule  
  else
    begin
    ValType := GetCompatibleType(ValType, RightValType);
    CheckOperator(OpTok, ValType);

    if UseShortCircuit then 
      GenerateShortCircuitEpilog
    else 
      GenerateBinaryOperator(OpTok.Kind, ValType);
    end;
    
  end;// while

end;// CompileTerm




procedure CompileSimpleExpression(var ValType: Integer);
var
  UnaryOpTok, OpTok: TToken;
  RightValType: Integer;
  LibProcIdentIndex: Integer;
  TempStorageAddr: Integer;
  UseShortCircuit: Boolean; 
  
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileSimpleExpression');
UnaryOpTok := Tok;
if UnaryOpTok.Kind in UnaryOperators then
  NextTok;

CompileTerm(ValType);

if UnaryOpTok.Kind in UnaryOperators then
  CheckOperator(UnaryOpTok, ValType);

if UnaryOpTok.Kind = MINUSTOK then GenerateUnaryOperator(MINUSTOK, ValType);     // Unary minus

while Tok.Kind in AdditiveOperators do
  begin
  OpTok := Tok;
  NextTok;
  
  UseShortCircuit := (OpTok.Kind = ORTOK) and (Types[ValType].Kind = BOOLEANTYPE);
  if UseShortCircuit then 
    GenerateShortCircuitProlog(OpTok.Kind);
  
  CompileTerm(RightValType); 

  // Try to convert integer to real
  ConvertIntegerToReal(ValType, RightValType, 0);
  ConvertIntegerToReal(RightValType, ValType, SizeOf(Double));
    
  // Try to convert character to string
  ConvertCharToString(ValType, RightValType, 0);
  ConvertCharToString(RightValType, ValType, SizeOf(LongInt));  
      
  // Special case: string concatenation
  if (OpTok.Kind = PLUSTOK) and IsString(ValType) and IsString(RightValType) then
    begin 
    LibProcIdentIndex := GetIdent('CONCATSTR');   

    TempStorageAddr := AllocateTempStorage(TypeSize(STRINGTYPEINDEX));    
    PushTempStoragePtr(TempStorageAddr);
    
    GenerateCall(Ident[LibProcIdentIndex].Address, BlockStackTop - 1, Ident[LibProcIdentIndex].NestingLevel);    
    PushTempStoragePtr(TempStorageAddr);
    ValType := STRINGTYPEINDEX;
    end
  // Special case: set union or difference  
  else if (OpTok.Kind in [PLUSTOK, MINUSTOK]) and (Types[ValType].Kind = SETTYPE) then  
    begin
    ValType := GetCompatibleType(ValType, RightValType);
    
    if OpTok.Kind = PLUSTOK then
      LibProcIdentIndex := GetIdent('SETUNION')
    else
      LibProcIdentIndex := GetIdent('SETDIFFERENCE');
      
    TempStorageAddr := AllocateTempStorage(TypeSize(ValType));    
    PushTempStoragePtr(TempStorageAddr);

    GenerateCall(Ident[LibProcIdentIndex].Address, BlockStackTop - 1, Ident[LibProcIdentIndex].NestingLevel);    
    PushTempStoragePtr(TempStorageAddr);
    end  
  // General rule
  else
    begin
    ValType := GetCompatibleType(ValType, RightValType);
    CheckOperator(OpTok, ValType);
 
    if UseShortCircuit then 
      GenerateShortCircuitEpilog
    else 
      GenerateBinaryOperator(OpTok.Kind, ValType);
    end;
  
  end;// while

end;// CompileSimpleExpression




procedure CompileExpression(var ValType: Integer);
var
  OpTok: TToken;
  RightValType: Integer;
  LibProcIdentIndex: Integer;

  
begin // CompileExpression
        If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileExpression');
CompileSimpleExpression(ValType);

if Tok.Kind in RelationOperators then
  begin
  OpTok := Tok;
  NextTok;
  CompileSimpleExpression(RightValType);

  // Try to convert integer to real
  ConvertIntegerToReal(ValType, RightValType, 0);
  ConvertIntegerToReal(RightValType, ValType, SizeOf(Double));
    
  // Try to convert character to string
  ConvertCharToString(ValType, RightValType, 0);
  ConvertCharToString(RightValType, ValType, SizeOf(LongInt));     
    
  // Special case: string comparison
  if IsString(ValType) and IsString(RightValType) then
    begin 
    LibProcIdentIndex := GetIdent('COMPARESTR');
    
    ValType := Ident[LibProcIdentIndex].Signature.ResultType;
    RightValType := INTEGERTYPEINDEX;
    
    GenerateCall(Ident[LibProcIdentIndex].Address, BlockStackTop - 1, Ident[LibProcIdentIndex].NestingLevel);
    PushFunctionResult(ValType); 
    PushConst(0);    
    end;

  // Special case: set comparison
  if (OpTok.Kind in [EQTOK, NETOK, GETOK, LETOK]) and (Types[ValType].Kind = SETTYPE) then
    begin
    GetCompatibleType(ValType, RightValType); 
    
    case OpTok.Kind of
      GETOK: LibProcIdentIndex := GetIdent('TESTSUPERSET');    // Returns  1 if Val >= RightVal, -1 otherwise 
      LETOK: LibProcIdentIndex := GetIdent('TESTSUBSET');      // Returns -1 if Val <= RightVal,  1 otherwise 
      else   LibProcIdentIndex := GetIdent('COMPARESETS');     // Returns  0 if Val  = RightVal,  1 otherwise  
    end;
 
    ValType := Ident[LibProcIdentIndex].Signature.ResultType;
    RightValType := INTEGERTYPEINDEX;
    
    GenerateCall(Ident[LibProcIdentIndex].Address, BlockStackTop - 1, Ident[LibProcIdentIndex].NestingLevel);
    PushFunctionResult(ValType);
    PushConst(0); 
    end;  

  GetCompatibleType(ValType, RightValType);
  CheckOperator(OpTok, ValType);
  ValType := BOOLEANTYPEINDEX;
  GenerateRelation(OpTok.Kind, RightValType);
  end
else if Tok.Kind = INTOK then
  begin
    if (TokenCTrace in TraceCompiler) or
     (KeywordCTrace in TraceCompiler) then
      EmitToken('IN');
  NextTok;
  CompileSimpleExpression(RightValType);
  
  if Types[RightValType].Kind <> SETTYPE then
    begin
       Fatal('Set expected');
       exit;
    end;
    
  if Types[RightValType].BaseType <> ANYTYPEINDEX then
    GetCompatibleType(ValType, Types[RightValType].BaseType)
  else if not (Types[ValType].Kind in OrdinalTypes) then
    begin
        Fatal('Ordinal type expected for IN operator');
        exit;
    end;   

  LibProcIdentIndex := GetIdent('INSET');
  ValType := Ident[LibProcIdentIndex].Signature.ResultType;
  
  GenerateCall(Ident[LibProcIdentIndex].Address, BlockStackTop - 1, Ident[LibProcIdentIndex].NestingLevel);
  PushFunctionResult(ValType);    
  end;  

end;// CompileExpression



// Called between BEGIN and END, REPEAT and UNTIL
procedure CompileStatementList(LoopNesting: Integer);
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileStatementList');
CompileStatement(LoopNesting);
while Tok.Kind = SEMICOLONTOK do
  begin
  NextTok;
  CompileStatement(LoopNesting);
  end;
end; // CompileStatementList 



procedure CompileCompoundStatement(LoopNesting: Integer); // BEGIN END block
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileCompoundStatement');
// we don't trace BEGIN because BeginCheck has already done so
   LastKeyTok := Tok;            //
   EatTok(BEGINTOK);             // BEGIN (Compound Statement)

   CompileStatementList(LoopNesting);      // stmts in BEGIN


   if beginCount = 1 then
    Begin
// At the end of the procedure, insert proc exit trap here


    end;
   PatchState := PatchProcEnd;

   EatTok(ENDTOK);      // END in BEGIN .. END   compound sttement
   Dec(BeginCount);
   Dec(BlockCount);    // increased on BEGIN, CASE, REPEAT, decreased on UNTIL, END

if (TokenCTrace in TraceCompiler) or
   (KeywordCTrace in TraceCompiler) or
   (BlockCTrace in TraceCompiler)  then
     EmitToken('END BeginCount='+IntToStr(BeginCount));

end; // CompileCompoundStatement


//{$NOTE CompileStatement}
//(*$SHOW Block,procfunc*)
// Handle one single statement
// Note: the begin statement for this procedure is ~ 500 lines below
procedure CompileStatement(LoopNesting: Integer);



  procedure CompileLabel;     // GOTO label
  var
    LabelIndex: Integer;
  begin
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileLabel');
  if Tok.Kind = IDENTTOK then
    begin
    LabelIndex := GetIdentUnsafe(Tok.Name);
    
    if LabelIndex <> 0 then
      if Ident[LabelIndex].Kind = GOTOLABEL then
        begin
        if Ident[LabelIndex].Block <> 
           BlockStack[BlockStackTop].Index then
           begin
               Fatal('Label is not declared in current procedure');
               exit;
           end;    
        
        Ident[LabelIndex].Address := GetCodeSize;        
        Ident[LabelIndex].IsUnresolvedForward := FALSE;
        Ident[NumIdent].DeclaredLine :=  TOK.DeclaredLine;               // Label
        Ident[LabelIndex].ForLoopNesting := ForLoopNesting;
        
        NextTok;
        EatTok(COLONTOK);
        end;      
    end;
  end; // CompileLabel
  
  
  
  // a := b
  procedure CompileAssignment(DesignatorType: Integer);
  var
    ExpressionType: Integer;
    LibProcIdentIndex: Integer;
  begin
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileAssignment');
      if (BecomesCTrace in TraceCompiler) or
         (TokenCTrace in TraceCompiler) then
      EmitToken('assignment');
  NextTok;

  CompileExpression(ExpressionType);
  
  // Try to convert integer to double, single to double or double to single
  ConvertIntegerToReal(DesignatorType, ExpressionType, 0);
  ConvertRealToReal(DesignatorType, ExpressionType);
    
  // Try to convert character to string
  ConvertCharToString(DesignatorType, ExpressionType, 0);

  // Try to convert string to pointer to character
  ConvertStringToPChar(DesignatorType, ExpressionType);     
    
  // Try to convert a concrete type to an interface type
  ConvertToInterface(DesignatorType, ExpressionType);       

  GetCompatibleType(DesignatorType, ExpressionType);

  if IsString(DesignatorType) then
    begin 
    LibProcIdentIndex := GetIdent('ASSIGNSTR');    
    GenerateCall(Ident[LibProcIdentIndex].Address, BlockStackTop - 1, Ident[LibProcIdentIndex].NestingLevel);    
    end
  else if Types[DesignatorType].Kind in StructuredTypes then
    GenerateStructuredAssignment(DesignatorType)
  else
    GenerateAssignment(DesignatorType);
  
  end; // CompileAssignment
  
  
  
  
  procedure CompileAssignmentOrCall(DesignatorType: Integer; DesignatorIsStatement: Boolean);
  begin
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileAssignmentOrCall');
  if Tok.Kind = OPARTOK then   // Method or procedural variable call
                               // (parentheses are required even
    begin                      // for empty parameter list)
        if (CallCTrace in TraceCompiler) OR
           (TokenCTrace in TraceCompiler) then
            Emittoken('proc call: '+Parserstate.ProcFuncName);
        CompileMethodOrProceduralVariableCall(DesignatorType, FALSE, FALSE)
    end
  else if DesignatorIsStatement then    // Optional assignment if designator already ends with a function call   
    if (Tok.Kind = BECOMESTOK) or (Tok.Kind = ERRSEMIEQTOK) then
      BEGIN
          ItsWrongIf(ERRSEMIEQTOK,BECOMESTOK,Err_14); // "; expected"
          CompileAssignment(DesignatorType);
      end
    else
      DiscardStackTop(1)                // Nothing to do - remove designator
  else                                  // Mandatory assignment
    BEGIN
        ErrIfNot(BECOMESTOK,Err_14);    // if not becomes (:=), error and pretend it was
        CompileAssignment(DesignatorType);  // this NEXTs the symbol, good or bad
    end; 
  end; // CompileAssignmentOrCall
  

  procedure CompileElseStatement(LoopNesting: Integer);  // ELSE in IF
  begin
     If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileElseStatement');
     if (TokenCTrace in TraceCompiler) or (KeywordCTrace in TraceCompiler) then
        EmitToken('ELSE');
     LastKeyTok := Tok;
     NextTok;
     GenerateElseProlog;
     CompileStatement(LoopNesting);   // stmt in ELSE
  end;

  procedure CompileIfStatement(LoopNesting: Integer);  // IF statement
  var
    ExpressionType: Integer;
    
  begin
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileIfStatement');
    if (TokenCTrace in TraceCompiler) or (KeywordCTrace in TraceCompiler) then
     EmitToken('IF');
    LastKeyTok := TOK;   // IF statement
    NextTok;
  
    CompileExpression(ExpressionType);
    GetCompatibleType(ExpressionType, BOOLEANTYPEINDEX);
  
    EatTok(THENTOK);
    if (TokenCTrace in TraceCompiler) or (KeywordCTrace in TraceCompiler) then
        EmitToken('THEN');

     GenerateIfCondition;            // Satisfied if expression is not FALSE
     GenerateIfProlog;               //
     CompileStatement(LoopNesting);  // stmt in IF

     if Tok.Kind <> ELSETOK then  // if .. then ... ELSE
     begin

     end
     else
             CompileElseStatement(LoopNesting);


     GenerateIfElseEpilog;
  end; // CompileIfStatement  



  
  procedure CompileCaseStatement(LoopNesting: Integer);  // CASE satement
  var
    SelectorType, ConstValType: Integer;
    NumCaseStatements: Integer;
    ConstVal, ConstVal2: TConst;
    
  begin
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileCaseStatement');
  if (TokenCTrace in TraceCompiler) or (KeywordCTrace in TraceCompiler) then
       EmitToken('CASE');
  Inc(BlockCount);     // Increased by BEGIN / CASE / REPEAT, decreased by UNTIL, END
  NextTok;
  
  CompileExpression(SelectorType);
  if not (Types[SelectorType].Kind in OrdinalTypes) then
    begin
        Fatal('Ordinal variable expected as CASE selector');
        exit;
    end;    
  
  EatTok(OFTOK);  // OF in CASE .. OF
  if (TokenCTrace in TraceCompiler) or (KeywordCTrace in TraceCompiler) then
       EmitToken('OF');


  PatchState := PatchCaseOf;

  GenerateCaseProlog;  

  NumCaseStatements := 0;

  repeat       // Loop over all cases

    repeat     // Loop over all constants for the current case
      CompileConstExpression(ConstVal, ConstValType);
      GetCompatibleType(ConstValType, SelectorType);

      if Tok.Kind = RANGETOK then                                      // Range check
        begin
        NextTok;
        CompileConstExpression(ConstVal2, ConstValType);
        GetCompatibleType(ConstValType, SelectorType);
        GenerateCaseRangeCheck(ConstVal.OrdValue, ConstVal2.OrdValue);
        end
      else
        GenerateCaseEqualityCheck(ConstVal.OrdValue);                     // Equality check

      if Tok.Kind <> COMMATOK then Break;
      NextTok;
    until FALSE;

    EatTok(COLONTOK);

    GenerateCaseStatementProlog;
    CompileStatement(LoopNesting);      // stmt in CASE
    GenerateCaseStatementEpilog;

    Inc(NumCaseStatements);

    // Add "OTHERWISE" as alternative in case statement
    if (Tok.Kind = ELSETOK) or  (Tok.Kind = OTHERWISETOK) or (Tok.Kind = ENDTOK) then
      begin
         if (TokenCTrace in TraceCompiler) or (KeywordCTrace in TraceCompiler) then
           if  Tok.Kind = ENDTOK then         // CASE .. END
              EmitToken('END statement(CASE)')
           else
              EmitToken('ELSE statement(CASE)');
          Break;
      end;
    EatTok(SEMICOLONTOK);
  until (Tok.Kind = ELSETOK) or (Tok.Kind = OTHERWISETOK) or (Tok.Kind = ENDTOK);  // CASE .. END or CASE .. ELSE / OTHERWISE
  
  // Default statements
  if (Tok.Kind = ELSETOK) or (Tok.Kind = OTHERWISETOK) then   // CASE .. ELSE / OTHERWISE
    begin
    NextTok;
    // since a case statement must be terminated by an END
    // a block of multiple statements is allowable
    CompileStatementList(LoopNesting);        // stmts in CASE ELSE
    end;          

  EatTok(ENDTOK);   // CASE .. END after ELSE
  if (TokenCTrace in TraceCompiler) or (KeywordCTrace in TraceCompiler) then
       EmitToken('END statement(CASE, after ELSE)');

  GenerateCaseEpilog(NumCaseStatements);
  end; // CompileCaseStatement
  
  
  
  
  procedure CompileWhileStatement(LoopNesting: Integer);   // WHILE
  var
    ExpressionType: Integer;
    
  begin      // WHILE
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileWhileStatement');
  if (TokenCTrace in TraceCompiler) or
     (KeywordCTrace in TraceCompiler) or
     (LoopCTrace in TraceCompiler)   then
      EmitToken('WHILE');

  SaveCodePos;      // Save return address used by GenerateWhileEpilog

  NextTok;
  CompileExpression(ExpressionType);
  GetCompatibleType(ExpressionType, BOOLEANTYPEINDEX);
  
  EatTok(DOTOK);     // DO in WHILE ... DO
  if (TokenCTrace in TraceCompiler) or (KeywordCTrace in TraceCompiler) then
    EmitToken('DO(WHILE)');

  GenerateBreakProlog(LoopNesting);
  GenerateContinueProlog(LoopNesting);
  GenerateWhileCondition;                         // Satisfied if expression is not zero
  GenerateWhileProlog;
  
  CompileStatement(LoopNesting);           // stmt in WHILE
  
  GenerateContinueEpilog(LoopNesting);
  GenerateWhileEpilog;
  GenerateBreakEpilog(LoopNesting);
  end; // CompileWhileStatement
  
  
  
  
  procedure CompileRepeatStatement(LoopNesting: Integer);   // REPEAT statement
  var
    ExpressionType: Integer;
    
  begin
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileRepeatStatement');
       inc(BlockCount);    // increased on BEGIN, CASE, REPEAT, decreased on UNTIL, END
      if (TokenCTrace in TraceCompiler) or
         (KeywordCTrace in TraceCompiler) or
         (LoopCTrace in TraceCompiler)   then
            EmitToken('REPEAT');
  PatchState :=PatchRepeat;

  GenerateBreakProlog(LoopNesting);
  GenerateContinueProlog(LoopNesting);
  GenerateRepeatProlog;

  LastKeyTok := Tok;      // save repeat
  NextTok;
  CompileStatementList(LoopNesting);                  // stmts in REPEAT


  EatTok(UNTILTOK);     // until
  LastKeyTok := Tok;

  Dec(BlockCount);     // increased on BEGIN, CASE, REPEAT, decreased on UNTIL, END
  if (TokenCTrace in TraceCompiler) or
     (KeywordCTrace in TraceCompiler) or
     (LoopCTrace in TraceCompiler)   then
      EmitToken('UNTIL');

  
  GenerateContinueEpilog(LoopNesting);

  CompileExpression(ExpressionType);
  GetCompatibleType(ExpressionType, BOOLEANTYPEINDEX);
  
  GenerateRepeatCondition;
  GenerateRepeatEpilog;
  GenerateBreakEpilog(LoopNesting);
  end; // CompileRepeatStatement
  
  
  
  
  procedure CompileForStatement(LoopNesting: Integer);
  var
    CounterIndex: Integer;
    ExpressionType: Integer;
    Down: Boolean;
      
  begin       // FOR statement
        If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileForStatement');
  if (TokenCTrace in TraceCompiler) or
     (KeywordCTrace in TraceCompiler) or
     (LoopCTrace in TraceCompiler)   then
    EmitToken('FOR');
  PatchState :=PatchFor;
  LastKeyTok := Tok;           // save FOR
  NextTok;
  
  AssertIdent;
  CounterIndex := GetIdent(Tok.Name);

  if  (Ident[CounterIndex].Kind <> VARIABLE) or
     ((Ident[CounterIndex].NestingLevel <> 1) and 
      (Ident[CounterIndex].NestingLevel <> BlockStackTop)) or
      (Ident[CounterIndex].PassMethod <> EMPTYPASSING) then
      begin
         Fatal('Simple local variable expected as FOR loop counter');
         exit;
      end;   

  if not (Types[Ident[CounterIndex].DataType].Kind in OrdinalTypes) then
    begin
    	Fatal('Ordinal variable expected as FOR loop counter');
    	exit;
    end;
    
  PushVarIdentPtr(CounterIndex);
  
  NextTok;
  EatTok(BECOMESTOK);
  
  // Initial counter value
  CompileExpression(ExpressionType);
  GetCompatibleType(ExpressionType, Ident[CounterIndex].DataType);  

  if not (Tok.Kind in [TOTOK, DOWNTOTOK]) then
    CheckTok(TOTOK);

  Down := Tok.Kind = DOWNTOTOK;
  NextTok;
  
  // Final counter value
  CompileExpression(ExpressionType);
  GetCompatibleType(ExpressionType, Ident[CounterIndex].DataType);
  
  // Assign initial value to the counter, compute and save the total number of iterations
  GenerateForAssignmentAndNumberOfIterations(Ident[CounterIndex].DataType, Down);
  
  // Save return address used by GenerateForEpilog
  SaveCodePos;
  
  // Check the remaining number of iterations
  GenerateForCondition;

  EatTok(DOTOK);     // FOR
  if (TokenCTrace in TraceCompiler) or
     (KeywordCTrace in TraceCompiler) or
     (LoopCTrace in TraceCompiler)   then
     EmitToken('DO(FOR)');

  GenerateBreakProlog(LoopNesting);
  GenerateContinueProlog(LoopNesting);
  GenerateForProlog;
  
  CompileStatement(LoopNesting);          // stmt in FOR
  
  GenerateContinueEpilog(LoopNesting);
  
  PushVarIdentPtr(CounterIndex);         
  GenerateForEpilog(Ident[CounterIndex].DataType, Down);
  
  GenerateBreakEpilog(LoopNesting);
  
  // Pop and discard the remaining number of iterations (i.e. zero)
  DiscardStackTop(1);                                          
  end; // CompileForStatement

  
  
  
  procedure CompileGotoStatement(LoopNesting: Integer);  // GOTO statement
  var
    LabelIndex: Integer;
    
  begin
            If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileGotoStatement');
  NextTok;
  
  AssertIdent;  // CHANGEME - to allow numbers for GOTO labels
  LabelIndex := GetIdent(Tok.Name);
  
  if Ident[LabelIndex].Kind <> GOTOLABEL then
    begin
    	Fatal('Label expected');
    	exit;
    end;
    
  if Ident[LabelIndex].Block <> 
     BlockStack[BlockStackTop].Index then
     begin
    	Fatal('Label is not declared in current procedure');
    	exit;
   	end; 	
    
  GenerateGoto(LabelIndex);

  NextTok;
  end; // CompileGotoStatement



  
  procedure CompileWithStatement(LoopNesting: Integer);
  var
    DesignatorType: Integer;
    DeltaWithNesting: Integer;
    TempStorageAddr: Integer;
    IsConst: Boolean;
    
  begin              // WITH statement
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileWithStatement');
  PatchState := PatchWith;
  NextTok;  
  DeltaWithNesting := 0; 

  repeat   
    // Save designator pointer to temporary storage
    TempStorageAddr := AllocateTempStorage(TypeSize(POINTERTYPEINDEX));    
    PushTempStoragePtr(TempStorageAddr);
    
    CompileBasicDesignator(DesignatorType, IsConst);
    CompileSelectors(DesignatorType);
    if not (Types[DesignatorType].Kind in
            [RECORDTYPE, INTERFACETYPE]) then
       begin
           Fatal('Record or interface expected');
           exit;
        end;   
      
    GenerateAssignment(POINTERTYPEINDEX);

    // Save designator info
    Inc(DeltaWithNesting);
    Inc(WithNesting);
    
    if WithNesting > MAXWITHNESTING then
      begin
          Fatal('Maximum WITH block nesting exceeded');
          exit;
      end;   
    
    WithStack[WithNesting].TempPointer := TempStorageAddr;
    WithStack[WithNesting].DataType := DesignatorType;
    WithStack[WithNesting].IsConst := IsConst;    
    
    if Tok.Kind <> COMMATOK then Break;
    NextTok;
  until FALSE;
  
  EatTok(DOTOK);
  if (TokenCTrace in TraceCompiler) or (KeywordCTrace in TraceCompiler) then
     EmitToken('DO(WITH)');

  
  CompileStatement(LoopNesting);         // stmt in WITH
  
  WithNesting := WithNesting - DeltaWithNesting;
  end; // CompileWithStatement


  procedure CompileAssemblerStatement(LoopNesting: Integer);
  begin
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileAssemblerStatement');
      repeat
           GetAssemblerStatement;    // in Scanner
           AssembleStatement;        // in assembler
           Halt(9);

       until (Tok.Kind = ENDTOK) ;
  end;
  
  function IsCurrentOrOuterFunc(FuncIdentIndex: Integer): Boolean;
  var
    BlockStackIndex: Integer;
  begin
      If  (ActivityCTrace in TraceCompiler) then  EmitHint('f IsCurrentOrOuterFunc');
  if Ident[FuncIdentIndex].Kind = FUNC then
    for BlockStackIndex := BlockStackTop downto 1 do
      if BlockStack[BlockStackIndex].Index = Ident[FuncIdentIndex].ProcAsBlock then
          begin
          Result := TRUE;
          Exit;
          end;        
  Result := FALSE;
  end; // IsCurrentOrOuterFunc



  
var
  IdentIndex: Integer;
  DesignatorType: Integer;
  DesignatorIsStatement: Boolean;
  
  
begin // CompileStatement
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileStatement');
CompileLabel;
if FirstStatement then    // this is the first
                          // statement on the line; handle anything
                          // to do such as line-number tracing
  begin


       FirstStatement := false; // Now it isn't anymore, but will be again, soon
  end;

case Tok.Kind of

  IDENTTOK:       // Assignment or procedure call
    begin
    if FieldOrMethodInsideWithFound(Tok.Name) then                      // Record field or method inside a WITH block
      begin
      DesignatorIsStatement := CompileDesignator(DesignatorType, FALSE);
      CompileAssignmentOrCall(DesignatorType, DesignatorIsStatement);
      end 
    else                                          // Ordinary identifier
      begin  
      IdentIndex := GetIdent(Tok.Name);
      
      case Ident[IdentIndex].Kind of
      
        VARIABLE, USERTYPE:                       // Assignment or procedural variable call
          begin
          DesignatorIsStatement := CompileDesignator(DesignatorType, FALSE);
          CompileAssignmentOrCall(DesignatorType, DesignatorIsStatement); 
          end;

        PROC, FUNC:                                          // Procedure or function call (returned result discarded)
            if Ident[IdentIndex].PredefProc <> EMPTYPROC then  // Predefined procedure
            begin
                Parserstate.ProcFuncName :=  Ident[IdentIndex].Name;
                if Ident[IdentIndex].Kind <> PROC then
                begin
                    Fatal('Procedure expected but predefined function ' + Parserstate.ProcFuncName + ' found');
              	    exit;
                end;
                CompilePredefinedProc(Ident[IdentIndex].PredefProc, LoopNesting)
            end
            else                                                          // User-defined procedure or function
            begin
                NextTok;
            
                if Tok.Kind = BECOMESTOK then                                // Special case: assignment to a function name
                begin
                    if not IsCurrentOrOuterFunc(IdentIndex) then
                    begin
	                Fatal('Function name expected but ' + Ident[IdentIndex].Name + ' found');
	                exit;
	            end;    

                 // Push pointer to Result
                    PushVarIdentPtr(Ident[IdentIndex].ResultIdentIndex);
                    DesignatorType := Ident[Ident[IdentIndex].ResultIdentIndex].DataType;
              
                    if Ident[Ident[IdentIndex].ResultIdentIndex].PassMethod = VARPASSING then
                        DerefPtr(POINTERTYPEINDEX);

                    CompileAssignment(DesignatorType);
                end
                else             // General rule: procedure or function call
                begin
                    Parserstate.ProcFuncName := Ident[IdentIndex].Name;
                    CompileCall(IdentIndex);
              
                    DesignatorType := Ident[IdentIndex].Signature.ResultType;
              
                    if (Ident[IdentIndex].Kind = FUNC) and (Tok.Kind in [DEREFERENCETOK, OBRACKETTOK, PERIODTOK, OPARTOK]) and
                       ((Types[DesignatorType].Kind in StructuredTypes) or DereferencePointerAsDesignator(DesignatorType, FALSE)) then
                    begin
                        PushFunctionResult(DesignatorType);
                        DesignatorIsStatement := CompileSelectors(DesignatorType, TRUE);
                        CompileAssignmentOrCall(DesignatorType, DesignatorIsStatement);
                    end;
                end;
            end;  
      else  //
      	begin
           Fatal('$$ 993 Statement expected but ' + Ident[IdentIndex].Name + ' found');

           // dumpcode not used, just saved
           //**ELSECATCHER
           // Our first attempt at error recovery; extra ; before else
           If itIs(ELSETOK) then  // erroneous ; before ELSE
           begin
                 Err(Err_70);       // fault the compile
                 CompileElseStatement(LoopNesting);
           end ;
        end;	
      end // case Ident[IdentIndex].Kind
      end; // else
    end;    

  ASMTOK:
   CompileAssemblerStatement(LoopNesting);

  BEGINTOK:
    CompileCompoundStatement(LoopNesting);    

  CASETOK:                              // std CASE stmt
    CompileCaseStatement(LoopNesting);  

  FORTOK:                        // FOR statement
    CompileForStatement(LoopNesting + 1);
    
  GOTOTOK:
    CompileGotoStatement(LoopNesting);

  IFTOK:
      CompileIfStatement(LoopNesting);

  REPEATTOK:
    CompileRepeatStatement(LoopNesting + 1);

  WHILETOK:
    CompileWhileStatement(LoopNesting + 1);

  WITHTOK:
    CompileWithStatement(LoopNesting);

end;// case

end;// CompileStatement
{$HIDE block,procfunc}


// Begin is about 440 lines ahead
procedure CompileType(var DataType: Integer);


  procedure CompileEnumeratedType(var DataType: Integer);
  var
    ConstIndex: Integer;
  begin
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileEnumeratedType');
  // Add new anonymous type
  DeclareType(ENUMERATEDTYPE);
  DataType := NumTypes;

  // Compile enumeration constants
  ConstIndex := 0;
  NextTok;
  
  repeat
    AssertIdent;
    DeclareIdent(Tok.Name, CONSTANT, 0, FALSE, DataType,
                EMPTYPASSING, ConstIndex, 0.0, '', [],
                EMPTYPROC, '', 0,Tok.DeclaredLine,Tok.DeclaredPos );
    
    Inc(ConstIndex);
    if ConstIndex > MAXENUMELEMENTS - 1 then
        begin
      		Fatal('Too many enumeration elements');

      	end;		
      
    NextTok;
    
    if Tok.Kind <> COMMATOK then Break;
    NextTok;
  until FALSE;
  
  EatTok(CPARTOK);
  
  Types[DataType].Low  := 0;
  Types[DataType].High := ConstIndex - 1;
  end; // CompileEnumeratedType




  procedure CompileTypedPointerType(var DataType: Integer);
  var
    NestedDataType: Integer;
  begin
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileTypedPointerType');
  // Add new anonymous type
  DeclareType(POINTERTYPE);
  DataType := NumTypes;

  // Compile pointer base type
  NextTok;
  CompileTypeIdent(NestedDataType, TRUE);
    
  Types[DataType].BaseType := NestedDataType;
  end; // CompileTypedPointerType
  
  
  
  
  procedure CompileArrayType(var DataType: Integer);
  var
    ArrType, IndexType, NestedDataType: Integer;
  begin
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileArrayType');
  NextTok;
  EatTok(OBRACKETTOK);

  DataType := NumTypes + 1;

  repeat
    // Add new anonymous type
    DeclareType(ARRAYTYPE);
    Types[NumTypes].IsOpenArray := FALSE;
    ArrType := NumTypes;

    CompileType(IndexType);
    if not (Types[IndexType].Kind in OrdinalTypes) then
      begin
      	  Fatal('Ordinal type expected for array bounds');

      end;	  
    Types[ArrType].IndexType := IndexType;

    if Tok.Kind <> COMMATOK then Break;
    
    Types[ArrType].BaseType := NumTypes + 1;
    NextTok;
  until FALSE;

  EatTok(CBRACKETTOK);
  EatTok(OFTOK);                    // OF in ARRAY [ ... ] OF
  if (TokenCTrace in TraceCompiler) or (KeywordCTrace in TraceCompiler) then
      EmitToken('OF');

  CompileType(NestedDataType);
  Types[ArrType].BaseType := NestedDataType;  
  end; // CompileArrayType
  
  
  
  
  procedure CompileRecordOrInterfaceType(var DataType: Integer; IsInterfaceType: Boolean);
  

    procedure DeclareField(const FieldName: TString; RecType, FieldType: Integer; var NextFieldOffset: Integer);
    var
      i, FieldTypeSize: Integer;      
    begin
        If  (ActivityCTrace in TraceCompiler) then EmitHint('P DeclareField');
    for i := 1 to Types[RecType].NumFields do
      if Types[RecType].Field[i]^.Name = FieldName then
        Begin
	        Fatal('Duplicate field ' + FieldName);
	      ;
	     end;

    // Add new field
    Inc(Types[RecType].NumFields);
    if Types[RecType].NumFields > MAXFIELDS then
      begin
  	    Fatal('Too many fields');

  	  end;  
      
    New(Types[RecType].Field[Types[RecType].NumFields]);
    
    with Types[RecType].Field[Types[RecType].NumFields]^ do
      begin
      Name     := FieldName;
      DataType := FieldType;
      Offset   := NextFieldOffset;            
      end;
      
    // For interfaces, save Self pointer offset from the procedural field
    if Types[RecType].Kind = INTERFACETYPE then
      Types[FieldType].SelfPointerOffset := -NextFieldOffset;      
    
    FieldTypeSize := TypeSize(FieldType);
    if FieldTypeSize >
       HighBound(INTEGERTYPEINDEX) - NextFieldOffset then
       begin
      	   Fatal('Type size is too large');

       end;

    NextFieldOffset := NextFieldOffset + FieldTypeSize;
    end; // DeclareField
    
    
    
    procedure CompileFixedFields(RecType: Integer; var NextFieldOffset: Integer);
    var
      FieldInListName: array [1..MAXFIELDS] of TString;
      NumFieldsInList, FieldInListIndex: Integer;
      FieldType: Integer;
      
    begin
        If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileFixedFields');
    while not (Tok.Kind in [CASETOK, ENDTOK, CPARTOK]) do     // (exclude) CASE in RECORD
      begin
      NumFieldsInList := 0;
      
      repeat
        AssertIdent;

        Inc(NumFieldsInList);
        if NumFieldsInList > MAXFIELDS then
	       begin
    	       Fatal('Too many fields');

    	   end;     
          
        FieldInListName[NumFieldsInList] := Tok.Name;

        NextTok;
        if (Tok.Kind <> COMMATOK) or IsInterfaceType then Break;
        NextTok;
      until FALSE;

      EatTok(COLONTOK);

      CompileType(FieldType);
      
      if IsInterfaceType and (Types[FieldType].Kind <> PROCEDURALTYPE) then
        begin
        	Fatal('Non-procedural fields are not allowed in interfaces');      

        end;

      for FieldInListIndex := 1 to NumFieldsInList do
        DeclareField(FieldInListName[FieldInListIndex], DataType, FieldType, NextFieldOffset);

      if Tok.Kind <> SEMICOLONTOK then Break; 
      NextTok;
      end; // while
    
    end; // CompileFixedFields
    
    
        
    procedure CompileFields(RecType: Integer; var NextFieldOffset: Integer);    
    var
      TagName: TString;
      TagVal: TConst;
      TagType, TagValType: Integer;
      TagTypeIdentIndex: Integer;
      VariantStartOffset: Integer;
    
    begin
        If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileFields');
    // Fixed fields
    CompileFixedFields(DataType, NextFieldOffset);
    
    // Variant fields
    if (Tok.Kind = CASETOK) and not IsInterfaceType then      // CASE in RECORD
      begin   
      NextTok;
      
      // Tag field
      AssertIdent;
      TagTypeIdentIndex := GetIdentUnsafe(Tok.Name);

      // this one is for RECORD .. CASE BOOLEAN Of etc.
      if (TagTypeIdentIndex <> 0) and (Ident[TagTypeIdentIndex].Kind = USERTYPE) then      // Type name found
        begin
        TagType := Ident[TagTypeIdentIndex].DataType;
        NextTok;
        end
      else                                                                                 // Field name found  
        begin    // RECORD .. CASE XRAY:INTEGER OF etc.
        TagName := Tok.Name;
        NextTok;
        EatTok(COLONTOK);      
        CompileType(TagType);           
        DeclareField(TagName, DataType, TagType, NextFieldOffset);
        end;
        
      if not (Types[TagType].Kind in OrdinalTypes) then
        begin
        	Fatal('Ordinal type expected for case variant');

        end;
    
      VariantStartOffset := NextFieldOffset;    
      EatTok(OFTOK);                           // OF in type OF
      if (TokenCTrace in TraceCompiler) or (KeywordCTrace in TraceCompiler) then
          EmitToken('OF');
      
      // Variants
      repeat
        repeat
          CompileConstExpression(TagVal, TagValType);
          GetCompatibleType(TagType, TagValType);
          if Tok.Kind <> COMMATOK then Break;
          NextTok; 
        until FALSE;
    
        EatTok(COLONTOK);
        EatTok(OPARTOK);
        
        NextFieldOffset := VariantStartOffset;
        CompileFields(DataType, NextFieldOffset);       // Field in RECORD
        
        EatTok(CPARTOK);      
        if (Tok.Kind = CPARTOK) or (Tok.Kind = ENDTOK) then Break;
 
        EatTok(SEMICOLONTOK);      
      until (Tok.Kind = CPARTOK) or (Tok.Kind = ENDTOK);
      
      end; // if    
    end; // CompileFields    
    

  
  var
    NextFieldOffset: Integer;
    
  
  begin // CompileRecordOrInterfaceType
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileRecordOrInterfaceType');
  NextFieldOffset := 0;
  
  // Add new anonymous type  
  if IsInterfaceType then
    DeclareType(INTERFACETYPE)
  else
    DeclareType(RECORDTYPE);
  
  Types[NumTypes].NumFields := 0;
  DataType := NumTypes;
  
  // Declare hidden Self pointer for interfaces
  if IsInterfaceType then
    DeclareField('SELF', DataType, POINTERTYPEINDEX, NextFieldOffset);  

  NextTok;
  CompileFields(DataType, NextFieldOffset);    
  EatTok(ENDTOK);        // RECORD
  end; // CompileRecordOrInterfaceType




  procedure CompileSetType(var DataType: Integer);
  var
    NestedDataType: Integer;
  begin
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileSetType');
  // Add new anonymous type
  DeclareType(SETTYPE);
  DataType := NumTypes;
  
  NextTok;
  EatTok(OFTOK);          // OF in SET OF
  if (TokenCTrace in TraceCompiler) or (KeywordCTrace in TraceCompiler) then
      EmitToken('OF');

  CompileType(NestedDataType);
  
  if (LowBound(NestedDataType) < 0) or (HighBound(NestedDataType) > MAXSETELEMENTS - 1) then
    begin
    	Fatal('Too many set elements');

    end;	
  
  Types[DataType].BaseType := NestedDataType; 
  end; // CompileSetType
  
  
  

  procedure CompileStringType(var DataType: Integer);
  var
    LenConstVal: TConst;
    LenType, IndexType: Integer;    
  begin
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileStringType');
  NextTok;    
  
  if Tok.Kind = OBRACKETTOK then
    begin
    NextTok;
    CompileConstExpression(LenConstVal, LenType);
    
    if not (Types[LenType].Kind in IntegerTypes) then
      begin
      	  Fatal('Integer type expected'); 

      	 end;
      
    if (LenConstVal.OrdValue <= 0) or (LenConstVal.OrdValue > MAXSTRLENGTH) then
      begin
      	  Fatal('Illegal string length');  

      end;
    
    // Add new anonymous type: 1..Len + 1
    DeclareType(SUBRANGETYPE);
    IndexType := NumTypes;

    Types[IndexType].BaseType := LenType;
    Types[IndexType].Low      := 1;
    Types[IndexType].High     := LenConstVal.OrdValue + 1;
    
    // Add new anonymous type: array [1..Len + 1] of Char
    DeclareType(ARRAYTYPE);
    DataType := NumTypes;

    Types[DataType].BaseType    := CHARTYPEINDEX;
    Types[DataType].IndexType   := IndexType;
    Types[DataType].IsOpenArray := FALSE;
    
    EatTok(CBRACKETTOK);
    end
  else
    DataType := STRINGTYPEINDEX;  

  end; // CompileStringType



  
  procedure CompileFileType(var DataType: Integer);
  var
    NestedDataType: Integer;
  begin
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileFileType');

  NextTok;
  
  if Tok.Kind = OFTOK then          // Typed file
    begin
    NextTok;
    CompileType(NestedDataType);
    
    if Types[NestedDataType].Kind = FILETYPE then
      begin
      	  Fatal('File of files is not allowed');    // That would be a directory!

      end;
   
    // Add new anonymous type
    DeclareType(FILETYPE);    
    Types[NumTypes].BaseType := NestedDataType;
    
    DataType := NumTypes;
    end
  else                              // Untyped/text file
    DataType := FILETYPEINDEX; 
 
  end; // CompileFileType
  



  procedure CompileSubrangeType(var DataType: Integer);
  var
    ConstVal: TConst;
    LowBoundType, HighBoundType: Integer;
  begin
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileSubrangeType');
  // Add new anonymous type
  DeclareType(SUBRANGETYPE);
  DataType := NumTypes;

  CompileConstExpression(ConstVal, LowBoundType);                               // Subrange lower bound
  if not (Types[LowBoundType].Kind in 
          OrdinalTypes + [SUBRANGETYPE]) then
     begin    
    	Fatal('Ordinal type expected for low bound of subrange');

    end;
  Types[DataType].Low := ConstVal.OrdValue;

  EatTok(RANGETOK);

  CompileConstExpression(ConstVal, HighBoundType);                              // Subrange upper bound
  if not (Types[HighBoundType].Kind in
          OrdinalTypes + [SUBRANGETYPE]) then
     begin     
   	 Fatal('Ordinal type expected for upper bound of subrange');

     end;
  Types[DataType].High := ConstVal.OrdValue;

  GetCompatibleType(LowBoundType, HighBoundType);

  if Types[DataType].High < Types[DataType].Low then
    begin
    	Fatal('Illegal subrange bounds');

    end;

  Types[DataType].BaseType := LowBoundType;  
  end; // CompileSubrangeType
  
  
  
  
  procedure CompileProceduralType(var DataType: Integer; IsFunction: Boolean);
  begin
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileProceduralType');
  PatchState := PatchProc;
  DeclareType(PROCEDURALTYPE);
  Types[NumTypes].MethodIdentIndex := 0;
  DataType := NumTypes;
  
  NextTok;
  
  CompileFormalParametersAndResult(IsFunction, Types[DataType].Signature);  
  end; // CompileProceduralType
  
  

var
  IdentIndex: LongInt;
  TypeNameGiven: Boolean;   


begin // CompileType

if Tok.Kind = PACKEDTOK then        // PACKED has no effect
  begin
  NextTok;
  if not (Tok.Kind in 
       [ARRAYTOK, RECORDTOK, INTERFACETOK, SETTOK, FILETOK]) then
     begin   
    	Fatal('PACKED is not allowed here');

      end		
  end;
 
case Tok.Kind of

  OPARTOK:
    CompileEnumeratedType(DataType);
    
  DEREFERENCETOK: 
    CompileTypedPointerType(DataType);
  
  ARRAYTOK:       
    CompileArrayType(DataType); 
 
  RECORDTOK, INTERFACETOK:      
    CompileRecordOrInterfaceType(DataType, Tok.Kind = INTERFACETOK);
    
  SETTOK:      
    CompileSetType(DataType); 
   
  STRINGTOK:
    CompileStringType(DataType);
    
  FILETOK:
    CompileFileType(DataType);
    
  PROCEDURETOK, FUNCTIONTOK:
    CompileProceduralType(DataType, Tok.Kind = FUNCTIONTOK)
     
else                                                                              // Subrange or type name
  TypeNameGiven := FALSE;
  IdentIndex := 0;
  if Tok.Kind = IDENTTOK then      
    begin
    IdentIndex := GetIdent(Tok.Name);
    if Ident[IdentIndex].Kind = USERTYPE then TypeNameGiven := TRUE;
    end;

  if TypeNameGiven then                                                           // Type name
    begin
    DataType := Ident[IdentIndex].DataType;
    NextTok;
    end
  else                                                                            // Subrange
    CompileSubrangeType(DataType);
    
end; // case  

end;// CompileType


{ $Show block,procfunc}

// Calls CompileDeclarations to Handle CONST, TYPE, VAR, LABEL and nested proc/func,
// then processes BEGIN/END of that rocedure, function or main program
// Note this proc's begin statement is about 800 lines away
procedure CompileBlock(BlockIdentIndex: Integer);

  // FIXME when going to ident pointers
  //  This is a list walker, base to top
  procedure ResolveForwardReferences;
  var
    TypeIndex, TypeIdentIndex, FieldIndex: Integer;
    DataType: Integer;    
  begin
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P ResolveForwardReferences');
  for TypeIndex := 1 to NumTypes do
    if Types[TypeIndex].Kind = FORWARDTYPE then
      begin
      TypeIdentIndex := GetIdent(Types[TypeIndex].TypeIdentName);     
      
      if Ident[TypeIdentIndex].Kind <> USERTYPE then
      	begin
	        Fatal('Type name expected');

	     end;   
        
      // Forward reference resolution
      DataType := Ident[TypeIdentIndex].DataType;
      
      Types[TypeIndex] := Types[DataType];
      Types[TypeIndex].AliasType := DataType;
      
      if Types[DataType].Kind in [RECORDTYPE, INTERFACETYPE] then
        for FieldIndex := 1 to Types[DataType].NumFields do
          begin
          New(Types[TypeIndex].Field[FieldIndex]);
          Types[TypeIndex].Field[FieldIndex]^ := Types[DataType].Field[FieldIndex]^;
          end;
      end; // if    
  end; // ResolveForwardReferences




  procedure CompileInitializer(InitializedDataOffset: LongInt; ConstType: Integer);
  var
    ConstVal: TConst;
    ConstValType: Integer;
    NumElements, ElementIndex, FieldIndex: Integer;
    
  begin
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileInitializer');
    // Numbers
  if Types[ConstType].Kind in OrdinalTypes + [REALTYPE, SINGLETYPE] then
    begin

    CompileConstExpression(ConstVal, ConstValType);

    // Try to convert integer to double or double to single
    ConvertConstIntegerToReal(ConstType, ConstValType, ConstVal);
    ConvertConstRealToReal(ConstType, ConstValType, ConstVal);          
    GetCompatibleType(ConstType, ConstValType); 
    if Types[ConstType].Kind = REALTYPE then
      Move(ConstVal.RealValue, InitializedGlobalData[InitializedDataOffset], TypeSize(ConstType))
    else if Types[ConstType].Kind = SINGLETYPE then
      Move(ConstVal.SingleValue, InitializedGlobalData[InitializedDataOffset], TypeSize(ConstType)) 
    else
      Move(ConstVal.OrdValue, InitializedGlobalData[InitializedDataOffset], TypeSize(ConstType));
    end
    
  // Arrays
  else if Types[ConstType].Kind = ARRAYTYPE then
    begin
    
    if IsString(ConstType) and (Tok.Kind <> OPARTOK) then         // Special case: strings
      begin
      CompileConstExpression(ConstVal, ConstValType);
      ConvertConstCharToString(ConstType, ConstValType, ConstVal);
      GetCompatibleType(ConstType, ConstValType);
      
      if Length(ConstVal.StrValue) > TypeSize(ConstType) - 1 then
        begin
        	Fatal('String is too long');

        end;
        
      DefineStaticString(ConstVal.StrValue, InitializedDataOffset, InitializedDataOffset);
      end
    else                                                          // General rule
      begin
      EatTok(OPARTOK);
      
      NumElements := HighBound(Types[ConstType].IndexType) - LowBound(Types[ConstType].IndexType) + 1;
      for ElementIndex := 1 to NumElements do
        begin
        CompileInitializer(InitializedDataOffset, Types[ConstType].BaseType);
        InitializedDataOffset := InitializedDataOffset + TypeSize(Types[ConstType].BaseType);

        // CHANGEME: This would be a good place to expand the
        //     error message so that if the next token is not a
        //     comma when one is expected, to say that more
        //     elements are needed, and where ) is needed, that
        //     too many elements have been supplied.
        if ElementIndex < NumElements then 
          EatTok(COMMATOK)          // "Comma expected"
        else
          EatTok(CPARTOK);          // ") expected"
        end; // for
      end; // else

    end
    
  // Records
  else if Types[ConstType].Kind = RECORDTYPE then
    begin
    EatTok(OPARTOK);
    
    repeat
      AssertIdent;
      FieldIndex := GetField(ConstType, Tok.Name);
      
      NextTok;
      EatTok(COLONTOK);
      
      CompileInitializer(InitializedDataOffset + Types[ConstType].Field[FieldIndex]^.Offset, Types[ConstType].Field[FieldIndex]^.DataType);          
      
      if Tok.Kind <> SEMICOLONTOK then Break;
      NextTok; 
    until FALSE;
    
    EatTok(CPARTOK);   // )
    end
    
  // Sets
  else if Types[ConstType].Kind = SETTYPE then
    begin
    CompileConstExpression(ConstVal, ConstValType);
    GetCompatibleType(ConstType, ConstValType);
    DefineStaticSet(ConstVal.SetValue, InitializedDataOffset, InitializedDataOffset);
    end        

  // pointers
  else if Types[ConstType].Kind = POINTERTYPE then
    BEGIN
        ConstVal.PointerValue:= NIL;
        Move(ConstVal.PointerValue, InitializedGlobalData[InitializedDataOffset], TypeSize(ConstType));
        if Tok.Kind <> NILTOK then
          begin
           Err(Err_305);  // "NIL is only initialization allowed"
           if tok.kind <> SEMICOLONTOK THEN
              Presume(SkipUntil,SEMICOLONTOK);
          end
        else  // initialization  OK
          NextTok;       // step over NIL

    end

  else
    begin
      	Fatal('Illegal type');

    end

  end; // CompileInitializer    



 
  procedure CompileLabelDeclarations;   // LABEL statement
  begin
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileLabelDeclarations');
  repeat
    AssertIdent;  // CHANGEME - Allow numbers for GOTO labels
    
    DeclareIdent(Tok.Name, GOTOLABEL, 0, FALSE, 0,
                 EMPTYPASSING, 0, 0.0, '', [], EMPTYPROC,
                 '', 0, Tok.DeclaredLine, Tok.DeclaredPos);
    
    NextTok;
    if Tok.Kind <> COMMATOK then Break;
    NextTok;
  until FALSE;
  
  EatTok(SEMICOLONTOK);
  end; // CompileLabelDeclarations


 
  
  procedure CompileConstDeclarations;    // CONST
  
  
    procedure CompileUntypedConstDeclaration(var NameTok: TToken);
    var
      ConstVal: TConst;
      ConstValType: Integer;    
    begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileUntypedConstDeclaration');
    EatTok(EQTOK);    
    CompileConstExpression(ConstVal, ConstValType);
    DeclareIdent(NameTok.Name, CONSTANT, 0, FALSE, ConstValType,
                 EMPTYPASSING, ConstVal.OrdValue,
                 ConstVal.RealValue, ConstVal.StrValue,
                 ConstVal.SetValue, EMPTYPROC, '', 0,
                 NameTok.DeclaredLine, NameTok.DeclaredPos);
    end; // CompileUntypedConstDeclaration;
   
    
    procedure CompileTypedConstDeclaration(var NameTok: TToken);
    var
      ConstType: Integer;    
    begin
        If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileTypedConstDeclaration');
    EatTok(COLONTOK);    
    CompileType(ConstType);    
    DeclareIdent(NameTok.Name, CONSTANT, 0, FALSE, ConstType, VARPASSING,
                  0, 0.0, '', [], EMPTYPROC, '', 0,
                  NameTok.DeclaredPos, NameTok.DeclaredLine);
    EatTok(EQTOK);    
    CompileInitializer(Ident[NumIdent].Address, ConstType);   
    end; // CompileTypedConstDeclaration    


  var
    NameTok: TToken; 
   
  begin // CompileConstDeclarations
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileConstDeclarations');
  repeat
    AssertIdent;

    NameTok := Tok;
    NextTok;
    
    if Tok.Kind = EQTOK then
      CompileUntypedConstDeclaration(NameTok)
    else
      CompileTypedConstDeclaration(NameTok);

    EatTok(SEMICOLONTOK);
  until Tok.Kind <> IDENTTOK;
  end; // CompileConstDeclarations
  
  

  
  procedure CompileTypeDeclarations;   // TYPE
  var
    NameTok: TToken;
    VarType: Integer;
  begin
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileTypeDeclarations');
  repeat
    AssertIdent;

    NameTok := Tok;
    NextTok;
    EatTok(EQTOK);

    CompileType(VarType);
    DeclareIdent(NameTok.Name, USERTYPE, 0, FALSE, VarType,
                 EMPTYPASSING,  0, 0.0,
                 '', [], EMPTYPROC, '', 0,
                 NameTok.DeclaredLine, NameTok.DeclaredPos);
    
    EatTok(SEMICOLONTOK);
  until Tok.Kind <> IDENTTOK;

  ResolveForwardReferences;
  end; // CompileTypeDeclarations
  
  
  

  procedure CompileVarDeclarations;     // VAR statement in a block, not in proc/func signature
  var
    IdentInListName: array [1..MAXPARAMS] of TString;
    IdeNtInLIstPos,
    IdentInListLine: array [1..MAXPARAMS] of Integer;
    NumIdentInList, IdentInListIndex: Integer;
    VarType: Integer;
  begin
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileVarDeclarations');
  repeat
    NumIdentInList := 0;
    repeat
      AssertIdent;

      Inc(NumIdentInList);
      if NumIdentInList > MAXPARAMS then
      	begin
        	Fatal('Too many variables in one list');

        end;
      
      IdentInListName[NumIdentInList] := Tok.Name;
      IdentInListPos[NumIdentInList]  := Tok.DeclaredPos;
      IdentInListLine[NumIdentInList] := Tok.DeclaredLine;

      NextTok;

      if Tok.Kind <> COMMATOK then Break;
      NextTok;
    until FALSE;

    EatTok(COLONTOK);      // What type of VAR is it?

    CompileType(VarType);

    if Tok.Kind = EQTOK then                                     // Initialized variable (equivalent to a typed constant, but mutable)
      begin
      if BlockStack[BlockStackTop].Index <> 1 then
      	begin
        	Fatal('Local variables cannot be initialized');

        end;
        
      if NumIdentInList <> 1 then
      	begin
        	Fatal('Multiple variables cannot be initialized');

        end;
        
      NextTok;
      DeclareIdent(IdentInListName[1], CONSTANT, 0, FALSE, VarType,   // Single Initialized variable
                    VARPASSING,
                    0,
                    0.0,
                    '',
                    [],
                    EMPTYPROC,
                    '',
                    0,
                    IdentInListLine[1],
                    IdentInListPos[1]);
      Ident[NumIdent].IsTypedConst := FALSE;  // Allow mutability
      CompileInitializer(Ident[NumIdent].Address, VarType);    // Initialize it
      end
    else                                                         // Uninitialized variables   
      for IdentInListIndex := 1 to NumIdentInList do
        DeclareIdent(IdentInListName[IdentInListIndex],VARIABLE, 0,FALSE, VarType,
                      EMPTYPASSING,
                      0,
                      0.0,
                      '',
                      [],
                      EMPTYPROC,
                      '',
                      0,
                    IdentInListLine[IdentInListIndex],
                    IdentInListPos[IdentInListIndex]);
      
    EatTok(SEMICOLONTOK);
  until Tok.Kind <> IDENTTOK;

  ResolveForwardReferences;
  end; // CompileVarDeclarations




  procedure CompileProcFuncDeclarations(IsFunction: Boolean);

    
    function CompileDirective(const ImportFuncName: TString): Boolean;
    var
      ImportLibNameConst: TConst;
      ImportLibNameConstValType: Integer;
      
    begin
        If  (ActivityCTrace in TraceCompiler) then  EmitHint('f CompileDirective');
    Result := FALSE;
    
    if Tok.Kind = IDENTTOK then
      if Tok.Name = 'EXTERNAL' then      // External (Windows API) declaration
        begin
        Ident[NumIdent].isAbsolute := TRUE; // mark as external
        if isFunction then
            begin
                inc(ScannerState.ExtFunc);
                inc(TotalExtFunc);
                // and reduce this as a unit func
                dec(ScannerState.FuncCount);
                dec(TotalFuncCount);
            end
        else
            begin
                inc(ScannerState.ExtProc);
                inc(TotalExtProc);
                // and reduce this as a unit proc
                dec(ScannerState.ProcCount);
                dec(TotalProcCount);
            end;

        if BlockStackTop <> 1 then
        	begin
          		Fatal('External declaration must be global');

          	end;
          
        // Read import library name
        NextTok;      
        CompileConstExpression(ImportLibNameConst, ImportLibNameConstValType);
        if not IsString(ImportLibNameConstValType) then
        	begin
          		Fatal('Library name expected');      

          	end;
        
        // Register import function
        GenerateImportFuncStub(AddImportFunc(ImportLibNameConst.StrValue, ImportFuncName));
        
        EatTok(SEMICOLONTOK);
        Result := TRUE;
        end
      else if Tok.Name = 'FORWARD' then  // Forward declaration
        begin
        Inc(NumBlocks);
        Ident[NumIdent].ProcAsBlock := NumBlocks;
        Ident[NumIdent].IsUnresolvedForward := TRUE;
        Ident[NumIdent].DeclaredLine :=  Tok.DeclaredLine;           // FORWARD
        GenerateForwardReference;
        
        NextTok;
        EatTok(SEMICOLONTOK);
        Result := TRUE;
        end
      else  if Tok.Name = 'XYZZY' then
           Err(Err_899)   // "Nothing happens"
      else
      	begin
        	Fatal('Unknown directive ' + Tok.Name);  

        end;
    end; // CompileDirective


    function CompileInterface: Boolean;
    begin
        If  (ActivityCTrace in TraceCompiler) then EmitHint('f CompileInterface');

    Result := FALSE;
    
    // Procedure interface in the interface section of a unit is an implicit forward declaration
    if ParserState.IsInterfaceSection and (BlockStack[BlockStackTop].Index = 1) then
      begin 
      Inc(NumBlocks);      
      Ident[NumIdent].ProcAsBlock := NumBlocks;
      Ident[NumIdent].IsUnresolvedForward := TRUE;      // INTERFACE declaration
      GenerateForwardReference;

      Result := TRUE;
      end;
      
    end; // CompileInterface

    
  
  var
    ForwardIdentIndex, FieldIndex: Integer;
    ReceiverType: Integer;
    ProcOrFunc: TIdentKind;
    ProcPos,
    ProcLine: Integer;
    NonUppercaseProcName, ReceiverName: TString;
    ForwardResolutionSignature: TSignature;
    
    
  begin // CompileProcFuncDeclarations
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileProcFuncDeclarations');
  AssertIdent;
  Parserstate.ProcFuncName := Tok.Name;      // current proc or func name
  ProcPos  := Tok.DeclaredPos;
  ProcLine := Tok.DeclaredLine;

  if  (TokenCTrace in TraceCompiler) or
      ((ProcCTrace in TraceCompiler) and (not isFunction)) or
      ((FuncCTrace in TraceCompiler) and isFunction) then
     if isfunction then
         EmitToken('func '+Parserstate.ProcFuncName)
      else
         EmitToken('proc '+Parserstate.ProcFuncName);

  NonUppercaseProcName := Tok.NonUppercaseName;
  NextTok;
  
  // Check for method declaration
  ReceiverName := '';
  ReceiverType := 0;
  
  if Tok.Kind = FORTOK then  // FOR in METHOD
    begin
    NextTok;
    AssertIdent;
    ReceiverName := Tok.Name;

    NextTok;
    EatTok(COLONTOK);
    CompileTypeIdent(ReceiverType, FALSE);
    
    if not (Types[ReceiverType].Kind in StructuredTypes) then
    	BEGIN
      		Fatal('Structured type expected');

      	end;
    
    
    if BlockStack[BlockStackTop].Index <> 1 then
    	begin
      		Fatal('Methods cannot be nested');

      	end;

    if Types[ReceiverType].Kind in [RECORDTYPE, INTERFACETYPE] then
      begin
      FieldIndex := GetFieldUnsafe(ReceiverType, Parserstate.ProcFuncName);
      if FieldIndex <> 0 then
      	begin
            Fatal('Duplicate field ');

        end;
      end;    
    end;  

  // Check for forward declaration resolution
  if ReceiverType <> 0 then
    ForwardIdentIndex := GetMethodUnsafe(ReceiverType, Parserstate.ProcFuncName)
  else
    ForwardIdentIndex := GetIdentUnsafe(Parserstate.ProcFuncName);
  
  // Possibly found an identifier of
  // another kind or scope, or it is already resolved
  if ForwardIdentIndex <> 0 then
    if not Ident[ForwardIdentIndex].IsUnresolvedForward or
       (Ident[ForwardIdentIndex].Block <> BlockStack[BlockStackTop].Index) or
       ((Ident[ForwardIdentIndex].Kind <> PROC) and not IsFunction) or
       ((Ident[ForwardIdentIndex].Kind <> FUNC) and IsFunction) then
     ForwardIdentIndex := 0;

  // Procedure/function signature
  if ForwardIdentIndex <> 0 then        // Forward declaration resolution
    begin    
    CompileFormalParametersAndResult(IsFunction, ForwardResolutionSignature);
    CheckSignatures(Ident[ForwardIdentIndex].Signature, ForwardResolutionSignature, Parserstate.ProcFuncName);
    DisposeParams(ForwardResolutionSignature);
    end
  else                                                                // Conventional declaration
    begin
    if IsFunction then ProcOrFunc := FUNC else ProcOrFunc := PROC;
    
    DeclareIdent(Parserstate.ProcFuncName, ProcOrFunc, 0, FALSE, 0, EMPTYPASSING,
                 0, 0.0, '', [], EMPTYPROC, ReceiverName,
                 ReceiverType, ProcLine, ProcPos);
    CompileFormalParametersAndResult(IsFunction, Ident[NumIdent].Signature);

    if (ReceiverType <> 0) and 
       (Ident[NumIdent].Signature.CallConv <> DEFAULTCONV) then
       BEGIN
      	    Fatal('STDCALL/CDECL is not allowed for methods'); 

      	END;
    end;           	

  EatTok(SEMICOLONTOK);  
  
  // Procedure/function body, if any
  if ForwardIdentIndex <> 0 then                                                    // Forward declaration resolution
    begin
    if (ReceiverType <> 0) and 
       (ReceiverName <> Ident[ForwardIdentIndex].ReceiverName) then
       BEGIN
      	   Fatal('Incompatible receiver name');

      	END;
   
    GenerateForwardResolution(Ident[ForwardIdentIndex].Address);

    //$$$ This may be PROC/Func begin
    CompileBlock(ForwardIdentIndex);

    if (IndexCTrace in TraceCompiler) or  (TokenCTrace in TraceCompiler) then
       emittoken('EXIT CompileBlock ForwardIdentIndex='+Radix(ForwardIdentIndex,10)+
                 ' BlockStackTop='+Radix(BlockStackTop,10)+
                 ' BlockStack[BlockStackTop].Index='+Radix(BlockStack[BlockStackTop].Index,10));
    if BlockStack[BlockStackTop].Index = 1 then
       isLocal := False      // We are compiling at Unit level
    else
       isLocal := True;      // We are compiling "inside" a proc/func or nested one

    EatTok(SEMICOLONTOK); 
    
    Ident[ForwardIdentIndex].IsUnresolvedForward := FALSE; 
    end  
  else if not CompileDirective(NonUppercaseProcName) and not
             CompileInterface then  // Declaration in the interface part, external or forward declaration
    begin
    Inc(NumBlocks);                                                                 // Conventional declaration   
    Ident[NumIdent].ProcAsBlock := NumBlocks;
    CompileBlock(NumIdent);

    if (IndexCTrace in TraceCompiler) or  (TokenCTrace in TraceCompiler) then
       emittoken('EXIT CompileBlock NumIdent='+Radix(NumIdent,10)+
                 ' BlockStackTop='+Radix(BlockStackTop,10)+
                 ' BlockStack[BlockStackTop].Index='+Radix(BlockStack[BlockStackTop].Index,10));
    if BlockStack[BlockStackTop].Index = 1 then
       isLocal := False      // We are compiling at Unit level
    else
       isLocal := True;      // We are compiling "inside" a proc/func or nested one

    EatTok(SEMICOLONTOK);
    end;                                                               
   
  end; // CompileProcFuncDeclarations
  


  // Called by CompileBlock
  // Handle CONST, TYPE, VAR, LABEL and proc/func,
  // either for a unit or in another
  // procedure or function
  procedure CompileDeclarations;
  var
    DeclTok: TToken;
    ParamIndex, StackParamIndex: Integer;
    TotalParamSize: Integer;
    NestedProcsFound: Boolean;
    DebugString: String;
    isFunction:Boolean;

    procedure DeclareResult;  // *RESULT
    begin
        If  (ActivityCTrace in TraceCompiler) then EmitHint('P DeclareResult');
    with Ident[BlockIdentIndex].Signature do
      if (Types[ResultType].Kind in StructuredTypes) and
         ((CallConv = DEFAULTCONV) or
         (TypeSize(ResultType) > 2 * SizeOf(LongInt))) then
          // For functions returning structured variables,
          // Result is a hidden VAR parameter
           DeclareIdent('RESULT', VARIABLE, TotalParamSize, FALSE, ResultType,
                         VARPASSING, 0, 0.0, '',  [],  EMPTYPROC, '',  0, Compiler_Defined,  Structured_Result)
      else      // Otherwise, Result is a hidden local variable
        DeclareIdent('RESULT', VARIABLE, 0, FALSE, ResultType,
                     EMPTYPASSING, 0, 0.0, '', [], EMPTYPROC,  '', 0,  Compiler_Defined, Standard_Result);
      
    Ident[BlockIdentIndex].ResultIdentIndex := NumIdent;
    end; // DeclareResult

  // *DECLARATIONS 
  begin     // Procedure CompileDeclarations
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileDeclarations');
  NestedProcsFound := FALSE; 
 
  // For procedures and functions, declare parameters and the Result variable
  
  // Default calling convention: ([var Self,] [var Result,] Parameter1, ...
  //                         ParameterN [, StaticLink]), result returned in EAX
  // STDCALL calling convention: (ParameterN, ... Parameter1,
  //                         [, var Result]), result returned in EAX, small
  //                         structures in EDX:EAX, reals in ST(0)
  // CDECL calling convention:   equivalent to STDCALL, except that
  //                         caller clears the stack
  
  if BlockStack[BlockStackTop].Index <> 1 then             
    begin
    TotalParamSize := GetTotalParamSize(Ident[BlockIdentIndex].Signature,
                        Ident[BlockIdentIndex].ReceiverType <> 0, FALSE);
    
    // Declare Self
    if Ident[BlockIdentIndex].ReceiverType <> 0 then
      DeclareIdent(Ident[BlockIdentIndex].ReceiverName, VARIABLE,
                   TotalParamSize, FALSE, Ident[BlockIdentIndex].ReceiverType,
                   VARPASSING, 0, 0.0, '', [], EMPTYPROC, '', 0, -1, -8);
             
    // Declare Result (default calling convention)
    if (Ident[BlockIdentIndex].Kind = FUNC) and
       (Ident[BlockIdentIndex].Signature.CallConv = DEFAULTCONV) then
           DeclareResult;

    // Used for debugging and run-time error messages
    if (Ident[BlockIdentIndex].Kind = FUNC) then
       DebugString := 'Function'
    else
       DebugString := 'Procedure';
    DeclareIdent('XDP_PROCTYPE',CONSTANT, 0, FALSE, STRINGTYPEINDEX,
                 EMPTYPASSING, 1, 0.0, DebugString, [], EMPTYPROC, '', 0, Compiler_Defined, System_Constant);
    DeclareIdent('XDP_PROCNAME',CONSTANT, 0, FALSE, STRINGTYPEINDEX,
                 EMPTYPASSING, 1, 0.0, ParserState.ProcFuncName, [], EMPTYPROC, '', 0, Compiler_Defined, System_Constant);

    // An actual procedure defined in the interface section
    // (as opposed to the declaration) is usually a mistake of a
    // duplicate declaration, so warn them
    if ParserState.IsInterfaceSection then
        Err3( Err_801,DebugString,ParserState.ProcFuncName,
                  Radix(Ident[BlockIdentIndex].DeclaredLine,10));

    // Allocate and declare other parameters
    for ParamIndex := 1 to Ident[BlockIdentIndex].Signature.NumParams do
      begin
      if Ident[BlockIdentIndex].Signature.CallConv = DEFAULTCONV then
        StackParamIndex := ParamIndex
      else  
        StackParamIndex := Ident[BlockIdentIndex].Signature.NumParams - ParamIndex + 1;    // Inverse parameter stack for STDCALL/CDECL procedures     
  
      DeclareIdent(Ident[BlockIdentIndex].Signature.Param[StackParamIndex]^.Name,
                   VARIABLE,
                   TotalParamSize,
                   Ident[BlockIdentIndex].Signature.CallConv <> DEFAULTCONV,
                   Ident[BlockIdentIndex].Signature.Param[StackParamIndex]^.DataType,
                   Ident[BlockIdentIndex].Signature.Param[StackParamIndex]^.PassMethod,
                   0,
                   0.0,
                   '',
                   [],
                   EMPTYPROC,
                   '', 
                   0,
                   -1,
                   -9);
      end;

    // Declare Result (STDCALL/CDECL calling convention)
    if (Ident[BlockIdentIndex].Kind = FUNC) and (Ident[BlockIdentIndex].Signature.CallConv <> DEFAULTCONV) then
      DeclareResult;
              
    end; // if

  
  // Loop over interface/implementation sections
  repeat
  
    // Local declarations
    while Tok.Kind in [LABELTOK, CONSTTOK, TYPETOK, VARTOK, PROCEDURETOK, FUNCTIONTOK] do
      begin
      PatchState := PatchDecl;
      DeclTok := Tok;
      NextTok;
      
      case DeclTok.Kind of
        LABELTOK:
          CompileLabelDeclarations;
          
        CONSTTOK:     
          CompileConstDeclarations;
          
        TYPETOK:      
          CompileTypeDeclarations;
          
        VARTOK:                     //VAR declaration statement
          CompileVarDeclarations;
          
        PROCEDURETOK, FUNCTIONTOK:
          begin
              isFunction := DeclTok.Kind = FUNCTIONTOK;

              // Can't do trace here as we don't know the name yet

          if (BlockStack[BlockStackTop].Index <> 1) and not NestedProcsFound then
            begin
            NestedProcsFound := TRUE;
            GenerateNestedProcsProlog;
            end;
    
          CompileProcFuncDeclarations(isFunction);
          end;  // proc, func
      end; // case

      end;// while
      
      
    if ParserState.IsUnit and ParserState.IsInterfaceSection and
       (BlockStack[BlockStackTop].Index = 1) then
      begin
      // immediately before IMPLEMENTATION
      // insert fake procedure:
      // if system mode is off, turn on
      // unit name in scannerstate.unitname
      // insert patch of "PROCEDURE unitname$init;'
      // turn SYSTEM flag off if we turned it on
      // so that will be a publicly declared private procedure
      // only the compiler can get to it (Unless someone does
      // something weird.


      EatTok(IMPLEMENTATIONTOK); // *IMPLEMENTATION
      PatchState := PatchDecl;
      ParserState.IsInterfaceSection := FALSE;
      end
    else
      Break;    
    
  until FALSE;      

    
  // Jump to entry point
  if NestedProcsFound then
    GenerateNestedProcsEpilog;
    
  end;  // Procedure CompileDeclarations
  
  
  
 // FIXME when we switch to pointers
 // this needs to be revised
  procedure CheckUnresolvedDeclarations;
  var
    IdentIndex: Integer;
  begin
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CheckUnresolvedDeclarations');
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P CheckUnresolvedDeclarations');
     // Starting at the top of the identifier table,
     // work down checking for unresolved declarations
  IdentIndex := NumIdent;
  
  while (IdentIndex > 0) and (Ident[IdentIndex].Block = BlockStack[BlockStackTop].Index) do
    begin
    if (Ident[IdentIndex].Kind in [GOTOLABEL, PROC, FUNC]) and
        Ident[IdentIndex].IsUnresolvedForward then
          Fatal('Unresolved declaration (on Line ' +
                IntToStr(Ident[IdentIndex].DeclaredLine) +
                ') of ' + Ident[IdentIndex].Name);

    Dec(IdentIndex);
    end;
  end; // CheckUnresolvedDeclarations  
  
  


  procedure DeleteDeclarations;  
  begin
        If  (ActivityCTrace in TraceCompiler) then EmitHint('P DeleteDeclarations');
      If  (ActivityCTrace in TraceCompiler) then EmitHint('P DeleteDeclarations');

  // Delete local identifiers
  while (NumIdent > 0) and (Ident[NumIdent].Block = BlockStack[BlockStackTop].Index) do
    begin
    // Warn if not used
    if not Ident[NumIdent].IsUsed and not Ident[NumIdent].IsExported and (Ident[NumIdent].Kind = VARIABLE) and (Ident[NumIdent].PassMethod = EMPTYPASSING) then
      // error numbers 800-899 are warnings
      Err3(Err_800, Ident[NumIdent].Name ,   // Variable never used
            IntToStr(Ident[NumIdent].DeclaredLine),
               IntToStr(Ident[NumIdent].DeclaredPos));
  
    // If procedure or function, delete parameters first
    if Ident[NumIdent].Kind in [PROC, FUNC] then
      DisposeParams(Ident[NumIdent].Signature);

    // Delete identifier itself
    Dec(NumIdent);
    end;     
    
  // Delete local types
  while (NumTypes > 0) and (Types[NumTypes].Block = BlockStack[BlockStackTop].Index) do
    begin
    // If procedural type, delete parameters first
    if Types[NumTypes].Kind = PROCEDURALTYPE then
      DisposeParams(Types[NumTypes].Signature) 
    
    // If record or interface, delete fields first
    else if Types[NumTypes].Kind in [RECORDTYPE, INTERFACETYPE] then
      DisposeFields(Types[NumTypes]);    

    // Delete type itself
    Dec(NumTypes);
    end;
      
  end; // DeleteDeclarations




var
  LibProcIdentIndex: Integer;
  TotalParamSize: Integer;


begin // CompileBlock
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileBlock');
    Inc(BlockStackTop);

    with BlockStack[BlockStackTop] do
    begin
        if BlockIdentIndex = 0 then    // if this is the start of unit or main program
            Index := 1
        else
            Index := Ident[BlockIdentIndex].ProcAsBlock;

        if Index = 1 then
            isLocal := False      // We are compiling at Unit level
        else
            isLocal := True;      // We are compiling "inside" a proc/func or nested one

        if (IndexCTrace in TraceCompiler) or  (TokenCTrace in TraceCompiler) then
            emittoken('ENTER CompileBlock BlockStackTop='+Radix(BlockStackTop,10)+
                     ' BlockStack[BlockStackTop].index='+Radix(BlockStack[BlockStackTop].Index,10)+
                     ' index='+Radix(Index,10));


        LocalDataSize := 0;
        ParamDataSize := 0;
        TempDataSize := 0;
    end;
  
    if (ParserState.UnitStatus.Index = 1) and
       (BlockStack[BlockStackTop].Index = 1) then     // starting the SYSTEM unit
    begin
        DeclarePredefinedTypes;
        DeclarePredefinedIdents;
    end;

    CompileDeclarations;     // Handle CONST, TYPE, VAR, LABEL and nested proc/func,

    if ParserState.IsUnit and (BlockStack[BlockStackTop].Index = 1) then
    begin
        // Main block of a unit (may contain the
        // implementation part, but not statements)

        // If we put in a unit initialization, it would go here
        // Procedure UNIT$INIT;

        CheckUnresolvedDeclarations;

        EatTok(ENDTOK);       // BLOCK
    end
    else
    begin    // Main block of a program
        if BlockStack[BlockStackTop].Index = 1 then
            SetProgramEntryPoint;

        GenerateStackFrameProlog(Ident[BlockIdentIndex].Signature.CallConv <> DEFAULTCONV);

        if BlockStack[BlockStackTop].Index = 1 then          // Main program
        begin
            isMainProgram := TRUE;
            GenerateFPUInit;
    
            LibProcIdentIndex := GetIdent('XDP_INITSYSTEM'); // Initialize heap and console I/O
            GenerateCall(Ident[LibProcIdentIndex].Address, BlockStackTop - 1,
                         Ident[LibProcIdentIndex].NestingLevel);

        // If units are imitialized, that would be done here
        //    Writeln('$$ **MAIN** at ',ScannerState.Line,':',ScannerState.Position);
        // patchtest:
        //       Prefixitem := ' Writeln(''This item inserted by patchtest''); ';
        //       PrefixPos := 1;
        //       patchflag := TRUE;
        end;


  // Block body
  GenerateGotoProlog;
  GenerateExitProlog;

  CompileCompoundStatement(0);

  CheckUnresolvedDeclarations;

  GenerateExitEpilog;                            // Direct all Exit procedure calls here
  GenerateGotoEpilog;

  if ForLoopNesting <> 0 then
       Catastrophic('Internal fault: Illegal FOR loop nesting'); {Fatal}

  // If function, return Result value
  // (via the EAX register, except some
  // special cases in STDCALL/CDECL functions)
  if (BlockStack[BlockStackTop].Index <> 1) and (Ident[BlockIdentIndex].Kind = FUNC) then
    begin
    PushVarIdentPtr(Ident[BlockIdentIndex].ResultIdentIndex);
    if Types[Ident[BlockIdentIndex].Signature.ResultType].Kind in StructuredTypes then
      begin
      if Ident[Ident[BlockIdentIndex].ResultIdentIndex].PassMethod = VARPASSING then
        DerefPtr(POINTERTYPEINDEX);
      end
    else  
      DerefPtr(Ident[BlockIdentIndex].Signature.ResultType);
      
    SaveStackTopToEAX;
    
    // Return Double in EDX:EAX
    if Types[Ident[BlockIdentIndex].Signature.ResultType].Kind = REALTYPE then
      SaveStackTopToEDX;
    
    // Treat special cases in STDCALL/CDECL functions
    ConvertResultFromPascalToC(Ident[BlockIdentIndex].Signature);    
    end;

  if BlockStack[BlockStackTop].Index = 1 then          // Main program
    begin
    LibProcIdentIndex := GetIdent('EXITPROCESS');  
    PushConst(0);
    GenerateCall(Ident[LibProcIdentIndex].Address, 1, 1);
    end;

  GenerateStackFrameEpilog(Align(BlockStack[BlockStackTop].LocalDataSize + BlockStack[BlockStackTop].TempDataSize, SizeOf(LongInt)), 
                           Ident[BlockIdentIndex].Signature.CallConv <> DEFAULTCONV);

  if BlockStack[BlockStackTop].Index <> 1 then         
    begin
    if Ident[BlockIdentIndex].Signature.CallConv = CDECLCONV then
      TotalParamSize := 0                                           // CDECL implies that the stack is cleared by the caller - no need to do it here
    else  
      TotalParamSize := GetTotalParamSize(Ident[BlockIdentIndex].Signature, Ident[BlockIdentIndex].ReceiverType <> 0, FALSE);
      
    GenerateReturn(TotalParamSize, Ident[BlockIdentIndex].NestingLevel);
    end;
    
  DeleteDeclarations;
  end; // else    
  
Dec(BlockStackTop);
end;// CompileBlock
{$HIDE PROC,FUNC,BLOCK}

procedure CompileUsesClause;
var
  SavedParserState: TParserState;
  UnitIndex: Integer;
begin
    If  (ActivityCTrace in TraceCompiler) then EmitHint('P CompileUsesClause');

  NextTok;

  repeat
     AssertIdent;
  
      UnitIndex := GetUnitUnsafe(Tok.Name);
  
      // If unit is not found, compile it now
      if UnitIndex = 0 then
      begin
          SavedParserState := ParserState;
          if not SaveScanner then
             Catastrophic('Unit nesting is too deep'); {Fatal}

          UnitIndex := CompileProgramOrUnit(Tok.Name + '.pas');

          ParserState := SavedParserState;
          if not RestoreScanner then
              Catastrophic('Internal fault: Scanner state cannot be restored'); {Fatal}
      end;
    
      ParserState.UnitStatus.UsedUnits := ParserState.UnitStatus.UsedUnits + [UnitIndex];
      SetUnitStatus(ParserState.UnitStatus);
  
      NextTok;
  
      if Tok.Kind <> COMMATOK then Break;
          NextTok;
  until FALSE;

  EatTok(SEMICOLONTOK);
   
end; // CompileUsesClause  

function CompileProgramOrUnit(const Name: TString): Integer;
Var
    FileList: Array[1..10] of TString;
    FileCount: Integer ;
    I: byte;
    SkipErrors: Boolean;
    ProcFuncCount,
    DebugUnit,
    Localcode,         // Generated bytes of code
    SLoc: Longint;     // Source Lines of Code
    ProgramTypeUC,
    ProgramType:String[7];
    CompileMessage: String ;

begin
    If  (ActivityCTrace in TraceCompiler) or
        (TokenCTrace in TraceCompiler) or (UnitCTrace in TraceCompiler) then
    EmitHint('f CompileProgramOrUnit('+Name+')');

    LinebufPtr :=0;
    LineString :='';

    CanDebug := TRUE;  // for now until the USES statement, user can {$ENABLE DEBUG
    EnableDebug := False; // user must explicitly $ENABLE DEBUG

    InitializeScanner(Name);
    NewUnit;

    NextTok;

    ParserState.IsUnit := FALSE;
    if Tok.Kind in [PROGRAMTOK, UNITTOK] then
    begin
        PatchState := PatchUnit;         // probably in a unit
        ParserState.IsUnit := Tok.Kind = UNITTOK;
        NextTok;
        AssertIdent;

        Units[ParserState.UnitStatus.Index].Name := Tok.Name;
        CompileMessage := Tok.Name;

        // store the unit's name in itself
        DeclareIdent('XDP_UNITNAME',CONSTANT, 0, FALSE, STRINGTYPEINDEX,EMPTYPASSING, 1, 0.0, TOK.Name, [], EMPTYPROC, '', 0, Compiler_Defined, System_Constant);
        DeclareIdent('XDP_FILENAME',CONSTANT, 0, FALSE, STRINGTYPEINDEX,EMPTYPASSING, 1, 0.0, Name, [], EMPTYPROC, '', 0, Compiler_Defined, System_Constant);
        UnitTotalIdent  := 1;  // The Unit's name itself counts as an identifier.
        UnitGlobalIdent := 1;
        UnitLocalIdent := 0;   // no local ones yet

        Scannerstate.UnitName := Tok.Name;
        Scannerstate.Filename := Tok.Name+'.pas'; //CHANGEME to get actual name
        NextTok;
// This is where we check for either a ( or a ;.
// The ( can only appear on a PROGRAM, not on a UNIT.

        ProgramTypeUC :='UNIT';
        ProgramType :='Unit';
        if NOT ParserState.IsUnit then
        begin   // We just had a PROGRAM, check for either ( or ;
            ProgramTypeUC :='PROGRAM';
            ProgramType :='Program';
            if (TokenCTrace in TraceCompiler) or
               (KeywordCTrace in TraceCompiler) or
               (UnitCTrace in TraceCompiler) then
              EmitToken(Programtype+' ' +Tok.Name+' ('+ScannerState.UnitName+')');
            PatchState := PatchProgram;   // definitely in a program
            // Const XDP_PROCNAME='$MAIN';
            DeclareIdent('XDP_PROCNAME',CONSTANT, 0, FALSE, STRINGTYPEINDEX, EMPTYPASSING, 1, 0.0, '$MAIN', [], EMPTYPROC, '', 0, Compiler_Defined, System_Constant);
            // Const XDP_PROGRAM ='PROGRAM';
            DeclareIdent('XDP_PROGRAM',CONSTANT, 0, FALSE, STRINGTYPEINDEX, EMPTYPASSING, 1, 0.0, ProgramTypeUC, [], EMPTYPROC, '', 0, Compiler_Defined, System_Constant);
            // Const XDP_PROCTYPE='Main program';
            DeclareIdent('XDP_PROCTYPE',CONSTANT, 0, FALSE, STRINGTYPEINDEX, EMPTYPASSING, 1, 0.0, 'Main program', [], EMPTYPROC, '', 0, Compiler_Defined, System_Constant);
            CheckEitherTok(SEMICOLONTOK, OPARTOK);
            If Tok.Kind = OPARTOK then
            begin
                FileCount := 0;
                SkipErrors := False;
                repeat
                      // Treat each argument in the PROGRAM statement
                      // as a file declaration; if a duplicae of a
                      // predefined file, ignore it
                      NextTok;
                      AssertIdent;
                      if (FileCount > 10) and not skipErrors then
                      begin
                           Err(Err_175);    // too many files in program header
                           SkipErrors :=true;
                      end;
                      Inc(FileCount);
                      If not SkipErrors then
                          FileList[FileCount] := Tok.Name;
                      NextTok;
                      CheckEitherTok(COMMATOK, CPARTOK);
                Until (Tok.Kind = CPARTOK) or ScannerState.EndOfUnit;
                // For right now, these are ignored
                //$$ Need to check what FILETOK does

                NextTok; // now it should be a semicolon; EatTok below will check
            end
            else
               if (TokenCTrace in TraceCompiler) or
                  (KeywordCTrace in TraceCompiler) or
                  (UnitCTrace in TraceCompiler) then
                 EmitToken('Unit ' + ScannerState.UnitName);
        end
        ELSE  // Const XDP_PROGRAM = 'UNIT';
        Begin
           DeclareIdent('XDP_PROGRAM',CONSTANT, 0, FALSE, STRINGTYPEINDEX, EMPTYPASSING, 1, 0.0,ProgramTypeUC, [], EMPTYPROC, '', 0, Compiler_Defined, System_Constant);
           DeclareIdent(CompileMessage,UnitIdent, 0, FALSE, STRINGTYPEINDEX, EMPTYPASSING, 1, 0.0, CompileMessage, [], EMPTYPROC, '', 0, Compiler_Defined, System_Constant);
        END;

{ $show Token,narrow}
        EatTok(SEMICOLONTOK); // either after UNIT or PROGRAM
    end    // ***ERROR** ** ERROR: extra ;
else
  begin
{ $Hide all}
     if (TokenCTrace in TraceCompiler) or (UnitCTrace in TraceCompiler) then
         EmitToken('Unnamed MAIN Program');
     Units[ParserState.UnitStatus.Index].Name := 'MAIN';
     ProgramTypeUC :='PROGRAM';
     ProgramType :='Program';;
     DeclareIdent('XDP_PROCNAME',CONSTANT, 0, FALSE, STRINGTYPEINDEX, EMPTYPASSING, 1, 0.0, '(UnNamed)', [], EMPTYPROC, '', 0, Compiler_Defined, System_Constant);
     DeclareIdent('XDP_PROGRAM',CONSTANT, 0, FALSE, STRINGTYPEINDEX, EMPTYPASSING, 1, 0.0, ProgramTypeUC, [], EMPTYPROC, '', 0, Compiler_Defined, System_Constant);
     DeclareIdent('XDP_PROCTYPE',CONSTANT, 0, FALSE, STRINGTYPEINDEX, EMPTYPASSING, 1, 0.0, 'Main program', [], EMPTYPROC, '', 0, Compiler_Defined, System_Constant);
  end;

ParserState.IsInterfaceSection := FALSE;
if ParserState.IsUnit then
  begin
  EatTok(INTERFACETOK);
      if (TokenCTrace in TraceCompiler) or (KeywordCTrace in TraceCompiler) then
        EmitToken('Interface');
  ParserState.IsInterfaceSection := TRUE;
  end;
  
// Always use System unit, except when compiling System unit itself
    if NumUnits > 1 then
        ParserState.UnitStatus.UsedUnits := [1]     // automatic implied "uses system;"
    else
        ParserState.UnitStatus.UsedUnits := [];     // but not, of course when UNIT System;

    SetUnitStatus(ParserState.UnitStatus);

    if EnableDebug then
     BEGIN
         DebugUnit := GetUnitUnsafe('DEBUG');
         if DebugUnit = 0 then
         begin
             // ignore the $STOP protector in Debug
             NonStop := TRUE;
             //Call ourselves: "Uses Debug"
             DebugUnit := CompileProgramOrUnit('Debug.pas');;
             NonStop := FALSE;
             ParserState.UnitStatus.UsedUnits := ParserState.UnitStatus.UsedUnits + [DebugUnit];
             SetUnitStatus(ParserState.UnitStatus);

         end;
     end;
    if Tok.Kind = USESTOK then
        CompileUsesClause;

    CanDebug := FALSE;   // can not enable debug now

    NumBlocks := 1;
    UnitTotalIdent  := 1;  // The Unit's name itself counts as an identifier.
    UnitGlobalIdent := 1;
    UnitLocalIdent := 0;   // no local ones yet
    isLocal := False;      // in Unit definitions, not local
    LocalCode := CodeSize;
    CompileBlock(0);
    if (IndexCTrace in TraceCompiler) or  (TokenCTrace in TraceCompiler) then
        emittoken('EXIT CompileBlock at Zero');
    CheckTok(PERIODTOK);

    // Question being, why fault the compile if they got to a
    // successful end? Because if they forgot to $ENDIF their
    // conditional block, it may have incorrect code left in.
    // Besides, it's sloppy practice.
    // make sure conditional code was closed
        if (CIndex <>0) then   // eof in conditional code
          begin
           Err2(Err_71,Radix(Ctable[Cindex].Line,10),Radix(Ctable[Cindex].Pos,10));
           UnRecoverable;
          end;


    PatchState := PatchProgram; // presumably we are outside of any
                                // unit at this point
    if (TokenCTrace in TraceCompiler) or (UnitCTrace in TraceCompiler) then
        EmitToken('Compile Completed',true);
    EmitStop;  // clear the counter so token tracing starts display over

    LocalCode := CodeSize - Localcode;  // Find out how much code was generated
    SLoc := ScannerState.Line;          //  and how many lines were compiled

    Notice('Compiled: ' + Name+ ', '+Comma(SLoc)+' lines,' +
           CommaP(UnitTotalIdent,'identifiers','identfier')+
           ' ('+(Comma(UnitLocalIdent)+' local, '+
           Comma(UnitGlobalIdent)+' '+ProgramType+').'+
           ' Code size '+Comma(LocalCode)+
           ' ($'+Radix(LocalCode,16)+') bytes.'));
    ProcFuncCount := Scannerstate.ProcCount+Scannerstate.ExtProc+Scannerstate.ExtFunc+Scannerstate.FuncCount;
    If ProcFuncCount = 0 then
        CompileMessage := '  No procedures or functions'
    else
    begin
        ProcFuncCount := Scannerstate.ProcCount+Scannerstate.ExtProc;
        If ProcFuncCount = 0 then
            CompileMessage := '  No procedures'
        else
        begin
            if ProcFuncCount = 1 then
            begin
               CompileMessage := '  One procedure';
               If Scannerstate.ExtProc<>0 then
                   CompileMessage :=  CompileMessage+', external';
            end
            else
            begin
                CompileMessage := '  '+ Comma(ProcFuncCount)+' procedures, (';
                If Scannerstate.ProcCount = 0 then
                    CompileMessage := CompileMessage+'no '+ProgramType+', '
                else
                    CompileMessage := CompileMessage+Comma(Scannerstate.ProcCount)+' '+ProgramType+', ';
                if Scannerstate.ExtProc = 0 then
                    CompileMessage := CompileMessage+'no'
                else
                    CompileMessage := CompileMessage+Comma(Scannerstate.ExtProc);
                CompileMessage := CompileMessage+' external)';
            end;
        end;
        ProcFuncCount := Scannerstate.FuncCount+Scannerstate.ExtFunc;
        If ProcFuncCount = 0 then
            CompileMessage := CompileMessage+', no functions'
        else
        begin
            if ProcFuncCount = 1 then
            begin
               CompileMessage :=  CompileMessage+', one function';
               If Scannerstate.ExtFunc<>0 then
                   CompileMessage :=  CompileMessage+', external';
            end
            else
            begin
                CompileMessage := CompileMessage+', '+ Comma(ProcFuncCount)+' functions, (';
                If Scannerstate.FuncCount = 0 then
                    CompileMessage := CompileMessage+'no '+ProgramType+', '
                else
                    CompileMessage := CompileMessage+Comma(Scannerstate.FuncCount)+' '+ProgramType+', ';
                if Scannerstate.ExtFunc = 0 then
                    CompileMessage := CompileMessage+'no'
                else
                    CompileMessage := CompileMessage+Comma(Scannerstate.ExtFunc);
                CompileMessage := CompileMessage+' external)';
            end;
        end;
    end;
    Notice(CompileMessage+'.');

    TotalLines := TotalLines+SLoc;
    Result := ParserState.UnitStatus.Index;
    FinalizeScanner;
end;// CompileProgramOUnit


end.

