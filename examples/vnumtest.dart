import 'stdio.dart';

int data0;
int data4;
int data5;

void vnumtest1(int data1, int data3) {
     data0 = data1*data3 - data1*data3;
}


void vnumtest2(int data1, int data3) {
     data0 = data1*data3 - data3*data1;
}


void vnumtest3(int data1, int data2, int data3) {
     int n, j, i, m, k;
     j = data1*data3;
     i = data3;
     m = data1;
     k = data2;
     n = m*i;
     data0 = n - j;
}


void vnumtest4(int data1, int data2, int data3) {
     int n, j, i, m, k;
     j = data1*data3;
     i = data3;
     m = data1;
     k = data2;
     n = i*m;
     data0 = n - j;
}


void vnumtest5(int data1, int data2, int data3) {
     int i, j, k, m, n;
     j = data1*data3;
     if (data3 == 3) {
     	i = data3;
	m = data1;
	k = data2;
	n = m*i;
	data0 = n - j;
     }
}


void vnumtest6(int data1, int data2, int data3) {
     int i, j, k, m, n;
     j = data1*data3;
     m = data1;
     k = j;
     if (data0 != 0) {
     	j = j + 3;
     }
     else {
     	  j = j - 3;
     }
     n = data3;
     j = data2 + j;
     data4 = k - m*n;
}


void vnumtest7(int data1, int data2, int data3) {
     int i, j, k, m, n;
     m = data1;
     n = data3;
     if (data0 != 0) {
         j = m*n;
	       i = data2;
	       data5 = i;
	       k = m*n;
     }
     else {
         j = 5;
	       k = 5;
     }
     data0 = k - j;
}


void main() {
     data0 = 0;
     data4 = 0;

     vnumtest1(0, 1);
     WriteLong(1);
     WriteLong(data0);
     WriteLine();

     vnumtest2(0, 1);
     WriteLong(2);
     WriteLong(data0);
     WriteLine();

     vnumtest3(0, 1, 2);
     WriteLong(3);
     WriteLong(data0);
     WriteLine();

     vnumtest4(0, 1, 2);
     WriteLong(4);
     WriteLong(data0);
     WriteLine();

     vnumtest5(0, 1, 2);
     WriteLong(5);
     WriteLong(data0);
     WriteLine();

     vnumtest6(0, 1, 2);
     WriteLong(6);
     WriteLong(data4);
     WriteLine();

     vnumtest7(0, 1, 2);
     WriteLong(7);
     WriteLong(data0);
     WriteLine();

}
