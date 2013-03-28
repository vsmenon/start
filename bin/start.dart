library start;

import 'dart:io';
import 'package:args/args.dart';

import 'startc/startc.dart';
import 'starti/starti.dart';

ArgResults options() {
  final options = new Options();
  final argv = options.arguments;
  
  final parser = new ArgParser();
  parser.addFlag('debug', help: 'Print debugging info', defaultsTo: false);
  parser.addFlag('show', help: 'Print IR', defaultsTo: false);
  parser.addFlag('run', help: 'Execute code', defaultsTo: true);
  parser.addFlag('stats', help: 'Show stats', defaultsTo: false);
  return parser.parse(argv);
}

void main()
{
  final args = options();
  if (args.rest.length != 1)
    throw 'Filename expected';
  final filename = args.rest[0];

  final file = new File(filename);
  final input = file.readAsStringSync();
  final output = compile(input);
  if (args['show'])
    print(output);
  if (args['run']) {
    final stats = execute(output, debug: args['debug']);
    if (args['stats'])
      print('\n$stats');
  }
}