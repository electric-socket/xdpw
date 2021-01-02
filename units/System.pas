// XD Pascal for Windows (XPDW) - a 32-bit compiler
// Copyright (c) 2009-2010, 2019-2020, Vasiliy Tereshkov
// Copyright 2020 Paul Robnson

// Latest upgrade by Paul Robinson: New Years Eve; Thursday, December 31, 2020

// VERSION 0.15

// general system variables and routines including system initializaton.
// Is automatically precompiled into every program XDPW produces.

// To put it bluntly, be damn sure if you put anything in here that
// it compiles correctly or the compiler will fault your compile
// and nothing will ever work. You might also want to make sure that
// it actually works when it runs. :)


// Updates to Version 0.15
// - Add error checking on I/O
// - Addcheck for "negative 0" or reverse maxint: -2147483648
// - Convert STDINPUTFILE to INPUT and STDOUTPUTFILE to OUTPUT
//   so programs that reference INPUT and OUTPUT will work
// - Convert internal routines to have the prefix XDP_ on their name
//   so that users can't accidentally override them and to give fair
//   warning they are system functions/procedure and you override or
//   change them at your own peril.
// - In check with the other two items, so the compiler can be compiled
//   with versions before 0.15, the original legacy definitions are
//   left in even though unnecessary once the 0.15 compiler source is
//   compiled and the version 0.15 source compiled using itself.

// Updates to Version 0.14.1
// -    Update Reset to honor FileMode so a reset on a read-only file
//      will work.
// -    add Windows errors so Reset (and other I/O routines) can
//      translate WindowsLastError to IOResult.

unit System;


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

interface


const  
  // Windows API constants
  
  STD_INPUT_HANDLE      = -10;  // INPUT
  STD_OUTPUT_HANDLE     = -11;  // OUTPUT
  STD_ERROR_HANDLE      = -12;  // STDERR
  
  FILE_ATTRIBUTE_NORMAL = 128;
  
  CREATE_ALWAYS         = 2;
  OPEN_EXISTING         = 3;
  
  GENERIC_READ          = $80000000;
  GENERIC_WRITE         = $40000000;
  
  INVALID_HANDLE_VALUE  = -1;
  
  FILE_BEGIN            = 0;
  FILE_CURRENT          = 1;
  FILE_END              = 2;


  
  // Other constants
  
  Pi                    = 3.141592653589793;
  NegativeZero          = Maxint+1;
  MaxLongint  = $7fffffff;
  MaxSmallint = 32767;
// these two predefined by the compiler  0.14.1
//  MaxStrLength          = 255;
//  MaxSetElements        = 256;
  MaxSetIndex           = MaxSetElements div 32 - 1;


  // Windows File Error Numbers

ERROR_SUCCESS             =     0; //  (0x0)    The operation completed successfully.
ERROR_INVALID_FUNCTION    =     1; //  (0x1)    Incorrect function.
ERROR_FILE_NOT_FOUND      =     2; //  (0x2)    The system cannot find the file specified.
ERROR_PATH_NOT_FOUND      =     3; //  (0x3)    The system cannot find the path specified.
ERROR_TOO_MANY_OPEN_FILES =     4; //  (0x4)    The system cannot open the file.
ERROR_ACCESS_DENIED       =     5; // (0x5)    Access is denied.
ERROR_INVALID_HANDLE      =     6; // (0x6)    The handle is invalid.
ERROR_ARENA_TRASHED       =     7; // (0x7)    The storage control blocks were destroyed.
ERROR_NOT_ENOUGH_MEMORY   =     8; // (0x8)    Not enough memory resources are available to process this command.
ERROR_INVALID_BLOCK       =     9; // (0x9)    The storage control block address is invalid.
ERROR_BAD_ENVIRONMENT     =    10; // (0xA)    The environment is incorrect.
ERROR_BAD_FORMAT          =    11; // (0xB)    An attempt was made to load a program with an incorrect format.
ERROR_INVALID_ACCESS      =    12; // (0xC)    The access code is invalid.
ERROR_INVALID_DATA        =    13; // (0xD)    The data is invalid.
ERROR_OUTOFMEMORY         =    14; // (0xE)    Not enough storage is available to complete this operation.
ERROR_INVALID_DRIVE       =    15; // (0xF)    The system cannot find the drive specified.
ERROR_CURRENT_DIRECTORY   =    16; // (0x10)   The directory cannot be removed.
ERROR_NOT_SAME_DEVICE     =    17; // (0x11)   The system cannot move the file to a different disk drive.
ERROR_NO_MORE_FILES       =    18; // (0x12)   There are no more files.
ERROR_WRITE_PROTECT       =    19; // (0x13)   The media is write protected.
ERROR_BAD_UNIT            =    20; // (0x14)   The system cannot find the device specified.
ERROR_NOT_READY           =    21; // (0x15)   The device is not ready.
ERROR_BAD_COMMAND         =    22; // (0x16)   The device does not recognize the command.
ERROR_CRC                 =    23; // (0x17)   Data error (cyclic redundancy check).
ERROR_BAD_LENGTH          =    24; // (0x18)   The program issued a command but the command length is incorrect.
ERROR_SEEK                =    25; // (0x19)   The drive cannot locate a specific area or track on the disk.
ERROR_NOT_DOS_DISK        =    26; // (0x1A)   The specified disk or diskette cannot be accessed.
ERROR_SECTOR_NOT_FOUND    =    27; // (0x1B)   The drive cannot find the sector requested.
ERROR_OUT_OF_PAPER        =    28; // (0x1C)   The printer is out of paper.
ERROR_WRITE_FAULT         =    29; // (0x1D)   The system cannot write to the specified device.
ERROR_READ_FAULT          =    30; // (0x1E)   The system cannot read from the specified device.
ERROR_GEN_FAILURE         =    31; // (0x1F)   A device attached to the system is not functioning.
ERROR_SHARING_VIOLATION   =    32; // (0x20)   The process cannot access the file because it is being used by another process.
ERROR_LOCK_VIOLATION      =    33; // (0x21)   The process cannot access the file because another process has locked a portion of the file.
ERROR_WRONG_DISK          =    34; // (0x22)   The wrong diskette is in the drive. Insert %2 (Volume Serial Number: %3) into drive %1.
ERROR_SHARING_BUFFER_EXCEEDED= 36; // (0x24)   Too many files opened for sharing.
ERROR_HANDLE_EOF          =    38; // (0x26)   Reached the end of the file.
//ERROR_HANDLE_DISK_FULL    =    39; // (0x27)   The disk is full.
//ERROR_NOT_SUPPORTED       =    50; // (0x32)   The request is not supported.
//ERROR_REM_NOT_LIST        =    51; // (0x33)   Windows cannot find the network path. Verify that the network path is correct and the destination computer is not busy or turned off. If Windows still cannot find the network path, contact your network administrator.
//ERROR_DUP_NAME            =    52; // (0x34)   You were not connected because a duplicate name exists on the network. If joining a domain, go to System in Control Panel to change the computer name and try again. If joining a workgroup, choose another workgroup name.
//ERROR_BAD_NETPATH         =    53; // (0x35)   The network path was not found.
//ERROR_NETWORK_BUSY        =    54; // (0x36)   The network is busy.
//ERROR_DEV_NOT_EXIST       =    55; // (0x37)   The specified network resource or device is no longer available.
//ERROR_TOO_MANY_CMDS       =    56; // (0x38)   The network BIOS command limit has been reached.
//ERROR_ADAP_HDW_ERR        =    57; // (0x39)   A network adapter hardware error occurred.
//ERROR_BAD_NET_RESP        =    58; // (0x3A)   The specified server cannot perform the requested operation.
//ERROR_UNEXP_NET_ERR       =    59; // (0x3B)   An unexpected network error occurred.
//ERROR_BAD_REM_ADAP        =    60; // (0x3C)   The remote adapter is not compatible.
//ERROR_PRINTQ_FULL         =    61; // (0x3D)   The printer queue is full.
//ERROR_NO_SPOOL_SPACE      =    62; // (0x3E)   Space to store the file waiting to be printed is not available on the server.
//ERROR_PRINT_CANCELLED     =    63; // (0x3F)   Your file waiting to be printed was deleted.
//ERROR_NETNAME_DELETED     =    64; // (0x40)   The specified network name is no longer available.
//ERROR_NETWORK_ACCESS_DENIED=   65; //  (0x41)    Network access is denied.
//ERROR_BAD_DEV_TYPE        =    66; //  (0x42)    The network resource type is not correct.
//ERROR_BAD_NET_NAME        =    67; //  (0x43)    The network name cannot be found.
//ERROR_TOO_MANY_NAMES      =    68; //  (0x44)    The name limit for the local computer network adapter card was exceeded.
//ERROR_TOO_MANY_SESS       =    69; //  (0x45)    The network BIOS session limit was exceeded.
//ERROR_SHARING_PAUSED      =    70; //  (0x46)    The remote server has been paused or is in the process of being started.
//ERROR_REQ_NOT_ACCEP       =    71; //  (0x47)    No more connections can be made to this remote computer at this time because there are already as many connections as the computer can accept.
//ERROR_REDIR_PAUSED        =    72; //  (0x48)    The specified printer or disk device has been paused.
//ERROR_FILE_EXISTS         =    80; //  (0x50)    The file exists.
//ERROR_CANNOT_MAKE         =    82; //  (0x52)    The directory or file cannot be created.


   RadixString: Array[0..35] of char=('0','1','2','3','4','5','6','7','8','9',
                         'A','B','C','D','E','F','G','H','I','J',
                            'K','L','M','N','O','P','Q','R','S','T',
                         'U','V','W','X','Y','Z');


type

  // Used by variouws Windows functions
// Mostly here for documentation purposes
// While INT64 is not yet implemented, it was predefined
// in the compiler as of 0.14.1; if you are compiling
// this on an earlier version, it is necessary to
// remove the // at the beginning of the next line
//   INT64 = Double;     // Signed 64-bit integer
   HANDLE = Integer;     // std Windows handle

   BOOL   = Boolean;
   CCHAR  = Char;
//   COLORREF= Double;  // DWord
// next item predefined by compiler 0.14.1
//   DWORD = INT64;    // Actually double word (signed) integer
   DWORDLONG = INT64;  // Unsigned Int_64
   DWORD_PTR= ^INT64;  // Unsigned 64-bit pointer
   DWORD32= Pointer;   // Unsigned 32-bit pointer
   DWORD64= INT64;    // Unsigned int_64
 // Any terms strting with "H" are just 32-bit handles
   INT = Integer;      //  Signed 32-bit integer
   INT_PTR = ^Integer;  // Signed 32-bt pointer
   INT8 = Byte;        // signed 8-bit nteger
   INT16 = Word;       // Signed 16-bit integer
   INT32 = Integer;    // Signed 32-bit integer
//   NEXT 2 ITEMs predefined by the compiler in 0.14.1
//   LONG = Integer;     // Signed 32-bit integer
//   LONGLONG = INT64;  // Signed 64-bit integer
   LONG_PTR = ^INTEGER; // Signed integer, same as machine's bit size
   lONG32 = INTEGER;   // Signed 32-bit integer
   LONG64 = int64;    // Signed 64-bit integer
// LPxxx - Pointer to something
   LPBOOL = ^Boolean;
   LPBYTE = ^Byte;
   LPCSTR = ^String;    // Pointer to null-termnated string
   LPTSTR = ^String;    // If Unicode aware, Ptr to a Unicode stng
   //                      pointer to a string
   LPVOID = Pointer;    // Pointer to anything
   LPWORD = ^Word;      // Pointer to word
   LPWSTR = ^String;    // Pointer to null-terminated 16-bit Unicode char strings
   PBOOL  = ^Boolean;
   PBOOLEAN= ^Boolean;
   PBYTE   = ^Byte;
// Next item predefined by compiler
   //PCHAR   = ^Char;
   PCSTR   = ^String;     // Pointer to 8-bit character null-terminated string
   PCTSTR  = ^String;      // Same as pCwstr: POINTER TO UNICODE C STRING IF AWARE,
   //                        OTHERWISE SAME AS PCStr
   PCWSTR   = ^String;     // Ptr to 16-bit unicode C string
   PDWORD   = ^INT64;     // Ptr TO dword
   PDWORDLONG = ^INT64;   // Ptr TO DWORDLONG
   PDWORD_PTR = ^INT64;   // Ptr to DWORD_PTR
   PDWORD32   = ^INTEGER;   // Ptr to DWORD32
   PDWORD64   = ^INT64;   // Ptr to DWORD64
   SHORT     = WORD;      // Windows SHORT isn't same as shortint
   UINT      = integer;   // unsigned integer
   WINBOOL   = Boolean;


  LongInt = Integer;  
  Double = Real;
  Extended = Real;
  Text = file;  
  PChar = ^Char;  

  // Note to self: must walk compilaation of
  // "file of char" to make sure compiler allocates
  // actual space for file variable if I expand
  // size of this record
  TFileRec = record
    Name: string;
    FileHandle: HANDLE;
  // The following are new in 0.15 and we must be sure
  // that the compiler allocates them
    Size,              // filesize
    Position,          // where we are in file
    BlockSize,         // block size to allocate
    BlockPos: Integer; // position in block
    Buffer: PChar;     // pointer to buffer
    Mode: Byte;        // open mode
    isClosed,          // if the buffer read to actual end
    isEoln,            // for EOLN() function
    IsEof: Boolean;    // for EOF() function
  end;

  PFileRec = ^TFileRec;  
  
  TStream = record
    Data: PChar;
    Index: Integer;
  end;

  PStream = ^TStream;

  TSetStorage = array [0..MaxSetIndex] of Integer;

var

  Input, Output, StdErr: file;
  DecimalSeparator: Char = '.';   // for other countries you
  ThousandSeparator: Char = ',';  // can change or swap these
  Filemode: byte = 2;          // Defalt open is read/write

// Windows API functions

function GetCommandLineA: Pointer stdcall; external 'KERNEL32.DLL';

function GetModuleFileNameA(hModule: LongInt; 
                            var lpFilename: string;
                            nSize: LongInt): LongInt stdcall; external 'KERNEL32.DLL';

function GetProcessHeap: LongInt stdcall; external 'KERNEL32.DLL';

function HeapAlloc(hHeap,
                   dwFlags,
                   dwBytes: LongInt): Pointer stdcall; external 'KERNEL32.DLL';

procedure HeapFree(hHeap,
                   dwFlags: LongInt; 
                   lpMem: Pointer) stdcall; external 'KERNEL32.DLL';

function GetStdHandle(nStdHandle: Integer): LongInt stdcall; external 'KERNEL32.DLL';

procedure SetConsoleMode(hConsoleHandle: LongInt; 
                         dwMode: LongInt) stdcall; external 'KERNEL32.DLL';

function CreateFileA(const lpFileName: string; 
                     dwDesiredAccess: LongInt;
                     dwShareMode: LongInt;
                     lpSecurityAttributes: Pointer; 
                     dwCreationDisposition, 
                     dwFlagsAndAttributes, 
                     hTemplateFile: LongInt): LongInt stdcall; external 'KERNEL32.DLL';
                     
function SetFilePointer(hFile: LongInt; 
                        lDistanceToMove: LongInt; 
                        pDistanceToMoveHigh: Pointer; 
                        dwMoveMethod: LongInt): LongInt stdcall; external 'KERNEL32.DLL';

function GetFileSize(hFile: LongInt; 
                     lpFileSizeHigh: Pointer): LongInt stdcall; external 'KERNEL32.DLL';        
                     
procedure WriteFile(hFile: LongInt;
                    lpBuffer: Pointer;
                    nNumberOfBytesToWrite: LongInt;
                    var lpNumberOfBytesWritten: LongInt;
                    lpOverlapped: LongInt) stdcall; external 'KERNEL32.DLL';
                    
function ReadFile(hFile: LongInt;
                   lpBuffer: Pointer;
                   nNumberOfBytesToRead: LongInt;
                   var lpNumberOfBytesRead: LongInt;
                   lpOverlapped: LongInt):integer stdcall; external 'KERNEL32.DLL';

procedure CloseHandle(hObject: LongInt) stdcall; external 'KERNEL32.DLL';

function GetLastError: LongInt stdcall; external 'KERNEL32.DLL';

function LoadLibraryA(const lpLibFileName: string): LongInt stdcall; external 'KERNEL32.DLL';

function GetProcAddress(hModule: LongInt; 
                        const lpProcName: string): Pointer stdcall; external 'KERNEL32.DLL';

function GetTickCount: LongInt stdcall; external 'KERNEL32.DLL';

procedure ExitProcess(uExitCode: Integer) stdcall; external 'KERNEL32.DLL';

{function GetEnvironmentVariable( Name: String;
                                 var Buffer: String;
                                 BufferSize: Integer):Integer stdcall;
                         external 'KERNEL32.DLL'; }

// Other functions

function Timer: LongInt;
procedure GetMem(var P: Pointer; Size: Integer);
procedure FreeMem(var P: Pointer);
procedure Randomize;
function Random: Real;
function Length(const s: string): Integer;
procedure SetLength(var s: string; NewLength: Integer);
procedure AssignStr(var Dest: string; const Source: string);
procedure AppendStr(var Dest: string; const Source: string);
procedure ConcatStr(const s1, s2: string; var s: string);
function CompareStr(const s1, s2: string): Integer;
procedure Move(var Source; var Dest; Count: Integer);
function Copy(const S: string; Index, Count: Integer): string;
procedure FillChar(var Data; Count: Integer; Value: Char);
function ParseCmdLine(Index: Integer; var Str: string): Integer;
function ParamCount: Integer;
function ParamStr(Index: Integer): string;
procedure IStr(Number: Integer; var s: string);
procedure Str(Number: Real; var s: string; MinWidth: Integer = 0; DecPlaces: Integer = 0);
procedure Val(const s: string; var Number: Real; var Code: Integer);
procedure IVal(const s: string; var Number: Integer; var Code: Integer);
procedure Assign(var F: file; const Name: string);
procedure Rewrite(var F: file; BlockSize: Integer = 1);
procedure Reset(var F: file; BlockSize: Integer = 1);
procedure Close(var F: file);
procedure BlockWrite(var F: file; var Buf; Len: Integer);
procedure BlockRead(var F: file; var Buf; Len: Integer; var LenRead: Integer);
procedure Seek(var F: file; Pos: Integer);
function FileSize(var F: file): Integer;
function FilePos(var F: file): Integer;
function EOF(var F: file): Boolean;
function IOResult: Integer;
Function WinIoResult: Integer;
function UpCase(ch: Char): Char;


function InSet(Element: Integer; var SetStorage: TSetStorage): Boolean;
procedure SetUnion(const SetStorage1, SetStorage2: TSetStorage; var SetStorage: TSetStorage);
procedure SetDifference(const SetStorage1, SetStorage2: TSetStorage; var SetStorage: TSetStorage);
procedure SetIntersection(const SetStorage1, SetStorage2: TSetStorage; var SetStorage: TSetStorage);
function CompareSets(const SetStorage1, SetStorage2: TSetStorage): Integer;
function TestSubset(const SetStorage1, SetStorage2: TSetStorage): Integer;
function TestSuperset(const SetStorage1, SetStorage2: TSetStorage): Integer;
Function Radix( N:LongInt; theRadix:Longint):string;

// Standard System procedural types
Function Odd(I:Integer):Boolean;

procedure XDP_AddToSet(var SetStorage: TSetStorage; FromElement, ToElement: Integer);
procedure XDP_AddUnit(UnitNumber,BeginLine,EndLine:Integer; UnitName:String);
procedure XDP_InitSet(var SetStorage: TSetStorage);
procedure XDP_InitSystem;
procedure XDP_ReadBoolean(var F: file; P: PStream; var Value: Boolean);
procedure XDP_ReadByte(var F: file; P: PStream; var Number: Byte);
procedure XDP_ReadCh(var F: file; P: PStream; var ch: Char);
procedure XDP_ReadCurrency(var F: file; P: PStream; var Number: Currency);
procedure XDP_ReadInt(var F: file; P: PStream; var Number: Integer);
procedure XDP_ReadInt64(var F: file; P: PStream; var Number: Int64);
procedure XDP_ReadInt128(var F: file; P: PStream; var Number: Int128);
procedure XDP_ReadNewLine(var F: file; P: PStream);
procedure XDP_ReadReal(var F: file; P: PStream; var Number: Real);
procedure XDP_ReadRec(var F: file; P: PStream; var Buf; Len: Integer);
procedure XDP_ReadSingle(var F: file; P: PStream; var Number: Single);
procedure XDP_ReadShortInt(var F: file; P: PStream; var Number: ShortInt);
procedure XDP_ReadSmallInt(var F: file; P: PStream; var Number: SmallInt);
procedure XDP_ReadString(var F: file; P: PStream; var s: string);
procedure XDP_ReadWord(var F: file; P: PStream; var Number: Word);
procedure XDP_WriteBooleanF(var F: file; P: PStream; Flag: Boolean; MinWidth, DecPlaces: Integer);
procedure XDP_WriteCurrencyF(var F: file; P: PStream; Number: Currency; MinWidth, DecPlaces: Integer);
procedure XDP_WriteIntF(var F: file; P: PStream; Number: Integer; MinWidth, DecPlaces: Integer);
procedure XDP_WriteInt64F(var F: file; P: PStream; Number: Int64; MinWidth, DecPlaces: Integer);
procedure XDP_WriteInt128F(var F: file; P: PStream; Number: Int128; MinWidth, DecPlaces: Integer);
procedure XDP_WriteNewLine(var F: file; P: PStream);
procedure XDP_WritePointerF(var F: file; P: PStream; Number: Integer; MinWidth, DecPlaces: Integer);
procedure XDP_WriteRealF(var F: file; P: PStream; Number: Real; MinWidth, DecPlaces: Integer);
procedure XDP_WriteRec(var F: file; P: PStream; var Buf; Len: Integer);
procedure XDP_WriteStringF(var F: file; P: PStream; const S: string; MinWidth, DecPlaces: Integer);


//  debug assist
procedure XDP_NilPointer(Name, Proc, FN:String; isProc:boolean; Line:Integer; Address:Integer);
procedure XDP_StartErrMsg(Msg:String);
Procedure XDP_WriteErrmsg(Msg:String);
Procedure XDP_WriteLnErrmsg;



// Historical; old names that are replaced by the new names
var
    StdInputFile, StdOutputFile: file;


procedure InitSystem;

procedure AddToSet(var SetStorage: TSetStorage; FromElement, ToElement: Integer);
procedure InitSet(var SetStorage: TSetStorage);
procedure ReadBoolean(var F: file; P: PStream; var Value: Boolean);
procedure ReadByte(var F: file; P: PStream; var Number: Byte);
procedure ReadCh(var F: file; P: PStream; var ch: Char);
procedure ReadInt(var F: file; P: PStream; var Number: Integer);
procedure ReadNewLine(var F: file; P: PStream);
procedure ReadReal(var F: file; P: PStream; var Number: Real);
procedure ReadShortInt(var F: file; P: PStream; var Number: ShortInt);
procedure ReadSingle(var F: file; P: PStream; var Number: Single);
procedure ReadSmallInt(var F: file; P: PStream; var Number: SmallInt);
procedure ReadString(var F: file; P: PStream; var s: string);
procedure WriteIntF(var F: file; P: PStream; Number: Integer; MinWidth, DecPlaces: Integer);
procedure WriteNewLine(var F: file; P: PStream);
procedure WritePointerF(var F: file; P: PStream; Number: Integer; MinWidth, DecPlaces: Integer);
procedure WriteRealF(var F: file; P: PStream; Number: Real; MinWidth, DecPlaces: Integer);
procedure WriteStringF(var F: file; P: PStream; const S: string; MinWidth, DecPlaces: Integer);


// Built-in funcs/procs
//
//  Break
//  Continue
//  Exit
//  Halt




implementation


type
      UnitItem = record   // units used in this program
       NameP: ^String;
       LineStart,
       LineEnd: Integer;
    end;


var
  RandSeed: Integer;  
  Heap: LongInt;  
  IOError: Integer = 0;
  WinIOError: Integer = 0;
  StdInputHandle,
  StdOutputHandle,
  StdErrorHandle: HANDLE;
  StdInputBuffer: string = '';
  StdInputBufferPos: Integer = 1;
  LastReadChar: Char = ' ';
  ErrMsgLen: Byte;               // for counting output error messages
  UnitList: Array[1..255] of UnitItem;      // Unit Table

  
procedure PtrStr(Number: Integer; var s: string); forward;  
  


// Initialization

 // Notice: This is the master initializarion procedure called by the
 // compiler at run time; It must start okay or the application
 // will not work
procedure XDP_InitSystem;
var
  FileRecPtr: PFileRec;
begin
Heap := GetProcessHeap;

StdInputHandle := GetStdHandle(STD_INPUT_HANDLE);
FileRecPtr := PFileRec(@Input);
FileRecPtr^.FileHandle := StdInputHandle;

StdOutputHandle := GetStdHandle(STD_OUTPUT_HANDLE);
FileRecPtr := PFileRec(@Output);
FileRecPtr^.FileHandle := StdOutputHandle;

StdErrorHandle := GetStdHandle(STD_ERROR_HANDLE);
FileRecPtr := PFileRec(@StdErr);
FileRecPtr^.FileHandle := StdErrorHandle;

// historical - As noted in the message near the top of this file, the
//              following are not needed when compiling with the version 0.15
//              compiler.They are kept to ensure compatibility if the compiler
//              or any other ptogram might be compiled with version 0.14.1 or
//              earlier.

FileRecPtr := PFileRec(@StdOutputFile);
FileRecPtr^.FileHandle := StdOutputHandle;

FileRecPtr := PFileRec(@StdInputFile);
FileRecPtr^.FileHandle := StdInputHandle;


end;



// Timer

function Timer: LongInt;
begin
Result := GetTickCount;
end;




// Heap routines

procedure GetMem(var P: Pointer; Size: Integer);
begin
P := HeapAlloc(Heap, 0, Size);
end;




procedure FreeMem(var P: Pointer);
begin
HeapFree(Heap, 0, P);
end;




// Random number generator routines


procedure Randomize;
begin
RandSeed := Timer;
end;




function Random: Real;
begin
RandSeed := 1975433173 * RandSeed;
Result := 0.5 * (RandSeed / $7FFFFFFF + 1.0);
end;


// String manipulation routines
procedure AppendStr(var Dest: string; const Source: string);
var
  DestLen, i: Integer;
begin
DestLen := Length(Dest);
i := 0;
repeat
  Inc(i);
  Dest[DestLen + i] := Source[i];
until Source[i] = #0;
end;

procedure AssignStr(var Dest: string; const Source: string);
begin
Move(Source, Dest, Length(Source) + 1);
end;

function Length(const s: string): Integer;
begin
Result := 0;
while s[Result + 1] <> #0 do Inc(Result);
end;





procedure SetLength(var s: string; NewLength: Integer);
begin
if NewLength >= 0 then s[NewLength + 1] := #0;
end;




procedure ConcatStr(const s1, s2: string; var s: string);
begin
s := s1;
AppendStr(s, s2);
end;




function CompareStr(const s1, s2: string): Integer;
var
  i: Integer;
begin
Result := 0;
i := 0;
repeat 
  Inc(i);
  Result := Integer(s1[i]) - Integer(s2[i]);
until (s1[i] = #0) or (s2[i] = #0) or (Result <> 0);
end;




procedure Move(var Source; var Dest; Count: Integer);
var
  S, D: LPCSTR;
  i: Integer;
begin
S := @Source;
D := @Dest;

if S = D then Exit;

for i := 1 to Count do
  D^[i] := S^[i];
end;




function Copy(const S: string; Index, Count: Integer): string;
begin
Move(S[Index], Result, Count);
Result[Count + 1] := #0;  
end;




procedure FillChar(var Data; Count: Integer; Value: Char);
var
  D: LPCSTR;
  i: Integer;
begin
D := @Data;
for i := 1 to Count do
  D^[i] := Value;
end;




function ParseCmdLine(Index: Integer; var Str: string): Integer;
var
  CmdLine: string;
  CmdLinePtr: LPCSTR;
  ParamPtr: array [0..7] of LPCSTR;
  i, NumParam, CmdLineLen: Integer;

begin
CmdLinePtr := GetCommandLineA;
CmdLineLen := Length(CmdLinePtr^);
Move(CmdLinePtr^, CmdLine, CmdLineLen + 1);

NumParam := 1;
ParamPtr[NumParam - 1] := @CmdLine;

for i := 1 to CmdLineLen do
  begin
  if CmdLine[i] <= ' ' then
    CmdLine[i] := #0;
    
  if (i > 1) and (CmdLine[i] > ' ') and (CmdLine[i - 1] = #0) then
    begin
    Inc(NumParam);
    ParamPtr[NumParam - 1] := Pointer(@CmdLine[i]);
    end;
  end;
  
if Index < NumParam then
  Str := ParamPtr[Index]^
else
  Str := '';

Result := NumParam;  
end;




function ParamCount: Integer;
var
  Str: string;
begin  
Result := ParseCmdLine(0, Str) - 1;
end; 




function ParamStr(Index: Integer): string;
begin
if Index = 0 then
  GetModuleFileNameA(0, Result, SizeOf(Result))
else  
  ParseCmdLine(Index, Result);
end;   




// File and console I/O routines

Procedure TranslateWindowsErrorToIoResult(Error:Longint);
begin
    IOError := Error;
    // Most error numbers are identical...
    //   2    File not found.
    //   3   Path not found.
    //   4   Too many open files.
    //   5   Access denied.
    //   6   Invalid file handle.
    if error = ERROR_INVALID_HANDLE then // almost certainly "File not open"
         IOError := 103
    //  12   Invalid file-access mode.
    //  15   Invalid disk number.
    //  16   Cannot remove current directory.
    //  17   Cannot rename across volumes.
// Most error numbers are identical, except...
   // 100    Error when reading from disk.
   // 101    Error when writing to disk.
   // 102    File not assigned.
   // 103    File not open.
   // 104    File not opened for input.
   // 105    File not opened for output.
   // 106    Invalid number.

// (Formerly) Fatal errors :

    else If error = ERROR_WRITE_PROTECT  then
          IOError := 150  //  Disk is write protected.
   // 151    Unknown device.
    else If error = ERROR_NOT_READY then
          IOError := 152  //  Drive not ready.
    else If error = ERROR_BAD_COMMAND then
          IOError := 153  //  Unknown command.
    else If error = ERROR_CRC    then
          IOError := 154  //  CRC check failed.
    else If error = ERROR_BAD_UNIT then
          IOError := 155  //  Invalid drive specified..
    else If error = ERROR_SEEK then
          IOError := 156  //  Seek error on disk.
    else If error = ERROR_NOT_DOS_DISK then
          IOError := 157  //  Invalid media type.
    else If error = ERROR_SECTOR_NOT_FOUND then
          IOError := 158  //  Sector not found.
    else If error = ERROR_OUT_OF_PAPER  then
          IOError := 159  //  Printer out of paper.
    else If error = ERROR_WRITE_FAULT then
          IOError := 160  //  Error when writing to device.
    else If error = ERROR_READ_FAULT then
          IOError := 161  //  Error when reading from device.
    else If error = ERROR_GEN_FAILURE then
          IOError := 162  //  Hardware failure.

end;

procedure Assign(var F: file; const Name: string);
var
  FileRecPtr: PFileRec;
begin
FileRecPtr := PFileRec(@F);
FileRecPtr^.Name := Name;
end;




procedure Rewrite(var F: file; BlockSize: Integer = 1);
var
  FileRecPtr: PFileRec;
begin
     FileRecPtr := PFileRec(@F);
     FileRecPtr^.FileHandle := CreateFileA(FileRecPtr^.Name,
                                       GENERIC_WRITE,
                                       0,
                                       nil,
                                       CREATE_ALWAYS,
                                       FILE_ATTRIBUTE_NORMAL,
                                       0);
  if FileRecPtr^.FileHandle = INVALID_HANDLE_VALUE then
  begin
      WinIOError := GetLastError;
      TranslateWindowsErrorToIoResult(WinIOError);
  end;
end;


// 2020-11-12 Paul Robinson Allow Reset to use the value of
//            FileMode to allow opening files which are read-only
procedure Reset(var F: file; BlockSize: Integer = 1);
var
  FileRecPtr: PFileRec;
  DesiredAccess: LongInt;

begin
  FileRecPtr := PFileRec(@F);
  DesiredAccess := GENERIC_READ or GENERIC_WRITE; // if filemode has an
                                                  // invalid value, use this
  case FileMode of
    0: DesiredAccess := GENERIC_READ;
    1: DesiredAccess := GENERIC_WRITE;
    2: DesiredAccess := GENERIC_READ or GENERIC_WRITE;
  end;
  FileRecPtr^.FileHandle := CreateFileA(FileRecPtr^.Name,
                                  DesiredAccess,
                                  0,
                                  nil,
                                  OPEN_EXISTING,
                                  FILE_ATTRIBUTE_NORMAL,
                                  0);
if FileRecPtr^.FileHandle = INVALID_HANDLE_VALUE then
  begin
  WinIOError := GetLastError;
 // Writeln('Last error=',WinIOError);

  TranslateWindowsErrorToIoResult(WinIOError);
  end;
end;




procedure Close(var F: file);
var
  FileRecPtr: PFileRec;
begin
FileRecPtr := PFileRec(@F);
CloseHandle(FileRecPtr^.FileHandle);
FileRecPtr^.FileHandle := INVALID_HANDLE_VALUE; // indicate file is not open
end;



  
procedure BlockWrite(var F: file; var Buf; Len: Integer);
var
  FileRecPtr: PFileRec;
  LenWritten: Integer;
begin
FileRecPtr := PFileRec(@F);
WriteFile(FileRecPtr^.FileHandle, @Buf, Len, LenWritten, 0);
end;




procedure BlockRead(var F: file; var Buf; Len: Integer; var LenRead: Integer);
Const
    NonOverlapped =0;
var
  FileRecPtr: PFileRec;
  Success: integer;
begin
FileRecPtr := PFileRec(@F);
Success := ReadFile(FileRecPtr^.FileHandle, @Buf, Len, LenRead, NonOverlapped);
if lenread=0 then
   begin
   writeln('BR lenread=0 succ=',success);
   end;
if 1<> success then
  begin
      WinIOError := GetLastError;
      TranslateWindowsErrorToIoResult(WinIOError);
  end;
end;




procedure Seek(var F: file; Pos: Integer);
var
  FileRecPtr: PFileRec;
begin
FileRecPtr := PFileRec(@F);
Pos := SetFilePointer(FileRecPtr^.FileHandle, Pos, nil, FILE_BEGIN);
end;




function FileSize(var F: file): Integer;
var
  FileRecPtr: PFileRec;
begin
FileRecPtr := PFileRec(@F);
Result := GetFileSize(FileRecPtr^.FileHandle, nil);
end;




function FilePos(var F: file): Integer;
var
  FileRecPtr: PFileRec;
begin
FileRecPtr := PFileRec(@F);
Result := SetFilePointer(FileRecPtr^.FileHandle, 0, nil, FILE_CURRENT);
end;




function EOF(var F: file): Boolean;
var
  FileRecPtr: PFileRec;
begin
FileRecPtr := PFileRec(@F);
if (FileRecPtr^.FileHandle = StdInputHandle)  or
   (FileRecPtr^.FileHandle = StdOutputHandle) or
   (FileRecPtr^.FileHandle = StdErrorHandle) then
  Result := FALSE
else
  Result := FilePos(F) >= FileSize(F);
end;




function IOResult: Integer;
begin
Result := IOError;
IOError := 0;
end;

// In case GetLastError is transient, e.g.
// retriving it resets it to 0
function WinIOResult: Integer;
begin
Result := WinIOError;
WinIOError := 0;
end;



procedure XDP_WriteRec(var F: file; P: PStream; var Buf; Len: Integer);
begin
BlockWrite(F, Buf, Len);
end;




procedure WriteCh(var F: file; P: PStream; ch: Char);
var
  Dest: PChar;
begin 
if P = nil then                                     // Console or file output
  BlockWrite(F, ch, 1)
else                                                // String stream output 
  begin                      
  Dest := PChar(Integer(P^.Data) + P^.Index);
  Dest^ := ch;
  Inc(P^.Index);
  end  
end;




procedure WriteString(var F: file; P: PStream; const S: string);
var
  Dest: PChar;
begin
if P = nil then                                     // Console or file output
  BlockWrite(F, S, Length(S))
else                                                // String stream output
  begin                      
  Dest := PChar(Integer(P^.Data) + P^.Index);
  Move(S, Dest^, Length(S));
  P^.Index := P^.Index + Length(S);
  end 
end;




procedure XDP_WriteStringF(var F: file; P: PStream; const S: string; MinWidth, DecPlaces: Integer);
var
  Spaces: string;
  i, NumSpaces: Integer;
begin
NumSpaces := MinWidth - Length(S);
if NumSpaces < 0 then NumSpaces := 0;

for i := 1 to NumSpaces do
  Spaces[i] := ' ';
Spaces[NumSpaces + 1] := #0;  
  
WriteString(F, P, Spaces + S);
end;




function WriteInt(var F: file; P: PStream; Number: Integer): Integer;
var
  Digit, Weight: Integer;
  Skip: Boolean;

begin
// Returns the string length
 if Number = 0 then
  begin
  WriteCh(F, P,  '0');
  Result := 1;
  end
else
  begin
  Result := 0;
  if Number < 0 then
     // Paul Robinson 2020-12-08: Add special case
     If number = NegativeZero then
     begin
         WriteString(F,P,'-2147483648');
         Result:=11;
         exit;
     end
     else
     begin
         WriteCh(F, P,  '-');
         Inc(Result);
         Number := -Number;
     end;

  Weight := 1000000000;
  Skip := TRUE;

  while Weight >= 1 do
    begin
    if Number >= Weight then Skip := FALSE;

    if not Skip then
      begin
      Digit := Number div Weight;
      WriteCh(F, P,  Char(ShortInt('0') + Digit));
      Inc(Result);
      Number := Number - Weight * Digit;
      end;

    Weight := Weight div 10;
    end; // while
  end; // else

end;




procedure XDP_WriteIntF(var F: file; P: PStream; Number: Integer; MinWidth, DecPlaces: Integer);
var
  S: string;
begin
IStr(Number, S);
WriteStringF(F, P, S, MinWidth, DecPlaces);
end;
  



procedure WritePointer(var F: file; P: PStream; Number: Integer);
var
  i, Digit: ShortInt;
begin
for i := 7 downto 0 do
  begin
  Digit := (Number shr (i shl 2)) and $0F;
  if Digit <= 9 then
      Digit := ShortInt('0') + Digit
  else
      Digit := ShortInt('A') + Digit - 10;
  WriteCh(F, P,  Char(Digit));
  end; 
end;




procedure XDP_WritePointerF(var F: file; P: PStream; Number: Integer; MinWidth, DecPlaces: Integer);
var
  S: string;
begin
PtrStr(Number, S);
WriteStringF(F, P, S, MinWidth, DecPlaces);
end;




function WriteReal(var F: file; P: PStream; Number: Real; MinWidth, DecPlaces: Integer): Integer;
const
  MaxDecPlaces = 16;
  ExponPlaces = 3;
  
var
  Integ, Digit, IntegExpon: Integer;
  Expon, Frac: Real;
  WriteExpon: Boolean;

begin
// Returns the string length
Result := 0;

Expon := ln(abs(Number)) / ln(10);
WriteExpon := (DecPlaces = 0) or (Expon > 9);

// Write sign
if Number < 0 then
  begin
  WriteCh(F, P,  '-');
  Inc(Result);
  Number := -Number;
  end
else if WriteExpon then
  begin
  WriteCh(F, P,  ' ');
  Inc(Result);
  end;  
  
// Normalize number
if not WriteExpon then
  begin
  IntegExpon := 0;
  if DecPlaces > MaxDecPlaces then DecPlaces := MaxDecPlaces;
  end
else  
  begin
  DecPlaces := MaxDecPlaces;
  
  if Number = 0 then 
    IntegExpon := 0 
  else 
    begin
    IntegExpon := Trunc(Expon);
    Number := Number / exp(IntegExpon * ln(10));
    
    if Number >= 10 then
      begin
      Number := Number / 10;
      Inc(IntegExpon);
      end
    else if Number < 1 then
      begin
      Number := Number * 10;
      Dec(IntegExpon);    
      end;
    end;  
  end;

// Write integer part
Integ := Trunc(Number);
Frac  := Number - Integ;

Result := Result + WriteInt(F, P, Integ);

// Write decimal separator  
WriteCh(F, P, DecimalSeparator);
Inc(Result);

// Truncate fractional part if needed
if (MinWidth > 0) and WriteExpon and (Result + DecPlaces + 2 + ExponPlaces > MinWidth) then  // + 2 for "e+" or "e-"
  begin
  DecPlaces := MinWidth - Result - 2 - ExponPlaces;
  if DecPlaces < 1 then DecPlaces := 1;
  end;
  
// Write fractional part
while DecPlaces > 0 do
  begin
  Frac := Frac * 10;
  Digit := Trunc(Frac);
  if Digit > 9 then Digit := 9;
  
  WriteCh(F, P,  Char(ShortInt('0') + Digit));
  Inc(Result);
  
  Frac := Frac - Digit;  
  Dec(DecPlaces);
  end; // while

// Write exponent
if WriteExpon then 
  begin
  WriteCh(F, P, 'e');

  if IntegExpon >= 0 then
    WriteCh(F, P, '+')
  else
    begin
    WriteCh(F, P, '-');  
    IntegExpon := -IntegExpon;
    end;
    
  // Write leading zeros
  if IntegExpon < 100 then WriteCh(F, P, '0');
  if IntegExpon <  10 then WriteCh(F, P, '0');
  
  WriteInt(F, P, IntegExpon);     
  Result := Result + 2 + ExponPlaces; 
  end;
 
end;

procedure XDP_WriteCurrencyF(var F: file; P: PStream; Number: Currency; MinWidth, DecPlaces: Integer);
begin
// nothing for now, just a placeholder
end;

procedure XDP_ReadCurrency(var F: file; P: PStream; var Number: Currency);
begin
// nothing for now, just a placeholder
end;

procedure XDP_ReadInt64(var F: file; P: PStream; var Number: Int64);
begin
// nothing for now, just a placeholder
end;

procedure XDP_ReadInt128(var F: file; P: PStream; var Number: Int128);
begin
// nothing for now, just a placeholder
end;

procedure XDP_WriteInt64F(var F: file; P: PStream; Number: Int64; MinWidth, DecPlaces: Integer);
begin
// nothing for now, just a placeholder
end;

procedure XDP_WriteInt128F(var F: file; P: PStream; Number: Int128; MinWidth, DecPlaces: Integer);
begin
// nothing for now, just a placeholder
end;


procedure XDP_WriteRealF(var F: file; P: PStream; Number: Real; MinWidth, DecPlaces: Integer);
var
  S: string;
begin
Str(Number, S, MinWidth, DecPlaces);
WriteStringF(F, P, S, MinWidth, DecPlaces);
end;




procedure WriteBoolean(var F: file; P: PStream; Flag: Boolean);
begin
if Flag then WriteString(F, P, 'TRUE') else WriteString(F, P, 'FALSE');
end;




procedure XDP_WriteBooleanF(var F: file; P: PStream; Flag: Boolean; MinWidth, DecPlaces: Integer);
begin
if Flag then WriteStringF(F, P, 'TRUE', MinWidth, DecPlaces) else WriteStringF(F, P, 'FALSE', MinWidth, DecPlaces);
end;




procedure XDP_WriteNewLine(var F: file; P: PStream);
begin
WriteCh(F, P, #13);  WriteCh(F, P, #10);
end;




procedure XDP_ReadRec(var F: file; P: PStream; var Buf; Len: Integer);
var
  LenRead: Integer;
begin
BlockRead(F, Buf, Len, LenRead);
end;




procedure XDP_ReadCh(var F: file; P: PStream; var ch: Char);
var
  LastError,
  Len: Integer;
  Dest: PChar;
  FileRecPtr: PFileRec;
  
begin
FileRecPtr := PFileRec(@F);
   
if P <> nil then                                       // String stream input
  begin                      
  Dest := PChar(Integer(P^.Data) + P^.Index);
  ch := Dest^;
  Inc(P^.Index);
  end
else if FileRecPtr^.FileHandle = StdInputHandle then       // Console input
  begin
  if StdInputBufferPos > Length(StdInputBuffer) then
    begin
    BlockRead(F, StdInputBuffer, SizeOf(StdInputBuffer) - 1, Len);
    StdInputBuffer[Len] := #0;   // Replace LF with end-of-string
    StdInputBufferPos := 1;
    end;
  
  ch := StdInputBuffer[StdInputBufferPos];
  Inc(StdInputBufferPos);
  end 
else                                                   // File input
  begin
  BlockRead(F, ch, 1, Len);
  if ch = #10 then BlockRead(F, ch, 1, Len);
// this is where we can check for EOF
  LastError := GetLastError;
  if lasterror<>0 then WriteLN('RCH GLE=',LastError);
  if Len <> 1 then ch := #0;
  end;

LastReadChar := ch;                                    // Required by ReadNewLine
end;

procedure XDP_ReadInt(var F: file; P: PStream; var Number: Integer);
var
  Ch: Char;
  Negative: Boolean;

begin
Number := 0;

// Skip spaces
repeat ReadCh(F, P, Ch) until (Ch = #0) or (Ch > ' ');

// Read sign  
Negative := FALSE; 
if Ch = '+' then
  ReadCh(F, P, Ch)
else if Ch = '-' then   
  begin
  Negative := TRUE;
  ReadCh(F, P, Ch);
  end;

// Read number
while (Ch >= '0') and (Ch <= '9') do
  begin
  Number := Number * 10 + ShortInt(Ch) - ShortInt('0');
  ReadCh(F, P, Ch);
  end; 

if Negative then Number := -Number;
end;




procedure XDP_ReadSmallInt(var F: file; P: PStream; var Number: SmallInt);
var
  IntNumber: Integer;
begin
ReadInt(F, P, IntNumber);
Number := IntNumber;
end;
  



procedure XDP_ReadShortInt(var F: file; P: PStream; var Number: ShortInt);
var
  IntNumber: Integer;
begin
ReadInt(F, P, IntNumber);
Number := IntNumber;
end;




procedure XDP_ReadWord(var F: file; P: PStream; var Number: Word);
var
  IntNumber: Integer;
begin
ReadInt(F, P, IntNumber);
Number := IntNumber;
end;



procedure XDP_ReadByte(var F: file; P: PStream; var Number: Byte);
var
  IntNumber: Integer;
begin
ReadInt(F, P, IntNumber);
Number := IntNumber;
end;




procedure XDP_ReadBoolean(var F: file; P: PStream; var Value: Boolean);
var
  IntNumber: Integer;
begin
ReadInt(F, P, IntNumber);
Value := IntNumber <> 0;
end;




procedure XDP_ReadReal(var F: file; P: PStream; var Number: Real);
var
  Ch: Char;
  Negative, ExponNegative: Boolean;
  Weight: Real;
  Expon: Integer;
 
begin
Number := 0;
Expon := 0;

// Skip spaces
repeat ReadCh(F, P, Ch) until (Ch = #0) or (Ch > ' ');

// Read sign
Negative := FALSE;
if Ch = '+' then
  ReadCh(F, P, Ch)
else if Ch = '-' then   
  begin
  Negative := TRUE;
  ReadCh(F, P, Ch);
  end;

// Read integer part
while (Ch >= '0') and (Ch <= '9') do
  begin
  Number := Number * 10 + ShortInt(Ch) - ShortInt('0');
  ReadCh(F, P, Ch);
  end;

if Ch = DecimalSeparator then        // Fractional part found
  begin
  ReadCh(F, P, Ch);

  // Read fractional part
  Weight := 0.1;
  while (Ch >= '0') and (Ch <= '9') do
    begin
    Number := Number + Weight * (ShortInt(Ch) - ShortInt('0'));
    Weight := Weight / 10;
    ReadCh(F, P, Ch);
    end;
  end;

if (Ch = 'E') or (Ch = 'e') then     // Exponent found
  begin
  // Read exponent sign
  ExponNegative := FALSE;
  ReadCh(F, P, Ch);
  if Ch = '+' then
    ReadCh(F, P, Ch)
  else if Ch = '-' then   
    begin
    ExponNegative := TRUE;
    ReadCh(F, P, Ch);
    end;

  // Read exponent
  while (Ch >= '0') and (Ch <= '9') do
    begin
    Expon := Expon * 10 + ShortInt(Ch) - ShortInt('0');
    ReadCh(F, P, Ch);
    end;

  if ExponNegative then Expon := -Expon;
  end;
     
if Expon <> 0 then Number := Number * exp(Expon * ln(10));
if Negative then Number := -Number;
end;




procedure XDP_ReadSingle(var F: file; P: PStream; var Number: Single);
var
  RealNumber: Real;
begin
ReadReal(F, P, RealNumber);
Number := RealNumber;
end;




procedure XDP_ReadString(var F: file; P: PStream; var s: string);
var
  i: Integer;
  Ch: Char;
begin
i := 1;
ReadCh(F, P, Ch);

while Ch <> #13 do
  begin
  s[i] := Ch;
  Inc(i);
  ReadCh(F, P, Ch);
  end;

s[i] := #0;
end;




procedure XDP_ReadNewLine(var F: file; P: PStream);
var
  Ch: Char;
begin
Ch := LastReadChar;
while not EOF(F) and (Ch <> #13) do ReadCh(F, P, Ch);
LastReadChar := #0;
end;




// Conversion routines


procedure Val(const s: string; var Number: Real; var Code: Integer);
var
  Stream: TStream;
begin
Stream.Data := PChar(@s);
Stream.Index := 0;

//ReadReal(StdInputFile, @Stream, Number);
ReadReal(Input, @Stream, Number);

if Stream.Index - 1 <> Length(s) then Code := Stream.Index else Code := 0;
end;




procedure Str(Number: Real; var s: string; MinWidth: Integer = 0; DecPlaces: Integer = 0);
var
  Stream: TStream;
begin
Stream.Data := PChar(@s);
Stream.Index := 0;

//WriteReal(StdOutputFile, @Stream, Number, MinWidth, DecPlaces);
WriteReal(Output, @Stream, Number, MinWidth, DecPlaces);
s[Stream.Index + 1] := #0;
end;




procedure IVal(const s: string; var Number: Integer; var Code: Integer);
var
  Stream: TStream;
begin
Stream.Data := PChar(@s);
Stream.Index := 0;

//ReadInt(StdInputFile, @Stream, Number);
ReadInt(Input, @Stream, Number);

if Stream.Index - 1 <> Length(s) then Code := Stream.Index else Code := 0;
end;




procedure IStr(Number: Integer; var s: string);
var
  Stream: TStream;
begin
Stream.Data := PChar(@s);
Stream.Index := 0;

//WriteInt(StdOutputFile, @Stream, Number);
WriteInt(Output, @Stream, Number);
s[Stream.Index + 1] := #0;
end;




procedure PtrStr(Number: Integer; var s: string);
var
  Stream: TStream;
begin
Stream.Data := PChar(@s);
Stream.Index := 0;

//WritePointer(StdOutputFile, @Stream, Number);
WritePointer(Output, @Stream, Number);
s[Stream.Index + 1] := #0;
end;



// to allow for EBCDIC OR ASCII this uses smaller blocks of chars
function UpCase(ch: Char): Char;
begin
    if (ch IN ['a'..'i', 'j'..'r', 's'..'z']) then
  Result := Chr(Ord(ch) - Ord('a') + Ord('A'))
else
  Result := ch;
end; 


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
      Result := S;
  end;



// Set manipulation routines


procedure XDP_InitSet(var SetStorage: TSetStorage);
begin
FillChar(SetStorage, SizeOf(SetStorage), #0);
end;




procedure XDP_AddToSet(var SetStorage: TSetStorage; FromElement, ToElement: Integer);
var
  Element: Integer;
  ElementPtr: ^Integer;
begin
ElementPtr := @SetStorage[FromElement shr 5];
ElementPtr^ := ElementPtr^ or (1 shl (FromElement and 31));

if ToElement > FromElement then
  for Element := FromElement + 1 to ToElement do
    begin
    ElementPtr := @SetStorage[Element shr 5];
    ElementPtr^ := ElementPtr^ or (1 shl (Element and 31));
    end;
end;




function InSet(Element: Integer; var SetStorage: TSetStorage): Boolean;
begin
Result := SetStorage[Element shr 5] and (1 shl (Element and 31)) <> 0;  
end;




procedure SetUnion(const SetStorage1, SetStorage2: TSetStorage; var SetStorage: TSetStorage);
var
  i: Integer;
begin
for i := 0 to MaxSetIndex do
  SetStorage[i] := SetStorage1[i] or SetStorage2[i];
end;




procedure SetDifference(const SetStorage1, SetStorage2: TSetStorage; var SetStorage: TSetStorage);
var
  i: Integer;
begin
for i := 0 to MaxSetIndex do
  SetStorage[i] := SetStorage1[i] and not SetStorage2[i];
end; 




procedure SetIntersection(const SetStorage1, SetStorage2: TSetStorage; var SetStorage: TSetStorage);
var
  i: Integer;
begin
for i := 0 to MaxSetIndex do
  SetStorage[i] := SetStorage1[i] and SetStorage2[i];
end; 




function CompareSets(const SetStorage1, SetStorage2: TSetStorage): Integer;
var
  i: Integer;
begin
Result := 0;
for i := 0 to MaxSetIndex do
  if SetStorage1[i] <> SetStorage2[i] then
    begin
    Result := 1;
    Exit;
    end;
end; 




function TestSubset(const SetStorage1, SetStorage2: TSetStorage): Integer;
var
  IntersectionStorage: TSetStorage;
begin
SetIntersection(SetStorage1, SetStorage2, IntersectionStorage);
if CompareSets(SetStorage1, IntersectionStorage) = 0 then Result := -1 else Result := 1;
end;




function TestSuperset(const SetStorage1, SetStorage2: TSetStorage): Integer;
var
  IntersectionStorage: TSetStorage;
begin
SetIntersection(SetStorage1, SetStorage2, IntersectionStorage);
if CompareSets(SetStorage2, IntersectionStorage) = 0 then Result := 1 else Result := -1;
end; 


Procedure XDP_WriteLnErrmsg;
begin
    Writeln;  //(STDERR);
    ErrMsgLen := 0;
end;


Procedure XDP_WriteErrmsg(Msg:String);
begin
    if ErrMsgLen >60 then
    begin
          XDP_WriteLnErrmsg;
          write({STDERR,}'$$+ ');
          ErrMsgLen := 4;
     end;
    Write({STDERR,}MSG);
    ErrmsgLen := ErrmsgLen+Length(MSG);
end;

procedure XDP_StartErrmsg(Msg:String);
begin
    XDP_WriteLnErrmsg;
    write({STDERR,}'$$  '+Msg);
    ErrMsgLen := 4;
end;

procedure XDP_NilPointer(Name, Proc, FN:String; isProc:boolean; Line:Integer; Address:Integer);
Var
    MSG: String;

begin
    XDP_StartErrmsg('System error: user pointer "'+Name+'" ');
    XDP_WriteErrmsg('referenced NIL in ');
    if proc='' then
        MSG :='MAIN Program'
    else
    begin
        if isProc then
            MSG := 'Procedure '
        else
            msg := 'Function ';
        MSG := MSG + proc;
   end;

   XDP_WriteErrmsg(MSG);
   XDP_WriteErrmsg('on line '+Radix(line,10)+' ');
   XDP_WriteErrmsg('of file '+ fN+ ' ');
   XDP_WriteErrmsg('at address $'+Radix(Address,16));
   writeln; //(STDERR);
   halt(9999);
end;

procedure XDP_AddUnit(UnitNumber,BeginLine,EndLine:Integer; UnitName:String);
begin
    UnitList[UnitNumber].LineStart:=BeginLine;
    UnitList[UnitNumber].LineEnd:=EndLine;
    New(UnitList[UnitNumber].NameP);
    UnitList[UnitNumber].NameP^ := UnitName;
end;

// Standard System function
Function Odd(I:Integer):Boolean;
begin
    Result := (I and $00000001) = 1;
end;


// Historical


procedure InitSystem;                                                                            begin  XDP_Initsystem; end;

procedure InitSet(var SetStorage: TSetStorage);                                                  begin  XDP_InitSet( SetStorage); end;
procedure ReadBoolean(var F: file; P: PStream; var Value: Boolean);                              begin  XDP_ReadBoolean( F, P, Value); end;
procedure ReadByte(var F: file; P: PStream; var Number: Byte);                                   begin  XDP_ReadByte( F, P, Number); end;
procedure ReadCh(var F: file; P: PStream; var ch: Char);                                         begin  XDP_ReadCh( F,  P, ch); end;
procedure ReadInt(var F: file; P: PStream; var Number: Integer);                                 begin  XDP_ReadInt( F, P, Number); end;
procedure ReadNewLine(var F: file; P: PStream);                                                  BEGIN  XDP_ReadNewLine( F, P);  END;
procedure ReadReal(var F: file; P: PStream; var Number: Real);                                   begin  XDP_ReadReal( F, P, Number); end;
procedure ReadRec(var F: file; P: PStream; var Buf; Len: Integer);                               BEGIN  XDP_ReadRec( F, P, Buf, Len); END;
procedure ReadShortInt(var F: file; P: PStream; var Number: ShortInt);                           BEGIN  XDP_ReadShortInt( F, P, Number); END;
procedure ReadSingle(var F: file; P: PStream; var Number: Single);                               begin  XDP_ReadSingle( F, P, Number);  end;
procedure ReadSmallInt(var F: file; P: PStream; var Number: SmallInt);                           begin  XDP_ReadSmallInt( F, P, Number); end;
procedure ReadString(var F: file; P: PStream; var s: string);                                    begin  XDP_ReadString( F, P, s); end;
procedure ReadWord(var F: file; P: PStream; var Number: Word);                                   BEGIN  XDP_ReadWord( F, P, Number);  END;
procedure WriteBooleanF(var F: file; P: PStream; Flag: Boolean; MinWidth, DecPlaces: Integer);   BEGIN  XDP_WriteBooleanF( F, P, Flag, MinWidth, DecPlaces); END;
procedure WriteIntF(var F: file; P: PStream; Number: Integer; MinWidth, DecPlaces: Integer);     BEGIN  XDP_WriteIntF( F, P, Number, MinWidth, DecPlaces); END;
procedure WriteNewLine(var F: file; P: PStream);                                                 begin  XDP_WriteNewLine( F, P); end;
procedure WriteRealF(var F: file; P: PStream; Number: Real; MinWidth, DecPlaces: Integer);       begin  XDP_WriteRealF( F, P, Number, MinWidth, DecPlaces); end;
procedure WriteRec(var F: file; P: PStream; var Buf; Len: Integer);                              BEGIN  XDP_WriteRec( F, P, Buf, Len); END;
procedure WritePointerF(var F: file; P: PStream; Number: Integer; MinWidth, DecPlaces: Integer); BEGIN  XDP_WritePointerF( F, P, Number, MinWidth, DecPlaces); END;
procedure WriteStringF(var F: file; P: PStream; const S: string; MinWidth, DecPlaces: Integer);  BEGIN  XDP_WriteStringF( F, P, S, MinWidth, DecPlaces); END;
procedure AddToSet(var SetStorage: TSetStorage; FromElement, ToElement: Integer);                begin  XDP_AddToSet(SetStorage, FromElement, ToElement); end;

end.
