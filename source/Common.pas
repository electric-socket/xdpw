// XD Pascal for Windows (XPDW) - a 32-bit compiler
// Copyright (c) 2009-2010, 2019-2020, Vasiliy Tereshkov
// Copyright 2020 Paul Robnson

// Latest upgrade by Paul Robinson: New Years Eve; Thursday, December 31, 2020

// VERSION 0.15 {.0}

// Common data and routines used by all modules

(*$Hide feelings*)

{$I-}
{$H-}

unit Common;


interface
const
// General, independent constants



     // XDPW - for display

       VERSION_MAJOR             = 0;
       VERSION_RELEASE           = 16;
       VERSION_PATCH             = 0;
       VERSION_FULL              = VERSION_MAJOR*1000+
                                   VERSION_RELEASE *10+
                                   VERSION_PATCH;

// note, the folowing MUST be a string of digits in quotes
// as PROGRAM UPD does an auto-upddate on every compile
// and it has to be passed as string to Notice.
       VERSION_REV               = '21';
       CODENAME                  = 'Groundhog Day';
       RELEASEDATE               = 'Tuesday, February 2, 2021';


       Months: array[1..12] of string[9]=
            ('January','February','March',   'April',   'May','     June',
             'July',    'August', 'September','October','November', 'Decenber');
       Days: Array[0..6] of string[9]=
             ('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday');


       DigitZero = Ord('0');     // used to translate digits to numbers

// Scanner
    // Predefined type indices
    // Note that STringTypeIndex MUST BE LAST in order to reserve space for predefined types

    ANYTYPEINDEX          = 1;      // Untyped parameter, or base type for untyped pointers and files
    INTEGERTYPEINDEX      = 2;
    SMALLINTTYPEINDEX     = 3;
    SHORTINTTYPEINDEX     = 4;
    INT64TYPEINDEX        = 5;
    INT128TYPEINDEX       = 6;
    WORDTYPEINDEX         = 7;
    BYTETYPEINDEX         = 8;
    CHARTYPEINDEX         = 9;
    BOOLEANTYPEINDEX      = 10;
    REALTYPEINDEX         = 11;     // Basic real type: 64-bit double (all temporary real results are of this type)
    CURRENCYTYPEINDEX     = 12;     // Currency: 31 digits, 27 before the decimal point, 4 after
    SINGLETYPEINDEX       = 13;
    POINTERTYPEINDEX      = 14;     // Untyped pointer, compatible with any other pointers
    FILETYPEINDEX         = 15;     // Untyped file, compatible with text files
    STRINGTYPEINDEX       = 16;     // String of maximum allowed length

    ErrorMsgMax = 6; // max no. of inserted error messages

  // Note: If you add new tokens, GETKEYWORD, GETTOKSPELLING,
  // TTOKENKIND, NUMKEYWORDS, and KEYWORD must **ALL** be adjusted.
  NUMKEYWORDS               = 45;    // ANDTOK .. XORTOK, 'AND' .. 'XOR'
  MAXENUMELEMENTS           = 256;
// 2000 might have been too small for MAXIDENTS,
// increasaing to 3000
// Also, if we switch to pointers both of these 2 following items
// may be eliminated
  MAXIDENTS                 = 3000;
  MAXTYPES                  = 2000;
// Units will remain an array; it's not so many
// that moving to a linked list helps
  MAXUNITS                  = 254;
  MAXFOLDERS                = 10;
  MAXEXTENSIONS             = 10;
  MAXBLOCKNESTING           = 10;
  MAXPARAMS                 = 30;
  MAXFIELDS                 = 100;
  MAXWITHNESTING            = 20;

  MAXINITIALIZEDDATASIZE    =    1 * 1024 * 1024;
  MAXUNINITIALIZEDDATASIZE  = 1024 * 1024 * 1024;
  MAXSTACKSIZE              =   16 * 1024 * 1024;
  SCANNERSTACKSIZE          = 11;  // To allow for up to 10 units plus Include file
  MAXTOKENS                 = 200;

  // Be aware function GetKeyword searches this using
  // a binary search, so the entries **must** be in
  // alphabetical order
  //
  // These have been moved from SCANNER and placed
  // "Above the line" (above IMPLEMENTATON) so they
  // can be seen by it, and are here so certain
  // items here can see them.
  // Note: If you add new tokens, GETKEYWORD, GETTOKSPELLING,
  // TTOKENKIND, NUMKEYWORDS, and KEYWORD must **ALL** be adjusted.
  // Also, to make comparisons shorter, these are defined as 20-character strings
  KeyWordSize = 20; // Change if thereareany longerthan 20 characters
    Keyword: array [1..NUMKEYWORDS] of String[KeywordSize] =
        (
        'AND',       // this ties to value of ANDTOK
        'ARRAY',
        'ASM',
        'BEGIN',
        'CASE',
        'CONST',
        'DIV',
        'DO',
        'DOWNTO',
        'ELSE',      //  10
        'END',
        'FILE',
        'FOR',
        'FUNCTION',
        'GOTO',
        'IF',
        'IMPLEMENTATION',
        'IN',
        'INTERFACE',
        'LABEL',         // 20
        'MOD',
        'NIL',
        'NOT',
        'OF',
        'OR',
        'OTHERWISE',
        'PACKED',
        'PROCEDURE',
        'PROGRAM',
        'RECORD',           // 30
        'REPEAT',
        'SET',
        'SHL',
        'SHR',
        'STRING',
        'THEN',
        'TO',
        'TYPE',
        'UNIT',
        'UNTIL',             // 40
        'USES',
        'VAR',
        'WHILE',
        'WITH',
        'XOR'        // this ties to value of XORTOK
        );

// Parser
// identifier definitions
   Compiler_Defined   =  -1;
    System_Constant   =  -2;
        System_Type   =  -3;
   System_Procedure   =  -4;
    System_Function   =  -5;
  Structured_Result   =  -6;
    Standard_Result   =  -7;
  Compiler_Reserved   = -99;
 XDP_SystemDeclared   = -65536;    // items defined by the SYSTEM unit


type

// General Types either independent or only depending on
// a constant

    TCharacter     = Char;
    PCharacter     = PChar;
    TString        = string;
    TShortString   = string;
    TGenericString = string;
    TCurrency      = Array [1..16] of byte;    // Currency
    TInt64         = array [1..2] of Integer; // 64-bit integer
    TInt128        = array [1..4] of Integer; // 128-bit integer

    TInFile  = file;
    TOutFile = file;

    PStringList = ^StringList;
    StringList = Record
        Prev,
        Next: PStringList;
        Item:   LPCSTR;
    end;

// Depedent types

    PLongInt = ^LongInt;



// Assembler

    TRegister = (NOREG, EAX, ECX, EDX, ESI, EDI, EBP, AX, AH, AL);

          AsmType = (NoOperands,           // opcode
                     Reg,                  // opcode REG
                     AddrReg,              // opcode [ Reg + ADDR ]
                     Addr,                 // opcode [ addr ]
                     Twovalue,             // opcode value,value
                     TwoRegs,              // opcode REG,REG
                     TwoRegsAddress,       // opcode REG,[REG+Addr]
                     TwoRegsTwoValue,      // opcode REG, [Reg + Value + Value]
                     ByteArray,            // byte   ARG,ARG,ARG, ..
                     Wordarray,            // WORD   arg,arg,arg  ..
                     IntArray,             // LONG   arg, ...
                     CharString);          // string ' STRING'
//{$dump symtab,all}
//{$stop}
       TAsmResult = record
                  Size: Byte;            // number of opcode bytes, or number of byt/word/long values
            case  Kind: AsmType of                   // What type of instruction
                  Reg, AddrReg, Addr,
                  TwoValue,
                  TwoRegs, TwoRegsAddress,
                  TwoRegsTwoValue:
                 (Opcodes: Array[1..10] of byte;     // the opcode bytes
            RegisterCount: Byte;                     // number of registrs used
                Registers: Array[1..2] of TRegister; // registers actually used
                   isName: Array[1..2] of boolean;   // are any values names as opposed to value or address
                    Value: Array[1..2] of Integer);  // value or index into ident table
             byteArray:  ( ByteVal: array[1..64] of byte);
             WordArray:  ( WordVal: Array[1..32] of word);
             IntArray:   ( IntVal:  Array[1..16] of long);
             CharString: ( StrVal: String[64]);
       end;


 // scanner

      // Note: If you add new tokens, GETKEYWORD, GETTOKSPELLING,
      // TTOKENKIND, NUMKEYWORDS, and KEYWORD must **ALL** be adjusted.

      // Also, if you add any tokens betweek ANDTOK and XORTOK these two
      // are used as an index into the keyword list. And if you add a
      // new keyword, it *must* be in alphabetical order. If it comes
      // alphabetically before AND or after XOR, references to these in
      // GETKEYWORD and GETTOKSPELLING need to change
      TTokenKind =
        (
        EMPTYTOK,

        COMMENTTOK,      // comments

        // conditional compilation tokens
        CCSIFTOK,        // $IF
        CCSIFDEFTOK,     // $IFDEF
        CCSIFNDEFTOK,    // $IFNDEF
        CCSELSEIFTOK,    // $ELSEIF
        CCSELSETOK,      // $ELSE
        CCSENDIFTOK,     // $ENDIF
        CCSDEFINETOK,    // $DEFINE
        CCSUNDEFTOK,     // $UNDEF

        JUNKTOK,         // anything not recognized
        EOFTOK,          // end of file during buffered read
        NULLTOK,         // need to reload token buffer

        // C-style operators

        PLUSEQTOK,       // +=
        MINUSEQTOK,      // -=
        MULEQTOK,        // *=
        DIVEQTOK,        // /=

        // if AAEC Pascal 8000 could have ** for exponentiation in 1980, we should now
        EXPONTOK,        // **

        // Limited set of assembler tokens
        ASMLABELTOK,     // assembler label
        ENDOFLINETOK,    // end of line found

        // Delimiters
        OPARTOK,         // (
        CPARTOK,         // )
        MULTOK,          // *
        PLUSTOK,         // +
        COMMATOK,        // ,
        MINUSTOK,        // -
        PERIODTOK,       // .
        RANGETOK,        // ..
        DIVTOK,          // /
        COLONTOK,        // :
        BECOMESTOK,      // :=  (formerly called "ASSIGNTOK")
        SEMICOLONTOK,    // ;
        LTTOK,           // <
        LETOK,           // <=
        NETOK,           // <>
        EQTOK,           // =
        GTTOK,           // >
        GETOK,           // >=
        ADDRESSTOK,      // @
        OBRACKETTOK,     // [
        CBRACKETTOK,     // ]
        DEREFERENCETOK,  // ^


    // Note if any of these are added (or removed), KEYWORD must be changed.
    // Pay special attention to ANDTOK and XORTOK as they are directly referenced
    // to its position in this list with respect to the corresponding list of
    // keywords. Also, since the list is searched using a binary search, they
    // **must** be declared in alphabetical order.

        // Keywords
        ANDTOK,           // AND
        ARRAYTOK,         // ARRAY
        ASMTOK,           // ASM
        BEGINTOK,         // BEGIN
        CASETOK,          // CASE
        CONSTTOK,         // CONST
        IDIVTOK,          // DIV
        DOTOK,            // DO
        DOWNTOTOK,        // DOWNTO
        ELSETOK,          // ELSE
        ENDTOK,           // END
        FILETOK,          // FILE
        FORTOK,           // FOR
        FUNCTIONTOK,      // FUNCTION
        GOTOTOK,          // GOTO
        IFTOK,            // IF
        IMPLEMENTATIONTOK,// IMPLEMENTATION
        INTOK,            // IN
        INTERFACETOK,     // INTERFACE
        LABELTOK,         // LABEL
        MODTOK,           // MOD
        NILTOK,           // NIL
        NOTTOK,           // NOT
        OFTOK,            // OF
        ORTOK,            // OR
        OTHERWISETOK,     // OTHERWISE
        PACKEDTOK,        // PACKED
        PROCEDURETOK,     // PROCEDURE
        PROGRAMTOK,       // PROGRAM
        RECORDTOK,        // RECORD
        REPEATTOK,        // REPEAT
        SETTOK,           // SET
        SHLTOK,           // SHL
        SHRTOK,           // SHR
        STRINGTOK,        // STRING
        THENTOK,          // THEN
        TOTOK,            // TO
        TYPETOK,          // TYPE
        UNITTOK,          // UNIT
        UNTILTOK,         // UNTIL
        USESTOK,          // USES
        VARTOK,           // VAR
        WHILETOK,         // WHILE
        WITHTOK,          // WITH
        XORTOK,           // XOR

        // User tokens
        IDENTTOK,         // identifier
        INTNUMBERTOK,     // integer number
        INT64NUMBERTOK,   // 64-bit integer
        INT128NUMBERTOK,  // 128-bit integer
        CURRENCYTOK,      // 31-digit currency value
        REALNUMBERTOK,    // real number
        BOOLEANTOK,       // decision
        CHARLITERALTOK,   // literal char
        STRINGLITERALTOK, // literal string

        // errors we try to recover from
        ERRUNTERMSTRING, // unterminated string
        ERRSEMIEQTOK,    // ;= error

        // Used for error messages
        ERRCHARTOK,       // 'character'
        ERRDIGITTOK,      // 'digit'
        ERRNUMBERTOK,     // 'number'
        ERRSTMTTOK,       // 'statement';
        ERRLINETOK        // 'line'

        );



     TBuffer = record
        Ptr: PCharacter;
        Size,                            // size of file
        Pos: Integer;                    // position in file
      end;


// parser / scanner

   TUnitStatus = record
       Index: Byte;
       UsedUnits: set of Byte;
   end;

  TParserState = record
      IsUnit,
      IsInterfaceSection: Boolean;
      ProcFuncName:String;             // current Procedure/Function Being Compiled
      UnitStatus: TUnitStatus;
   end;

var
     UnitStatus: TUnitStatus;
     ParserState: TParserState;

     // for user program debugging
     NonStop:Boolean = FALSE; // ignore {$STOP in unit
     CanDebug: Boolean=TRUE;  // user can {$ENABLE debug
     EnableDebug: Boolean; // user has not enabled debgging
     Debugging:Boolean = FALSE; // is debugging

     // for $INCLUDE files
     inInclude: Boolean = False;   // not now in $INCLUDE file

 const
  // dependent constants

    Digits:    set of TCharacter = ['0'..'9'];
    HexDigits: set of TCharacter = ['0'..'9', 'A'..'F'];
    Spaces:    set of TCharacter = [#1..#31, ' '];
    RadixSet:  set of TCharacter = ['0'..'9', 'A'..'I', 'J'..'R', 'S'..'Z'];
    // to allow for EBCDIC or ASCII this uses smaller blocks of chars
  Identifiers: Set of TCharacter = ['A'..'I', 'J'..'R', 'S'..'Z',
                                      'a'..'i', 'j'..'r', 's'..'z','_'];
    AlphaNums: set of TCharacter = ['0'..'9', 'A'..'I', 'J'..'R', 'S'..'Z',
                                              'a'..'i', 'j'..'r', 's'..'z','_'];

type

// Scanner

    // if adding a new type, be sure to check:
    //    "predefined type indexes"
    //    procedure DeclarePredefinedTypes
    //    TTypeKind
    //    function GetTypeSpelling
  TTypeKind = (	EMPTYTYPE,      ANYTYPE,        INTEGERTYPE,    INT64TYPE,
                INT128TYPE,     CURRENCYTYPE,   SMALLINTTYPE,   SHORTINTTYPE,
                WORDTYPE,       BYTETYPE,       CHARTYPE,       BOOLEANTYPE,
                REALTYPE,       SINGLETYPE,     POINTERTYPE,    FILETYPE,
                ARRAYTYPE,      RECORDTYPE,     INTERFACETYPE,  SETTYPE,
                PROCEDURALTYPE, METHODTYPE,     ENUMERATEDTYPE, SUBRANGETYPE,
                FORWARDTYPE);

    TToken = record
       Name: TString;     // For easy analysis, this is always in upper case
       DeclaredPos,            // Where it was declared
       DeclaredLine:Integer;
       case Kind: TTokenKind of
           IDENTTOK:         (NonUppercaseName: TShortString);  // This is needed
                                                                // in the case of EXTERNAL procedures where the name
                                                                // might have to be in mixed case
           INT64NUMBERTOK:   (Int64Value:TInt64);
           INT128NUMBERTOK:  (Int128Value:TInt128);
           CURRENCYTOK:      (CurrencyValue:TCurrency);
           INTNUMBERTOK:     (OrdValue: LongInt);    // For all other ordinal types
           REALNUMBERTOK:    (RealValue: Double);
           STRINGLITERALTOK: (StrAddress: Integer;
                              StrLength: Integer);
   end;

    
      TScannerState = record
        Token: TToken;      // Current token
        UnitName,           // current unit
        FileName: TString;  // name of file
        ProcCount,          // number of procedures
        FuncCount,          // and functions in unit
        ExtFunc,            // number of External Procedures
        ExtProc,            // and functions in unit
        Position,           // current position in
        Line: Integer;      // line being examined
        Buffer: TBuffer;
        ch, ch2: TCharacter;
        inComment,           // we're inside a comment
        IOCheck,             // IOChecking handled by {$I+ or {$I-} on a per-file basis
        EndOfUnit: Boolean;  // end of file
      end;



  TByteSet  = set of Byte;

  TConst = packed record
  case Kind: TTypeKind of
    INTEGERTYPE: (OrdValue: LongInt);         // For all ordinal types 
    REALTYPE:    (RealValue: Double);
    INT64TYPE:   (Int64Value:TInt64);
    INT128TYPE:  (Int128Value:TInt128);
    CURRENCYTYPE:(CurrencyValue: TCurrency);
    SINGLETYPE:  (SingleValue: Single);
    ARRAYTYPE:   (StrValue: TShortString);
    POINTERTYPE: (PointerValue: Pointer);
    SETTYPE:     (SetValue: TByteSet);        // For all set types    
  end;   
  
  TPassMethod = (EMPTYPASSING, VALPASSING, CONSTPASSING, VARPASSING); 

  TParam = record
    Name: TString;
    DataType: Integer;
    PassMethod: TPassMethod;
    Default: TConst;
  end;

  PParam = ^TParam;
  
  PParams = array [1..MAXPARAMS] of PParam;   
    
  TIdentKind = (EMPTYIDENT, UNITIDENT, GOTOLABEL, CONSTANT,
                USERTYPE, VARIABLE, PROC, FUNC, UNDEFIDENT);

  TScope = (EMPTYSCOPE, GLOBAL, LOCAL);
  
  TRelocType = (EMPTYRELOC, CODERELOC, INITDATARELOC, UNINITDATARELOC, IMPORTRELOC);
  
  TCallConv = (DEFAULTCONV, STDCALLCONV, CDECLCONV);

  TPredefProc =
    (
    EMPTYPROC,
    
    // Procedures     
    INCPROC,      // inc
    DECPROC,      // dec
    READPROC, 
    WRITEPROC, 
    READLNPROC, 
    WRITELNPROC,
    INLINEPROC,     // INLINE(n,N);
    NEWPROC,        // new
    DISPOSEPROC,    // dispose
    BREAKPROC,      // These four: Break, Continue,
    CONTINUEPROC,   // Exit, and Halt, are styled as
    EXITPROC,       // if they were procedures but are
    HALTPROC,       // handled internally by the compiler

    // Functions
    SIZEOFFUNC,     // SIZEOF(
    ORDFUNC,
    CHRFUNC,
    LOWFUNC,
    HIGHFUNC,
    PREDFUNC,
    SUCCFUNC,
    ROUNDFUNC,
    TRUNCFUNC,
    ABSFUNC,    // Pascal STD Func ABS()
    SQRFUNC,	//        	SQR()
    SINFUNC,	//		SIN()
    COSFUNC,	//		COS()
    ARCTANFUNC,	//	`	ARCTAN()
    EXPFUNC,	//		EXP()
    LNFUNC,	//		LN()
    SQRTFUNC	//		SQRT()
    );		// Missing:  EOF() EOLN() and ODD()
    
  TSignature = record
    NumParams: Integer;
    NumDefaultParams: Integer;
    Param: PParams;
    Line,
    ResultType: Integer;
    CallConv: TCallConv;
  end;

  IdentP      = ^TIdentifier;// A specific identifier
  TraceP      = ^TTrace;     // Trace table for debugging

  TIdentifier = record
    Prev,                    // Links for when this is a linked list
    Next: IdentP;            // instead of an array
    Kind: TIdentKind;        // CONST, TYPE, PROC, FUNC, etc.
    Name: TString;
    // The following two items have two uses. (1) For procedural types
    // declared FORWARD (or proc/func signatures in the IMPLEMENTATION
    // section of a unit, the line number where it was declared if
    // they do not define the proc/func. (2) For unused VARs the line
    // number and position on the line where declared.
    DeclaredLine,            // Line Bumber in file it was declared
    DeclaredPos,             // Position on that line where declared
    DataType: Integer;
    Address: LongInt;
    ConstVal: TConst;
    UnitIndex: Integer;
    Block: Integer;                   // Index of a block in which the identifier is defined
    isAbsolute: Boolean;              // is the variable declared an absolute address
                                      // or is the proc/func external
    NestingLevel: Byte;
    ReceiverName: TString;            // Receiver variable name for a method
    ReceiverType: Integer;            // Receiver type for a method
    Scope: TScope;
    RelocType: TRelocType;
    PassMethod: TPassMethod;          // Value, CONST or VAR parameter status
    Signature: TSignature;
    ResultIdentIndex: Integer;
    ProcAsBlock: Integer;
    PredefProc: TPredefProc;
    IsUsed: Boolean;                 // to warn of unused variables
    IsUnresolvedForward: Boolean;
    IsExported: Boolean;
    IsTypedConst: Boolean;
    IsInCStack: Boolean;
    ForLoopNesting: Integer;          // Number of nested FOR loops where the label is defined
  end;

  TTrace = record                     // for procedure tracing
    isFunc: Boolean;                  // procedure or function
    StartLine,                        // first line no. of proc/func
    EndLine,                          // last line no.
    startAddress,                     // start and end addresses
    EndAddress: Integer;              // of this procedure's code
    UnitID: Byte;                     // unit number
    Name: TString;                    // procedure name
  end;

  TField = record
    Name: TString;
    DataType: Integer;
    Offset: Integer;
  end;

  PField = ^TField;
  TypePtr = ^TType;

  TType = record
    Prev,                   // links for when this is a linked list
    Next: TypePtr;
    Block: Integer;
    BaseType: Integer;      // indexes to another type
    AliasType: Integer;
    
  case Kind: TTypeKind of     
    SUBRANGETYPE:              (Low, High: Integer);
  
    ARRAYTYPE:                 (IndexType: Integer;
                                IsOpenArray: Boolean);
                      
    RECORDTYPE, INTERFACETYPE: (NumFields: Integer;
                                Field: array [1..MAXFIELDS] of PField);


    PROCEDURALTYPE:            (Signature: TSignature;
                                SelfPointerOffset: LongInt);  // For interface method variables as temporary results
    
    METHODTYPE:                (MethodIdentIndex: Integer);   // For static methods as temporary results
  
    FORWARDTYPE:               (TypeIdentName: TShortString);   
  end;
  
  TBlock = record
    Index: Integer;
    LocalDataSize, ParamDataSize, TempDataSize: LongInt;
  end;
  
  TUnit = record
    Name: TString;
  end;

  TWithDesignator = record
    TempPointer: Integer;
    DataType: Integer;
    IsConst: Boolean;
  end;

  // Eventually I will stop using the indirect procedures
  // but I will save the definitions and examples as they provide
  // interesting, useful functionality, such as defining different routines to
  // execute dynamically at run-time. Besides, the replacement must be done
  // carefully, as the last time i tried it crashed this compiler so badly
  // I had to back out all changes and use a diff/merge tool to carefully
  // re-add them individually until I discovered what broke it.
  TWriteProc = procedure (ClassInstance: Pointer; const Msg: TString);

    // Internals - for compiler tracing

    // makse sure you change SHOW/$HIDE through
    // proc OptionShowHide in unit Scanner if
    // you aded new options
      TraceType = (
                   ActivityCTrace,        // procedurecs/funcs called by the Parser
                   BecomesCTrace,       // := assignments
                   BlockCTrace,         // begin and repeat blocks
                   CallCTrace,          // proc and function calls
                   CodeCTrace,          // actual code being generated
                   CodeGenCTrace,       // see what is being called for code generation
                   CommentCTrace,       // comment trace
                   FlagCtrace,          // flag error messages
                   FuncCTrace,          // functions
                   IdentCTrace,         // identifiers
                   IndexCtrace,         // index value on call to start compiling a block
                   InputCtrace,         // have compile list what it is reading
                   InputHexCTrace,      // dump input in char and hex
                   KeywordCTrace,       // all keywords
                   LoopCTrace,          // Loops: For, Repeat, While
                   NarrowCTrace,        // show one token per line
                   ProcCTrace,          // Procedures
                   StatisticsCTrace,    // compiler statistics
                   SymbolCTrace,        // symbols
                   TokenCTrace,         // tokens in general (basically everything)
                   UnitCTrace          // unit and program
                   );


  // parser


const    
  // Operator sets  
  MultiplicativeOperators = [MULTOK, DIVTOK, IDIVTOK, MODTOK, SHLTOK, SHRTOK, ANDTOK];
  AdditiveOperators       = [PLUSTOK, MINUSTOK, ORTOK, XORTOK];
  UnaryOperators          = [PLUSTOK, MINUSTOK];
  RelationOperators       = [EQTOK, NETOK, LTTOK, LETOK, GTTOK, GETOK];

  OperatorsForIntegers    = MultiplicativeOperators - [DIVTOK] + AdditiveOperators + RelationOperators + [NOTTOK];
  OperatorsForReals       = [MULTOK, DIVTOK, PLUSTOK, MINUSTOK] + RelationOperators;
  OperatorsForBooleans    = [ANDTOK, ORTOK, XORTOK, NOTTOK] + RelationOperators;

  // Type sets
  IntegerTypes     = [INTEGERTYPE, SMALLINTTYPE, SHORTINTTYPE, WORDTYPE, BYTETYPE];
  Int64Types       = IntegerTypes + [INT64TYPE];
  Int128Types      = Int64Types + [INT128TYPE];
  OrdinalTypes     = IntegerTypes + [CHARTYPE, BOOLEANTYPE, SUBRANGETYPE, ENUMERATEDTYPE];
  UnsignedTypes    = [WORDTYPE, BYTETYPE, CHARTYPE];
  NumericTypes     = IntegerTypes + [REALTYPE];
  CurrencyTypes    = NumericTypes + [CURRENCYTYPE];
  StructuredTypes  = [ARRAYTYPE, RECORDTYPE, INTERFACETYPE, SETTYPE, FILETYPE];
  CastableTypes    = OrdinalTypes + [POINTERTYPE, PROCEDURALTYPE];


var

// Scanner

       AsmResult: TAsmResult;
       LastKeyTok,               // the last keyword token of executable condition: IF, REPEAT, PROCEDURE, BEFGIN, etc.
                                 // directive being an identifier, an executable keyword
                                 // IF, GOTO, assignment, call, REPEAT, FOR . BEGIN, UNTIL, etc.
       Tok: TToken;
       TokenBuffer: Array[1..MaxTokens] of TToken; // used by the assembler
       KeyWordCount: Array[1..NUMKEYWORDS] of Integer;


  // CompilerTrace

  ShowToken: Boolean = FALSE;
  ShowParse: Boolean = FALSE;
  ShowTokenLine: Boolean = FALSE;
  TraceCompiler: Set of TraceType = [];  // default to trace nothing;
  // for severe analysis needs, set
  // to TOKEN which is (almost) everything
  LinePrefix: String[10];
  LineString: String = '';
  LineBuf: Array[0..255] of byte;  // copy of input ss read in bytes
  LinebufPtr: Byte=0;              // length of buffer as used

  // scanner

  ScannerState: TScannerState;



    SysDef,                  // Consider all idents system identifiers
    SysIdent,                // Allow identifires to have $ in them; this is
                             // used to create procedures, functions or variables
                             // that user code can not call (or accidentally override)
    isLocal,                 // are identifiers in a procedure/function or
                             // are they global to the unit?
    isMainProgram: Boolean;  // is this the main program as opposed to a procedure

    // these indicate block level at start and end of line
    LineBlockChange :Boolean;
    LineBlockStart,
    LineBlockEnd: Byte;

    // To count statement blocks: Begin, Repeat, Case;
    // Increase on BEGIN, DECREASE on END
    // increase on REPEAT, DECREASE on UNTIL
    // Increase on CASE, DECREASE on END

     BlockCount: Integer =0; // +1 on BEGIn / REPEAT / CASE; -1 on END / UNTIL
     BeginCount: Integer = 0;     // Starts at 0 each proc/func,
                                  // +1 on begin, -1 on END

     FirstStatement: Boolean;     // Is this the first statement on a line?

     LastIdentifier: String;      // previous identifier, used in modifier assignment
     Skipping: Boolean;            // Global Var to indicate in Skipping mode (See Conditional unit)



  ScannerStack: array [1..SCANNERSTACKSIZE] of TScannerState;
  ScannerStackTop: Integer = 0;

  CodeSize: Integer;             // Moved from CodeGen

  // since the array was searched sequentially, it
  // should be relatively easy to move to
  // a linked list of pointers

  // Where a list is established by pointers, -BASE points
  // to the initial start of the list, -TOP points to the latest entry.
  NewIdent,             // item being searched
  IdentBase,            // These will point to the base and
  IdentTop: IdentP;     // the top of the idetifier linked list

  SearchType,              // used when searching for types
  BaseType,             // base
  TopType: TypePtr;     // and top of type list


  // Once we go to pointers insted of arrays, most of these wll either
  // change to a linked list, to a pointer, or disappear entirely

  Ident: array [1..MAXIDENTS] of TIdentifier;
  Types: array [1..MAXTYPES] of TType;
  InitializedGlobalData: array [0..MAXINITIALIZEDDATASIZE - 1] of Byte;
  Units: array [1..MAXUNITS] of TUnit;
  Extensions: array [1..MAXEXTENSIONS] of TString;
  Folders: array [1..MAXFOLDERS] of TString;
//  Folders: FolderListP;
  BlockStack: array [1..MAXBLOCKNESTING] of TBlock;
  WithStack: array [1..MAXWITHNESTING] of TWithDesignator;

  NumIdent: integer =0;                // index into identifier table; usually points to the last defined identifier
  MaxIdentCount: integer = 0;          // largest number of identifiers ever used
  TotalIdent: integer =0;              // number of identifiers used in entire program
  TotalExtProc: Integer = 0;           // number of External Procedures
  TotalExtFunc: Integer = 0;           // and functions
  TotalProcCount: Integer = 0;         // number of Procedures
  TotalFuncCount: Integer = 0;         // and functions in program
  UnitLocalIdent,           // identifoers declared at unit level
  UnitGlobalIdent,          // Identifiers declared in procs/funcs
  UnitTotalIdent: Integer;  // Number of identifiers this unit

  NumTypes, NumUnits, NumFolders,
  NumBlocks, BlockStackTop, ForLoopNesting,
  WithNesting, InitializedGlobalDataSize,
  UninitializedGlobalDataSize: Integer;
  IsConsoleProgram: Boolean;


// FOR PROGRAM LISTING AND COMPILER DEBUGGING
   ListProgram,
   Statistics: Boolean;
   ListingLine,
   ListingPage: Integer;
   ListingPageLine,
   ListingPos,
   ListingProcLevelOpen,
   ListingProcLevelClose,
   ListingBlockLevelOpen,
   ListingBlockLevelClose: Byte;


   TotalLines: LongInt = 0; // Total number of lines read/compiled

 //   TestInit:  TestRecord = (Hi:=5; Lo:=6);


procedure InitializeCommon;
procedure FinalizeCommon;
procedure CopyParams(var LeftSignature, RightSignature: TSignature);
procedure DisposeParams(var Signature: TSignature);
procedure DisposeFields(var DataType: TType);
function GetTokSpelling(TokKind: TTokenKind): TString;
function GetTypeSpelling(DataType: Integer; LongDesc:Boolean=TRUE): TString;
function GetIDKindSpelling(IDKind:TIdentKind): Char;
function GetPassSpelling(Pass:TPassMethod):TString;
function Align(Size, Alignment: Integer): Integer;


// used for indirect procedures
procedure SetWriteProcs(ClassInstance: Pointer; NewNoticeProc, NewWarningProc, NewErrorProc: TWriteProc);        // indirect procedure
procedure Notice(const Msg: TString);
procedure Warning(const Msg: TString);
function IsString(DataType: Integer): Boolean;
// procedure SetUnitStatus(var NewUnitStatus: TUnitStatus);
function GetKeyword(const KeywordName: TString): TTokenKind;
Function Plural(N:LongInt; Plu:String; Sng: String):   string;
Function Comma(K:Longint; Sep:char =','):string;
Function CommaP(N:LongInt; Plu:String; Sng: String; Sep:char =','):   string;
function I2(N:Word):string;
Function GetScopeSpelling(Scope: TScope): TString;
Procedure NewString(Var SA: LPCSTR);
Procedure DisposeString(Var SA: LPCSTR);


implementation


var
  NoticeProc, WarningProc, ErrorProc: TWriteProc;         // indirect procedures
  WriteProcsClassInstance: Pointer;



  StringManager: PStringList;



procedure InitializeCommon;
begin
FillChar(Ident, SizeOf(Ident), #0);
FillChar(Types, SizeOf(Types), #0);
FillChar(Units, SizeOf(Units), #0);
FillChar(InitializedGlobalData, SizeOf(InitializedGlobalData), #0);

NumIdent                    := 0; 
NumTypes                    := 0;
NumUnits                    := 0;
NumFolders                  := 0; 
NumBlocks                   := 0; 
BlockStackTop               := 0; 
ForLoopNesting              := 0;
WithNesting                 := 0;
InitializedGlobalDataSize   := 0;
UninitializedGlobalDataSize := 0;

IsConsoleProgram            := TRUE;  // Console program by default
end;

//  FIXME when using pointers, dispose of them, too
procedure FinalizeCommon;
var
  i: Integer;
  
begin
// Dispose of dynamically allocated parameter data
for i := 1 to NumIdent do
  if (Ident[i].Kind = PROC) or (Ident[i].Kind = FUNC) then
    DisposeParams(Ident[i].Signature);

// Dispose of dynamically allocated parameter and field data
for i := 1 to NumTypes do
  begin
  if Types[i].Kind = PROCEDURALTYPE then
    DisposeParams(Types[i].Signature) 
  else if Types[i].Kind in [RECORDTYPE, INTERFACETYPE] then
    DisposeFields(Types[i]);
  end;
end;




procedure CopyParams(var LeftSignature, RightSignature: TSignature);
var
  i: Integer;
begin
for i := 1 to RightSignature.NumParams do
  begin
  New(LeftSignature.Param[i]);
  LeftSignature.Param[i]^ := RightSignature.Param[i]^;
  end;
end;



//  FIXME when using pointers, dispose of them, too
procedure DisposeParams(var Signature: TSignature);
var
  i: Integer;
begin
for i := 1 to Signature.NumParams do
  Dispose(Signature.Param[i]);
end; 



//  FIXME when using pointers, dispose of them, too
procedure DisposeFields(var DataType: TType);
var
  i: Integer;
begin
for i := 1 to DataType.NumFields do
  Dispose(DataType.Field[i]);
end; 


// This is in common bcause it is used by both 
// Scanner and Parser`
// Note: If you add new tokens, GETKEYWORD, GETTOKSPELLING,
// TTOKENKIND, NUMKEYWORDS, and KEYWORD must **ALL** be adjusted.
function GetTokSpelling(TokKind: TTokenKind): TString;
begin
case TokKind of
  EMPTYTOK:                          Result := 'no token';
  OPARTOK:                           Result := '(';
  CPARTOK:                           Result := ')';
  MULTOK:                            Result := '*';
  PLUSTOK:                           Result := '+';
  COMMATOK:                          Result := ',';
  MINUSTOK:                          Result := '-';
  PERIODTOK:                         Result := '.';
  RANGETOK:                          Result := '..';
  DIVTOK:                            Result := '/';
  COLONTOK:                          Result := ':';
  BECOMESTOK:                        Result := ':=';
  SEMICOLONTOK:                      Result := ';';
  LTTOK:                             Result := '<';
  LETOK:                             Result := '<=';
  NETOK:                             Result := '<>';
  EQTOK:                             Result := '=';
  GTTOK:                             Result := '>';
  GETOK:                             Result := '>=';
  ADDRESSTOK:                        Result := '@';
  OBRACKETTOK:                       Result := '[';
  CBRACKETTOK:                       Result := ']';
  DEREFERENCETOK:                    Result := '^';
  ANDTOK..XORTOK:                    Result := Keyword[Ord(TokKind) - Ord(ANDTOK) + 1];

  PLUSEQTOK:                         Result := '+=';
  MINUSEQTOK:                        Result := '-=';
  MULEQTOK:                          Result := '*=';
  DIVEQTOK:                          Result := '/=';
  JUNKTOK:                           Result := 'unrecognized character';

  COMMENTTOK:                        Result := 'Text Comment';
  CCSIFTOK:                          Result := '$IF Compiler Directive';
  CCSIFDEFTOK:                       Result := '$IFDEF Compiler Directive';
  CCSIFNDEFTOK:                      Result := '$IFNDEF Compiler Directive';
  CCSELSEIFTOK:                      Result := '$ELSEIF Compiler Directive';
  CCSELSETOK:                        Result := '$ELSE Compiler Directive';
  CCSENDIFTOK:                       Result := '$ENDIF Compiler Directive';
  CCSDEFINETOK:                      Result := '$DEFINE Compiler Directive';
  CCSUNDEFTOK:                       Result := '$UNDEF Compiler Directive';

  IDENTTOK:                          Result := 'identifier';
  INTNUMBERTOK:                      Result := 'integer';
  REALNUMBERTOK:                     Result := 'real number';
  CHARLITERALTOK:                    Result := 'character literal';
  STRINGLITERALTOK:                  Result := 'string literal';
  ASMLABELTOK:                       Result := 'assembler label';

  // pure errors
  ERRSEMIEQTOK:                      Result := ';='; // ;= isn't right, dummy!

  // Error message fields
  ERRCHARTOK:                        Result := 'character';
  ERRDIGITTOK:                       Result := 'digit';
  ERRNUMBERTOK:                      Result := 'number';
  ERRSTMTTOK:                        Result := 'statement';
  ERRLINETOK:                        Result := 'line'

else
  Result := 'unknown token';
end; //case
end;



// make sure Keyword is updated if you change this
function GetTypeSpelling(DataType: Integer; LongDesc:Boolean=TRUE): TString;
begin
case Types[DataType].Kind of
  EMPTYTYPE:     if LongDesc then  Result := 'no type'       else Result := 'NONE';
  ANYTYPE:       if LongDesc then  Result := 'any type'      else Result := 'ANY ';
  INT64TYPE:     if LongDesc then  Result := 'integer 64'    else Result := 'I64 ';
  INT128TYPE:    if LongDesc then  Result := 'integer 128'   else Result := 'I128';
  INTEGERTYPE:   if LongDesc then  Result := 'integer'       else Result := 'I   ';
  SMALLINTTYPE:  if LongDesc then  Result := 'small integer' else Result := 'smI ';
  SHORTINTTYPE:  if LongDesc then  Result := 'short integer' else Result := 'SHI ';
  WORDTYPE:                        Result := 'word';
  BYTETYPE:                        Result := 'byte';
  CHARTYPE:      if LongDesc then  Result := 'character'     else Result := 'char';
  BOOLEANTYPE:   if LongDesc then  Result := 'Boolean'       else Result := 'bool';
  REALTYPE:                        Result := 'real';
//  DOUBLETYPE:  if LongDesc then  Result := 'double-precision real' else Result := 'dpR ';
  SINGLETYPE:    if LongDesc then  Result := 'single-precision real' else Result := 'sgR ';
  POINTERTYPE:    begin
                 if LongDesc then  Result := 'pointer'       else Result := 'ptr ';
                  if Types[Types[DataType].BaseType].Kind <> ANYTYPE then
                    if LongDesc then Result := Result + ' to ' + GetTypeSpelling(Types[DataType].BaseType)
                                else Result := 'p ->'+GetTypeSpelling(Types[DataType].BaseType, FALSE);
                  end;  
  FILETYPE:       begin
                                     Result := 'file';
                  if Types[Types[DataType].BaseType].Kind <> ANYTYPE then       // related to FILE declarations
                    if LongDesc then Result := Result + ' of ' + GetTypeSpelling(Types[DataType].BaseType)
                                else Result := 'F->' + GetTypeSpelling(Types[DataType].BaseType,FALSE);
                  end;  
  ARRAYTYPE:      begin   // check for string ("array of char")
                     if Types[Types[DataType].BaseType].Kind  = CHARTYPE then  if LongDesc then  Result := 'string' else Result := 'Strg'
                     else  if LongDesc then
                             Result := 'array of ' + GetTypeSpelling(Types[DataType].BaseType)
                     else Result := 'a-> ' + GetTypeSpelling(Types[DataType].BaseType,FALSE);
                  end;
  RECORDTYPE:     if LongDesc then Result := 'record'      else Result := 'rec ';
  CURRENCYTYPE:   if LongDesc then Result := 'currency'    else Result := 'curr';
  INTERFACETYPE:  if LongDesc then Result := 'interface'   else Result := 'ifac';
  SETTYPE:        if LongDesc then Result := 'set of ' + GetTypeSpelling(Types[DataType].BaseType)
                              else Result := 's-> '+GetTypeSpelling(Types[DataType].BaseType, FALSE);
  ENUMERATEDTYPE: if LongDesc then Result := 'enumeration' else Result := 'enum';
  SUBRANGETYPE:   if LongDesc then Result := 'subrange of ' + GetTypeSpelling(Types[DataType].BaseType)
                              else Result := 'SU->'+GetTypeSpelling(Types[DataType].BaseType,FALSE);
  PROCEDURALTYPE: if LongDesc then Result := 'procedural type'  else Result := 'PTyp';
//  SYSTEMPROCTYPE: if LongDesc then Result := 'system procedure' else Result := 'sp  ';
//  SYSTEMFUNCTYPE: if LongDesc then Result := 'system function'  else Result := 'sF  ';
//  PROCTYPE:       if LongDesc then Result := 'procedure'        else Result := 'PROC';
//  FUNCTYPE:       if LongDesc then Result := 'function'         else Result := 'FUNC';

else
  if LongDesc then Result := 'unknown type' else Result := '????';
end; //case
end;

Function GetScopeSpelling(Scope: TScope): TString;
begin
    case Scope of
       EMPTYSCOPE: Result := ' empty ';
       GLOBAL:     Result := 'global ';
       LOCAL:      Result := ' local ';
    end;
end;

function Align(Size, Alignment: Integer): Integer;
begin
Result := ((Size + (Alignment - 1)) div Alignment) * Alignment;
end;



 // used for indirect procedures
procedure SetWriteProcs(ClassInstance: Pointer; NewNoticeProc, NewWarningProc, NewErrorProc: TWriteProc);
begin
WriteProcsClassInstance := ClassInstance;

NoticeProc  := NewNoticeProc;
WarningProc := NewWarningProc;
ErrorProc   := NewErrorProc;
end;

procedure Notice(const Msg: TString);
begin
Writeln(OUTPUT,Msg);
end;

// indirect procedure
procedure Warning(const Msg: TString);
begin
WarningProc(WriteProcsClassInstance, Msg);
end;
// This is left here for technical reasons (every time I
// try to remove it, it breaks the compiler)
procedure OldError(const Msg: TString);
begin
ErrorProc(WriteProcsClassInstance, Msg);
end;


function IsString(DataType: Integer): Boolean;
    begin
     Result := (Types[DataType].Kind = ARRAYTYPE) and (Types[Types[DataType].BaseType].Kind = CHARTYPE);
    end;





// Note: If you add new tokens, GETKEYWORD, GETTOKSPELLING,
// TTOKENKIND, NUMKEYWORDS, and KEYWORD must **ALL** be/ adjusted.

function GetKeyword(const KeywordName: TString): TTokenKind;
var
  Index,
  Max, Mid, Min: Integer;
  Found: Boolean;
begin
Result := EMPTYTOK;

// Binary search
Min := 1;
Max := NUMKEYWORDS;

repeat
  Mid := (Min + Max) div 2;
  if KeywordName > Keyword[Mid] then
    Min := Mid + 1
  else
    Max := Mid - 1;
  Found := KeywordName = Keyword[Mid];
until Found or (Min > Max);

   if Found then
   begin
       Index := Ord(ANDTOK) - 1 + Mid;
       Result := TTokenKind(Index);
       Inc(KeyWorDCount[Index])
   End;
end;







function GetIDKindSpelling(IDKind:TIdentKind): Char;
begin
   Case IDkind of
     EMPTYIDENT: Result := '?';
     GOTOLABEL:  Result := 'L';
     CONSTANT:   Result := 'C';
     USERTYPE:   Result := 'U';
     VARIABLE:   Result := 'V';
     PROC:       Result := 'P';
     FUNC:       Result := 'f';
   end;
end;


function GetPassSpelling(Pass:TPassMethod):TString;
begin
    Case Pass of
       EMPTYPASSING: RESULT := ' EMPTY ';
         VALPASSING: RESULT := ' VALUE ';
       CONSTPASSING: RESULT := ' CONST ';
         VARPASSING: RESULT := ' VAR ';
    end;

end;


{
Function hex( N:LongInt):string;
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
         rem := num mod 16;
         S := HexString[ rem ]+S;
         num := num DIV 16;
       end;
      Result := S;
  end;
}

 Function Comma(K:Longint; Sep:char =','):string;
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
    Result := S;
end;

  Function Plural(N:LongInt; Plu:String; Sng: String): string;
  Var
     s:String;
  Begin
      IStr(N,S);
      S := ' '+S+' ';
      If n<>1 Then
          Result:= S+ Plu
       Else
          Result := S + Sng;
  End;


// CommaP - Functon of both Comma AND Plural

Function CommaP(N:LongInt; Plu:String; Sng: String; Sep:char =','): string;
Var
     S:String;
begin
    S := Comma(N,Sep);
    S := ' '+S+' ';
    If n<>1 Then
        Result := S + Plu
     Else
        Result := S + Sng;
end;



function I2(N:Word):string;
var
   T1:String[3];
 begin
    T1 :=Radix(N,10);
    If Length(T1)<2 then
       T1 := '0'+T1;
    Result := T1;
end;

Procedure NewString(Var SA: LPCSTR);
begin
     If StringManager = NIL then
     begin
         New(StringManager);
         New(SA);
         StringManager^.Prev := NIL;
         StringManager^.Next := NIL;
         StringManager^.Item := NIL;
     end
     else
     begin
        If StringManager^.Item = NIL then
            New(SA)
        else
        begin
            SA := StringManager^.Item;
            StringManager^.Item := NIL;
            If StringManager^.Prev<>NIL then
                StringManager := StringManager^.Prev;
        end;
    end;
end;

Procedure DisposeString(Var SA: LPCSTR);
begin
    If StringManager^.Item <> NIl then
    begin
        While StringManager^.Next<>NIL do
        begin
            StringManager := StringManager^.Next;
            If StringManager^.Item = NIL then
            begin
                StringManager^.Item := SA;
                SA := NIL;
                exit;
            end;
        end;
        New(StringManager^.Next);
        StringManager^.Next^.Prev := StringManager;
        StringManager := StringManager^.Next;
        StringManager^.Item := SA;
        SA := NIL;
    end
    else
    begin
        StringManager^.Item := SA;
        SA := NIL;
    end;
end;

end.
        
    
    Ñ   
  
      
      3 
            