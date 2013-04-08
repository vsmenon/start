//test array and struct
import 'stdio.dart';

class A {
  var x;
  var y;
}

class B {
  var y;
  var a;
}

class C {
  var y;
}

var b;

void init1(var a, var b) {
  b.a = a;
  a.x = 19;
}

void init2(var c) {
  c.y = 23;
  b = c;
}

void main()
{
  var a;
  var b2;
  var c;

  a = new A();
  b = null;
  b2 = new B();
  init1(a, b2);
  init2(a);
  init2(b2);

  WriteLong(b2.a.y + b.y + b2.a.x - 23);
  WriteLine();
  if (b is B) {
    WriteLong(b.y);
    WriteLine();
  }
}

/*
42
*/
