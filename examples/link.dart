//test array and struct

import 'stdio.dart';

class A {
  int value;
  A next;
}

A init(int count) {
  A a;
  if (count <= 0) {
    a = null;
  } else {
    a = new A();
    a.value = count;
    a.next = init(count - 1);
  }
  return a;
}

int sum(A a) {
  if (a == null) {
    return 0;
  } else {
    return sum(a.next) + a.value;
  }
}

void main()
{
  A a;

  a = init(10);
  WriteLong(sum(a));
  WriteLine();
}


/*
55
*/
