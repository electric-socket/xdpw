#  XDPascal for Windows Version 0.16
For some reason these changes I made to the file do not appear here even though
it was properly COMMITted and I even manually uploaded it. I'm still seeing the old
0.15 release file. I'm not sure what's wrong.

This is the documentation for the release of version 0.16 of the XDPascal
compiler (February 2, 2021, code name "Groundhog Day")

Now repeat that a 1,000 times. (Yeah, I know that's a weak reference to the
movie of the same name.)

These are the things I got done while also working on a cross-reference tool.
- Fixed a nasty bug that broke the Readln processor and that
I hadn't even realized I'd done it; I thought I put everything back as it was.
I had actually broken it in 0.15 because a test program that compileds fine
with Version 0.14.1 (as well as Free Pascal) but had a syntax error now, and
in 0.15.
- In going along with making Pascal more like C, in addition to using $ to
indicate a hexadecimal constant, you can also prefix it with 0x (or 0X) as in
0xBEF, 0xbef. 0xBEF, etc.  So the statements <code>a= $5B;</code> or
<code>a= 0x5B;</code> are equivalent.
- in addition to indicating the alternative when no selector matches on a
CASE statement with ELSE, you may also use OTHERWISE. It has been added as a
reserved word.
- The "Radix constant" operator n#x where n is an integer from 2-36 and X is a
number expressed in that base. When it works, you can use Nnumbers like  17, $11,
or 0x11 and now  2#10001, 4#10, 8#21, 17#10, or 18#G.



# Version 0.15
This is the documentation for the release of version 0.15 of the XDPascal 
compiler (December 31, 2020, code name "New Years Eve"), written by the 
current maintainer, Paul Robinson. The project home is <a href="https://XDPascal.com">https://XDPascal.com</a>,  it can be downloaded from there, from <a href="https://github.com/electric-socket/xdpw">Github</a>, or from <a href="https://sourceforge.net/projects/xd-pascal-compiler/files/latest/download">Sourceforge</a>, and bugs can be reported at <a href="https://bugs.xdpascal.com">https://bugs.xdpascal.com</a>, (currently using <a href="https://www.mantisbt.org/">Mantis</a>; I may switch to <a href="https://www.bugzilla.org/">Bugzilla</a>) or by e-mail to <a href="mailto:XDPascal@xdpascal.com">XDPascal@xdpascal.com</a>.

XDPascal is a 32-bit one-pass self-hosting Pascal compiler for Windows on X86 processors. It is open source, written in Pascal (it is used to compile itself), and licensed under the BSD-2 clause license. There have been a number of major improvements from version 0.14.1. I didn't get to everything I had planned to accomplish (who does?) as I set an aggressive schedule to complete the compiler by December 31, 2020 and met it. (I have found if you don't set a schedule and stick to it, development goes on 
forever, or until the resources run out.) The most important things I planned to do did get accomplished. Here are some of the new features:

 - <strong>Include files</strong>. Using the <code>\$I filename</code> or <code>\$INCLUDE filename</code> directive, the contents of a file can be included at that point in the program, as if the entire file had been inserted in place of the comment. To prevent "*crock recursion*" (a file directly or indirectly including itself, causing an endless loop) only one <code>\$INCLUDE </code>file at a time may be invoked.
 - You can create <strong>compile-time definitons</strong>. The compiler supports the compiler directives <code>$DEFINE</code> and <code>$UNDEF</code> to create and erase compile-time symbols. Symbols can be defined, defined as a number value, or defined as having a string value. While this feature is nice, it serves no purpose if you can't use it to cause the compiler to <i>do</i> something, which brings us to...
 - <strong>Conditional compilation</strong>: by use of the<code> \$IFDEF</code>
and <code>\$IFNDEF</code> directives, to test whether a compile-time variable is or is not defined.&nbsp; If the test succeeds, the compiler continues scanning and compiling the source. If the test fails, the compiler skips over the code in the unit or program until a <code>\$ELSE</code> or <code>\$ENDIF</code> directive is found. You can compile code for some conditions and not others through <code>\$IFDEF</code> which checks to see if a particular compile-time variable is defined, or <code>\$IFNDEF</code> to check if it is not defined. (I didn't have enough time to get <code>\$IF</code> and <code>\$ELSEIF</code> implemented, but that will probably get done in a later release.)</li><li><strong>Conditional identifiers</strong>. The conditional identifier <code>XDP</code> is automatically included by the compiler, so it is possible to test 
which compiler a program is being targeted for. I'm thinking, if anything in the XDPascal compiler is not compatible with Free Pascal or Gnu Pascal (giving someone a choice of which compiler to use) a programmer can put <code>{\$IFDEF xdp} </code>or<code> (*\$IFDEF xdp*)</code> before code specifically to be compiled by XDPascal, as well as <code>\$IFNDEF xdp</code> for code for a different compiler. Or an <code>\$IFDEF</code> with a different compiler's symbol and <code>\$ELSE</code> for portions to compile with XDPascal or any other compiler.</li><li><strong>Additional conditional identifiers</strong> used to identify the compiler are also defined : <ol><li> <code>XDP_FULLVERSION</code> which has the value <code>150</code> (for version 0.15, the .0 is implied)</li> <li><code>XDP_VERSION</code>&nbsp; which is defined as <code>0</code></li><li><code>XDP_RELEASE</code> which is defined as <code>15</code>; and</li><li><code>XDP_PATCH</code> which is defined as <code>0</code>. </li>
<li>These definitions were intended to allow checking the compiler version for when new features get added, but when I could not finish <code>$IF</code> and <code>$ELSEIF</code> in time, they became features to be used later.</li>
<li><strong><code>\$NOTE</code> and <code>\$WARNING</code></strong> can send messages at compile time. They have no effect on the compilation.</li>
<li><strong><code>\$FATAL </code>and <code>\$STOP</code></strong>
directives immediately halt compilation with an optional message.
Together with <code>$IFDEF</code>/<code>$IFNDEF</code>/<code>$ELSE</code>
they can stop a compile of a program if a feature is not present.</li>
</ul>
<h3> <span style="color: #3366ff;">The following lesser things also got
done:</span></h3>
<ul><li><strong>Some recovery from user program errors.</strong> While most of 
the compiler is still "quit on error," there has been an improvement so 
that some errors simply produce an error message but the compiler
continues processing the source program to try and spot more potential
errors. The compiler originally quit on <em>all </em>errors, so if 
there were any it never reached the linker, which creates the 
executable. As a result if the program finished compiling it always 
called the linker to bind the user's program. Now, the linker will only 
be called if the error count is zero. This means there is the potential 
for the compiler to be able to scan an entire program and report all 
further syntax errors, if any.</li>
<li><strong>Additional comment type (*.</strong> As was announced in the 
previous release, the compiler supports <code>(* *)</code> as well as
<code>{  }</code> block comments. Diverting from Standard Pascal, comments <u>do
not</u> nest. e.g. a <code>{ comment }</code> may be inside of a <code>(* 
comment *)</code> and vice-versa; and the terminators cannot be 
mixed, i.e. <code>{</code> <em>must</em> be closed by <code>}</code> 
while <code>(*</code> <em>must</em> be closed by <code>*). (*)</code> 
at the start of a comment does not close that comment .</li>
<li><strong>More Standard Pascal support</strong>. The symbol pair <code> (.</code>may be used interchangeably with <code>[ </code>(open bracket) and the 
symbols <code>.)</code> may be used interchangeably with ] (close 
bracket).</li>
<li><strong>Better reporting of errors</strong>, e.g. if you declare a
procedure or function in the <code>INTERFACE</code> section of a <code>UNIT</code> (or a forward declaration in the main program or the <code>IMPLEMENTATION</code> section of a <code>UNIT</code>) and the header of the procedure or function declaration (the "signature") does not match the signature of the procedure or function when it is defined, the compiler will more 
precisely say why (2 arguments in the declaration but 3 in the 
definition; argument names or types don't match, e.g. defining an 
argument as real but declaring it as integer, etc.)</li>
<li><strong>More compiler directives</strong>. A <code>(*$</code> or 
<code>{$</code>  comment tells the compiler you want to instruct it about something,
separate from the code it generates based on the instructions in the
program.  There are a number of directives for tracing what the
compiler does (very useful if you want to modify it), to support
features, or to learn things.</li>
<li><strong>Much more information</strong> about the user program is
available, including the number of identifiers used, and now number of
procedures and functions, including how many are local to the program
and how many are calls to external routines.</li>
<li><strong>Several "exercise" programs</strong> test compiler
functionality, such as the <code>$I filename</code>/<code>$INCLUDE
filename</code> directive and conditional compilation (see below).</li>
<li><strong>Several error programs</strong> check the compiler's
processing of error conditions (to try to implement recovery and
continued syntax checking).</li>
<li><strong>Ampersand</strong> (<code>&amp;</code>) may be used before an
identifier if it might be the same as a keyword.</li>
<li><strong>Optional dereference operator</strong>. Borrowing from the
"New Stanford Pascal" mainframe Pascal compiler (<a href="https://github.com/StanfordPascal/Pascal">on GitHub</a>), the symbol <code>-&gt;</code> may be used interchangeably with <code>^</code> for the dereference operator.</li>
</ul>
<h2> <span style="color: #3366ff;">Internals </span></h2>
<p>For those interested in how the compiler works, there are a number of
features to allow you to "look under the hood" and see what it is doing.
These are invoked by compiler directives. These include:</p>
<ul><li><code>$SHOW</code> to cause the compiler to tell what token (symbol)
it is processing, block structure, variable assignment, code it is
generating, etc. These should be used sparingly, as they can generate
voluminous output. But for determining what happens when a particular
statement or line is scanned or compiled, it can be an invaluable
resource. </li>
<li><code>$HIDE</code> allows some or all of the <code>\$SHOW</code> flags
set to be turned off.</li>
<li>While the directives are shown in upper case and the flags are shown
in lower case, the <code>$SHOW</code> and <code>$HIDE</code>
directives, and the flags are not case sensitive.</li>
<li>Scanning options include, with <code>$SHOW</code> enabling the
display, and <code>$HIDE</code> suppressing the display, of:</li>
<li><code>$SHOW keywords</code> to display when a keyword like <code>IF</code>, <code>DO</code>. <code>IMPLEMENTATION</code>, <code>ELSE</code> etc. is seen.</li>
<li><code>$SHOW symbols</code> to display when individual symbols, like <code>&lt;</code>, <code>:=</code> or ^ are found.</li>
<li><code>$SHOW block</code> to show when the three major block types: <code>BEGIN</code>  - <code>END</code>; <code>REPEAT</code> - <code> UNTIL</code>; and the <code>ELSE</code> - <code>END</code> clause in a <code>CASE</code> statement, are found.</li>
<li><code>$SHOW identifiers</code> to show when they are defined or used.</li>
<li><code>$SHOW procedure</code> or <code>$SHOW function</code> to display
when a procedure or function signature is spotted, or <code>$SHOW procfunc </code>(or <code>$SHOW procfunc</code>) to show both.</li>
<li><code>\$SHOW limit n</code> causes the compilei to show processing 
output for only the next <code>n</code> items before stopping. </li>
<li><code>$HIDE limit n</code> stops showing the next n symbols before 
continuing.</li>
<li><code>$SHOW token</code> turns all of these on (except <code>$SHOW</code>/<code>$HIDE limit</code>.)   Can produce huge amounts of information, be forewarned.</li>
<li><code>$SHOW code</code> to display what assembly statements and data
are being generated.</li>
<li><code>$SHOW codegen</code> to display what procedures or functions are
being called to generate the code..</li>
<li><code>$SHOW all</code> and <code>$HIDE all </code>display or stop
displaying everything listed above.</li>
<li><code>$SHOW narrow</code> to display one token per screen line.
Otherwise symbols are shown one after another until the source line
ends. </li>
<li><code>$SHOW wide</code> reverses <code>$SHOW narrow.</code></li>
<li>While a large part of these have been implemented, not everything is
completely handled; the most important part was to get some conditional
compilation features <code>$IFDEF</code>, <code>$IFNDEF</code>, <code>$DEFINE</code> and <code>$UNDEF</code> and the <code>$INCLUDE</code> feature working. But, these were helpful in allowing me to find where to make other fixes.</li>
<li>Lots more comments, suggestions and hints have been added to the
source code to explain what certain things the compiler does or what
things are happening.</li>
</ul>
<h1><span style="color: #3366ff;">And now, a look back at Version 0.14.1</span></h1>
<p>The following were my goals I mentioned in the readme for Version 0.15.
Let's see how I did:</p>
<table width="100%" border="1"><tbody>
<tr><td width="1%"><img src="redx.svg" alt="Fail" title="No" height="22" width="22"><br></td>
<td><i>Change compiler internals to use a linked list for identifiers
instead of an array. </i>Never even got there. If the compiler is
going to be capable of compiling larger programs, it will need to
use a linked list in dynamic memory for the symbol table. This is
the first compiler I've seen use an array of records to define its
symbol table instead of a linked list. Potentially the same thing
applies to the list of types, which the entries in the identifier
table refer to. </td></tr>
<tr><td><img src="green_check.svg" alt="OK" title="Yes" height="25" width="25"><br></td>
<td><em>Support (* *) comments</em>. Completely done.<br></td></tr>
<tr><td><img src="redx.svg" alt="Fail" title="No" height="22" width="22">
</td>
<td><em>Add the NAME qualifier for external routines that might be in
characters not legal for use as Pascal identifiers.</em> Couldn't
even get to it.&nbsp; Probably not even necessary.</td></tr>
<tr><td><img src="redx.svg" alt="Fail" title="No" height="22" width="22">
</td>
<td><em>Allow insertion of assembly instructions.</em> Just not enough 
time. I think I'm overestimating my capabilities. Even a very simple 
mini-assembler might have taken a week or more to implement.</td></tr
><tr><td><img src="green_check.svg" alt="OK" title="Yes" height="25" width="25"></td>
<td><em>More compiler directives...</em> Definitely got this.<br></td></tr>
<tr><td style="width: 20px;"><img src="redx.svg" alt="Fail" title="No" height="22" width="22"> </td>
<td style="width: 710px;"><em>... including support for listing and cross-reference of variables.</em> I barely got <code>$INCLUDE</code> to work on the morning of 2020-12-31. Implementing a proper cross-reference feature would, again, have taken too long. That is why I've decided to work full time on creating one, as I explain below.
</td></tr>
<tr><td><img src="green_check.svg" alt="OK" title="Yes" height="25" width="25"></td>
<td><em>When warning about unused variables, it reports where they
were declared.</em> Got this one.</td></tr>
<tr><td><img src="redx.svg" alt="Fail" title="No" height="22" width="22"></td>
<td><em>Start putting in “hooks” to support 64-bit compiling. </em>Never
even got to it. And&nbsp; my assembler skills are very rusty, I'd have to go through what has to change. That would be a huge project as well..</td></tr>
<tr><td><img src="redx.svg" alt="Fail" title="No" height="22" width="22"></td>
<td>Add support for 64-bit integers. I didn't have time to implement
it, and even so, most people do not expect to do 64-bit arithmetic
in a 32-bit application. </td></tr>
<tr><td><img src="redx.svg" alt="Fail" title="No" height="22" width="22"></td>
<td><em>Add the placing of file parameters on the PROGRAM statement </em>This
was done, although the parameters are ignored, except to count them.</td></tr>
<tr><td><img src="green_check.svg" alt="OK" title="Yes" height="25" width="25"></td>
<td><em>Add compile-time conditional compilation </em>The first part,
conditional variables and <code>$IFDEF</code>/<code>$IFNDEF</code>/<code>$ELSE</code> has been completed. $IF and $ELSEIF could not be competed.</td></tr>
<tr><td><img src="redx.svg" alt="Fail" title="No" height="22" width="22"></td>
<td><em>Optionally generate assembly language files</em>&nbsp; I
wonder if I thought I was Superman and able to accomplish
everything. </td></tr>
<tr><td><img src="redx.svg" alt="Fail" title="No" height="22" width="22"></td>
<td><em>Separating the code generated from the compiler so it could be
used to develop for other machines or other operasting systems</em>
Perhaps I should get partial credit hetr; that could not have neen
done until both conditional compilation and include file support
could be added. Or maybe include support wasn't needed but you'd
then have to include every machine architecture call or special
setting. </td></tr></tbody></table>
<p>I will say there is one inadvertant problem the compiler has. One thing:
I think the parser is "too tightly integrated" into the code generator. If 
someone uses a FOR statement, the parser should simply tell the code
generator, "prepare to handle a <code>FOR</code> statement" (or <code>REPEAT</code>, or start of a <code>PROCEDURE</code>), then "start <code>FOR</code> loop, use this control variable, start with this value, end with this
value" and let the code generator handle it. Then at the end, tell the code generator "End of <code>FOR</code> loop," "end of <code>WHILE</code> statement," "<code>ELSE</code> clause in <code>IF</code> statement," etc., and let the code generator handle it. The parser does not need to know that the program must push four registers on the stack, or clear the EAX register, that's the code generator's job. From a standpoint of making the compiler portable for other processors or other operating systems, or both, that is the way it should be done. But XDPascal wasn't really designed for portability, which is why the "leakage" of information from the Code Generator to the Parser is inadvertant. This is probably one thing that needs to change. I've seen it in other compilers, especially ones like the subset Pascal-S, or the Standard Pascal P5 compiler, where the generation of P-code (a forerunner of the Java Virtual Machine bytecode) is tied to the scanning and parsing of the program. If these are 
not segregated, the compiler becomes "too tightly bound" and making changes or improvements can be very difficult. But I think making the compiler capable of being machine independence, and thus portability to other architectures, operating systems, or even operating modes (like having the compiler generate a different language instead of machine code, such as a Pascal to C translator) becomes possible. </p>
<p>I think having a compiler be "modular" and separating the pieces is a good idea; that way if you want to switch how source is scanned, or how code is generated, as long as the interface - the procedure calls to perform actions - is the same, any piece can be replaced with another, possibly better one. Or one to use a different method. For example, the program reads the source file by opening it, determining its size, requesting a block of memory big enough to hold it, then simply "reading" the file by moving a byte from memory. This is obviously much faster than doing an operating system request to read one bite. If the compiler is moved to a system where files are read a record ata time (like mainframes, or if source was being retrieved from a database or an archive) then it may be necessary to change how files are accessed, possibly to doing multiple reads one after another or reading the whole file as a block and using reference counting to know where line endings are. (Knowing line endings is important for two reasons:</p>
<ol><li>To know when a // comment ends, and</li>
<li>To know if a quoted string was not closed by the end of a line.</li></ol>
<p>So, I guess that is one of the things I can put down for the future, to
make the compiler as modular as I can so each "subsystem" can be upgraded,
or replaced, without affecting any other subsystem that depends upon
it.&nbsp; We'll see what happens. </p>
<p>I'm going to take a break from working on XDPascal for a wile to work on
something I think is desperately needed, especially since Pascal compilers
either stopped providing it or never did: a cross-reference and listing
program. There have been many cross-reference programs written before, but
they were written before UCSD Pascal and later the Object Pascal standard
gave us units, and include files. A listing program allows you to print
out your program (and now, it could also generate an HTML or a PDF
listing), but a cross-reference is a critical tool in understanding how
your (or someone else's) program works. It can allow you to identify
unused variables, constants, types or procedures and functions. It can
also identify what functions or procedures call, or are called by, whom.
And the same thing for units. If you have an identifier in one unit being
used in a different one (or where in the other unit it is being used), the
cross-reference can tell you. Also, one thing this can do, which I saw
with the LUA compiler documentation, is to create "clickable links" where
a variable is referenced in an HTML file, clicking on the variable can
have it jump to the definition in the same or a different file. Extremely
useful when trying to figure out what a particular part of an application
is doing, or to spot unintended side effects. While for a smaller program
like the compiler, it would be nice,&nbsp; when you get to something like
the Free Pascal compiler, which is potentially hundreds of files and
dozens of units, it is probably critical to have. And having finished this
work on XDPascal, a good cross-reference tool is something I think we need
much more than another Pascal compiler. (Plus it has the added benefit
that if I create a separate cross-reference program, I don't have to add
the feature to the compiler. It also then becomes available for other
programs that use features XDPascal does not support, like objects,
operator overloading, virtual methods, etc.)</p>
<p>I also have another program (completely unrelated to Pascal) that I want
to release in time for a contest in June 2021. So I'm going to be busy,
but I intend to come back to XDPascal before too long, and add
improvements. While it may have been Vasily's baby, it's my child now, and
I want to see what I can help it grow up to become.</p>
<p>I hope you enjoy this new release as much as I enjoyed creating it. I do
want to thank Vasiliy Tereshkov who created the previous releases through
0.12 and made this whole thing possible. (Although I might have simply
started with something else, it might not have been as good.) </p>
<p>Paul Robinson<br>
January 1-2, 2021</p>

XDPascal for Windows Version 0.15

This is the documentation for the release of version 0.15 of the XDPascal
compiler (December 31, 2020, code name “New Years Eve”), written by the
current maintainer, Paul Robinson. The project home is https://XDPascal.com, it can be downloaded from there, from Github, or from Sourceforge, and bugs can be reported at https://bugs.xdpascal.com, (currently using Mantis; I may switch to Bugzilla) or by e-mail to XDPascal@xdpascal.com.

XDPascal is a 32-bit one-pass self-hosting Pascal compiler for Windows on X86 processors. It is open source, written in Pascal (it is used to compile itself), and licensed under the BSD-2 clause license. There have been a number of major improvements from version 0.14.1. I didn’t get to everything I had planned to accomplish (who does?) as I set an aggressive schedule to complete the compiler by December 31, 2020 and met it. (I have found if you don’t set a schedule and stick to it, development goes on
forever, or until the resources run out.) The most important things I planned to do did get accomplished. Here are some of the new features:

    Include files. Using the $I filename or $INCLUDE filename directive, the contents of a file can be included at that point in the program, as if the entire file had been inserted in place of the comment. To prevent “crock recursion” (a file directly or indirectly including itself, causing an endless loop) only one $INCLUDE file at a time may be invoked.
    You can create compile-time definitons. The compiler supports the compiler directives DEFINE</code>and<code>DEFINE</code> and <code>DEFINE</code>and<code>UNDEF to create and erase compile-time symbols. Symbols can be defined, defined as a number value, or defined as having a string value. While this feature is nice, it serves no purpose if you can’t use it to cause the compiler to do something, which brings us to…
    Conditional compilation: by use of the $IFDEF
    and $IFNDEF directives, to test whether a compile-time variable is or is not defined.  If the test succeeds, the compiler continues scanning and compiling the source. If the test fails, the compiler skips over the code in the unit or program until a $ELSE or $ENDIF directive is found. You can compile code for some conditions and not others through $IFDEF which checks to see if a particular compile-time variable is defined, or $IFNDEF to check if it is not defined. (I didn’t have enough time to get $IF and $ELSEIF implemented, but that will probably get done in a later release.)
    Conditional identifiers. The conditional identifier XDP is automatically included by the compiler, so it is possible to test
    which compiler a program is being targeted for. I’m thinking, if anything in the XDPascal compiler is not compatible with Free Pascal or Gnu Pascal (giving someone a choice of which compiler to use) a programmer can put {$IFDEF xdp} or ($IFDEF xdp) before code specifically to be compiled by XDPascal, as well as $IFNDEF xdp for code for a different compiler. Or an $IFDEF with a different compiler’s symbol and $ELSE for portions to compile with XDPascal or any other compiler.
    Additional conditional identifiers used to identify the compiler are also defined :
        XDP_FULLVERSION which has the value 150 (for version 0.15, the .0 is implied)
        XDP_VERSION  which is defined as 0
        XDP_RELEASE which is defined as 15; and
        XDP_PATCH which is defined as 0. 

These definitions were intended to allow checking the compiler version for when new features get added, but when I could not finish $IF and $ELSEIF in time, they became features to be used later.
\$NOTE and \$WARNING can send messages at compile time. They have no effect on the compilation.
\$FATAL and \$STOP directives immediately halt compilation with an optional message. Together with $IFDEF/$IFNDEF/$ELSE they can stop a compile of a program if a feature is not present.
The following lesser things also got done:

    Some recovery from user program errors. While most of the compiler is still "quit on error," there has been an improvement so that some errors simply produce an error message but the compiler continues processing the source program to try and spot more potential errors. The compiler originally quit on all errors, so if there were any it never reached the linker, which creates the executable. As a result if the program finished compiling it always called the linker to bind the user's program. Now, the linker will only be called if the error count is zero. This means there is the potential for the compiler to be able to scan an entire program and report all further syntax errors, if any.
    Additional comment type (*. As was announced in the previous release, the compiler supports (* *) as well as { } block comments. Diverting from Standard Pascal, comments do not nest. e.g. a { comment } may be inside of a (* comment *) and vice-versa; and the terminators cannot be mixed, i.e. { must be closed by } while (* must be closed by *). (*) at the start of a comment does not close that comment .
    More Standard Pascal support. The symbol pair (.may be used interchangeably with [ (open bracket) and the symbols .) may be used interchangeably with ] (close bracket).
    Better reporting of errors, e.g. if you declare a procedure or function in the INTERFACE section of a UNIT (or a forward declaration in the main program or the IMPLEMENTATION section of a UNIT) and the header of the procedure or function declaration (the "signature") does not match the signature of the procedure or function when it is defined, the compiler will more precisely say why (2 arguments in the declaration but 3 in the definition; argument names or types don't match, e.g. defining an argument as real but declaring it as integer, etc.)
    More compiler directives. A (*$ or {$ comment tells the compiler you want to instruct it about something, separate from the code it generates based on the instructions in the program. There are a number of directives for tracing what the compiler does (very useful if you want to modify it), to support features, or to learn things.
    Much more information about the user program is available, including the number of identifiers used, and now number of procedures and functions, including how many are local to the program and how many are calls to external routines.
    Several "exercise" programs test compiler functionality, such as the $I filename/$INCLUDE filename directive and conditional compilation (see below).
    Several error programs check the compiler's processing of error conditions (to try to implement recovery and continued syntax checking).
    Ampersand (&) may be used before an identifier if it might be the same as a keyword.
    Optional dereference operator. Borrowing from the "New Stanford Pascal" mainframe Pascal compiler (on GitHub), the symbol -> may be used interchangeably with ^ for the dereference operator.

Internals

For those interested in how the compiler works, there are a number of features to allow you to "look under the hood" and see what it is doing. These are invoked by compiler directives. These include:

    $SHOW to cause the compiler to tell what token (symbol) it is processing, block structure, variable assignment, code it is generating, etc. These should be used sparingly, as they can generate voluminous output. But for determining what happens when a particular statement or line is scanned or compiled, it can be an invaluable resource.
    $HIDE allows some or all of the \$SHOW flags set to be turned off.
    While the directives are shown in upper case and the flags are shown in lower case, the $SHOW and $HIDE directives, and the flags are not case sensitive.
    Scanning options include, with $SHOW enabling the display, and $HIDE suppressing the display, of:
    $SHOW keywords to display when a keyword like IF, DO. IMPLEMENTATION, ELSE etc. is seen.
    $SHOW symbols to display when individual symbols, like <, := or ^ are found.
    $SHOW block to show when the three major block types: BEGIN - END; REPEAT - UNTIL; and the ELSE - END clause in a CASE statement, are found.
    $SHOW identifiers to show when they are defined or used.
    $SHOW procedure or $SHOW function to display when a procedure or function signature is spotted, or $SHOW procfunc (or $SHOW procfunc) to show both.
    \$SHOW limit n causes the compilei to show processing output for only the next n items before stopping.
    $HIDE limit n stops showing the next n symbols before continuing.
    $SHOW token turns all of these on (except $SHOW/$HIDE limit.) Can produce huge amounts of information, be forewarned.
    $SHOW code to display what assembly statements and data are being generated.
    $SHOW codegen to display what procedures or functions are being called to generate the code..
    $SHOW all and $HIDE all display or stop displaying everything listed above.
    $SHOW narrow to display one token per screen line. Otherwise symbols are shown one after another until the source line ends.
    $SHOW wide reverses $SHOW narrow.
    While a large part of these have been implemented, not everything is completely handled; the most important part was to get some conditional compilation features $IFDEF, $IFNDEF, $DEFINE and $UNDEF and the $INCLUDE feature working. But, these were helpful in allowing me to find where to make other fixes.
    Lots more comments, suggestions and hints have been added to the source code to explain what certain things the compiler does or what things are happening.

And now, a look back at Version 0.14.1

The following were my goals I mentioned in the readme for Version 0.15. Let's see how I did:
Fail
	Change compiler internals to use a linked list for identifiers instead of an array. Never even got there. If the compiler is going to be capable of compiling larger programs, it will need to use a linked list in dynamic memory for the symbol table. This is the first compiler I've seen use an array of records to define its symbol table instead of a linked list. Potentially the same thing applies to the list of types, which the entries in the identifier table refer to.
OK
	Support (* *) comments. Completely done.
Fail 	Add the NAME qualifier for external routines that might be in characters not legal for use as Pascal identifiers. Couldn't even get to it.  Probably not even necessary.
Fail 	Allow insertion of assembly instructions. Just not enough time. I think I'm overestimating my capabilities. Even a very simple mini-assembler might have taken a week or more to implement.
OK 	More compiler directives... Definitely got this.
Fail 	... including support for listing and cross-reference of variables. I barely got $INCLUDE to work on the morning of 2020-12-31. Implementing a proper cross-reference feature would, again, have taken too long. That is why I've decided to work full time on creating one, as I explain below.
OK 	When warning about unused variables, it reports where they were declared. Got this one.
Fail 	Start putting in “hooks” to support 64-bit compiling. Never even got to it. And  my assembler skills are very rusty, I'd have to go through what has to change. That would be a huge project as well..
Fail 	Add support for 64-bit integers. I didn't have time to implement it, and even so, most people do not expect to do 64-bit arithmetic in a 32-bit application.
Fail 	Add the placing of file parameters on the PROGRAM statement This was done, although the parameters are ignored, except to count them.
OK 	Add compile-time conditional compilation The first part, conditional variables and $IFDEF/$IFNDEF/$ELSE has been completed. $IF and $ELSEIF could not be competed.
Fail 	Optionally generate assembly language files  I wonder if I thought I was Superman and able to accomplish everything.
Fail 	Separating the code generated from the compiler so it could be used to develop for other machines or other operasting systems Perhaps I should get partial credit hetr; that could not have neen done until both conditional compilation and include file support could be added. Or maybe include support wasn't needed but you'd then have to include every machine architecture call or special setting.

I will say there is one inadvertant problem the compiler has. One thing: I think the parser is "too tightly integrated" into the code generator. If someone uses a FOR statement, the parser should simply tell the code generator, "prepare to handle a FOR statement" (or REPEAT, or start of a PROCEDURE), then "start FOR loop, use this control variable, start with this value, end with this value" and let the code generator handle it. Then at the end, tell the code generator "End of FOR loop," "end of WHILE statement," "ELSE clause in IF statement," etc., and let the code generator handle it. The parser does not need to know that the program must push four registers on the stack, or clear the EAX register, that's the code generator's job. From a standpoint of making the compiler portable for other processors or other operating systems, or both, that is the way it should be done. But XDPascal wasn't really designed for portability, which is why the "leakage" of information from the Code Generator to the Parser is inadvertant. This is probably one thing that needs to change. I've seen it in other compilers, especially ones like the subset Pascal-S, or the Standard Pascal P5 compiler, where the generation of P-code (a forerunner of the Java Virtual Machine bytecode) is tied to the scanning and parsing of the program. If these are not segregated, the compiler becomes "too tightly bound" and making changes or improvements can be very difficult. But I think making the compiler capable of being machine independence, and thus portability to other architectures, operating systems, or even operating modes (like having the compiler generate a different language instead of machine code, such as a Pascal to C translator) becomes possible.

I think having a compiler be "modular" and separating the pieces is a good idea; that way if you want to switch how source is scanned, or how code is generated, as long as the interface - the procedure calls to perform actions - is the same, any piece can be replaced with another, possibly better one. Or one to use a different method. For example, the program reads the source file by opening it, determining its size, requesting a block of memory big enough to hold it, then simply "reading" the file by moving a byte from memory. This is obviously much faster than doing an operating system request to read one bite. If the compiler is moved to a system where files are read a record ata time (like mainframes, or if source was being retrieved from a database or an archive) then it may be necessary to change how files are accessed, possibly to doing multiple reads one after another or reading the whole file as a block and using reference counting to know where line endings are. (Knowing line endings is important for two reasons:

    To know when a // comment ends, and
    To know if a quoted string was not closed by the end of a line.

So, I guess that is one of the things I can put down for the future, to make the compiler as modular as I can so each "subsystem" can be upgraded, or replaced, without affecting any other subsystem that depends upon it.  We'll see what happens.

I'm going to take a break from working on XDPascal for a wile to work on something I think is desperately needed, especially since Pascal compilers either stopped providing it or never did: a cross-reference and listing program. There have been many cross-reference programs written before, but they were written before UCSD Pascal and later the Object Pascal standard gave us units, and include files. A listing program allows you to print out your program (and now, it could also generate an HTML or a PDF listing), but a cross-reference is a critical tool in understanding how your (or someone else's) program works. It can allow you to identify unused variables, constants, types or procedures and functions. It can also identify what functions or procedures call, or are called by, whom. And the same thing for units. If you have an identifier in one unit being used in a different one (or where in the other unit it is being used), the cross-reference can tell you. Also, one thing this can do, which I saw with the LUA compiler documentation, is to create "clickable links" where a variable is referenced in an HTML file, clicking on the variable can have it jump to the definition in the same or a different file. Extremely useful when trying to figure out what a particular part of an application is doing, or to spot unintended side effects. While for a smaller program like the compiler, it would be nice,  when you get to something like the Free Pascal compiler, which is potentially hundreds of files and dozens of units, it is probably critical to have. And having finished this work on XDPascal, a good cross-reference tool is something I think we need much more than another Pascal compiler. (Plus it has the added benefit that if I create a separate cross-reference program, I don't have to add the feature to the compiler. It also then becomes available for other programs that use features XDPascal does not support, like objects, operator overloading, virtual methods, etc.)

I also have another program (completely unrelated to Pascal) that I want to release in time for a contest in June 2021. So I'm going to be busy, but I intend to come back to XDPascal before too long, and add improvements. While it may have been Vasily's baby, it's my child now, and I want to see what I can help it grow up to become.

I hope you enjoy this new release as much as I enjoyed creating it. I do want to thank Vasiliy Tereshkov who created the previous releases through 0.12 and made this whole thing possible. (Although I might have simply started with something else, it might not have been as good.)

Paul Robinson
January 1-2, 2021



#  XDPascal for Windows Version 0.16
For some reason these changes I made to the file do not appear here even though
it was properly COMMITted and I even manually uploaded it. I'm still seeing the old
0.15 release file. I'm not sure what's wrong.

This is the documentation for the (aat this moment upcoming) release of version 0.16 of
the XDPascal compiler (February 2, 2021, code name "Groundhog Day")

Now repeat that 1,000 times. (Yeah, I know that's a weak reference to the
movie of the same name.)

These are the things I got done while also working on a cross-reference tool (as I state below).
- Fixed a nasty bug that broke the Readln processor and that
I hadn't even realized I'd done it; I thought I put everything back as it was.
I had actually broken it in 0.15 because a test program that compileds fine
with Version 0.14.1 (as well as Free Pascal) but had a syntax error now, and
in 0.15.
- In going along with making Pascal more like C, in addition to using $ to
indicate a hexadecimal constant, you can also prefix it with 0x (or 0X) as in
0xBEF, 0xbef. 0xBEF, etc.  So the statements <code>a= $5B;</code> or
<code>a= 0x5B;</code> are equivalent.
- in addition to indicating the alternative when no selector matches on a
CASE statement with ELSE, you may also use OTHERWISE. It has been added as a
reserved word.

There are other things I'm working on but i don't want tol reveal them until
I have them working. If you're readsing this it means I haven't fixed it yet.
The "Radix constant" operator n#x where n is an integer from 2-36 and X is a
number expressed in that base. When it works, you can use it like  17, $11,
or 0x11 with 2#10001, 8#21, 17#10, or 18#G.


# XDPascal Version 0.15

This is the documentation for the release of version 0.15 of the XDPascal compiler (December 31, 2020, code name "New Years Eve"), written by the current maintainer, Paul Robinson. The project home is https://XDPascal.com, it can be downloaded from there, from Github, or from Sourceforge, and bugs can be reported at https://bugs.xdpascal.com, (currently using Mantis; I may switch to Bugzilla) or by e-mail to XDPascal@xdpascal.com. XDPascal is a 32-bit one-pass self-hosting Pascal compiler for Windows on X86 processors. It is open source, written in Pascal (it is used to compile itself), and licensed under the BSD-2 clause license. There have been a number of major improvements from version 0.14.1. I didn't get to everything I had planned to accomplish (who does?) as I set an aggressive schedule to complete the compiler by December 31, 2020 and met it. (I have found if you don't set a schedule and stick to it, development goes on forever, or until the resources run out.) The most important things I planned to do did get accomplished. Here are some of the new features:

- Include files. Using the $I filename or $INCLUDE filename directive, the contents of a file can be included at that point in the program, as if the entire file had been inserted in place of the comment. To prevent "crock recursion" (a file directly or indirectly including itself, causing an endless loop) only one $INCLUDE file at a time may be invoked.
- You can create compile-time definitons. The compiler supports the compiler directives $DEFINE and $UNDEF to create and erase compile-time symbols. Symbols can be defined, defined as a number value, or defined as having a string value. While this  feature is nice, it serves no purpose if you can't use it to cause the compiler to do something, which brings us to...
- Conditional compilation: by use of the $IFDEF and $IFNDEF directives, to test whether a compile-time variable is or is not defined.  If the test succeeds, the compiler continues scanning and compiling the source. If the test fails, the compiler skips over the code in the unit or program until a $ELSE or $ENDIF directive is found. You can compile code for some conditions and not others through $IFDEF which checks to see if a particular compile-time variable is defined, or $IFNDEF to check if it is not defined. (I didn't have enough time to get $IF and $ELSEIF implemented, but that will probably get done in a later release.)
- Conditional identifiers. The conditional identifier XDP is automatically included by the compiler, so it is possible to test which compiler a program is being targeted for. I'm thinking, if anything in the XDPascal compiler is not compatible with Free Pascal or Gnu Pascal (giving someone a choice of which compiler to use) a programmer can put {$IFDEF xdp} or (*$IFDEF xdp*) before code specifically to be compiled by XDPascal, as well as $IFNDEF xdp for code for a different compiler. Or an $IFDEF with a different compiler's symbol and $ELSE for portions to compile with XDPascal or any other compiler.
- Additional conditional identifiers used to identify the compiler are also defined:
- XDP_FULLVERSION which has the value 150 (for version 0.15, the .0 is implied)
- XDP_VERSION  which is defined as 0
- XDP_RELEASE which is defined as 15; and
- XDP_PATCH which is defined as 0.
- These definitions were intended to allow checking the compiler version for when new
features get added, but when I could not finish $IF and $ELSEIF in time, they became features to be used later.
- $NOTE and $WARNING can send messages at compile time. They have no effect on the compilation.
- $FATAL and $STOP directives immediately halt compilation with an optional message. Together
with $IFDEF/$IFNDEF/$ELSE they can stop a compile of a program if a feature is not present.

The following lesser things also got done:

= Some recovery from user program errors. While most of the compiler is still "quit on error," there has been an
improvement so that some errors simply produce an error message but the compiler continues processing the source
program to try and spot more potential errors. The compiler originally quit on all errors, so if there were any
it never reached the linker, which creates the executable. As a result if the program finished compiling it
always called the linker to bind the user's program. Now, the linker will only be called if the error count is
zero. This means there is the potential for the compiler to be able to scan an entire program and report all
further syntax errors, if any.
- Additional comment type (\*. As was announced in the previous release, the compiler supports (* *) as well as
{ } block comments. Diverting from Standard Pascal, comments do not nest. e.g. a { comment } may be inside of a
(* comment \*)  and vice-versa; and the terminators cannot be mixed, i.e. { must be closed by } while (* must be
closed by *). (*) at the start of a comment does not close that comment.
More Standard Pascal support.
-The symbol pair (. may be used interchangeably with \[ (open bracket) and the symbols .) may be used
interchangeably with ] (close bracket).
- Better reporting of errors, e.g. if you declare a procedure or function in the INTERFACE section of a UNIT
(or a forward declaration in the main program or the IMPLEMENTATION section of a UNIT) and the header of the
procedure or function declaration (the "signature") does not match the signature of the procedure or function when
it is defined, the compiler will more precisely say why (2 arguments in the declaration but 3 in the definition;
argument names or types don't match, e.g. defining an argument as real but declaring it as integer, etc.)
- More compiler directives. A (*$ or {$  comment tells the compiler you want to instruct it about something, separate
from the code it generates based on the instructions in the program .  There are a number of directives for tracing
what the compiler does (very useful if you want to modify it), to support features, or to learn things.
- Much more information about the user program is available, including the number of identifiers used, and now number of
procedures and functions, including how many are local to the program and how many are calls to external routines.
- Several "exercise" programs test compiler functionality, such as the $I filename/$INCLUDE filename directive and
conditional compilation (see below).
- Several error programs check the compiler's processing of error conditions (to try to implement recovery and continued syntax
checking).
- Ampersand (&) may be used before an identifier if it might be the same as a keyword.
- Optional dereference operator. Borrowing from the "New Stanford Pascal" mainframe Pascal compiler (on GitHub https://github.com/StanfordPascal/Pascal), the symbol -> may
be used interchangeably with ^ for the dereference operator.

# Internals

For those interested in how the compiler works, there are a number of features to allow you to "look under the hood" and see what it is doing. These are invoked by compiler directives. These include:

-$SHOW to cause the compiler to tell what token (symbol) it is processing, block structure, variable assignment, code it is generating, etc. These should be used sparingly, as they can generate voluminous output. But for determining what happens when a particular statement or line is scanned or compiled, it can be an invaluable resource.
-$HIDE allows some or all of the $SHOW flags set to be turned off.
-While the directives are shown in upper case and the flags are shown in lower case, the $SHOW and $HIDE directives, and the flags are not case sensitive.
-Scanning  options include, with $SHOW enabling the display, and $HIDE suppressing the display, of:
-    $SHOW keywords to display when a keyword like IF, DO. IMPLEMENTATION, ELSE  etc. is seen.
-    $SHOW symbols to display when individual symbols, like <, := or ^ are found.
-    $SHOW block to show when the three major block types: BEGIN - END; REPEAT - UNTIL; and the ELSE - END clause in a CASE statement, are found.
-    $SHOW identifiers to show when they are defined or used.
-    $SHOW procedure, $SHOW function to display when a procedure or function signature is spotted, or $SHOW procfunc (or $SHOW procfunc)  to show both
-    $SHOW limit n causes the compilei to show processing output for only the next n items before stopping.
-    $HIDE limit n stops showing the next n symbols before continuing.
-    $SHOW token turns all of these on (except $SHOW/$HIDE limit..) Can produce huge amounts of information, be forewarned.
-    $SHOW code to display what assembly statements and data are being generated.
-    $SHOW codegen to display what procedures or functions are being called to generate the code..
-    $SHOW all and $HIDE all display or stop displaying everything listed above.
-    $SHOW narrow to display one token per screen line. Otherwise symbols are shown one after another until the source line ends.
-    $SHOW wide reverses $SHOW narrow.
-    While a large part of these have been implemented, not everything is completely handled; the most important part was to get
some conditional compilation features $IFDEF, $IFNDEF, $DEFINE and $UNDEF and the $INCLUDE feature working. But, these were helpful
in allowing me to find where to make other fixes.
-    Lots more comments, suggestions and hints have been added to the source code to explain what certain things the compiler does or what things are happening.


# And now, a look back at Version 0.14.1

The following were my goals I mentioned in the readme for Version 0.15. Let's see how I did:
- ![](redx.svg) Change compiler internals to use a linked list for identifiers instead of an array. Never even got there. If the compiler is going to be capable
of compiling larger programs, it will need to use a linked list in dynamic memory for the symbol table. This is the first compiler I've seen use an array of
records to define its symbol table instead of a linked list. Potentially the same thing applies to the list of types, which the entries in the identifier table
refer to.
- ![](green_check.svg) Support (* *) comments. Completely done.
- ![](redx.svg) Add the NAME qualifier for external routines that might be in characters not legal for use as Pascal identifiers. Couldn't even get to it.
Probably not even necessary.
- ![](redx.svg)  Allow insertion of assembly instructions. Just not enough time. I think I'm overestimating my capabilities. Even a very simple mini-assembler
might have taken a week or more to implement.
- ![](green_check.svg) 	More compiler directives... Definitely got this.
- ![](redx.svg) ... including support for listing and cross-reference of variables. I barely got $INCLUDE to work on the morning of 2020-12-31. Implementing
a proper cross-reference feature would, again, have taken too long. That is why I';ve decided to work full timev on creating one, as I explain below.
- ![](green_check.svg) 	When warning about unused variables, it reports where they were declared. Got this one.
- ![](redx.svg) Start putting in “hooks” to support 64-bit compiling. Never even got to it. And  my assembler skills are very rusty, I'd have to go through
what has to change. That would be a huge project as well..
- ![](redx.svg) Add support for 64-bit integers. I didn't have time to implement it, and even so, most people do not expect to do 64-bit arithmetic in a 32-bit application.
- ![](redx.svg) Add the placing of file parameters on the PROGRAM statement This was done, although the parameters are ignored, except to count them.
- ![](green_check.svg) 	Add compile-time conditional compilation The first part, conditional variables and $IFDEF/$IFNDEF/$ELSE has been completed. $IF and $ELSEIF could not be competed.
- ![](redx.svg) Optionally generate assembly language files  I wonder if I thought I was Superman and able to accomplish everything.
- ![](redx.svg) Separating the code generated from the compiler so it could be used to develop for other machines or other operasting systems Perhaps
I should get partial credit there; that could not have neen done until both conditional compilation and include file support could be added. Or maybe
include support wasn't needed but you'd then have to include every machine architecture call or special setting.

I will say there is one inadvertant problem the compiler has. One thing: I think the parser is "too tightly integrated" into the code generator. If someone uses a FOR statement, the parser should simply tell the code generator, "prepare to handle a FOR statement" (or REPEAT, or start of a PROCEDURE), then "start FOR loop, use this control variable, start with this value, end with this value" and let the code generator handle it. Then at the end, tell the code generator "End of FOR loop," "end of WHILE statement," "ELSE clause in IF statement," etc., and let the code generator handle it. The parser does not need to know that the program must push four registers on the stack, or clear the EAX register, that's the code generator's job. From a standpoint of making the compiler portable for other processors or other operating systems, or both, that is the way it should be done. But XDPascal wasn't really designed for portability, which is why the "leakage" of information from the Code Generator to the Parser is inadvertant. This is probably one thing that needs to change. I've seen it in other compilers, especially ones like the subset Pascal-S, or the Standard Pascal P5 compiler, where the generation of P-code (a forerunner of the Java Virtual Machine bytecode) is tied to the scanning and parsing of the program. If these are not segregated, the compiler becomes "too tightly bound" and making changes  or improvements can be very difficult. But I think making the compiler capable of being machine independence, and thus portability to other architectures, operating systems, or even operating modes (like having the compiler generate a different language instead of machine code, such as a Pascal to C translator) becomes possible.

I  think having a compiler be "modular" and separating the pieces is a good idea; that way if you want to switch how source is scanned, or how code is generated, as long as the interface - the procedure calls to perform actions - is the same, any piece can be replaced with another, possibly better one. Or one to use a different method. For example, the program reads the source file by opening it, determining its size, requesting a block of memory big enough to hold it, then simply "reading" the file by moving a byte from memory. This is obviously much faster than doing an operating system request to read one bite. If the compiler is moved to a system where files are read a record ata time (like mainframes, or if source was being retrieved from a database or an archive) then it may be necessary to change how files are accessed, possibly to doing multiple reads one after another or reading the whole file as a block and using reference counting to know where line endings are. (Knowing line endings is important for two reasons:

- To know when a // comment ends, and
- To know if a quoted string was not closed by the end of a line.

So, I guess that is one of the things I can put down for the future, to make the compiler as modular as I can so each "subsystem" can be upgraded, or replaced, without affecting any other subsystem that depends upon it.  We'll see what happens.

I'm going to take a break from working on XDPascal for a wile to work on something I think is desperately needed, especially since Pascal compilers either stopped providing it or never did: a cross-reference and listing program. There have been many cross-reference programs written before, but they were written before UCSD Pascal and later the Object Pascal standard gave us units, and include files. A listing program allows you to print out your program (and now, it could also generate an HTML or a PDF listing), but a cross-reference is a critical tool in understanding how your (or someone else's) program works. It can allow you to identify unused variables, constants, types or procedures and functions. It can also identify what functions or procedures call, or are called by, whom. And the same thing for units. If you have an identifier in one unit being used in a different one (or where in the other unit it is being used), the cross-reference can tell you. Also, one thing this can do, which I saw with the LUA compiler documentation, is to create "clickable links" where a variable is referenced in an HTML file, clicking on the variable can have it jump to the definition in the same or a different file. Extremely useful when trying to figure out what a particular part of an application is doing, or to spot unintended side effects. While for a smaller program like the compiler, it would be nice,  when you get to something like the Free Pascal compiler, which is potentially hundreds of files and dozens of units, it is probably critical to have. And having finished this work on XDPascal, a good cross-reference tool is something I think we need much more than another Pascal compiler. (Plus it has the added benefit that if I create a separate cross-reference program, I don't have to add the feature to the compiler. It also then becomes available for other programs that use features XDPascal does not support, like objects, operator overloading, virtual methods, etc.)

I also have another program (completely unrelated to Pascal) that I want to release in time for a contest in June 2021. So I'm going to be busy, but I intend to come back to XDPascal before too long, and add improvements. While it may have been Vasily's baby, it's my child now, and I want to see what I can help it grow up to become.

I hope you enjoy this new release as much as I enjoyed creating it. I do want to thank Vasiliy Tereshkov who created the previous releases through 0.12 and made this whole thing possible. (Although I might have simply started with something else, it might not have been as good.)

Paul Robinson
January 1-2, 2021




# Version 0.14.1:

#XDPW - XD Pascal for Windows: A 32-bit compiler

New feature for version 0.14.0

    Error position: When there is an error, the compiler will report Line number and Column in the file, not just line number

New features for version 0.14.1

More statistics:

-  For each unit, the number of lines compiled for that unit is reported
-  Total number of lines compiled is reported
-     Total number of identifiers (Procedure, Function, Const, and Var) used
-     Highest number of identifiers used
-     Total compilation time and total lines compiled per second
-     Date and time compilation began and ended reported
-     Memory usage for code and data reported in decimal and hex
-  Character misuse is flagged:
- Close brace } used without a preceding { will warn a person of an incorrect comment
- Using double quote “ is flagged, warning that only \' is allowed
- When an illegal character is discovered, its position and character value are reporteI

I see XDPW as a teaching (“pedagogical”) and convenience tool, for either doing quick compiles either where using a monolithic, large compiler won't do, or for those
looking for an easy, approachable tool for learning to program. I have plans for the
future of XDPW (in no particular order) including:
-     Change compiler internals to use a linked list for identifiers instead of an array. This will (vastly) increase the size of a program XDPW can compile. It will also demonstrate how to work with linked lists
-  Support (* *) comments
-  Add the NAME qualifier for external routines that might be in characters not
legal for use as Pascal identifiers
-  Allow insertion of assembly instructions in procedures or blocks
-  More compiler directives including support for listing and cross-reference of variables
-   When warning about unused variables, it reports where they were declared,
rather than listing them as being at the end of the main program.
-  Start putting in “hooks” to support 64-bit compiling
-   Add support for 64-bit integers and 64-bit arithmetic as well as automatic type
conversion between byte, word and integer values to and from 64-bit values
-   Add the placing of file parameters on the PROGRAM statement, so files can
be declared
-   Add compile-time conditional compilation
-   Optionally generate assembly language files instead of direct executable programs,
or allow for creating dynamic load libraries (DLLs)
-   Add an “absolute” qualifier for variables accessing internal addresses directly. This is important for certain system programs or hardware access applications
-   Insert support for “C-style” assignment operators: +=, -=, *=, and /=
-  A rudimentary text editor for quick source code fixes
-  Add the & prefix to allow an identifier to be the same as a reserved word
-  Implement the ability to “compile to memory” so a program can be compiled and
run inside the compiler similar to the original Turbo Pascal compiler
-   Separating the code generated from the compiler so it could be used to develop
for other machines or other operasting systems

I don;t know how much of this I can actually accomplih, but I have to set (reasonable) goals.

I do not expect XDPW to be the “ultimate” go to tool for writing large applications. GNU Pascal and especially Free Pascal do a tremendoius job; in fact, I use the Lazarus editor (nominally used for creating forms-based Free Pascal applications) for working on XDPW. But sometimes Free Pascal is just too slow and bloated for quick edit-compile cycles

What XDPW does well is quick development of small to medium sized programs
or for “toolbox” work: when you need a quick, simple program to automate a
task or to figure out how to do something. Or specifically how to write a compiler.
Compilers do a lot of complex work analyzing files and records, and is something
worth exploring. XDPW is not a“toy,”you can use it to do actual, real work, in a
format that is much more accessable and “approachable” than other monolithic
compilers like GNU Pascal, Delphi or Free Pascal. It's also very efficient. Code
generated by XDPW can be 90% smaller, programs developed by it can use
1/10 the space of a similar text-mode application compiled by a full-size compiler.

I mean, the Free Pascal compile is a world-class, full-service compiler capable of
taking on even extremely large programs. I happen to like it. But I can never
understand what it is doing; the compiler source code alone is over 250,000
lines! Plus hundreds to thousands more for each specific CPU it targets. Add to
that tens of thousands more lines of code for the run-time libraries and it's too
big for one person to get their head around. At under 15,000 lines, XDPW is very
approachable for one person wanting to learn how a compiler works.


Come learn with us!
Paul Robinson



# From Version 0.12

<img src="logo.png">

# XD Pascal for Windows

_Dedicated to my father Mikhail Tereshkov, who instilled in me a taste for engineering_

## Summary
XD Pascal is a small embeddable self-hosting compiler for a Pascal language dialect. Any comments, suggestions, or bug reports are appreciated. Feel free to contact the author on GitHub or by e-mail VTereshkov@mail.ru. Enjoy.

### Features
* [Go-style methods and interfaces](https://medium.com/@vtereshkov/how-i-implemented-go-style-interfaces-in-my-own-pascal-compiler-a0f8d37cd297?source=friends_link&sk=72a20752cb866c716daac13abc1fab22)
* Native x86 code generation (32 bit Windows executables)
* Support for both console and GUI applications
* No external assembler or linker needed
* Floating-point arithmetic using the x87 FPU
* [Integration](https://github.com/vtereshkov/raylib-xdpw) with the [Raylib](https://www.raylib.com) game development library
* Integration with Geany IDE
* Compiler source for Delphi 6/7, Free Pascal and XD Pascal itself (Delphi 2009+ migration is [straightforward](https://github.com/vtereshkov/xdpw/issues/2#issuecomment-573929657))

![](maze.png)

## Detailed description

### Usage
Type in the command prompt:
```
xdpw <file.pas>
```
The source file should be specified with its extension (.pas).

### Language

XD Pascal is similar to Delphi 6/7 and Free Pascal with the following changes:

#### Enhancements
* The compiler is self-hosting
* The compiler is extremely compact (~10000 lines) and can be easily embedded into larger systems
* Go-style methods and interfaces are supported

#### Differences
* Strings are null-terminated arrays of characters (C style), but indexed from 1 for Pascal compatibility
* The `Text` type is equivalent to `file`. It can be used for both text and untyped files
* Method calls and procedural variable calls require parentheses even for empty parameter lists

#### Limitations
* No classical (C++/Delphi style) object-oriented programming
* No visual components
* Units cannot be compiled separately
* Only peephole optimizations
* `Extended` is equivalent to `Double`
* No `High` and `Low` functions for open arrays. Open array length should be explicitly passed to a subroutine
* Statement labels cannot be numerical

#### Formal grammar
```
ProgramOrUnit = [("program" | "unit") Ident ";"]
                ["interface"] [UsesClause] Block "." .

UsesClause = "uses" Ident {"," Ident} ";" .

Block = { Declarations } (CompoundStatement | "end") .

Declarations = DeclarationSection ["implementation" DeclarationSection] .

DeclarationSection = LabelDeclarations |
                     ConstDeclarations |
                     TypeDeclarations |
                     VarDeclarations |
                     ProcFuncDeclarations .

Initializer = ConstExpression |
              StringLiteral |
              "(" Initializer {"," Initializer} ")" |
              "(" Ident ":" Initializer {";" Ident ":" Initializer} ")" |
              SetConstructor .

LabelDeclarations = "label" Ident {"," Ident} ";"

ConstDeclarations = (UntypedConstDeclaration | TypedConstDeclaration)
               {";" (UntypedConstDeclaration | TypedConstDeclaration)} .

UntypedConstDeclaration = "const" Ident "=" ConstExpression .

TypedConstDeclaration = "const" Ident ":" Type "=" Initializer .

TypeDeclarations = "type" Ident "=" Type ";" {Ident "=" Type ";"} .

VarDeclarations = "var" IdentList ":" Type ["=" Initializer] ";"
                       {IdentList ":" Type ["=" Initializer] ";"} .

ProcFuncDeclarations = ("procedure" | "function") Ident
                       [Receiver] [FormalParams] [":" TypeIdent]
                       [CallModifier] ";" [(Directive | Block) ";"] .

Receiver = "for" Ident ":" TypeIdent .

CallModifier = "stdcall" | "cdecl" .

Directive = "forward" | "external" ConstExpression .

ActualParams = "(" [ (Expression | Designator) |
                {"," (Expression | Designator)} ] ")" .

FormalParams = "(" FormalParamList {";" FormalParamList} ")" .

FormalParamList = ["const" | "var"] IdentList [":" ["array" "of"] TypeIdent]
                                              ["=" ConstExpression] .

IdentList = Ident {"," Ident} .

Type = "(" Ident {"," Ident} ")" |
       "^" TypeIdent |
       ["packed"] "array" "[" Type {"," Type} "]" "of" Type |
       ["packed"] "record" Fields "end" |
       ["packed"] "interface" FixedFields "end" |
       ["packed"] "set" "of" Type |
       ["packed"] "string" [ "[" ConstExpression "]" ] |
       ["packed"] "file" ["of" Type] |
       ConstExpression ".." ConstExpression |
       ("procedure" | "function") [FormalParams] [":" TypeIdent] [CallModifier] |
       Ident .

Fields = FixedFields
           ["case" [Ident ":"] Type "of"
               ConstExpression {"," ConstExpression} ":" "(" Fields ")"
          {";" ConstExpression {"," ConstExpression} ":" "(" Fields ")"}] [";"] .

FixedFields = IdentList ":" Type {";" IdentList ":" Type} .

TypeIdent = "string" | "file" | Ident .

Designator = BasicDesignator {Selector} .

BasicDesignator = Ident |
                  Ident [ActualParams] |
                  Ident "(" Expression ")" .

Selector = "^" |
           "[" Expression {"," Expression} "]" |
           "." Ident |
           "(" ActualParams ")".

Statement = [Label ":"] [ (Designator | Ident) ":=" Expression |
                          (Designator | Ident) [ActualParams] {Selector} |
                          CompoundStatement |
                          IfStatement |
                          CaseStatement |
                          WhileStatement |
                          RepeatStatement |
                          ForStatement |
                          GotoStatement |
                          WithStatement ] .

Label = Ident .

StatementList = Statement {";" Statement} .

CompoundStatement = "begin" StatementList "end" .

IfStatement = "if" Expression "then" Statement ["else" Statement] .

CaseStatement = "case" Expression "of" CaseElement {";" CaseElement}
                    [";"] ["else" StatementList] [";"] "end" .

WhileStatement = "while" Expression "do" Statement .

RepeatStatement = "repeat" StatementList "until" Expression .

ForStatement = "for" Ident ":=" Expression ("to" | "downto") Expression "do" Statement.

GotoStatement = "goto" Label .

WithStatement = "with" Designator {"," Designator} "do" Statement .

CaseElement = CaseLabel {"," CaseLabel} ":" Statement .

CaseLabel = ConstExpression [".." ConstExpression] .

ConstExpression = Expression .

Expression = SimpleExpression [("="|"<>"|"<"|"<="|">"|">="|"in") SimpleExpression] .

SimpleExpression = ["+"|"-"] Term {("+"|"-"|"or"|"xor") Term}.

Term = Factor {("*"|"/"|"div"|"mod"|"shl"|"shr"|"and") Factor}.

Factor = (Designator | Ident) [ActualParams] {Selector} |
         Designator |
         "@" Designator |
         Number |
         CharLiteral |
         StringLiteral |
         "(" Expression ")" |
         "not" Factor |
         SetConstructor |
         "nil" |
         Ident "(" Expression ")" {Selector} .

SetConstructor = "[" [Expression [".." Expression]
                     {"," Expression [".." Expression]}] "]" .

Ident = (Letter | "_") {Letter | "_" | Digit}.

Number = "$" HexDigit {HexDigit} |
         Digit {Digit} ["." {Digit}] ["e" ["+" | "-"] Digit {Digit}] .

CharLiteral = "'" (Character | "'" "'") "'" |
              "#" Number .

StringLiteral = "'" {Character | "'" "'"} "'".
```

### Compiler
The compiler is based on a recursive descent parser. It directly builds a Windows PE executable without using any external assembler or linker.

#### Directives
* `$APPTYPE` - Set application type. Examples: `{$APPTYPE GUI}`, `{$APPTYPE CONSOLE}`
* `$UNITPATH` - Set additional unit search path. Example: `{$UNITPATH ..\units\}`

#### Optimizations
Some simple peephole optimizations are performed:
* Push/pop elimination
* FPU push/pop elimination
* Local variable loading optimizations
* Array element access optimizations
* Record field access optimizations
* Assignment optimizations
* Comparison optimizations
* Condition testing optimizations

#### Inlined procedures and functions
The following identifiers are implemented as part of the compiler. Their names are not reserved words and can be locally redefined by the user.
```pascal
procedure Inc(var x: Integer);
procedure Dec(var x: Integer);
procedure Read([var F: file;] var x1 {; var xi});
procedure Write([var F: file;] x1[:w[:d]] {; xi[:w[:d]]});
procedure ReadLn([var F: file;] var x1 {; var xi});
procedure WriteLn([var F: file;] x1[:w[:d]] {; xi[:w[:d]]});
procedure New(var P: Pointer);
procedure Dispose(var P: Pointer);
procedure Break;
procedure Continue;
procedure Exit;
procedure Halt[(const error: Integer)];
function SizeOf(var x | T): Integer;
function Ord(x: T): Integer;
function Chr(x: Integer): Char;
function Low(var x: T | T): T;
function High(var x: T | T): T;
function Pred(x: T): T;
function Succ(x: T): T;
function Round(x: Real): Integer;
function Abs(x: T): T;
function Sqr(x: T): T;
function Sin(x: Real): Real;
function Cos(x: Real): Real;
function Arctan(x: Real): Real;
function Exp(x: Real): Real;
function Ln(x: Real): Real;
function SqRt(x: Real): Real;
```

### Standard library

#### System unit
```pascal
function Timer: Integer;
procedure GetMem(var P: Pointer; Size: Integer);
procedure FreeMem(var P: Pointer);
procedure Randomize;
function Random: Real;
procedure Assign(var F: file; const Name: string);
procedure Rewrite(var F: file[; BlockSize: Integer]);
procedure Reset(var F: file[; BlockSize: Integer]);
procedure Close(var F: file);
procedure BlockRead(var F: file; var Buf; Len: Integer; var LenRead: Integer);
procedure BlockWrite(var F: file; var Buf; Len: Integer);
procedure Seek(var F: file; Pos: Integer);
function FileSize(var F: file): Integer;
function FilePos(var F: file): Integer;
function EOF(var F: file): Boolean;
function IOResult: Integer;
function Length(const s: string): Integer;
procedure Move(var Source; var Dest; Count: Integer);
function Copy(const S: string; Index, Count: Integer): string;
procedure FillChar(var Data; Count: Integer; Value: Char);
function ParamCount: Integer;
function ParamStr(Index: Integer): string;
procedure Val(const s: string; var Number: Real; var Code: Integer);
procedure Str(Number: Real; var s: string[; DecPlaces: Integer]);
procedure IVal(const s: string; var Number: Integer; var Code: Integer);
procedure IStr(Number: Integer; var s: string);
function UpCase(ch: Char): Char;
```

#### SysUtils unit
```pascal
function IntToStr(n: Integer): string;
function StrToInt(const s: string): Integer;
function FloatToStr(x: Real): string;
function FloatToStrF(x: Real; Format: TFloatFormat; Precision, Digits: Integer): string;
function StrToFloat(const s: string): Real;
function StrToPChar(const s: string): PChar;
function PCharToStr(p: PChar): string;
function StrToPWideChar(const s: string): PWideChar;
function PWideCharToStr(p: PWideChar): string;
```

### Samples
* `factor.pas`   - Integer factorization demo
* `lineq.pas`    - Linear equation solver. Uses `gauss.pas` unit. Requires `eq.txt`, `eqerr.txt`, or similar data file
* `life.pas`     - The Game of Life
* `sort.pas`     - Array sorting demo
* `fft.pas`      - Fast Fourier Transform demo
* `inserr.pas`   - Inertial navigation system error estimation demo. Uses `kalman.pas` unit
* `list.pas`     - Linked list operations demo
* `map.pas`      - Heterogenous list operations and Map function demo. Demonstrates XD Pascal methods and interfaces
* `gui.pas`      - GUI application demo. Uses `windows.pas` unit
* `raytracer.pas`- Raytracer demo. Demonstrates XD Pascal methods and interfaces. Equivalent to `raytracer.go`

<img src="scene.png">

### Known issues

Windows Defender antivirus is known to give false positive results on some programs compiled with XD Pascal.

