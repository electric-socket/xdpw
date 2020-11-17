// XD Pascal for Windows (XPDW) - a 32-bit compiler
// Copyright (c) 2020, Paul Robinson

// Latest upgrade by Paul Robinson:  Friday, November 6, 2020

// VERSION 0.14.2

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

uses
  Common;

Type
    PatchState = (
      PatchProc,      // start of a proc, func, prop or meth
      PatchProcBegin, // first BEGIN of a Procedure, Function
                      // Property or method
       PatchProcEnd,  // Matching END statement
       PatchIf,       // Was an IF statement
       PatchBegin,    // a BEGIN other than at the start of a proc
       PatchEnd,      // matching End
       PatchFor,      // FOR loop
       PatchWhile,    // WHILE loop
       PatchDo,       // DO in FOR .. DO or WHILE ... DO
       PatchElse,     // ELSE clause
       PatchCase,     // CASE statement
       PatchCaseOf,   // OF in Case ... OF
       PatchCaseCond  // One of the conditions in a CASE statemet
      );

VAR

// ProcName is in Common ScannerState
   PrefixItem,
   SuffixItem:  string;    // code to insert
   PrefixPos,
   SuffixPos: Byte; // How many chars of each have been read
   PatchFlag,  // Does scanner divert to reading from
               // PrefixItem or PostFixItem?
   PatchTrap: Boolean; // Used to allow one statement

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
// if Prefixtem is not null AND PrefixPos <= Length(Prefix) then
//     read the next character from PrefixItem
//     Add 1 to prefixPos
// else
//    If PrefixPos> Length(PrefixItem) then
//       set PatchFlag off
//       prefixitem = ''
//       prefixPos=0
//       If Postfixitem <>'' then
//          set patchtrap on

// in the parser,
//     if we are at the end of the next statement, and
//      patchTrap is set, then
//         Move Suffixcode to prefixCode
//         SeSuffixCode to ''
//         set PatchFlag on
//          set PatchTrap off
//
//



implementation

end.

