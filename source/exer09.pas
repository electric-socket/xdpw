// XD Pascal for Windows (XPDW) - a 32-bit compiler
// Copyright (c) 2009-2010, 2019-2020, Vasiliy Tereshkov
// Copyright 2020 Paul Robnson

// Latest upgrade by Paul Robinson: New Years Eve; Thursday, December 31, 2020

// VERSION 0.15    {.0}

// Check compiler func/proc nesting depth


Program Exer09;

uses ExerUnit;

VAR
    A:Integer;


Procedure A01;
 Procedure A02;
  Procedure A03;
   Procedure A04;
    Procedure A05;
     Procedure A06;
      Procedure A07;
       Procedure A08;
        Procedure A09;
         Procedure A10;
          Procedure A11;
           Procedure A12;
            Procedure A13;
             Procedure A14;
              Procedure A15;
               Procedure A16;
                Procedure A17;
                 Procedure A18;
                  function A19:boolean;
                   Procedure A20;
                   begin // A20
                       Inc(A);
                       Writeln(' A20');
                       Writeln('Unit name ',XDP_UnitName,' From ',XDP_ProcType,' ',XDP_ProcName);
                       Writeln('A=',A);
                       Write('A20 ');
                       Dec(A);
                       exit; // prevent recursion
                       A20; A19; a18; A17; A16; A15; A14; A13; A12; A11;
                       A10; A09; A08; A07; A06; A05; A04; A03; A02; A01;
                   end;
                  begin // A19
                      Inc(A);
                      Write(' A19');
                      A20;
                      Write('A19');
                      Writeln('Unit name ',XDP_UnitName,' From ',XDP_ProcType,' ',XDP_ProcName);
                      Dec(A);
                      exit; // prevent recursion
                      A20; A19; a18; A17; A16; A15; A14; A13; A12; A11;
                      A10; A09; A08; A07; A06; A05; A04; A03; A02; A01;
                  end;
                 begin // A18
                     Inc(A);
                     Write(' A18');
                     A19;
                     Write(' A18');
                     Dec(A);
                 end;
                begin // A17
                    inc(A);
                    Write(' A17');
                    A18;
                    Write(' A17');
                    Dec(A);
                end;
               begin // A16
                   Inc(A);
                   Write(' A16');
                   A17;
                   Write(' A16');
                   Dec(A);
               end;
              begin // A15
                  Inc(A);
                  Write(' A15');
                  A16;
                  Write(' A15');
                  Dec(A);
              end;
             begin // A14
                 Inc(A);
                 Write(' A14');
                 A15;
                 Write('A14');
                 Dec(A);
             end;
            begin // A13
                Inc(A);
                Write(' A13');
                A14;
                Write(' A13');
                Dec(A);
            end;
           begin // A12
               Write(' A12');
               A13;
               Write(' A12');
               Inc(A);
           end;
          begin // A11
              Inc(A);
              Write(' A11');
              A12;
              Write(' A11');
              Dec(A);
          end;
         begin // A10
             Inc(A);
             Write(' A10');
             A11;
             Write(' A10');
             Dec(A);
         end;
        begin // A09
            Inc(A);
            Write(' A09');
            A10;
            Write(' A09');
            Dec(A);
        end;
       begin // A08
           Inc(A);
           Write(' A08');
           A09;
           Write(' A08');
           Dec(A);
       end;
      begin // A07
          Inc(A);
          Write(' A07');
          A08;
          Write(' A07');
          Dec(A);
      End;
     begin // A06
         Inc(A);
         Write(' A06');
         A07;
         Write(' A06');
         Dec(A);
    end;
    begin // A05
        Inc(A);
        Write(' A05');
        A06;
        Write(' A05');
        Dec(A);
    end;
   begin // A04
       Inc(A);
       Write(' A04');
       A05;
       Write(' A04');
       Dec(A);
   end;
  begin // A03
      Inc(A);
      Write(' A03');
      A04;
      Write(' A03');
      Dec(A);
  end;
 Begin // A02
     Inc(A);
     Write(' A02');
     A03;
     Write(' A02');
     Dec(A);
 end;
begin // A01
    Inc(A);
    Write(' A01');
    A02;
    Write(' A01');
    Dec(A);
end;

Begin // MAIN
    A :=1;
    writeln(' A=',A);
    Write('Main');
    A01;
    Writeln(' Main');
    writeln(' A=',A);
    Writeln('Unit name ',XDP_UnitName,' From ',XDP_ProcType,' ',XDP_ProcName);
    InProc;
    InFunc;

end.

