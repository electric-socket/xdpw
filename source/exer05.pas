// XD Pascal for Windows (XPDW) - a 32-bit compiler
// Copyright 2020 Paul Robnson

// Latest upgrade by Paul Robinson: New Years Eve; Thursday, December 31, 2020

// VERSION 0.15 {.0}

// Tests the Trim() functions

program exer05;

uses SysUtils;

var
   Q:String;

begin
     Writeln ('Trim');
     Q  := '';                         Writeln(' ':5,'"',Trim(Q),'"');
     Q  := 'A';                        Writeln(' ':5,'"',Trim(Q),'"');
     Q  := 'AB';                       Writeln(' ':5,'"',Trim(Q),'"');
     Q  := 'ABC';                      Writeln(' ':5,'"',Trim(Q),'"');
     Q  := '     A';                   Writeln(' ':5,'"',Trim(Q),'"');
     Q  := '     AB';                  Writeln(' ':5,'"',Trim(Q),'"');
     Q  := '     A  B     ';           Writeln(' ':5,'"',Trim(Q),'"');
     Q  := '     A  B     C';          Writeln(' ':5,'"',Trim(Q),'"');
     Q  := '     A  B     C     ';     Writeln(' ':5,'"',Trim(Q),'"');
     Q  := 'A     ';                   Writeln(' ':5,'"',Trim(Q),'"');
     Q  := 'AB     ';                  Writeln(' ':5,'"',Trim(Q),'"');
     Q  := 'ABC     ';                 Writeln(' ':5,'"',Trim(Q),'"');
     Q  := 'A     ';                   Writeln(' ':5,'"',Trim(Q),'"');
     Q  := 'AB     ';                  Writeln(' ':5,'"',Trim(Q),'"');
     Q  := 'A  B     ';                Writeln(' ':5,'"',Trim(Q),'"');
     Q  := 'A  B     C';               Writeln(' ':5,'"',Trim(Q),'"');
     Q  := 'A  B     C     ';          Writeln(' ':5,'"',Trim(Q),'"');

     Writeln ('LTrim');
     Q  := '';                         Writeln(' ':5,'"',LTrim(Q),'"');
     Q  := 'A';                        Writeln(' ':5,'"',LTrim(Q),'"');
     Q  := 'AB';                       Writeln(' ':5,'"',LTrim(Q),'"');
     Q  := 'ABC';                      Writeln(' ':5,'"',LTrim(Q),'"');
     Q  := '     A';                   Writeln(' ':5,'"',LTrim(Q),'"');
     Q  := '     AB';                  Writeln(' ':5,'"',LTrim(Q),'"');
     Q  := '     A  B     ';           Writeln(' ':5,'"',LTrim(Q),'"');
     Q  := '     A  B     C';          Writeln(' ':5,'"',LTrim(Q),'"');
     Q  := '     A  B     C     ';     Writeln(' ':5,'"',LTrim(Q),'"');
     Q  := 'A     ';                   Writeln(' ':5,'"',LTrim(Q),'"');
     Q  := 'AB     ';                  Writeln(' ':5,'"',LTrim(Q),'"');
     Q  := 'ABC     ';                 Writeln(' ':5,'"',LTrim(Q),'"');
     Q  := 'A     ';                   Writeln(' ':5,'"',LTrim(Q),'"');
     Q  := 'AB     ';                  Writeln(' ':5,'"',LTrim(Q),'"');
     Q  := 'A  B     ';                Writeln(' ':5,'"',LTrim(Q),'"');
     Q  := 'A  B     C';               Writeln(' ':5,'"',LTrim(Q),'"');
     Q  := 'A  B     C     ';          Writeln(' ':5,'"',LTrim(Q),'"');

     Writeln ('RTrim');
     Q  := '';                         Writeln(' ':5,'"',RTrim(Q),'"');
     Q  := 'A';                        Writeln(' ':5,'"',RTrim(Q),'"');
     Q  := 'AB';                       Writeln(' ':5,'"',RTrim(Q),'"');
     Q  := 'ABC';                      Writeln(' ':5,'"',RTrim(Q),'"');
     Q  := '     A';                   Writeln(' ':5,'"',RTrim(Q),'"');
     Q  := '     AB';                  Writeln(' ':5,'"',RTrim(Q),'"');
     Q  := '     A  B     ';           Writeln(' ':5,'"',RTrim(Q),'"');
     Q  := '     A  B     C';          Writeln(' ':5,'"',RTrim(Q),'"');
     Q  := '     A  B     C     ';     Writeln(' ':5,'"',RTrim(Q),'"');
     Q  := 'A     ';                   Writeln(' ':5,'"',RTrim(Q),'"');
     Q  := 'AB     ';                  Writeln(' ':5,'"',RTrim(Q),'"');
     Q  := 'ABC     ';                 Writeln(' ':5,'"',RTrim(Q),'"');
     Q  := 'A     ';                   Writeln(' ':5,'"',RTrim(Q),'"');
     Q  := 'AB     ';                  Writeln(' ':5,'"',RTrim(Q),'"');
     Q  := 'A  B     ';                Writeln(' ':5,'"',RTrim(Q),'"');
     Q  := 'A  B     C';               Writeln(' ':5,'"',RTrim(Q),'"');
     Q  := 'A  B     C     ';          Writeln(' ':5,'"',RTrim(Q),'"');


end.

