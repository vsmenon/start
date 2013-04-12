// NOTE: This is not a Start sample.
// It's a shim library used to make Start samples run in the Dart runtime.

library stdio;

var _buffer = new StringBuffer();

void _printf(String str) {
  final list = str.split('\n');
  assert(list.length > 0);
  _buffer.write(list[0]);
  if (list.length > 1) {
    print(_buffer.toString());
    _buffer = new StringBuffer();
    for (int i = 1; i < list.length - 1; ++i) {
      print(list[i]);
    }
    _buffer.write(list.last);
  }
}

void WriteLong(int n) => _printf(' $n');

void WriteLine() => _printf('\n');
