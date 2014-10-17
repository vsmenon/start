library checker;

import 'package:args/args.dart';
import 'package:analyzer/analyzer.dart';
import 'package:analyzer/options.dart';
import 'package:analyzer/src/analyzer_impl.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/source.dart';

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
  final Source source;
  final CompilationUnit lib;
  final Map<Uri, CompilationUnit> parts = new Map<Uri, CompilationUnit>();

  Library(this.uri, this.source, this.lib);
}

abstract class TypeRules {
  final TypeProvider provider;

  TypeRules(TypeProvider this.provider);

  bool isSubTypeOf(DartType t1, DartType t2);
  bool isAssignable(DartType t1, DartType t2);

  bool checkAssignment(Expression expr, DartType t);
}

class DartRules extends TypeRules {
  DartRules(TypeProvider provider) : super(provider);

  bool isSubTypeOf(DartType t1, DartType t2) {
    return t1.isSubtypeOf(t2);
  }

  bool isAssignable(DartType t1, DartType t2) {
    return t1.isAssignableTo(t2);
  }

  bool checkAssignment(Expression expr, DartType type) {
    final staticType = expr.staticType;
    if (!isAssignable(staticType, type)) {
      print('Type check failed: $expr (${expr.staticType}) is not of type $type');
      return false;
    }
    return true;
  }
}

class StartRules extends TypeRules {
  StartRules(TypeProvider provider) : super(provider);

  bool isDynamic(DartType t) {
    // Erasure
    if (t is TypeParameterType)
      return true;
    if (t.isDartCoreFunction)
      return true;
    return t == provider.dynamicType;
  }

  bool isPrimitive(DartType t) {
    // FIXME: Handle VoidType here?
    if (t == provider.intType || t == provider.doubleType || t == provider.boolType)
      return true;
    if (t.name == "num")
      return true;
    return false;
  }

  bool isPrimitiveEquals(DartType t1, DartType t2) {
    assert(isPrimitive(t1) || isPrimitive(t2));
    t1 = (t1.name == "num") ? provider.doubleType : t1;
    t2 = (t2.name == "num") ? provider.doubleType : t2;
    return t1 == t2;
  }

  bool isFunctionSubTypeOf(FunctionType f1, FunctionType f2) {
    final params1 = f1.parameters;
    final params2 = f2.parameters;
    final ret1 = f1.returnType;
    final ret2 = f2.returnType;

    if (!isSubTypeOf(ret1, ret2)) {
      // Covariant return types.
      return false;
    }

    if (params1.length < params2.length) {
      return false;
    }

    for (int i = 0; i < params2.length; ++i) {
      ParameterElement p1 = params1[i];
      ParameterElement p2 = params2[i];

      // Contravariant parameter types.
      if (!isSubTypeOf(p2.type, p1.type))
        return false;

      // If the base param is optional, the sub param must be optional:
      // - either neither are named or
      // - both are named with the same name
      // If the base param is required, the sub may be optional, but not named.
      if (p2.parameterKind != ParameterKind.REQUIRED) {
        if (p1.parameterKind == ParameterKind.REQUIRED)
          return false;
        if (p2.parameterKind == ParameterKind.NAMED)
          if (p1.parameterKind != ParameterKind.NAMED || p1.name != p2.name)
            return false;
      } else {
        if (p1.parameterKind == ParameterKind.NAMED)
          return false;
      }
    }
    return true;
  }

  bool isInterfaceSubTypeOf(InterfaceType i1, InterfaceType i2) {
    // FIXME: Verify this!
    // Note: this essentially applies erasure on generics
    // instead of Dart's covariance.

    if (i1 == i2)
      return true;

    if (i1.element == i2.element)
      // Erasure!
      return true;

    if (i1 == provider.objectType)
      return false;

    if (isInterfaceSubTypeOf(i1.superclass, i2))
      return true;

    for (final parent in i1.interfaces) {
      if (isInterfaceSubTypeOf(parent, i2))
        return true;
    }

    for (final parent in i1.mixins) {
      if (isInterfaceSubTypeOf(parent, i2))
        return true;
    }

    return false;
  }

  bool isSubTypeOf(DartType t1, DartType t2) {
    // Primitives are standalone types.  Unless boxed, they do not subtype
    // Object and are not subtyped by dynamic.
    if (isPrimitive(t1) || isPrimitive(t2))
      return isPrimitiveEquals(t1, t2);

    if (t1 is TypeParameterType)
      t1 = provider.dynamicType;
    if (t2 is TypeParameterType)
      t2 = provider.dynamicType;

    if (t1 == t2)
      return true;

    // Null can be assigned to anything else.
    // FIXME: Can this be anything besides null?
    if (t1.isBottom)
      return true;

    // Trivially true for non-primitives.
    if (t2 == provider.objectType)
      return true;

    // Trivially false.
    if (t1 == provider.objectType && t2 != provider.dynamicType)
      return false;

    // How do we handle dynamic?  In Dart, dynamic subtypes everything.
    // This is somewhat counterintuitive - subtyping usually narrows.
    // Here we treat dynamic essentially as Object.
    if (isDynamic(t1))
      return false;
    if (isDynamic(t2))
      return true;

    // "Traditional" name-based subtype check.
    // FIXME: What happens with classes that implement Function?
    // Are typedefs handled correctly?
    if (t1 is InterfaceType && t2 is InterfaceType) {
      if (isInterfaceSubTypeOf(t1, t2)) {
        return true;
      }
    }

    if (t1 is! FunctionType || t2 is! FunctionType)
      return false;

    // Functions
    // Note: it appears under the hood all Dart functions map to a class / hidden type
    // that:
    //  (a) subtypes Object (an internal _FunctionImpl in the VM)
    //  (b) implements Function
    //  (c) provides standard Object members (hashCode, toString)
    //  (d) contains private members (corresponding to _FunctionImpl?)
    //  (e) provides a call method to handle the actual function invocation
    //
    // The standard Dart subtyping rules are structural in nature.  I.e.,
    // bivariant on arguments and return type.
    //
    // The below tries for a more traditional subtyping rule:
    // - covariant on return type
    // - contravariant on parameters
    // - 'sensible' (?) rules on optional and/or named params
    // but doesn't properly mix with class subtyping.  I suspect Java 8 lambdas
    // essentially map to dynamic (and rely on invokedynamic) due to similar
    // issues.
    return isFunctionSubTypeOf(t1 as FunctionType, t2 as FunctionType);
  }

  bool isAssignable(DartType t1, DartType t2) {
    return isSubTypeOf(t1, t2);
  }

  bool checkAssignment(Expression expr, DartType type) {
    final exprType = expr.staticType;
    if (!isAssignable(exprType, type)) {
      if (isDynamic(exprType) && isPrimitive(type)) {
        print('  AUTO: $expr ($exprType) must be unboxed to type $type');
      } else if (isDynamic(exprType)) {
        print('  AUTO: $expr ($exprType) will need runtime check for type $type');
      } else if ((isDynamic(type) || type == provider.objectType) && isPrimitive(exprType)) {
        print('  AUTO: $expr ($exprType) must be boxed');
      } else if (isSubTypeOf(type, exprType)) {
        print('  AUTO: $expr ($exprType) will need runtime check to cast to type $type');
      } else if (isPrimitive(exprType) && isPrimitive(type)) {
        print('  AUTO: $expr ($exprType) should be converted to type $type');
      } else {
        String kind = (exprType is FunctionType || type is FunctionType) ? 'of function' : 'of expression';
        print('ERROR: Type check $kind failed: $expr ($exprType) is not of type $type');
      }
      return false;
    }
    return true;
  }
}

class WorkListItem {
  final Uri uri;
  final Source source;
  final bool isLibrary;
  WorkListItem(this.uri, this.source, this.isLibrary);
}

class ProgramChecker extends RecursiveAstVisitor {
  final AnalysisContext _context;
  final TypeRules _rules;
  final Uri _root;
  final Map<Uri, CompilationUnit> _unitMap;
  final Map<Uri, Library> _libraries;
  final List<Library> _stack;
  final List<WorkListItem> workList = [];
  final List<WorkListItem> partWorkList = [];

  Uri toUri(String string) {
    // FIXME: Use analyzer's resolver logic.
    if (string.startsWith('package:')) {
      String package = string.substring(8);
      string = 'packages/' + package;
      return _root.resolve(string);
    } else {
      return _stack.last.uri.resolve(string);
    }
  }

  void add(Uri uri, Source source, bool isLibrary) {
    if (isLibrary)
      workList.add(new WorkListItem(uri, source, isLibrary));
    else
      partWorkList.add(new WorkListItem(uri, source, isLibrary));
  }

  CompilationUnit load(Uri uri, Source source, bool isLibrary) {
    if (uri.scheme == 'dart') {
      // print('skipping $uri');
      return null;
    }
    if (_unitMap.containsKey(uri)) {
      assert(isLibrary);
      return _unitMap[uri];
    }
    print(' loading $uri');
    final unit = getCompilationUnit(source, isLibrary);
    _unitMap[uri] = unit;
    if (isLibrary) {
      assert(!_libraries.containsKey(uri));
      Library lib = new Library(uri, source, unit);
      _libraries[uri] = lib;
      _stack.add(lib);
    } else {
      Library lib = _stack.last;
      assert(!lib.parts.containsKey(uri));
      lib.parts[uri] = unit;
    }
    unit.visitChildren(this);
    if (isLibrary) {
      while (partWorkList.isNotEmpty) {
        WorkListItem item = partWorkList.removeAt(0);
        assert(!item.isLibrary);
        load(item.uri, item.source, item.isLibrary);
      }
      final last = _stack.removeLast();
      assert(last.uri == uri);
    }
    return unit;
  }

  void loadFromDirective(UriBasedDirective directive, bool isLibrary) {
    String content = directive.uri.stringValue;
    Uri uri = toUri(content);
    Source source = directive.source;
    add(uri, source, isLibrary);
  }

  CompilationUnit getCompilationUnit(Source source, bool isLibrary) {
    Source container = isLibrary ? source : _stack.last.source;
    return _context.getResolvedCompilationUnit2(source, container);
  }

  ProgramChecker(this._context, this._rules, this._root, Source source)
      : _unitMap = new Map<Uri, CompilationUnit>()
      , _libraries = new Map<Uri, Library>()
      , _stack = new List<Library>() {
    add(_root, source, true);
  }

  void check() {
    while (workList.isNotEmpty) {
      WorkListItem item = workList.removeAt(0);
      assert(item.isLibrary);
      load(item.uri, item.source, item.isLibrary);
    }
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
    // print('Found $name in ${_stack.last.uri}');
    node.visitChildren(this);
    return node;
  }

  AstNode visitAssignmentExpression(AssignmentExpression node) {
    DartType staticType = node.leftHandSide.staticType;
    checkAssignment(node.rightHandSide, staticType);
    node.visitChildren(this);
    return node;
  }

  bool checkArgumentList(ArgumentList node) {
    NodeList<Expression> list = node.arguments;
     for (Expression arg in list) {
       ParameterElement element = node.getStaticParameterElementFor(arg);
       if (element == null) {
         return false;
         print('ERROR: dynamic invoke for $node');
         continue;
       }
       DartType expectedType = element.type;
       if (expectedType == null)
         expectedType = _rules.provider.dynamicType;
       checkAssignment(arg, expectedType);
     }
     return true;
  }

  AstNode visitMethodInvocation(MethodInvocation node) {
    bool checked = checkArgumentList(node.argumentList);
    if (!checked) {
      print('WARNING: dynamic invoke required for: $node');
    }
    node.visitChildren(this);
    return node;
  }

  AstNode visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    bool checked = checkArgumentList(node.argumentList);
    if (!checked) {
      print('WARNING: dynamic invoke required for: $node');
    }
    node.visitChildren(this);
    return node;
  }

  AstNode visitVariableDeclarationList(VariableDeclarationList node) {
    TypeName type = node.type;
    final dartType = getType(type);
    for (VariableDeclaration variable in node.variables) {
      // String name = variable.name.name;
      // print('Found variable $name of type $dartType');
      final initializer = variable.initializer;
      if (initializer != null)
        checkAssignment(initializer, dartType);
    }
    node.visitChildren(this);
    return node;
  }

  DartType getType(TypeName name) {
    return (name == null) ? _rules.provider.dynamicType : name.type;
  }

  bool checkAssignment(Expression expr, DartType type) {
    return _rules.checkAssignment(expr, type);
  }
}

void main(List argv)
{
  int exitCode = 0;
  CommandLineOptions options = CommandLineOptions.parse(argv);

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
    print('error');

  AnalysisContext context = analyzer.context;
  TypeProvider provider = (context as AnalysisContextImpl).typeProvider;
  final source = analyzer.librarySource;

  final uri = new Uri.file(filename);
  final visitor = new ProgramChecker(context, new StartRules(provider), uri, source);
  visitor.check();
  print('done');
}


