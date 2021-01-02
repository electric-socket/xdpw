// Exer01 - program to exercise various functions of the XDPascal Compiler

program Exer01;
CONST
    CString = 'A string';
    Cchar ='A';
    CInt = 99;

TYPE
    ARecord = Record
      I1: Integer;
      S1: String
    end;

VAR
    Aarray:    Array[0..255] of Char;
    Bbyte:     Byte;
//    CCurrency: Currency;
//    iint128:   Int128;
//    Iint64:    Int64;
    Iinteger:  Integer;
    DDouble:   Double;
    ISingle:   Single;
    Rreal:     Real;
    RRecord:   Arecord;
    Sset:      Set of Char;
    Vchar:     Char;

    Procedure Pprocedure;
    begin
        Write('This is Pprocedure');
        Writeln;
    end;

begin
    {$show all,narrow}
    DDouble := 0;
    {$Hide all}

    Write( Aarray[0]    );
    Write( Bbyte        );
    Write( Cchar        );
//    Write( CCurrency    );
//    Write( iint128      );
//    Write( Iint64       );
    Write( Iinteger     );
    Write( DDouble      );
    Write( ISingle      );
    Write( Rreal        );
//    Write( RRecord      );
    Writeln('End');
end.

