// XD Pascal for Windows (XPDW) - a 32-bit compiler
// Copyright 2020 Paul Robnson

// Latest upgrade by Paul Robinson: New Years Eve; Thursday, December 31, 2020

// VERSION 0.15 {.0}

// Enables tracing of the compiler's operations
// This is really for debugging (or rather, *tracing* of
// the compiler so I (or someone else eventually working
// on this) can determine what is happening. It may be
// interesing to others for other reasosn

unit CompilerTrace;

interface

Uses common;


Var

    TraceLimit: LongInt;
    Dirty: Boolean;              // have we generated any output this file
    ShowTokenFile: Boolean = False;
    EMITInt: Integer;            // for usewhen an EMIT needs
    EMITString:String;           // a temporary variable (or two)


Procedure EmitToken(Token: String; DoWriteln:Boolean=False; ShowPrefix: Boolean=True; ShowSuffix: Boolean=True; Prefix: Char='['; Suffix: Char=']');
Procedure EmitGen(Token: String; DoWriteln:Boolean=False; ShowPrefix: Boolean=True; ShowSuffix: Boolean=True);
Procedure EmitHint(Token: String; DoWriteln:Boolean=False; ShowPrefix: Boolean=True; ShowSuffix: Boolean=True);
Procedure EmitStop;
Procedure ShowStatistics;



implementation

Procedure ShowStatistics;

Var
   J,
   N,
   I: Integer;
   KSC:Array[1..NumKeywords] of integer;
   S:String;
   // Since there's less than 100 entries
   // and we only do this once, we don't need
   // a fast sort
begin
    For I := 1 to NumKeywords-1 do
        KSC[I] := I;
    For I := 1 to NumKeywords-1 do
        For J := I+1 to NumKeywords do
        begin
            If KeywordCount[I]<KeywordCount[J] then
            begin
                KSC[I] := J;
                KSC[J] := I;
            end;
        end;

    Writeln('Alphabetical list of keywords by usage');
    N := 0;
    Write(' ':4);
    For I := 1 to NumKeywords-1 do
    begin
        If KeywordCount[i]=0 then Continue;
        S :=Keyword[I]+' '+Comma(KeywordCount[I]);
        J :=26-Length
        (S);
        Write(S,' ':J);
        N:= N+26;
        if N>=78 then
        begin
            writeln;
            N := 0;
        end;
    end;
    writeln;
end;


Procedure EmitToken(Token:String;
                    DoWriteln:Boolean=False;
                    ShowPrefix: Boolean=True;
                    ShowSuffix: Boolean=True;
                    Prefix: Char='[';
                    Suffix: Char=']');
VAR
    ShowStart: Boolean;

begin
   if tracelimit >= 0 then
   begin
       if not ShowTokenFile then   // If the file name has
       begin                       // not been displayed, do so
           writeln;
           if ScannerState.filename <>'' then
               writeln(ScannerState.FileName,' tokens:');
           ShowTokenFile := TRUE;
       end;
       ShowStart := TRUE; // If in Narrow mode, do we need to show blank prefix?

   // Note to self: Should we use Scannerstate.Line or TOK.DeclaredLine?
   // the latter may be more accurate but might not be the current
   // token by time it's reported to us here

       if not ShowTokenLine then        // if line number hasn't been shown, do so
       begin
           writeln;
           write(' ':4,Scannerstate.Line:6,' T: ');
           ShowTokenLine := TRUE;
           ShowStart := FALSE;
       end;
       If NarrowCTrace in TraceCompiler then
       begin
           if showSuffix then
               DoWriteln := TRUE; // In narrow mode, do newline after each token
                                  // but not if this is a continuing token
           if ShowPrefix and ShowStart then  // show prefix start of line
               Write(' ':14);
       end;

       if ShowPrefix then
           write(' ',Prefix);
       Write(Token);
       If ShowSuffix then
           Write(Suffix,' ');

       if DoWriteln then
           writeln;
       Dirty := TRUE;
       if tracelimit = 0 then exit; // unlimited
       dec(tracelimit);
       if tracelimit =0 then  // in this case, cease tracing
           emitstop;
   end
   else  // hiding traces until 0
       Inc(TraceLimit);
end;

Procedure EmitGen(Token:String;
                  DoWriteln:Boolean=False;
                  ShowPrefix: Boolean=True;
                  ShowSuffix: Boolean=True);
begin
    EmitToken(Token,DoWriteln, ShowPrefix,ShowSuffix,'<','>');
end;

Procedure EmitHint(Token:TString; DoWriteln:Boolean=False;
                  ShowPrefix: Boolean=True; ShowSuffix: Boolean=True);
begin
       EmitToken(Token,DoWriteln, ShowPrefix,ShowSuffix,'{','}');
end;

   Procedure EmitStop;
   begin
       ShowToken := FALSE ;
       ShowTokenLine := FALSE;
       ShowTokenFile := FALSE;
       if dirty then
            writeln;
       Dirty := False;
   end;


end.

