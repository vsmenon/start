//test recursive function calls
import 'stdio.dart';

var a, m, q, r;
var count;

dynamic Factorial(var n)
{
  var res;
  if (n == 0) {
    res = 1;
  } else {
    res = n * Factorial(n-1);
  }
  return res;
}


dynamic FibRec(var n)
{
  var x, y, res;

  if (n <= 1) {
    res = 1;
  } else {
    x = FibRec(n-1);
    y = FibRec(n-2);
    res = x + y;
  }
  return res;
}


void MoveDisc(var from, var to)
{
  WriteLong(from);
  WriteLong(to);
  WriteLine();
  count = count + 1;
}


void MoveTower(var from, var by, var to, var height)
{
  if (height == 1) {
    MoveDisc(from, to);
  } else {
    MoveTower(from, to, by, height-1);
    MoveDisc(from, to);
    MoveTower(by, from, to, height-1);
  }
}


void Hanoi(var height)
{
  count = 0;
  MoveTower(1, 2, 3, height);
  WriteLine();
  WriteLong(count);
  WriteLine();
}


void main()
{
  var res;
  a = 16807;
  m = 127;
  m = m * 256 + 255;
  m = m * 256 + 255;
  m = m * 256 + 255;
  q = m ~/ a;
  r = m % a;
  WriteLong(Factorial(7));
  WriteLine();
  WriteLine();
  WriteLong(FibRec(11));
  WriteLine();
  WriteLine();
  Hanoi(3);
  WriteLine();
}


/*
 expected output:
 5040

 144

 1 3
 1 2
 3 2
 1 3
 2 1
 2 3
 1 3

 7
*/
