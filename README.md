Start
===================

Start is a simple 'toy' programming language for investigating different aspects of compiler implementation and optimization.

Start is based upon a subset of the Dart programming language, an optionally typed C-style programming language.  This includes:

- top-level methods
- basic types: int, bool, List, dynamic
- basic control flow: if, while
- classes and heap-allocated objects
- static and dynamic typing

Start omits many features of Dart: it doesn't have inheritance, virtual methods, closures, libraries, and some control flow features (switches, for-loops).  It doesn't support any of Dart's libraries.

Although many Start programs run identically in Dart, Start differs in important ways.  The int type is 64-bit and non-nullable in Start but infinite precision and nullable in Dart.  The bool type is non-nullable in Start but nullable in Dart.

The start compiler translates source programs into a bytecode-like intermediate representation.  The start
interpreter executes the bytecode-like representation.

Installation
------------

1.  Download the Dart SDK from here: http://www.dartlang.org/downloads.html

2.  Unzip and add the dart-sdk/bin directory to your path.

3.  Download Start from https://github.com/vsmenon/start.  You can either:
(a)   Use git (recommended): git clone https://github.com/vsmenon/start.git
(b)   Download a tarball: https://github.com/vsmenon/start/archive/master.zip

4.  Navigate to the project:
  > cd start

5.  Install dependencies:
  > pub install

6.  Run correctness tests:
  > dart bin/test.dart

7.  Run performance tests:
  > dart bin/time.dart
