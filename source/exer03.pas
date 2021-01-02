// XD Pascal for Windows (XPDW) - a 32-bit compiler
// Copyright 2020 Paul Robnson

// Latest upgrade by Paul Robinson: New Years Eve; Thursday, December 31, 2020

// VERSION 0.15

//  Compiler test program  Err03.pas
// tests the proposition that ; is
// never legal before ELSE


program exer03;
Var
    Test,test2: Boolean;


Begin

    Test := True;
    Test2 := true;

    if test then
       if test2 then
           Writeln('Reached Part 1');  // semi-colon here should be illegal
     else
        Writeln('Reached Part 2');

end.

