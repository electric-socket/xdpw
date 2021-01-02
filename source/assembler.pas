// XD Pascal for Windows (XPDW) - a 32-bit compiler
// Copyright 2020 Paul Robnson

// Latest upgrade by Paul Robinson: New Years Eve; Thursday, December 31, 2020

// VERSION 0.15  {.0}

// mini-assembler

unit Assembler;

interface

Uses Common;


procedure AssembleStatement;

implementation
CONST
    OpcodeCount = 8;

    Opcode: array[1..OpcodeCount] of string[6] =(
            'AND',  'CALL', 'LEA',  'MOV',   'POP',
            'PUSH', 'OR',   'XOR');


procedure AssembleStatement;
begin



end;



end.

