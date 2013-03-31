//test array and struct

import 'stdio.dart';

class A {
  int value;
  A next;
}

A tmp;
int total;

void init(int count) {
  A a;
  if (count <= 0) {
    tmp = null;
  } else {
    init(count - 1);
    a = new A();
    a.value = count;
    a.next = tmp;
    tmp = a;
  }
}

void sum(A a) {
  if (a == null) {
    total = 0;
  } else {
    sum(a.next);
    total = total + a.value;
  }
}

void main()
{
  A a;
  
  init(10);
  a = tmp;
  sum(a);
  WriteLong(total);
  WriteLine();
}


/*
55
*/
