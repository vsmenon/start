//test array and struct

import 'stdio.dart';

class A {
  var value;
  var next;
}

dynamic init(var count) {
  var a;
  if (count <= 0) {
    a = null;
  } else {
    a = new A();
    a.value = count;
    a.next = init(count - 1);
  }
  return a;
}

dynamic sum(var a) {
  if (a == null) {
    return 0;
  } else {
    return sum(a.next) + a.value;
  }
}

void main()
{
  var a;

  a = init(10);
  WriteLong(sum(a));
  WriteLine();
}


/*
55
*/
