//test multiple control flow
import 'stdio.dart';

int m;
int n;

List tmp;
void alloc(int m, int n) {
  int i;
  tmp = new List(m);
  i = 0;
  while (i < m) {
    tmp[i] = new List(n);
    i = i + 1;
  }
}

void main()
{
  List m1;
  List m2;
  List m3;

  int i, j, k;

  m = 4;
  n = 3;

  alloc(m, n);
  m1 = tmp;

  alloc(n, m);
  m2 = tmp;

  alloc(n, n);
  m3 = tmp;

  i = 0;
  while (i < m) {
    j = 0;
    while (j < n) {
      m1[i][j] = i+j*2;
      WriteLong(i+j*2);
      j = j + 1;
    }
    WriteLine();
    i = i + 1;
  }

  i = 0;
  while (i < m) {
    j = 0;
    while (j < n) {
      m2[j][i] = m1[i][j];
      j = j + 1;
    }
    i = i + 1;
  }
  WriteLine();

  i = 0;
  while (i < n) {
    j = 0;
    while (j < m) {
      WriteLong(m2[i][j]);
      j = j + 1;
    }
    WriteLine();
    i = i + 1;
  }

  i = 0;
  while (i < n) {
    j = 0;
    while (j < n) {
      m3[i][j] = 0;
      j = j + 1;
    }
    i = i + 1;
  }
  WriteLine();

  i = 0;
  while (i < n) {
    j = 0;
    while (j < n) {
      k = 0;
      while (k < m) {
        m3[i][j] = m3[i][j] + (m1[k][j] * m2[i][k]);
        k = k + 1;
      }
      j = j + 1;
    }
    i = i + 1;
  }

  i = 0;
  while (i < n) {
    j = 0;
    while (j < n) {
      WriteLong(m3[i][j]);
      j = j + 1;
    }
    WriteLine();
    i = i + 1;
  }
}


/*
 expected output:
 0 2 4
 1 3 5
 2 4 6
 3 5 7

 0 1 2 3
 2 3 4 5
 4 5 6 7

 14 26 38
 26 54 82
 38 82 126
*/
