library start_test;

import 'dart:async';
import 'dart:io';

import 'package:unittest/unittest.dart';

final TESTS = [
                'class.dart',
                'gcd.dart',
                'hanoifibfac.dart',
                'link.dart',
                'mmm.dart',
                'prime.dart',
                'regslarge.dart',
                'sieve.dart',
                'sort.dart',
                'struct.dart',
                ];

int findTime(String output) {
  final lines = output.split('\n');
  for (String line in lines) {
    if (line.contains("Dynamic cycles")) {
      final words = line.split(' ');
      return int.parse(words.last);
    }
  }
}

Future<int> time(String vm, String interp, String dir,
                         String test) {
  final out = Process.run(vm, [interp, '--stats',
                                     '$dir/$test'])
      .then((r) => r.exitCode != 0
        ? fail('$test failed on:\n${r.stderr}')
        : r.stdout);

  return out.then(findTime);
}

void runTests(String vm, String path) {
  final interp = '$path/bin/start.dart';
  for (final name in TESTS) {
    time(vm, interp, '$path/examples', name).then((typed) {
      time(vm, interp, '$path/untyped', name).then((untyped) {
        print('$name: typed:$typed untyped:$untyped (${untyped/typed})');
      });
    });

  }
}

void main() {
  final options = new Options();
  final vm = options.executable;
  final script = options.script;
  Future<String> dir = new File(script).directory().then((d) => d.path);
  dir.then((path) => runTests(vm, '$path/..'));
}