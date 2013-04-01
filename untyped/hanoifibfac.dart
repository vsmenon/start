//test recursive function calls
import 'stdio.dart';

var a, m, q, r;
var count;
var res;


void Factorial(var n)
{
  if (n == 0) {
    res = 1;
  } else {
    Factorial(n-1);
    res = n * res;
  }
}


void FibRec(var n)
{
  var x, y;

  if (n <= 1) {
    res = 1;
  } else {
    FibRec(n-1);
    x = res;
    FibRec(n-2);
    y = res;
    res = x + y;
  }
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
  a = 16807;
  m = 127;
  m = m * 256 + 255;
  m = m * 256 + 255;
  m = m * 256 + 255;
  q = m / a;
  r = m % a;
  Factorial(7);
  WriteLong(res);
  WriteLine();
  WriteLine();
  FibRec(11);
  WriteLong(res);
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
