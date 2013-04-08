//test array and struct
import 'stdio.dart';

class Rational {
  var numerator;
  var denominator;
}

// Return value for functions.
var retVal;

void gcd(var a, var b)
{
  var c;

  while (b != 0) {
    c = a;
    a = b;
    b = c % b;
  }
  retVal = a;
}

void makeRational(var n, var d) {
  var common;

  gcd(n, d);
  common = retVal;
  retVal = new Rational();
  retVal.numerator = n ~/ common;
  retVal.denominator = d ~/ common;
}

void add(var a, var b) {
  if (a is int) {
    if (b is int) {
      retVal = a + b;
    } else {
      makeRational(a * b.denominator + b.numerator, b.denominator);
    }
  } else {
    // a is Rational
    if (b is int) {
      makeRational(b * a.denominator + a.numerator, a.denominator);
    } else {
      makeRational(a.numerator * b.denominator + b.numerator * a.denominator, a.denominator * b.denominator);
    }
  }
}

void write(var a) {
  if (a is Rational) {
    WriteLong(a.numerator);
    WriteLong(a.denominator);
    WriteLine();    
  } else { 
    // a is int
    WriteLong(a);
    WriteLine();
  }
}

void main() {
  var a, b;
  var x, y;

  a = 2;
  b = 5;

  makeRational(1, 2);
  x = retVal;
  makeRational(2, 3);
  y = retVal;

  write(a);
  write(x);
  add(a, x);
  write(retVal);
  add(y, y);
  write(retVal);
  add(a, b);
  write(retVal);
}

/*
 2
 1 2
 5 2
 4 3
 7
*/
