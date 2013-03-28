//test control flow hierarchy
import 'stdio.dart';

void main()
{
  int a, b, c, d, e, f;
  int n, x;

  n = 13;
  x = 0;


  a = 0;
  while(a < n){
    b = 0;
    x = 0;
    while(b < n){
      c = 0;
      while(c <n ){
        d = 0;
        while(d < n){
          e = 0;
          while(e<n){
            f = 0;
            while(f < n){
              x=x+1;
              f= f +1;
            }
            e=e+1;

          }
          d = d +1;
        }

        c = c+1;
      }
      b=b+1;
    }
    a=a+1;
  }
  WriteLong(x);
  WriteLine();
}


/*
 expected output:
 371293
*/
