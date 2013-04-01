//test array and while sentence
import 'stdio.dart';

var n;

void main() {

    var i;
    var j;
    var temp;
    List array;

    n = 10;
    array = new List(n);

    i = 0;
    while (i < n) {
        array[i] = (n - i - 1);
        i = i + 1;
    }

    i = 0;
    while (i < n) {
        WriteLong(array[i]);
        i = i + 1;
    }
    WriteLine();

    i = 0;
    while (i < n) {
        j = 0;
        while (j < i) {
            if (array[j] > array[i]) {
                temp = array[i];
                array[i] = array[j];
                array[j] = temp;
            }
            j = j + 1;
        }
        i = i + 1;
    }

    i = 0;
    while (i < n) {
        WriteLong(array[i]);
        i = i + 1;
    }
    WriteLine();
}

/*
 expected output:
*/
