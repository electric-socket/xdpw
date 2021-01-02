(*$SHOW all,narrow*)
program exer08;
Var
    A: Boolean;


begin
    Case A of
      True:  A := NOT A;
      False: A := A;
    end;

end.

