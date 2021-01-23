// trace how the compilee handles a specification error

program err004;
const
       a = 5;
var
       By: byte;
       I: Integer;
       R:Real;

begin
{$Show all,narrow}
      halt(0);
      Halt(By);
      Halt(a);
      Halt(R);

      inc(0);
      inc(a);
end.

