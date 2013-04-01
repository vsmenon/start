//test array and struct
import 'stdio.dart';

class A {
  var value;
  var next;
}

var tmp;
var total;

void init(var count) {
  var a;
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

void sum(var a) {
  if (a == null) {
    total = 0;
  } else {
    sum(a.next);
    total = total + a.value;
  }
}

void main()
{
  var a;

  init(10);
  a = tmp;
  sum(a);
  WriteLong(total);
  WriteLine();
}


/*
55
*/
