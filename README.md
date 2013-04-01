Start
===================

Start is a simple 'toy' programming language for investigating different aspects of compiler implementation and optimization.

Start is based upon a subset of the [Dart programming language](http://www.dartlang.org), an optionally typed C-style programming language.  This includes:

- top-level methods
- basic types: int, bool, List, dynamic
- basic control flow: if, while
- classes and heap-allocated objects
- static and dynamic typing

Start omits many features of Dart: it doesn't have inheritance, virtual methods, closures, libraries, and some control flow features (exceptions, switches, for-loops).  It doesn't support any of Dart's libraries.

Although many Start programs run identically in Dart, Start differs in important ways.  The int type is 32-bit and non-nullable in Start but infinite precision and nullable in Dart.  The bool type is non-nullable in Start but nullable in Dart.

The start compiler translates source programs into a bytecode-like intermediate representation.  The start
interpreter executes the bytecode-like representation.

See the [Start Language and Intermediate Form Overview](https://github.com/vsmenon/start/wiki/Language-and-IR-Overview) for more details.

Installation
------------

1.  Download the Dart SDK from here: http://www.dartlang.org/downloads.html

2.  Unzip and add the dart-sdk/bin directory to your path.

3.  Download Start from https://github.com/vsmenon/start.  You can either use git (recommended):
  
    > git clone https://github.com/vsmenon/start.git
  
    Or, download a tarball: https://github.com/vsmenon/start/archive/master.zip

4.  Navigate to the project:
    > cd start

5.  Install dependencies:
    > pub install

6.  Run correctness tests to ensure everything is working:
    > dart bin/test.dart

7.  Run performance tests:
    > dart bin/time.dart

Compile and Run
---------------

You can execute a Start program from source as follows:
  > dart bin/start.dart examples/link.dart

To compile without running, use the `-c` flag:
  > dart bin/start.dart -c examples/link.dart

To save the intermediate code to file, run:
  > dart bin/start.dart -c examples/link.dart > link.start

Finally, to run intermediate code:
  > dart bin/start.dart -r link.start

Performance metrics
-------------------

The Start interpreter provides performance metrics that model a very simple execution machine.  To print these after
execution, use the _-p_ flag.  For example, the following shows the performance of both the typed and untyped version
of _link.dart_:

  > dart bin/start.dart -p examples/link.dart
  
  > dart bin/start.dart -p untyped/link.dart

Acknowledgements
----------------

The Start compiler and intermediate representation are based upon the csc educational compiler developed
by [Martin Burtscher](http://cs.txstate.edu/~mb92/) at UT Austin and used in Prof. Keshav Pingali's
[graduate compiler course](http://www.cs.utexas.edu/users/pingali/CS380C/2007fa/index.html) there.


