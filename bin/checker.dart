library checker;

import 'package:args/args.dart';
import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/ast.dart';
// import 'package:analyzer/src/generated/scanner.dart';

final parser = new ArgParser();

ArgResults options(List argv) {
  parser.addFlag('compile', abbr: 'c', help: 'Compile only', defaultsTo: false);
  parser.addFlag('debug', abbr: 'd', help: 'Print debugging info',
      defaultsTo: false);
  parser.addFlag('help', abbr: 'h', help: 'Show usage', defaultsTo: false);
  parser.addFlag('run', abbr: 'r', help: 'Run from IR', defaultsTo: false);
  parser.addFlag('show', help: 'Print IR', defaultsTo: false);
  parser.addFlag('stats', abbr: 'p', help: 'Show stats', defaultsTo: false);
  return parser.parse(argv);
}

class Library {
  final Uri uri;
  final CompilationUnit lib;
  final Map<Uri, CompilationUnit> parts = new Map<Uri, CompilationUnit>();

  Library(this.uri, this.lib);
}

class MyVisitor extends RecursiveAstVisitor {
  final Uri _root;
  final Map<Uri, CompilationUnit> _sources;
  final Map<Uri, Library> _libraries;
  final List<Library> _stack;

  Uri toUri(String string) {
    if (string.startsWith('package:')) {
      String package = string.substring(8);
      string = 'packages/' + package;
      return _root.resolve(string);
    } else {
      return _stack.last.uri.resolve(string);
    }
  }

  CompilationUnit load(Uri uri, bool isLibrary) {
    print('loading $uri');
    if (uri.scheme == 'dart') {
      print('skipping $uri');
      return null;
    }
    if (_sources.containsKey(uri)) {
      assert(isLibrary);
      return _sources[uri];
    }
    CompilationUnit unit = parseDartFile(uri.toFilePath());
    _sources[uri] = unit;
    if (isLibrary) {
      assert(!_libraries.containsKey(uri));
      Library lib = new Library(uri, unit);
      _libraries[uri] = lib;
      _stack.add(lib);
    } else {
      Library lib = _stack.last;
      assert(!lib.parts.containsKey(uri));
      lib.parts[uri] = unit;
    }
    unit.visitChildren(this);
    if (isLibrary) {
      final last = _stack.removeLast();
      assert(last.uri == uri);
    }
    return unit;
  }

  CompilationUnit loadFromDirective(UriBasedDirective directive, bool isLibrary) {
    String content = directive.uri.stringValue;
    Uri uri = toUri(content);
    CompilationUnit unit = load(uri, isLibrary);
    return unit;
  }

  MyVisitor(this._root)
      : _sources = new Map<Uri, CompilationUnit>()
      , _libraries = new Map<Uri, Library>()
      , _stack = new List<Library>() {
    load(_root, true);
  }

  AstNode visitExportDirective(ExportDirective node) {
    loadFromDirective(node, true);
    node.visitChildren(this);
    return node;
  }

  AstNode visitImportDirective(ImportDirective node) {
    loadFromDirective(node, true);
    node.visitChildren(this);
    return node;
  }

  AstNode visitPartDirective(PartDirective node) {
    loadFromDirective(node, false);
    node.visitChildren(this);
    return node;
  }

  AstNode visitFunctionDeclaration(FunctionDeclaration node) {
    String name = node.name.name;
    print('Found $name in ${_stack.last.uri}');
    node.visitChildren(this);
    return node;
  }
}

void main(List argv)
{
  final args = options(argv);
  if (args['help']) {
    print('dart bin/bootstrap.dart <filename>');
    print(parser.getUsage());
    return;
  }

  if (args.rest.length != 1)
    throw 'Filename expected';
  final filename = args.rest[0];
  final uri = new Uri.file(filename);
  final visitor = new MyVisitor(uri);
  print('done');
}