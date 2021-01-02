// XD Pascal for Windows (XPDW) - a 32-bit compiler
// Copyright 2020 Paul Robnson

// Latest upgrade by Paul Robinson: New Years Eve; Thursday, December 31, 2020

// VERSION 0.15 {.0}

// program to auomatically update the revision level
// of the compiler and to create a batch file to
// update all files in local GIT repository

(* I use a two-stage process; I start with the master
   repository on Github. This is cloned to a pristine
   first-stage repository on R:\ (which is SUBST to
   the actual drive and folder where XDPW is housed).
   I copy that first-stage repository to another
   work directory where I do editing. I use the file
   C.BAT allowing me to just type C (and RETURN) to
   recompile. C runs this program to increase the
   revision number in COMMON.PAS by 1, rewrite
   COMMON.PAS with the new update number, then this
   program creates BK.BAT which updates the first-stage
   repository.

   If the first compile works, it means there are no
   syntax errors in the current revision. If so, that
   compiler binary, SOURCE\XDPW.EXE is moved over from
   the SOURCE subdirectory as X.EXE. Then, the compiler
   is recompiled again, this time with itself to do two
   things: (1) confirm it has no errors, and (2) to update
   the revision level of the compiler. If the recompile
   is successful, then all files are automatically copied
   back to the first stage repository on R:, and a commit
   is made. This way, only revisions that work are pushed
   to the first stage, avoiding the problem of making a
   commit of a compiler with syntax errors or one which
   does not work (at least to the extent of actually being
   able to successfully compile itself.)
*)

Program upd;
const
    name      = 'source\common.pas';
    test      = 'VERSION_REV';
    zero      = Ord('0');

    Workdrive = 'X:';  // change this to the drive and
    Workdir   = '\';   // folder you edit in
    StageDrive= 'R:';  // change this to the drive and
    Stagedir  = '\';   // folder your local repository is in
    batchFile = 'bk.bat'; // newly created batch file to update repository

type
    Pcharacter = ^Char;

    { Taking a hint from the compiler, I don't read or write files
      one byte at a time. I request a block of memory big enough to
      hold the entire file, read it all into that, then go through
      the cached memory copy a byte at a time. I write to the memory
      file a byte at a time, then rewrite the copy back as a single
      block write. *Much* faster. }

    TBuffer = record
       inPtr,
       OutPtr: PCharacter;
       Ch: Char;
       Line,
       InPosition,
       InSize,
       OutSize,
       inPos,
       OutPos: Integer;
       EndOfUnit: Boolean;
    end;

var
  F: File;
  buffer: TBuffer;
  ActualSize: Integer;
  I,L,
  OldVersion:Integer;
  CrLf: String[2];
  NewVersion:String[5];


  procedure readch;
  begin
      with Buffer do
      begin
          ch := #0;
          if inPos <= inSize then
          begin
              ch := PCharacter(Integer(inPtr) + inPos)^;
              if ch=#10 then
                 begin
                     Inc(line);
                     InPosition :=0;
                 end;
              Inc(inPos);
              Inc(InPosition);
          end
      else
         EndOfUnit := TRUE;
      end;
  end;

  Procedure WriteCh(C:Char);
  begin
     with buffer do
     begin
         PCharacter(Integer(outPtr) + outPos)^ := C;
         inc(outPos);
     end;
  end;

  Procedure WriteString(S:string);
  var
      L: Integer;

  begin
      For L := 1 to Length(S) do
        WriteCh(S[L]);
  end;

  function check: boolean;
  begin
      Result := False;

      with buffer do
      For I:= 1 to L do
         begin
             writech(Ch);;
             if Ch <> test[i] then
                exit;
             readch;
         end;
      Result := TRUE;
  end;

 Procedure CreateBatFile;
 VAR
     Lines: array[1..50] of string;
     I,K,Size: Integer;
begin

     I := 1;
     Lines[I]:='cd '+WorkDrive+Workdir+CrLf; inc(I);
     Lines[I]:='cd '+StageDrive+Stagedir+CrLf; inc(I);
     Lines[i]:=StageDrive+CrLf; inc(I);
     Lines[I]:='copy /y '+WorkDrive+CrLf; inc(I);
     Lines[I]:='copy /y '+WorkDrive+'units\* units' + CrLf; inc(I);
     Lines[I]:='copy /y '+WorkDrive+'source\* source' + CrLf; inc(I);
     Lines[I]:='del *.bak' + CrLf; inc(I);
     Lines[I]:='del source\*.bak' + CrLf; inc(I);
     Lines[I]:='del units\*.bak' + CrLf; inc(I);
     Lines[I]:='del source\*.o' + CrLf; inc(I);
     Lines[I]:='git add * source\* units\*' + CrLf; inc(I);
     Lines[I]:='git commit -m rev_'+NewVersion + CrLf; inc(I);
     Lines[I]:='exit' + CrLf; inc(I);

     Size := 0;
     For K := 1 to I do
         Size := Size + Length(Lines[K]);
     buffer.outpos :=0;
     For K := 1 to I do
         WriteString(Lines[K]);

     Assign(F,BatchFile);
     rewrite(F);

     with buffer do
          BlockWrite(F, OutPtr^,OutPos);
     Close(F);
  end;

  Procedure DoTest;
  var
      isQuote:  boolean;
  begin
  with buffer do
      begin
      Writeln('Pass 1 at ',line,':',inposition);
      while not (ch in ['0'..'9','''']) do
      begin
         WriteCh(Ch);
         ReadCh;
      end;
      Writeln('Pass 2 at ',line,':',inposition);
      OldVersion := 0;
      isQuote := ch = '''';
      if isquote then  readch;
      While CH in ['0'..'9'] do
      begin
         Oldversion := Oldversion*10 + (ord(Ch)-Zero);
         readch;
      end;
      Write('Version number changed from ',OldVersion,' to ');
      Inc(oldVersion);
      NewVersion := Radix(OldVersion,10);
      Writeln(NewVersion);
      if isquote then WriteCh('''');
      WriteString(NewVersion);
      if isquote then WriteCh('''');
      repeat
          readch;
          writech(Ch)
      until endofunit;
      FreeMem(InPtr);
      Assign(F,name);
      rewrite(F);
      BlockWrite(F, OutPtr^,OutPos);
      Close(F);
      FreeMem(OutPtr);

      CreateBatFile;

      Writeln('Completed');
      halt;
      end;
  end;

begin

   L := Length(Test);

   {There is a small problem with the compiler, it doesn't allow you
    to create strings like

     Const S := 'Hello there'#13$10 ;
       or
     Const T := 'Hi'+S;

     I'll work on that later. So I just use a
     string var and initialize it to contain
     CRLF. Guess what I named the string.}


   Crlf := #13; Crlf:=CRLF+#10;
   with buffer do
   begin
       Assign(F,name );
       reset(F,1);
       InSize := FileSize(F);
       inPos := 0;;
       outPos := 0;
       line := 1;
       inposition := 0;
       EndOfUnit := False;

       GetMem(inPtr,  InSize);
       GetMem(OutPtr, InSize+10);
       ActualSize := 0;
       BlockRead(F, InPtr^, InSize, ActualSize);
       Close(F);
       if ActualSize <> InSize then
       begin
          Writeln('Fatal: Unable to read source file ' + Name);

          Halt(16);
       end;
       writeln('Open ok');
       readCh;
       Repeat
           if check then dotest
           else
           readch;
       until EndOfUnit;
       Writeln('Check failed');
   end;
end.


