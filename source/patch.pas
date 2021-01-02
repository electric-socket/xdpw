// XD Pascal for Windows (XPDW) - a 32-bit compiler
// Copyright 2020 Paul Robnson

// Latest upgrade by Paul Robinson: New Years Eve; Thursday, December 31, 2020

// VERSION 0.15 {.0}

// Inserts code into the program in certain cases

unit Patch;

// Primarily for debugging but can be used for other purposes.
//
// When certain constructs are found in the source program, if
// the conditions warrant it, the code is replaced with prefix
// code, suffix code, or both. For example, if procedure
// tracing is in effect, after the first BEGIN of the procedure,
// a trace instruction is inserted, perhaps something like
//   trace_Start('Procedure Name');
// then, before the last END is inserted
//   trace_stop;
// however, any EXIT statement in the p4rocedure has to be
// intercepted. However, this depends on where the EXIT
// statement is located. If it is inside of a BEGIN-END, or
// REPEAT-until block, fine. But if it's in a single-line
// FOR-DO loop, IF-THEN, ELSE, WHILE-do, we have to
// encapsulate it with a BEGIN and the trace statement, then
// insert an END statement either after the item, or
// before the semicolon (if there is one). This doesn't
// just apply to procedure tracing but can apply to any
// other form of insertion of code, including line number
// tracing, inline debugger, run to line tracing under
// control of a source-level debugger. Or any number of things.


interface

uses   Common;

Type
    PatchCondition = (
       PatchProgram,  // PROGRAM statement, or not in any unit
       PatchUnit,     // UNIT statement
       PatchProc,      // start of a proc, func, prop or meth
       PatchProcBegin, // first BEGIN of the Main Program, a Procedure, Function
                      // Property or method
       PatchProcEnd,  // Matching proc END statement
       PatchDecl,     // in a declaration area (VAR, CONST, TYPE)
       PatchIf,       // Was an IF statement
       PatchThen,     // matching THEN
       PatchBegin,    // a block other than at the start of a proc
       PatchEnd,      // matching End of block
       PatchRepeat,
       PatchFor,
       PatchWith,
       PatchWhile,
       PatchDo,       // DO in FOR .. DO, WITH ... DO, or WHILE ... DO
       PatchElse,     // ELSE clause
       PatchCase,     // CASE statement
       PatchCaseOf,   // OF in Case ... OF
       PatchCaseCond  // One of the conditions in a CASE statemet
      );

VAR

   PrefixItem,
   SuffixItem:  string;    // code to insert
   PrefixPos,
   SuffixPos: Byte; // How many chars of each have been read
   MakeUnitInit,   // Are we adding a fake procedure?
   PatchFlag,  // Does scanner divert to reading from
               // PrefixItem or PostFixItem?
   PatchTrap: Boolean; // Used to allow one statement
   PatchState: PatchCondition;

// How this will work: If patching is enabled, when we get to
// a "patch event" we determine how to handle it:
// # if the event can allow an insertion before the next token
//   without encapsulation (having to put anything "around" the
//   code like a BEGIN-END block, before and after), then we
//   just back up to the start of the token, insert the code
//   into PrefixItem, set PostfixItem to null,  then turn the
//   PatchFlag on.
// # If the event can allow us to insert after the next item
//   without encapsulating the statement, we can put the code in
//   Either PrefixItem or PostFixItem, set the other to null,
//   then turn the PatchFlag on.
// # The most complicated. The code requires we insert, say a
//   BEGIN block before our patch code and the original code
//   and after the code. We insert a "BEGIN " before our code
//   in prefixCode, then an " END" in postfix code. We then
//   turn the PatchFlag on.
// When scanner asks for another character, if patchflag is on,
// if Prefixtem is not null AND PrefixPos <= Length(PrefixItem) then
//     read the next character from PrefixItem
//     Add 1 to prefixPos
// else
//    If PrefixPos> Length(PrefixItem) then
//       set PatchFlag off
//       prefixitem = ''
//       prefixPos=0
//       If Suffixitem <>'' then
//          set patchtrap on

// in the parser,
//     if we are at the end of the next statement, and
//      patchTrap is set, then
//         Move Suffixcode to prefixCode
//         SeSuffixCode to ''
//         set PatchFlag on
//          set PatchTrap off
//
//   This should allo us to encapsulate one statement,
//   no matter how long it is
//

Procedure  InitUnit;

implementation

// we will get called when the IMPLEMENTATION
// token is found, or when either a BEGIN statement
// in a unit happens, or when there is no BEGIN statement,
// only the END. statement, so we can 'HIJACK' the parser by
// supplying it with fake tokens to tell it to comple a "made up"
// procedure called "unitname$INIT" (notice the $) this makes
// it a "special" procedure that user code cannot call

// if the unit has a BEGIN statement outside of a procedure, we will]
// Change it to put it into a fake procedure. If not, we create a dummy
// fake procedure so the compiler doesn't5 barf for there being a
// procedure declared that isn't there.

Procedure  InitUnit;
begin



end;


end.

