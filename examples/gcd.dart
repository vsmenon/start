//test multiple function calls
import 'stdio.dart';

int a, b;
int res;


void GCD(int a, int b)
{
  int c;

  while (b != 0) {
    c = a;
    a = b;
    b = c % b;
    WriteLong(c);
    WriteLong(a);
    WriteLong(b);
    WriteLine();
  }
  res = a;
}


void main()
{
  a = 25733;
  b = 48611;
  GCD(a, b);
  WriteLong(res);
  WriteLine();
  WriteLine();

  a = 7485671;
  b = 7480189;
  GCD(a, b);
  WriteLong(res);
  WriteLine();
}


/*
 expected output:
 25733 48611 25733
 48611 25733 22878
 25733 22878 2855
 22878 2855 38
 2855 38 5
 38 5 3
 5 3 2
 3 2 1
 2 1 0
 1

 7485671 7480189 5482
 7480189 5482 2741
 5482 2741 0
 2741
*/
