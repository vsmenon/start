import 'stdio.dart';

class Point {
  int x;
  int y;
}

int size;

void show(List points) {
  int i;

  i = 0;
  while (i < points.length) {
    WriteLong(points[i].y);
    i = i + 1;
  }
  WriteLine();
}

void main() {
  List points;
  int i;
  Point p;

  size = 10;
  points = new List(size);
  i = 0;
  while (i < size) {
    p = new Point();
    p.x = i;
    p.y = i*i;
    points[i] = p;
    i = i + 1;
  }

  show(points);
}

