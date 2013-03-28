//test array and struct
import 'stdio.dart';

class A {
  dynamic x;
  dynamic y;
}

class B {
  dynamic y;
  dynamic a;
}

class C {
  dynamic y;
}

dynamic b;

void init1(dynamic a, dynamic b) {
  b.a = a;
  a.x = 19;
}

void init2(dynamic c) {
  c.y = 23;
  b = c;
}

void main()
{
  dynamic a;
  dynamic b2;
  dynamic c;

  a = new A();
  b = null;
  b2 = new B();
  init1(a, b2);
  init2(a);
  init2(b2);

  WriteLong(b2.a.y + b.y + b2.a.x - 23);
  WriteLine();
}

/*
42
*/
