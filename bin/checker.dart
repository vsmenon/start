library checker;

import 'dart:io';

import 'package:args/args.dart';
import 'package:analyzer/analyzer.dart';
import 'package:analyzer/options.dart';
import 'package:analyzer/src/analyzer_impl.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:logging/logging.dart' as logger;

import 'package:start/startj/typechecker.dart';

final parser = new ArgParser();

ArgResults parse(List argv) {
  parser.addFlag('type-check', abbr: 't', help: 'Typecheck only', defaultsTo: false);
  parser.addOption('log', abbr: 'l', help: 'Logging level', defaultsTo: 'severe');
  parser.addOption('dart-sdk', help: 'Dart SDK Path', defaultsTo: null);
  return parser.parse(argv);
}

void main(List argv) {
  // Parse the command-line options.
  ArgResults args = parse(argv);
  String dartPath = Platform.executable;
  const dartExec = 'bin/dart';
  String dartSdk = args['dart-sdk'];
  if (dartSdk == null && dartPath.endsWith(dartExec)) {
    dartSdk = dartPath.substring(0, dartPath.length - dartExec.length);
  }

  // Pass the remaining options to the analyzer.
  final analyzerArgv = ['--dart-sdk', dartSdk];
  analyzerArgv.addAll(args.rest);
  CommandLineOptions options = CommandLineOptions.parse(analyzerArgv);

  // Configure logger
  log = new logger.Logger('checker');
  String levelName = args['log'];
  levelName = levelName.toUpperCase();
  logger.Level level = logger.Level.LEVELS.firstWhere((logger.Level l) => l.name == levelName);
  logger.Logger.root.level = level;
  logger.Logger.root.onRecord.listen((logger.LogRecord rec) {
    AstNode node = rec.error;
    var pos = '';
    if (node != null) {
      final root = node.root as CompilationUnit;
      final info = root.lineInfo.getLocation(node.beginToken.offset);
      pos = ' ${root.element}:${info.lineNumber}:${info.columnNumber}';
    }
    print('${rec.level.name}$pos: ${rec.message}');
  });

  // Run dart analyzer.  We rely on it for resolution.
  int exitCode = 0;
  if (options.sourceFiles.length != 1)
    throw 'Filename expected';
  final filename = options.sourceFiles[0];
  AnalyzerImpl analyzer = new AnalyzerImpl(filename, options, 0);
  var errorSeverity = analyzer.analyzeSync();
  if (errorSeverity == ErrorSeverity.ERROR) {
    exitCode = errorSeverity.ordinal;
  }
  if (options.warningsAreFatal && errorSeverity == ErrorSeverity.WARNING) {
    exitCode = errorSeverity.ordinal;
  }
  if (exitCode != 0)
    log.severe('error');

  // Invoke the checker on the entry point.
  AnalysisContext context = analyzer.context;
  TypeProvider provider = (context as AnalysisContextImpl).typeProvider;
  final source = analyzer.librarySource;
  final uri = new Uri.file(filename);
  final visitor = new ProgramChecker(context, new StartRules(provider), uri, source);
  visitor.check();
  log.shout('done');
}


