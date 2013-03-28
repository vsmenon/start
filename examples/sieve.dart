//test the array
import 'stdio.dart';

/*
 * Sieve of Eratosthenes
 * Method for finding out prime numbers.
 */

int n;

void main() {
    int i;
    int j;
    List is_prime;
    n = 1000;
    is_prime = new List(n);
    // int is_prime[1000];

    /* Mark all numbers as prime, initially */
    is_prime[0] = 0;
    is_prime[1] = 0;
    i = 2;
    while (i < n) {
        is_prime[i] = 1;
        i = i + 1;
    }

    i = 2;
    while (i < n) {
        if (is_prime[i] != 0) {
            j = 2;
            while ((i * j) < n) {
                is_prime[i * j] = 0;
                j = j + 1;
            }
        }
        i = i + 1;
    }

    /* Write out all the prime numbers */
    i = 2;
    while (i < n) {
        if (is_prime[i] != 0) {
            WriteLong(i);
        }
        i = i + 1;
    }
    WriteLine();
}
