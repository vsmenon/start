library start;

import 'dart:io';
import 'package:args/args.dart';

import 'package:start/startc.dart';
import 'package:start/starti.dart';

final parser = new ArgParser();

ArgResults options() {
  final options = new Options();
  final argv = options.arguments;

  parser.addFlag('compile', abbr: 'c', help: 'Compile only', defaultsTo: false);
  parser.addFlag('debug', abbr: 'd', help: 'Print debugging info',
      defaultsTo: false);
  parser.addFlag('help', abbr: 'h', help: 'Show usage', defaultsTo: false);
  parser.addFlag('run', abbr: 'r', help: 'Run from IR', defaultsTo: false);
  parser.addFlag('show', help: 'Print IR', defaultsTo: false);
  parser.addFlag('stats', abbr: 'p', help: 'Show stats', defaultsTo: false);
  return parser.parse(argv);
}

void main()
{
  final args = options();
  if (args['help']) {
    print('dart bin/start.dart <filename>');
    print(parser.getUsage());
    exit(0);
  }

  if (args.rest.length != 1)
    throw 'Filename expected';
  final filename = args.rest[0];

  final file = new File(filename);
  final input = file.readAsStringSync();
  final output = args['run'] ? input : compile(input);

  if (args['show'] || args['compile'])
    print(output);
  if (!args['compile']) {
    final stats = execute(output, debug: args['debug']);
    if (args['stats'])
      print('\n$stats');
  }
}