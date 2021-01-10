// XD Pascal for Windows (XPDW) - a 32-bit compiler
// Copyright (c) 2009-2010, 2019-2020, Vasiliy Tereshkov
// Copyright 2020 Paul Robnson

// Latest upgrade by Paul Robinson: New Years Eve; Thursday, December 31, 2020

// VERSION 0.15    {.0}

// Covert the stored code in memory into a windoes PE executable file

{$I-}
{$H-}

unit Linker;


interface


uses  Common, Error, CodeGen;


procedure InitializeLinker;
procedure SetProgramEntryPoint;
function AddImportFunc(const ImportLibName, ImportFuncName: TString): LongInt;
procedure LinkAndWriteProgram(const ExeName: TString);



implementation
type
  TDOSStub = array [0..127] of Byte;

const
  // This translates rougly to "This program cannot run in DOS Mode"
  // Note: While some old programs "expect" this to be 128 bytes, it
  // can be longer, which was intended to allow a developer to package
  // both a DOS mode and Windows mode app in the same executable
  // An EXE reader should use bytes 60-64 ($3C) to determine
  // where the PE header should be
  DOSStub: TDOSStub =
    (
    $4D, $5A,  // signature: array [1..2] of char =  Start of MSDOS "MZ" header; 64 bytes
    $90, $00,  // lastsize: SHORT
    $03, $00,  // nblocks : SHORT
    $00, $00,  // nreloc  : SHORT
    $04, $00,  // hdrsize : SHORT
    $00, $00,  // minalloc: SHORT
    $FF, $FF,  // maxalloc: SHORT
    $00, $00,  // SS      : SHORT - Initial SS reg value
    $B8, $00,  // SP      : SHORT - Initial Sp reg value
    $00, $00,  // checksum: SHORT
    $00, $00,  // IP      : SHORT - initial IP register value
    $00, $00,  // CS      : SHORT - initial CS register value
    $40, $00,  // relocpos: SHORT
    $00, $00,  // noverlay: SHORT
    $00, $00,  $00, $00,  $00, $00,
    $00, $00,  // reserved1: ARRAY [1..4] OF SHORT
    $00, $00,  // OEM_id  : SHORT
    $00, $00,  // OEM_info: SHORT
    $00, $00, $00, $00, $00, $00,
    $00, $00, $00, $00, $00, $00,
    $00, $00, $00, $00, $00, $00,
    $00, $00, // reserved2: ARRAY [1..10] OF SHORT
    $80, $00, $00, $00, // PEheader_address LONG - in this case, byte 128
                        // ;      actual MSDOS stub program
    $0E,                //   push CS
    $1F,                //   pop  DS
    $BA, $0E, $00,      //   mov  DX,message
    $B4, $09,           //   mov  AH,$09    - MSDOS write to terminal argument
    $CD, $21,           //   int  $21       - Call MSDOS
    $B8, $01, $4C,      //   mov  AX, $4C01 - MSDOS terminate program argument
    $CD, $21,           //   int  $21       - Call MSDOS
    $54, $68, $69, $73, $20,  //message db "This program cannot be run in DOS mode."
    $70, $72, $6F, $67, $72, $61, $6D, $20, //program
    $63, $61, $6E, $6E, $6F, $74, $20,      //cannot
    $62, $65, $20,                          //be
    $72, $75, $6E, $20,                     //run
    $69, $6E, $20,                          //in
    $44, $4F, $53, $20,                     //DOS
    $6D, $6F, $64, $65, $2E,                //mode.
    $0D, $0D, $0A, $24,  //        db 0x0d, 0x0d, 0x0a, '$'
    $00, $00, $00, $00, $00, $00, $00       // filler to align to next segment
    );                                      //PEheader - starts next

  IMGBASE           = $400000;
  SECTALIGN         = $1000;
  FILEALIGN         = $200;
  
  MAXIMPORTLIBS     = 100;
  MAXIMPORTS        = 2000;


  type
  TPEHeader = packed record
    PE: array [0..3] of TCharacter;     // "PE"
    Machine: Word;                      // $014C for 386
    NumberOfSections: Word;
    TimeDateStamp: LongInt;
    PointerToSymbolTable: LongInt;
    NumberOfSymbols: LongInt;
    SizeOfOptionalHeader: Word;
    Characteristics: Word;
  end;


  TPEOptionalHeader = packed record
    Magic: Word;
    MajorLinkerVersion: Byte;
    MinorLinkerVersion: Byte;
    SizeOfCode: LongInt;
    SizeOfInitializedData: LongInt;
    SizeOfUninitializedData: LongInt;
    AddressOfEntryPoint: LongInt;
    BaseOfCode: LongInt;
    BaseOfData: LongInt;
    ImageBase: LongInt;
    SectionAlignment: LongInt;
    FileAlignment: LongInt;
    MajorOperatingSystemVersion: Word;
    MinorOperatingSystemVersion: Word;
    MajorImageVersion: Word;
    MinorImageVersion: Word;
    MajorSubsystemVersion: Word;
    MinorSubsystemVersion: Word;
    Win32VersionValue: LongInt;
    SizeOfImage: LongInt;
    SizeOfHeaders: LongInt;
    CheckSum: LongInt;
    Subsystem: Word;
    DllCharacteristics: Word;
    SizeOfStackReserve: LongInt;
    SizeOfStackCommit: LongInt;
    SizeOfHeapReserve: LongInt;
    SizeOfHeapCommit: LongInt;
    LoaderFlags: LongInt;
    NumberOfRvaAndSizes: LongInt;
  end;
  
  
  TDataDirectory = packed record
    VirtualAddress: LongInt;
    Size: LongInt;
  end;  


  TPESectionHeader = packed record
    Name: array [0..7] of TCharacter;
    VirtualSize: LongInt;
    VirtualAddress: LongInt;
    SizeOfRawData: LongInt;
    PointerToRawData: LongInt;
    PointerToRelocations: LongInt;
    PointerToLinenumbers: LongInt;
    NumberOfRelocations: Word;
    NumberOfLinenumbers: Word;
    Characteristics: LongInt;
  end;
  
  
  THeaders = packed record
    Stub: TDOSStub;
    PEHeader: TPEHeader;
    PEOptionalHeader: TPEOptionalHeader;
    DataDirectories: array [0..15] of TDataDirectory;
    CodeSectionHeader, DataSectionHeader, BSSSectionHeader, ImportSectionHeader: TPESectionHeader;	
  end;
  
  
  TImportLibName = array [0..15] of TCharacter;
  TImportFuncName = array [0..31] of TCharacter;


  TImportDirectoryTableEntry = packed record
    Characteristics: LongInt;
    TimeDateStamp: LongInt;
    ForwarderChain: LongInt;
    Name: LongInt;
    FirstThunk: LongInt;
  end; 


  TImportNameTableEntry = packed record
    Hint: Word;
    Name: TImportFuncName;
  end;
  
  
  TImport = record
    LibName, FuncName: TString;
  end; 


  TImportSectionData = record
    DirectoryTable: array [1..MAXIMPORTLIBS + 1] of TImportDirectoryTableEntry;
    LibraryNames: array [1..MAXIMPORTLIBS] of TImportLibName;
    LookupTable: array [1..MAXIMPORTS + MAXIMPORTLIBS] of LongInt;
    NameTable: array [1..MAXIMPORTS] of TImportNameTableEntry;   
    NumImports, NumImportLibs: Integer;
  end;


var
  Headers: THeaders;
  Import: array [1..MAXIMPORTS] of TImport;
  ImportSectionData: TImportSectionData;
  LastImportLibName: TString;
  ProgramEntryPoint: LongInt;


 

 
procedure Pad(var f: file; Size, Alignment: Integer);
var
  i: Integer;
  b: Byte;
begin
b := 0;
for i := 0 to Align(Size, Alignment) - Size - 1 do
  BlockWrite(f, b, 1);
end;



  
procedure FillHeaders(CodeSize, InitializedDataSize, UninitializedDataSize, ImportSize: Integer);
const
  IMAGE_FILE_MACHINE_I386           = $14C;

  IMAGE_FILE_RELOCS_STRIPPED        = $0001;
  IMAGE_FILE_EXECUTABLE_IMAGE       = $0002;
  IMAGE_FILE_32BIT_MACHINE          = $0100;
  
  IMAGE_SCN_CNT_CODE                = $00000020;
  IMAGE_SCN_CNT_INITIALIZED_DATA    = $00000040;
  IMAGE_SCN_CNT_UNINITIALIZED_DATA  = $00000080;  
  IMAGE_SCN_MEM_EXECUTE             = $20000000;
  IMAGE_SCN_MEM_READ                = $40000000;
  IMAGE_SCN_MEM_WRITE               = $80000000;

begin
FillChar(Headers, SizeOf(Headers), #0);

with Headers do
  begin  
  Stub := DOSStub;  
      
  with PEHeader do
    begin  
    PE[0]                         := 'P';  
    PE[1]                         := 'E';
    Machine                       := IMAGE_FILE_MACHINE_I386;
    NumberOfSections              := 4;
    SizeOfOptionalHeader          := SizeOf(PEOptionalHeader) + SizeOf(DataDirectories);
    Characteristics               := IMAGE_FILE_RELOCS_STRIPPED or IMAGE_FILE_EXECUTABLE_IMAGE or IMAGE_FILE_32BIT_MACHINE;
    end;

  with PEOptionalHeader do
    begin 
    Magic                         := $10B;   // Normal executable; $29B for PE32+                                             // PE32
    MajorLinkerVersion            := 3; 
    SizeOfCode                    := CodeSize;
    SizeOfInitializedData         := InitializedDataSize;
    SizeOfUninitializedData       := UninitializedDataSize;    
    AddressOfEntryPoint           := Align(SizeOf(Headers), SECTALIGN) + ProgramEntryPoint;
    BaseOfCode                    := Align(SizeOf(Headers), SECTALIGN);
    BaseOfData                    := Align(SizeOf(Headers), SECTALIGN) + Align(CodeSize, SECTALIGN);
    ImageBase                     := IMGBASE;
    SectionAlignment              := SECTALIGN;
    FileAlignment                 := FILEALIGN;
    MajorOperatingSystemVersion   := 4;
    MajorSubsystemVersion         := 4;
    SizeOfImage                   := Align(SizeOf(Headers), SECTALIGN) + Align(CodeSize, SECTALIGN) + Align(InitializedDataSize, SECTALIGN) + Align(UninitializedDataSize, SECTALIGN) + Align(ImportSize, SECTALIGN);
    SizeOfHeaders                 := Align(SizeOf(Headers), FILEALIGN);
    Subsystem                     := 2 + Ord(IsConsoleProgram);    // 2 for GUI, 3 for console                            // Win32 GUI/console
    SizeOfStackReserve            := $1000000;
    SizeOfStackCommit             := $100000;
    SizeOfHeapReserve             := $1000000;
    SizeOfHeapCommit              := $100000;
    NumberOfRvaAndSizes           := 16;
    end;

  with DataDirectories[1] do                                                              // Import directory
    begin
    VirtualAddress                := Align(SizeOf(Headers), SECTALIGN) + Align(CodeSize, SECTALIGN) + Align(InitializedDataSize, SECTALIGN) + Align(UninitializedDataSize, SECTALIGN);
    Size                          := ImportSize;
    end;
    
  with CodeSectionHeader do
    begin
    Name[0]                       := '.';
    Name[1]                       := 't';
    Name[2]                       := 'e';
    Name[3]                       := 'x';
    Name[4]                       := 't';
    VirtualSize                   := CodeSize;
    VirtualAddress                := Align(SizeOf(Headers), SECTALIGN);
    SizeOfRawData                 := Align(CodeSize, FILEALIGN);
    PointerToRawData              := Align(SizeOf(Headers), FILEALIGN);
    Characteristics               := LongInt(IMAGE_SCN_CNT_CODE or IMAGE_SCN_MEM_READ or IMAGE_SCN_MEM_EXECUTE);
    end;
    
  with DataSectionHeader do
    begin
    Name[0]                       := '.';
    Name[1]                       := 'd';
    Name[2]                       := 'a';
    Name[3]                       := 't';
    Name[4]                       := 'a';
    VirtualSize                   := InitializedDataSize;
    VirtualAddress                := Align(SizeOf(Headers), SECTALIGN) + Align(CodeSize, SECTALIGN);
    SizeOfRawData                 := Align(InitializedDataSize, FILEALIGN);
    PointerToRawData              := Align(SizeOf(Headers), FILEALIGN) + Align(CodeSize, FILEALIGN);
    Characteristics               := LongInt(IMAGE_SCN_CNT_INITIALIZED_DATA or IMAGE_SCN_MEM_READ or IMAGE_SCN_MEM_WRITE);
    end;
    
  with BSSSectionHeader do
    begin
    Name[0]                       := '.';
    Name[1]                       := 'b';
    Name[2]                       := 's';
    Name[3]                       := 's';
    VirtualSize                   := UninitializedDataSize;
    VirtualAddress                := Align(SizeOf(Headers), SECTALIGN) + Align(CodeSize, SECTALIGN) + Align(InitializedDataSize, SECTALIGN);
    SizeOfRawData                 := 0;
    PointerToRawData              := Align(SizeOf(Headers), FILEALIGN) + Align(CodeSize, FILEALIGN) + Align(InitializedDataSize, FILEALIGN);
    Characteristics               := LongInt(IMAGE_SCN_CNT_UNINITIALIZED_DATA or IMAGE_SCN_MEM_READ or IMAGE_SCN_MEM_WRITE);
    end;    

  with ImportSectionHeader do
    begin
    Name[0]                       := '.';
    Name[1]                       := 'i';
    Name[2]                       := 'd';
    Name[3]                       := 'a';
    Name[4]                       := 't';
    Name[5]                       := 'a';
    VirtualSize                   := ImportSize;
    VirtualAddress                := Align(SizeOf(Headers), SECTALIGN) + Align(CodeSize, SECTALIGN) + Align(InitializedDataSize, SECTALIGN) + Align(UninitializedDataSize, SECTALIGN);
    SizeOfRawData                 := Align(ImportSize, FILEALIGN);
    PointerToRawData              := Align(SizeOf(Headers), FILEALIGN) + Align(CodeSize, FILEALIGN) + Align(InitializedDataSize, FILEALIGN);
    Characteristics               := LongInt(IMAGE_SCN_CNT_INITIALIZED_DATA or IMAGE_SCN_MEM_READ or IMAGE_SCN_MEM_WRITE);
    end;

  end;
  
end;




procedure InitializeLinker;
begin
FillChar(Import, SizeOf(Import), #0);
FillChar(ImportSectionData, SizeOf(ImportSectionData), #0);
LastImportLibName := '';
ProgramEntryPoint := 0;
end;




procedure SetProgramEntryPoint;
begin
if ProgramEntryPoint <> 0 then
  begin
      Fatal('Duplicate program entry point');
      Exit;
  end;

ProgramEntryPoint := GetCodeSize;
end;


    

function AddImportFunc(const ImportLibName, ImportFuncName: TString): LongInt;
begin
with ImportSectionData do
  begin  
  Inc(NumImports);
  if NumImports > MAXIMPORTS then
    begin
    Fatal('Maximum number of import functions exceeded');
    Exit;
    end;

  Import[NumImports].LibName := ImportLibName;
  Import[NumImports].FuncName := ImportFuncName;
  
  if ImportLibName <> LastImportLibName then
    begin
    Inc(NumImportLibs);
    if NumImportLibs > MAXIMPORTLIBS then
      begin
          Fatal('Maximum number of import libraries exceeded');
          Exit;
      end;
    LastImportLibName := ImportLibName;
    end;
    
  Result := (NumImports - 1 + NumImportLibs - 1) * SizeOf(LongInt);  // Relocatable  
  end;
end;




procedure FillImportSection(var ImportSize, LookupTableOffset: Integer);
var
  ImportIndex, ImportLibIndex, LookupIndex: Integer;
  LibraryNamesOffset, NameTableOffset: Integer;

begin
with ImportSectionData do
  begin
  LibraryNamesOffset :=                      SizeOf(DirectoryTable[1]) * (NumImportLibs + 1);  
  LookupTableOffset  := LibraryNamesOffset + SizeOf(LibraryNames[1])   *  NumImportLibs;
  NameTableOffset    := LookupTableOffset  + SizeOf(LookupTable[1])    * (NumImports + NumImportLibs);
  ImportSize         := NameTableOffset    + SizeOf(NameTable[1])      *  NumImports;  
  
  LastImportLibName := '';
  ImportLibIndex := 0;
  LookupIndex := 0;
    
  for ImportIndex := 1 to NumImports do
    begin   
    // Add new import library
    if (ImportLibIndex = 0) or (Import[ImportIndex].LibName <> LastImportLibName) then
      begin    
      if ImportLibIndex <> 0 then Inc(LookupIndex);  // Add null entry before the first thunk of a new library    

      Inc(ImportLibIndex);

      DirectoryTable[ImportLibIndex].Name       := LibraryNamesOffset + SizeOf(LibraryNames[1]) * (ImportLibIndex - 1);                                                                             
      DirectoryTable[ImportLibIndex].FirstThunk := LookupTableOffset  + SizeOf(LookupTable[1])  *  LookupIndex;

      Move(Import[ImportIndex].LibName[1], LibraryNames[ImportLibIndex], Length(Import[ImportIndex].LibName));

      LastImportLibName := Import[ImportIndex].LibName;   
      end; // if

    // Add new import function
    Inc(LookupIndex);
    if LookupIndex > MAXIMPORTS + MAXIMPORTLIBS then
      Begin
          Fatal('Maximum number of lookup entries exceeded');
          Exit;
      end;

    LookupTable[LookupIndex] := NameTableOffset + SizeOf(NameTable[1]) * (ImportIndex - 1);                                              

    Move(Import[ImportIndex].FuncName[1], NameTable[ImportIndex].Name, Length(Import[ImportIndex].FuncName));
    end;
  end; 
end;




procedure FixupImportSection(VirtualAddress: LongInt);
var
  i: Integer;
begin
with ImportSectionData do
  begin
  for i := 1 to NumImportLibs do
    with DirectoryTable[i] do
      begin
      Name := Name + VirtualAddress;
      FirstThunk := FirstThunk + VirtualAddress;
      end;
      
  for i := 1 to NumImports + NumImportLibs do
    if LookupTable[i] <> 0 then 
      LookupTable[i] := LookupTable[i] + VirtualAddress;
  end;  
end;



// Called by main program to write tthe code to disk-
procedure LinkAndWriteProgram(const ExeName: TString);
var
  OutFile: TOutFile;
  CodeSize, ImportSize, LookupTableOffset: Integer;
  
begin
if ProgramEntryPoint = 0 then
     Catastrophic('Program entry point not found');

CodeSize := GetCodeSize;

FillImportSection(ImportSize, LookupTableOffset);
FillHeaders(CodeSize, InitializedGlobalDataSize, UninitializedGlobalDataSize, ImportSize);

Relocate(IMGBASE + Headers.CodeSectionHeader.VirtualAddress,
         IMGBASE + Headers.DataSectionHeader.VirtualAddress,
         IMGBASE + Headers.BSSSectionHeader.VirtualAddress,
         IMGBASE + Headers.ImportSectionHeader.VirtualAddress + LookupTableOffset);

FixupImportSection(Headers.ImportSectionHeader.VirtualAddress);

if errorcount <>0 then exit; // Don't create file if errors

// Write output file
Assign(OutFile, TGenericString(ExeName));
Rewrite(OutFile, 1);

if IOResult <> 0 then
     Catastrophic('Unable to open output file ' + ExeName);  {fatal}

BlockWrite(OutFile, Headers, SizeOf(Headers));
Pad(OutFile, SizeOf(Headers), FILEALIGN);

BlockWrite(OutFile, Code, CodeSize);
Pad(OutFile, CodeSize, FILEALIGN);

BlockWrite(OutFile, InitializedGlobalData, InitializedGlobalDataSize);
Pad(OutFile, InitializedGlobalDataSize, FILEALIGN);

with ImportSectionData do
  begin
  BlockWrite(OutFile, DirectoryTable, SizeOf(DirectoryTable[1]) * (NumImportLibs + 1));
  BlockWrite(OutFile, LibraryNames,   SizeOf(LibraryNames[1])   *  NumImportLibs);
  BlockWrite(OutFile, LookupTable,    SizeOf(LookupTable[1])    * (NumImports + NumImportLibs));
  BlockWrite(OutFile, NameTable,      SizeOf(NameTable[1])      *  NumImports);
  end;  
Pad(OutFile, ImportSize, FILEALIGN);

Close(OutFile); 
end;


end. 

