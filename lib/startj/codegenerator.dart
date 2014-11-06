library codegenerator;

import 'dart:io';

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/resolver.dart' hide Library;
import 'package:analyzer/src/generated/source.dart';

import 'typechecker.dart';

class OutWriter {
  IOSink _sink;
  int _indent = 0;
  String _prefix = "";
  bool newline = true;

  OutWriter(String path) {
    final file = new File(path);
    file.createSync();
    _sink = file.openWrite();
  }

  void write(String string, [int indent = 0]) {
    if (indent < 0)
      inc(indent);
    List<String> lines = string.split('\n');
    int length = lines.length;
    for (int i = 0; i < length - 1; ++i) {
      String prefix = (lines[i].isNotEmpty && (newline || i > 0)) ? _prefix : '';
        _sink.write('$prefix${lines[i]}\n');
    }
    String last = lines.last;
    if (last.isNotEmpty && (newline && length == 1 || length > 1))
      _sink.write(_prefix);
    _sink.write(last);
    newline = last.isEmpty;
    if (indent > 0)
      inc(indent);
  }

  void inc([int n = 2]) {
    _indent = _indent + n;
    assert(_indent >= 0);
    _prefix = "".padRight(_indent);
  }

  void dec([int n = 2]) {
    _indent = _indent - n;
    assert(_indent >= 0);
    _prefix = "".padRight(_indent);
  }

  void close() {
    _sink.close();
  }
}

class UnitGenerator extends GeneralizingAstVisitor {
  final OutWriter root;
  final CompilationUnit unit;
  OutWriter current = null;

  UnitGenerator(this.root, this.unit);

  void generate() {
    current = root;
    unit.visitChildren(this);
  }

  AstNode visitFunctionDeclaration(FunctionDeclaration node) {
    String name = node.name.name;
    String visibility = name.startsWith('_') ? "" : "public ";
    assert(node.parent is CompilationUnit);
    String returnType = javaType(node.returnType);
    String args = "";
    current.write("${visibility}static $returnType $name($args) {\n", 2);
    node.functionExpression.body.accept(this);
    current.write("}\n", -2);

    if (name == "main") {
      // Entry point.  Generate trampoline from Java-style main.
      // TODO(vsm): Convert args.
      current.write("""

public static void main(String[] args) {
  main();
}
""");
    }
    return node;
  }

  AstNode visitSimpleIdentifier(SimpleIdentifier node) {
    current.write(node.name);
    return node;
  }

  AstNode visitExpressionFunctionBody(ExpressionFunctionBody node) {
    current.write("return ");
    node.expression.accept(this);
    current.write(";\n");
  }

  AstNode visitMethodInvocation(MethodInvocation node) {
    String name = qualifiedName(node.methodName);
    current.write('$name(');
    node.argumentList.accept(this);
    current.write(')');
    return node;
  }

  AstNode visitArgumentList(ArgumentList node) {
    NodeList<Expression> arguments = node.arguments;
    int length = arguments.length;
    if (length > 0) {
      arguments[0].accept(this);
      for (int i = 1; i < length; ++i) {
        current.write(', ');
        arguments[i].accept(this);
      }
    }
    return node;
  }

  AstNode visitBlockFunctionBody(BlockFunctionBody node) {
    NodeList<Statement> statements = node.block.statements;
    for (final statement in statements)
      statement.accept(this);
    current.write(';\n');
    return node;
  }

  AstNode visitExpressionStatement(ExpressionStatement node) {
    node.expression.accept(this);
    return node;
  }

  AstNode visitStringLiteral(StringLiteral node) {
    current.write('"${node.stringValue}"');
    return node;
  }

  AstNode visitNode(AstNode node) {
    current.write('// Unimplemented: $node');
    return node;
  }

  String javaType(TypeName t) {
    // TODO(vsm): Fix...
    if (t == null)
      return "Object";
    return t.name.name;
  }

  static const Map<String, String> _builtins = const <String, String>{
    'dart.core': 'core',
  };

  String qualifiedName(SimpleIdentifier id) {
    // prefix?
    String prefix = "";
    String name = id.name;
    Element element = id.staticElement;
    if (element.enclosingElement is CompilationUnitElement) {
      LibraryElement library = element.enclosingElement.enclosingElement;
      final package = library.name;
      // TODO(vsm): Fix this.
      final libname = _builtins[package];
      prefix = '$package.$libname.';
    }
    return "$prefix$name";
  }
}

class LibraryGenerator {
  final String name;
  final Library library;
  final Directory dir;
  OutWriter root;

  LibraryGenerator(this.name, this.library, this.dir);

  void generateUnit(CompilationUnit unit) {
    final unitGen = new UnitGenerator(root, unit);
    unitGen.generate();
  }

  void generate() {
    root = new OutWriter(dir.path + '/$name.java');
    // TODO(vsm): Write package and imports.
    root.write("""
package $name;

import dart.core.*;

public class $name {
""", 2);
    generateUnit(library.lib);
    library.parts.forEach((Uri uri, CompilationUnit unit) {
      generateUnit(unit);
    });
    root.write("""
}
""", -2);
  }
}

class CodeGenerator {
  final String outDir;
  final Uri root;
  final Map<Uri, Library> libraries;

  CodeGenerator(this.outDir, this.root, this.libraries);

  String _libName(Library lib) {
    for (Directive directive in lib.lib.directives) {
      if (directive is LibraryDirective)
        return directive.name.toString();
    }
    // Fall back on the file name.
    String tail = lib.uri.pathSegments.last;
    if (tail.endsWith('.dart'))
      tail = tail.substring(0, tail.length - 5);
    return tail;
  }

  void generate() {
    Uri base = Uri.base;
    Uri out = base.resolve(outDir + '/');
    final top = new Directory.fromUri(out);
    top.createSync();

    libraries.forEach((Uri uri, Library lib) {
      final name = _libName(lib);
      final dir = new Directory.fromUri(out.resolve(name));
      dir.createSync();

      LibraryGenerator libgen = new LibraryGenerator(name, lib, dir);
      libgen.generate();
    });
  }
}

