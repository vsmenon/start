library renum;

import 'dart:io';

void _check(bool flag, String message) {
  if (!flag) {
    print(message);
    throw new Exception(message);
  }
}

Map _parse(String bytecode) {
  final instMap = new Map<num, int>();
  int count = 0;
  // Read in the program from stdin
  for (final line in bytecode.split('\n')) {
    var words = line.trim().split(" ");
    if (line.trim() == "") {
      // print('$line\n');
      continue;
    }
    if (words[0] != "instr") {
      // print('$line\n');
      continue;
    }
    count += 1;
    num pc = double.parse(words[1].replaceFirst(':', ''));
    instMap[pc] = count;
  }
  return instMap;
}

void _renum(String bytecode, Map<num, int> instMap) {
  int count = 0;
  // Read in the program from stdin
  for (final line in bytecode.split('\n')) {
    var words = line.trim().split(" ");
    if (line.trim() == "") {
      print(line);
      continue;
    }
    if (words[0] != "instr") {
      print(line);
      continue;
    }
    count += 1;
    String newInst = '    instr $count:';
    // _check(index == (instructions.length + 1), "Invalid index $index");
    for (int i = 2; i < words.length; ++i) {
      var word = words[i];
      if (word[0] == '(') {
        final pc = double.parse(word.substring(1, word.length - 1));
        word = '(${instMap[pc]})';
      } else if (word[0] == '[') {
        final pc = double.parse(word.substring(1, word.length - 1));
        word = '[${instMap[pc]}]';
      }
      newInst += ' $word';
    }
    print(newInst);
  }
}

void main()
{
  final args = (new Options()).arguments;

  final filename = args[0];

  final file = new File(filename);
  final input = file.readAsStringSync();

  final map = _parse(input);
  _renum(input, map);
}