//test array and struct
import 'stdio.dart';

class A {
  dynamic value;
  dynamic next;
}

dynamic tmp;
dynamic total;

void init(dynamic count) {
  dynamic a;
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

void sum(dynamic a) {
  if (a == null) {
    total = 0;
  } else {
    sum(a.next);
    total = total + a.value;
  }
}

void main()
{
  dynamic a;
  
  init(10);
  a = tmp;
  sum(a);
  WriteLong(total);
  WriteLine();
}


/*
55
*/
