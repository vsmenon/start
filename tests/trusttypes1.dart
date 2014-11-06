import 'dart:math';

class A {
  int x = 42;
}
void bar(A a) {
  // Is this integer addition?
  print(a.x + a.x);
}

void main() {
  List<A> list = <A>[];
  list.add(new A());
  list.add(new B(new Point<int>(1,2)));
  list.forEach((A a) => bar(a));
}

class B extends A {
  var _x;
  B(this._x);

  get x => _x;
}
