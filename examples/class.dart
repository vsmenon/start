//test array and struct
import 'stdio.dart';

class A {
  int x;
  int y;
}

class B {
  int y;
  A a;
}

class C {
  A y;
}

var b;

void init1(A a, B b) {
  b.a = a;
  a.x = 19;
}

void init2(var c) {
  c.y = 23;
  b = c;
}

void main()
{
  A a;
  B b2;
  C c;

  a = new A();
  b = null;
  b2 = new B();
  init1(a, b2);
  init2(a);
  init2(b2);

  WriteLong(b2.a.y + b.y + b2.a.x - 23);
  WriteLine();
  if (42 is int) {
    WriteLong(b.y);
    WriteLine();
  }
  WriteLong(7);
  WriteLine();
}

/*
42
*/
