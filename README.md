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
