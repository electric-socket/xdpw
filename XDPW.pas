// XD Pascal for Windows (XPDW) - a 32-bit compiler
// Copyright (c) 2009-2010, 2019-2020, Vasiliy Tereshkov

// Latest upgrade by Paul Robinson:  Saturday, October 31, 2020

// VERSION 0.14.1

// The Main program of the compiler.
{$show tokens}
{$APPTYPE CONSOLE}
{$I-}
{$H-}


program XDPW;
uses SysUtils , Common, Scanner, Parser, CodeGen, Linker, Listing ;

 {(* function CreateProcessA(lpApplicationName: LPCSTR;
         lpCommandLine: LPCSTR;
         lpProcessAttributes,
         lpThreadAttributes: PSecurityAttributes;
         bInheritHandles: BOOL;
         dwCreationFlags: DWORD;
         lpEnvironment: Pointer;
         lpCurrentDirectory: LPCSTR;
         const lpStartupInfo: TStartupInfoA;
         var lpProcessInformation: TProcessInformation): BOOL; external 'kernel32' // name 'CreateProcessA';
         *) }

procedure SplitPath(const Path: TString; var Folder, Name, Ext: TString);
var
  DotPos, SlashPos, i: Integer;
begin
Folder := '';  
Name := Path;  
Ext := '';

DotPos := 0;  
SlashPos := 0;

for i := Length(Path) downto 1 do
  if (Path[i] = '.') and (DotPos = 0) then 
    DotPos := i
  else if (Path[i] = '\') and (SlashPos = 0) then
    SlashPos := i; 

if DotPos > 0 then
  begin
  Name := Copy(Path, 1, DotPos - 1);
  Ext  := Copy(Path, DotPos, Length(Path) - DotPos + 1);
  end;
  
if SlashPos > 0 then
  begin
  Folder := Copy(Path, 1, SlashPos);
  Name   := Copy(Path, SlashPos + 1, Length(Name) - SlashPos);
  end;  

end;



procedure NoticeProc(ClassInstance: Pointer; const Msg: TString);
begin
WriteLn(Msg);  
end;




procedure WarningProc(ClassInstance: Pointer; const Msg: TString);
begin
if NumUnits >= 1 then
  Notice(ScannerFileName + ' (' + IntToStr(ScannerLine) +
        ':' + IntToStr(ScannerPos) +  ') Warning: ' + Msg)
else
  Notice('Warning: ' + Msg);  
end;



// Actual error message generated here
procedure ErrorProc(ClassInstance: Pointer; const Msg: TString);
begin
if NumUnits >= 1 then
   Notice(ScannerFileName + ' (' + IntToStr(ScannerLine) +
          ':' + IntToStr(ScannerPos)  + ') Error: ' + Msg)
else
  Notice('Error: ' + Msg);  

repeat FinalizeScanner until not RestoreScanner;
FinalizeCommon;
Halt(1);
end;


Const
    Months: array[1..12] of string[9]=
       ('January','February','March',   'April',   'May','     June',
        'July',    'August', 'September','October','November', 'Decenber');
    Days: Array[0..6] of string[9]=
        ('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday');

var
  CompilerPath, CompilerFolder, CompilerName, CompilerExt,
  PasPath, PasFolder, PasName, PasExt,
  ExePath: TString;
  StartTime,
  EndTime: TSystemTime;
  TimeString: String;
  H,M,S,MS,
  TotalData: Integer;
  CompCount:Double;


  Function Comma(K:Longint):string;
  var
     i:integer;
     s: string;
  begin
      S := intToStr(K);
      i := length(s)-3;
      while i>0 do
      begin
          S := Copy(S,1,i) +','+copy(s,i+1,length(s));
          I := I-3;
      end;
      Result := S;
  end;

function I2(N:Word):string;
var
   T1,t2:String[1];
begin
    T1 := CHR(N mod 10+ord('0'));
    T2 := Chr(N div 10+ord('0'));
    Result := T1+T2;
end;



begin
SetWriteProcs(nil, @NoticeProc, @WarningProc, @ErrorProc);

Notice('XD Pascal for Windows ' + VERSION);
Notice('Copyright (c) 2009-2010, 2019-2020, Vasiliy Tereshkov');
GetLocalTime(StartTime);
TimeString := Days[StartTime.dayOfWeek]+' '+Months[StartTime.month]+
              ' '+IntToStr(StartTime.day)+', '+IntToStr(StartTime.year);
TimeString := TimeString+' '+IntToStr(StartTime.Hour)+
               ':'+I2(StartTime.Minute)+':'+I2(StartTime.Second);
Notice('Compilation started: '+TimeString);


if ParamCount < 1 then
  begin
  Notice('Usage: xdpw <file.pas>');
  Halt(1);
  end;
  
CompilerPath := TString(ParamStr(0));
SplitPath(CompilerPath, CompilerFolder, CompilerName, CompilerExt);  

PasPath := TString(ParamStr(1));
SplitPath(PasPath, PasFolder, PasName, PasExt);

InitializeCommon;
InitializeLinker;
InitializeCodeGen;

Folders[1] := PasFolder;
Folders[2] := CompilerFolder + 'units\';
NumFolders := 2;

TotalLines := 0;
CompileProgramOrUnit('system.pas');
InitListing;
CompileProgramOrUnit(PasName + PasExt);

ExePath := PasFolder + PasName + '.exe';
LinkAndWriteProgram(ExePath);
GetLocalTime(EndTime);
TotalData := InitializedGlobalDataSize + UninitializedGlobalDataSize;

TimeString := Days[EndTime.dayOfWeek]+' '+Months[EndTime.month]+
              ' '+IntToStr(EndTime.day)+', '+IntToStr(EndTime.year);
TimeString := TimeString+' '+IntToStr(EndTime.Hour)+
               ':'+I2(EndTime.Minute)+':'+I2(endTime.Second);
Notice('Compilation completed: '+TimeString);

Notice('Code size: ' + Comma(GetCodeSize) + ' ($'+
        Hex(GetCodeSize)+') bytes. Data size: ' + Comma(TotalData )+
        ' ($'+Hex(TotalData) + ') bytes');

Notice('Complete. Total program length was '+
       Comma(TotalLines)+' lines.');
Notice('Total number of identifies used '+
        Comma(TotalIdent)+' of which at most '+
        Comma(MaxIdentCount)+' were used at any one time.');

    H :=  EndTime.Hour;
    if StartTime.Hour < EndTime.Hour  then
        h:=H + 24;
     h := h - StartTime.Hour;
     M := EndTime.Minute ;
     if M < StartTime.minute then
     begin
          H := H-1;
          M := M+60;
     end;
     M := M - StartTime.minute;
     S := EndTime.second  ;
     if S < StartTime.second then
     BEGIN
        M := M-1;
        S := S+60;
     END;
     S := S-StartTime.second;
     MS := EndTime.MilliSecond;
     IF MS < StartTime.MilliSecond then
     begin
        MS := MS+1000;
        S := S-1;
     end;
     MS := MS-StartTime.MilliSecond;

// we won't bother with days,
// nobody is going to compile something taking that long
// (anything tht big, they'd use a full-service
// monolithic compiler)
   TimeString := '';
   If H >0 then
      Timestring := Plural(H,'hours','hour')+' ';
   If M >0 then
      Timestring := TimeString + Plural(M,'minutes','minute')+' ';
   if timestring <> '' then
      Timestring := Timestring +' and';
   Timestring := TimeString + IntToStr(S)+'.' + IntToStr(MS)+' seconds.';
   Notice( 'Compilation took '+TimeString);

   S:= (H*3600 + M*60 + S);
   compcount := ( TotalLines / (S+MS/1000))+0.5;
   TotalLines := TRUNC(Compcount);
   Notice( 'Compilation rate was approx. '+
         Comma(Totallines)+' lines per second.');

repeat FinalizeScanner until not RestoreScanner;
FinalizeCommon;
end.

