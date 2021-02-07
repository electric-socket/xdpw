// XD Pascal for Windows (XPDW) - a 32-bit compiler
// Copyright (c) 20020, Paul Robinson

// VERSION 0.15    {.0}

// Unit for use by compiler exercises


unit ExerUnit;

interface
const
   H1 = $DeadBeef;
   &Repeat = $1F;
   O1 = &177362;

var
  x:integer;


Procedure InProc;
function InFunc:Boolean;


implementation

Procedure Hiddenproc;
begin
    repeat
         exit;
    until false;
end;

Procedure InProc;
begin
    Writeln('My unit is ',xdp_unitname,' my procedure type is ',
            XDP_ProcType,' and my name is ',xdp_procName);
end;

function InFunc:Boolean;
begin
    Writeln('My unit is ',xdp_unitname,' my procedure type is ',
            XDP_ProcType,' and my name is ',xdp_procName);
end;


end.


