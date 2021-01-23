{$DEFINE Trace}
// XD Pascal for Windows (XPDW) - a 32-bit compiler
// Copyright (c) 2009-2010, 2019-2020, Vasiliy Tereshkov
// Copyright 2020,2021 Paul Robnson

// Latest upgrade by Paul Robinson: Groundhog Day; Tuesday, February 2, 2021

// VERSION 0.16 {.0}

// The Main program of the compiler. If called by XDPWT, includes compiler tracing

{$APPTYPE CONSOLE}
{$I-}
{$H-}

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


program XDPW_T;  // (Input,Output,xprogram,m);

uses SysUtils,
     Common,
     Conditional,
     CompilerTrace,
     Scanner,
     Parser,
     CodeGen,
     Linker,
     Listing,
     Error,
     Compileroptions;

//
// $NOTE Noteworks are capable*)
{ $Warning theWarning works}
{ $Message Hi there}
{ $Message NOTE Second Note}
{ $message warning another warning}
{ $Stop Me}
{ $fatal Heart Attack}
{ $IF Maybe}





 { function CreateProcessA(lpApplicationName: LPCSTR;
         lpCommandLine: LPCSTR;
         lpProcessAttributes,
         lpThreadAttributes: PSecurityAttributes;
         bInheritHandles: BOOL;
         dwCreationFlags: DWORD;
         lpEnvironment: Pointer;
         lpCurrentDirectory: LPCSTR;
         const lpStartupInfo: TStartupInfoA;
         var lpProcessInformation: TProcessInformation): BOOL; external 'kernel32' // name 'CreateProcessA';
         }

// This procedure has two "teat comments" in which a { comment and
// a (* comment are immediately preceeding a keyword, This self-tests
// the compiler's checking for brace and paren star comments by causing them
// to trip a compile error with an unrecgognized identifier (AR if the brace
// comment processor "oereats," EGIN if the (* processor does.). If they
// "undereat," the brace processor will trip for having  a } outside a
// comment, (* havng unexpected ( found

procedure SplitPath(const Path: TString; var Folder, Name, Ext: TString);
{}var
  DotPos, SlashPos, i: Integer;
(**)begin
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
end;




procedure WarningProc(ClassInstance: Pointer; const Msg: TString);
begin
   if NumUnits >= 1 then
      Notice(' ** '+ScannerState.FileName + ' (' + IntToStr(ScannerState.Line) +
        ':' + IntToStr(ScannerState.Position) +  ') Warning: ' + Msg)
   else
      Notice(' ** Warning: ' + Msg);
end;



// Actual error message is generated by Fatal/err procedures
// This is left here for technical reasons (every time I
// try to remove it, it breaks the compiler)
procedure ErrorProc(ClassInstance: Pointer; const Msg: TString);
begin
     if NumUnits >= 1 then
        Notice(ScannerState.FileName + ' (' + Radix(ScannerState.Line,10) +
                                 ':' + Radix(ScannerState.Position,10)  + ') Error: ' + Msg)
     else
        Notice('Fatal Error: ' + Msg);

     repeat
         FinalizeScanner
     until not RestoreScanner;
     FinalizeCommon;
     Halt(1);
end;


var
  CompilerPath, CompilerFolder, CompilerName, CompilerExt,
  PasPath, PasFolder, PasName, PasExt,
  ExePath: TString;
  StartTime,
  EndTime: TSystemTime;
  AdviceMessage,
  TimeString: String;
  H,M,S,MS,
  ProcFuncCount,
  TotalData: Integer;
  CompCount:Double;
  Dot: String[1] ='.';


//{$Show block,procfunc}
//{$show all,narrow}



begin
// {$hide all}
// uzed for indirect procedure calls
    SetWriteProcs(nil, @NoticeProc, @WarningProc, @ErrorProc);

    Advicemessage := Radix(VERSION_MAJOR,10) + Dot+ Radix(VERSION_RELEASE,10);
    IF VERSION_PATCH<>0 THEN
        Advicemessage :=Advicemessage +'.'+Radix(VERSION_PATCH,10);
    IF VERSION_REV <> '' THEN
        Advicemessage :=Advicemessage +' Rev '+ VERSION_REV;
    Notice('XD Pascal for Windows (Release Code named "' + CODENAME+'"), Version '+ Advicemessage);
    Notice('    Release date: '+ReleaseDate);
    Notice('Copyright (c) 2009-2010, 2019-2020, Vasiliy Tereshkov');
    Notice('Copyright 2020, 2021 Paul Robinson');

    GetLocalTime(StartTime);

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

    TimeString := Days[StartTime.dayOfWeek]+' '+Months[StartTime.month]+
                  ' '+IntToStr(StartTime.day)+', '+IntToStr(StartTime.year);
    TimeString := TimeString+' '+IntToStr(StartTime.Hour)+
                  ':'+I2(StartTime.Minute)+':'+I2(StartTime.Second);
    Notice('Compilation started: '+TimeString);
    Notice('');

    TotalLines := 0;

    isMainProgram := FALSE; // Off until first BEGIN in main program

    sysDef := True;         // these are system defined
    CompileProgramOrUnit('system.pas');
    sysDef := False;
    InitListing;
    Dirty := FALSE;                    // No Compiler tracing yet
    ErrorWarned :=False;

    CompileProgramOrUnit(PasName + PasExt);
    if errorCount =0 then
    begin
        ExePath := PasFolder + PasName + '.exe';
        LinkAndWriteProgram(ExePath);
        TotalData := InitializedGlobalDataSize + UninitializedGlobalDataSize;
    end;


    GetLocalTime(EndTime);

    TimeString := Days[EndTime.dayOfWeek]+' '+Months[EndTime.month]+
                  ' '+IntToStr(EndTime.day)+', '+IntToStr(EndTime.year);
    TimeString := TimeString+' '+IntToStr(EndTime.Hour)+
                  ':'+I2(EndTime.Minute)+':'+I2(endTime.Second);
    Notice('');
    AdviceMessage := 'Compilation completed ';
    if ErrorCount <> 0  then
        AdviceMessage := '*** Compile failed ***  Compilation ends: ';
    Notice(AdviceMessage+TimeString);
    AdviceMessage := 'Complete with *NO* errors.';
    if ErrorCount = 0  then
        Notice('Code size: ' + Comma(GetCodeSize) + ' ($'+
               Radix(GetCodeSize,16)+') bytes. Data size: ' + Comma(TotalData )+
               ' ($'+Radix(TotalData,16) + ') bytes.')
    else
        AdviceMessage := 'Incomplete, with'+CommaP(ErrorCount,'errors','error')+'.';

    Notice(AdviceMessage+' Total program length was '+
           Comma(TotalLines)+' lines.');
    Notice('Total number of identifiers used '+
           Comma(TotalIdent)+' of which at most '+
           Comma(MaxIdentCount)+' were used at any one time.');

    ProcFuncCount := TotalExtProc + TotalProcCount;
    AdviceMessage := Comma(ProcFuncCount)+' procedures ('+Comma(TotalProcCount)+' program, ';
    AdviceMessage := AdviceMessage + Comma(TotalExtProc)+' external), ';
    ProcFuncCount := TotalFuncCount + TotalExtFunc;
    AdviceMessage := AdviceMessage + Comma(ProcFuncCount)+' functions ('+Comma(TotalFuncCount)+' program, '+Comma(TotalExtFunc)+' external)';
    Notice(AdviceMessage+'.');


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
// monolithic compiler, or a rendering farm, and use a
// compiler that produced separate modules with a 'make' system(
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

    Notice('Compilation rate was approx. '+
           Comma(Totallines)+' lines per second.');
    if errorcount <>0 then
    begin
        Notice('');
        AdviceMessage := 'You will need to correct ';
        If ErrorCount = 1 then
          AdviceMessage := AdviceMessage + 'the error'
        else
          AdviceMessage := AdviceMessage + 'the '+Comma(ErrorCount)+' errors';
        Notice(AdviceMessage+' already detected so far, and try again.');
    end;

    repeat FinalizeScanner until not RestoreScanner;
    FinalizeCommon;

    If StatisticsCTrace in TraceCompiler then
       ShowStatistics;

end.

