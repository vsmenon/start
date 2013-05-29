import 'stdio.dart';

int data0;
int data1;
int data2;

void cproptest1() {
  int j;
  j = 1 + 2 * 4;
  data0 = j;
}

void cproptest9() {
  int i;
  int stop;
  int j;

  stop = data0;
  j = 21;
  i = 1;
  while (i < stop) {
    j = (j - 20) * 21;
    i = i + 1;
  }
  data1 = j;
  data2 = i;
}

void main() {
  data0 = 0;

  cproptest1();
  WriteLong(data0);
  WriteLine();

  data1 = 0;
  data2 = 0;
  cproptest9();
  WriteLong(data1);
  WriteLong(data2);
  WriteLine();
}