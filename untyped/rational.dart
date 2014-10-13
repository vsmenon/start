//test array and struct
import 'stdio.dart';

class Rational {
  var numerator;
  var denominator;
}

gcd(var a, var b)
{
  var c;

  while (b != 0) {
    c = a;
    a = b;
    b = c % b;
  }
  return a;
}

dynamic makeRational(var n, var d) {
  var common;
  var retVal;

  common = gcd(n, d);
  retVal = new Rational();
  retVal.numerator = n ~/ common;
  retVal.denominator = d ~/ common;
  return retVal;
}

dynamic add(var a, var b) {
  if (a is int) {
    if (b is int) {
      return a + b;
    } else {
      return makeRational(a * b.denominator + b.numerator, b.denominator);
    }
  } else {
    // a is Rational
    if (b is int) {
      return makeRational(b * a.denominator + a.numerator, a.denominator);
    } else {
      return makeRational(a.numerator * b.denominator + b.numerator * a.denominator, a.denominator * b.denominator);
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
  var retVal;

  a = 2;
  b = 5;

  x = makeRational(1, 2);
  y = makeRational(2, 3);

  write(a);
  write(x);
  retVal = add(a, x);
  write(retVal);
  retVal = add(y, y);
  write(retVal);
  retVal = add(a, b);
  write(retVal);
}

/*
 2
 1 2
 5 2
 4 3
 7
*/
