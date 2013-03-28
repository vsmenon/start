//test recursive function calls
import 'stdio.dart';

dynamic a, m, q, r;
dynamic count;
dynamic res;


void Factorial(dynamic n)
{
  if (n == 0) {
    res = 1;
  } else {
    Factorial(n-1);
    res = n * res;
  }
}


void FibRec(dynamic n)
{
  dynamic x, y;

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


void MoveDisc(dynamic from, dynamic to)
{
  WriteLong(from);
  WriteLong(to);
  WriteLine();
  count = count + 1;
}


void MoveTower(dynamic from, dynamic by, dynamic to, dynamic height)
{
  if (height == 1) {
    MoveDisc(from, to);
  } else {
    MoveTower(from, to, by, height-1);
    MoveDisc(from, to);
    MoveTower(by, from, to, height-1);
  }
}


void Hanoi(dynamic height)
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
