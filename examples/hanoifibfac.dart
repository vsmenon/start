//test recursive function calls
import 'stdio.dart';

int a, m, q, r;
int count;

int Factorial(int n)
{
  int res;
  if (n == 0) {
    res = 1;
  } else {
    res = n * Factorial(n-1);
  }
  return res;
}


int FibRec(int n)
{
  int x, y, res;

  if (n <= 1) {
    res = 1;
  } else {
    x = FibRec(n-1);
    y = FibRec(n-2);
    res = x + y;
  }
  return res;
}


void MoveDisc(int from, int to)
{
  WriteLong(from);
  WriteLong(to);
  WriteLine();
  count = count + 1;
}


void MoveTower(int from, int by, int to, int height)
{
  if (height == 1) {
    MoveDisc(from, to);
  } else {
    MoveTower(from, to, by, height-1);
    MoveDisc(from, to);
    MoveTower(by, from, to, height-1);
  }
}


void Hanoi(int height)
{
  count = 0;
  MoveTower(1, 2, 3, height);
  WriteLine();
  WriteLong(count);
  WriteLine();
}


void main()
{
  int res;
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
