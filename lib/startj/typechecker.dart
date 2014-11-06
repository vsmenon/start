library typechecker;

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:logging/logging.dart' as logger;

import 'typewalker.dart';

logger.Logger log;

class Library {
  final Uri uri;
  final Source source;
  final CompilationUnit lib;
  final Map<Uri, CompilationUnit> parts = new Map<Uri, CompilationUnit>();
  final Map<Uri, Library> imports = new Map<Uri, Library>();

  Library(this.uri, this.source, this.lib);
}

abstract class TypeRules {
  final TypeProvider provider;

  TypeRules(TypeProvider this.provider);

  bool isSubTypeOf(DartType t1, DartType t2);
  bool isAssignable(DartType t1, DartType t2);

  bool checkAssignment(Expression expr, DartType t);

  void setCompilationUnit(CompilationUnit unit) {}

  DartType getStaticType(Expression expr) => expr.staticType;

  DartType mapGenericType(DartType type);
  DartType elementType(Element e);
}

class DartRules extends TypeRules {
  DartRules(TypeProvider provider) : super(provider);

  bool isSubTypeOf(DartType t1, DartType t2) {
    return t1.isSubtypeOf(t2);
  }

  bool isAssignable(DartType t1, DartType t2) {
    return t1.isAssignableTo(t2);
  }

  bool checkAssignment(Expression expr, DartType toType) {
    final fromType = getStaticType(expr);
    if (!isAssignable(fromType, toType)) {
      // print('Type check failed: $expr ($fromType) is not of type $toType');
      return false;
    }
    return true;
  }

  DartType mapGenericType(DartType type) => type;

  DartType elementType(Element e) {
    return (e as dynamic).type;
  }
}

class StartRules extends TypeRules {
  // If true, num is treated as a synonym for double.
  // If false, num is always boxed.
  static const bool primitiveNum = false;
  StartTypeWalker _typeWalker = null;
  LibraryElement _current = null;

  StartRules(TypeProvider provider) : super(provider);

  void setCompilationUnit(CompilationUnit unit) {
    LibraryElement lib = unit.element.enclosingElement;
    if (lib != _current) {
      _current = lib;
      _typeWalker = new StartTypeWalker(provider, _current);
      unit.visitChildren(_typeWalker);
    }
  }

  // FIXME: Don't use Dart's static type propagation rules.
  DartType getStaticType(Expression expr) {
    return _typeWalker.getStaticType(expr);
    //return super.getStaticType(expr);
  }

  bool isDynamic(DartType t) {
    // Erasure
    if (t is TypeParameterType)
      return true;
    if (t.isDartCoreFunction)
      return true;
    return t.isDynamic;
  }

  bool canBeBoxedTo(DartType primitiveType, DartType boxedType) {
    assert(isPrimitive(primitiveType));
    // Any primitive can be boxed to Object or dynamic.
    if (boxedType.isObject || boxedType.isDynamic || boxedType is TypeParameterType)
      return true;
    // True iff a location with this type may be assigned a boxed
    // int or double.
    if (primitiveType != provider.boolType)
      if (!primitiveNum && boxedType.name == "num")
        return true;
    return false;
  }

  bool isPrimitive(DartType t) {
    // FIXME: Handle VoidType here?
    if (t.name == "void")
      return true;
    if (t == provider.intType || t == provider.doubleType || t == provider.boolType)
      return true;
    if (primitiveNum && t.name == "num")
      return true;
    return false;
  }

  bool isPrimitiveEquals(DartType t1, DartType t2) {
    assert(isPrimitive(t1) || isPrimitive(t2));
    if (primitiveNum) {
      t1 = (t1.name == "num") ? provider.doubleType : t1;
      t2 = (t2.name == "num") ? provider.doubleType : t2;
    }
    return t1 == t2;
  }

  bool isWrappableFunctionType(FunctionType f1, FunctionType f2) {
    // Can f1 be wrapped into an f2?
    assert(!isFunctionSubTypeOf(f1, f2));
    return isFunctionSubTypeOf(f1, f2, true);
  }

  bool canAutoConvertTo(DartType t1, DartType t2) {
    // TODO(vsm): Factor out common logic with error reporting below.
    if (isPrimitive(t2) && canBeBoxedTo(t2, t1)) {
      // Unbox
      return true;
    } else if (isDynamic(t1)) {
      // Type check
      return true;
    } else if (isPrimitive(t1) && canBeBoxedTo(t1, t2)) {
      // Box
      return true;
    } else if (isSubTypeOf(t2, t1)) {
      // Down cast
      // return true;
      return false;
    } else if (isPrimitive(t1) && isPrimitive(t2)) {
      // Primitive conversion
      return true;
    } else if (t2.isVoid) {
      // Ignore the value.
      return true;
    }
    return false;
  }

  bool isFunctionSubTypeOf(FunctionType f1, FunctionType f2, [bool wrap = false]) {
    final params1 = f1.parameters;
    final params2 = f2.parameters;
    final ret1 = f1.returnType;
    final ret2 = f2.returnType;

    // TODO(vsm): Factor this out.  If ret1 can be auto-converted to ret2:
    //  - primitive conversion
    //  - box
    //  - unbox
    //  - cast to dynamic
    //  - cast from dynamic
    // TODO(vsm): Emit a warning when we require a wrapped function
    if (!isSubTypeOf(ret1, ret2) && !(wrap && canAutoConvertTo(ret1, ret2))) {
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
      if (!isSubTypeOf(p2.type, p1.type) && !(wrap && canAutoConvertTo(p2.type, p1.type)))
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
    final exprType = getStaticType(expr);
    if (!isAssignable(exprType, type)) {
      if (isPrimitive(type) && canBeBoxedTo(type, exprType)) {
        log.info('$expr ($exprType) must be unboxed to type $type');
      } else if (isDynamic(exprType)) {
        log.info('$expr ($exprType) will need runtime check for type $type');
      } else if (isPrimitive(exprType) && canBeBoxedTo(exprType, type)) {
        log.info('$expr ($exprType) must be boxed');
      } else if (isSubTypeOf(type, exprType)) {
        var kind = 'AUTO';
        if (type is FunctionType) {
          kind = 'AUTO_FUNCTION';
          final message = 'FUNCTION AUTO? $exprType to $type';
          // print(message);
        }
        log.info('$kind: $expr ($exprType) will need runtime check to cast to type $type');
      } else if (isPrimitive(exprType) && isPrimitive(type)) {
        log.info('$expr ($exprType) should be converted to type $type');
      } else {
        if (exprType is FunctionType && type is FunctionType && isWrappableFunctionType(exprType, type)) {
          log.warning('(WRAPPED_FUNCTION): $expr ($exprType) to type $type');
        } else {
          String kind = (exprType is FunctionType || type is FunctionType) ? 'of function' : 'of expression';
          log.severe('Type check $kind failed: $expr ($exprType) is not of type $type', expr);
        }
      }
      return false;
    }
    return true;
  }

  DartType mapGenericType(DartType type) {
    return _typeWalker.dynamize(type);
  }

  DartType elementType(Element e) {
    return _typeWalker.baseElementType(e);
  }
}

class WorkListItem {
  final Uri uri;
  final Source source;
  final bool isLibrary;
  WorkListItem(this.uri, this.source, this.isLibrary);
}

class InvalidOverride {
  final ExecutableElement element;
  final InterfaceType base;
  final FunctionType methodType;
  final FunctionType baseType;
  final bool fieldOverride;

  InvalidOverride(this.element, this.base, this.methodType, this.baseType, [this.fieldOverride = false]);

  ClassDeclaration get parent => element.enclosingElement.node as ClassDeclaration;
  String toString() {
    if (fieldOverride)
      return 'Invalid field override for ${element.name} in ${parent.name} over $base';
    else
      return 'Invalid override for ${element.name} in ${parent.name} over $base: $methodType does not subtype $baseType';
  }
}

class ProgramChecker extends RecursiveAstVisitor {
  final AnalysisContext _context;
  final TypeRules _rules;
  final Uri _root;
  final Map<Uri, CompilationUnit> _unitMap;
  final Map<Uri, Library> libraries;
  final List<Library> _stack;
  final List<WorkListItem> workList = [];
  final List<WorkListItem> partWorkList = [];

  Uri _uri = null;

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
    if (isLibrary) {
      workList.add(new WorkListItem(uri, source, isLibrary));
      if (_stack.isNotEmpty) {
        // This is an import / export.
        // Record the key.  Fill in the library later.
        Library lib = _stack.last;
        lib.imports[uri] = null;
      }
    } else {
      partWorkList.add(new WorkListItem(uri, source, isLibrary));
    }
  }

  void finalizeImports() {
    libraries.forEach((Uri uri, Library lib) {
      for (Uri key in lib.imports.keys)
        lib.imports[key] = libraries[key];
    });
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
    // print(' loading $uri');
    _uri = uri;
    final unit = getCompilationUnit(source, isLibrary);
    _rules.setCompilationUnit(unit);
    _unitMap[uri] = unit;
    if (isLibrary) {
      assert(!libraries.containsKey(uri));
      Library lib = new Library(uri, source, unit);
      libraries[uri] = lib;
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
      , libraries = new Map<Uri, Library>()
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
    DartType staticType = _rules.getStaticType(node.leftHandSide);
    checkAssignment(node.rightHandSide, staticType);
    node.visitChildren(this);
    return node;
  }

  // Check that member declarations soundly override any overridden declarations.
  InvalidOverride findInvalidOverride(ExecutableElement element, InterfaceType type, [bool allowFieldOverride = null]) {
    // FIXME: This can be done a lot more efficiently.
    assert(!element.isStatic);

    // TODO(vsm): Move this out.
    FunctionType subType = _rules.elementType(element);

    ExecutableElement baseMethod;
    String memberName = element.name;

    final isGetter = element is PropertyAccessorElement && element.isGetter;
    final isSetter = element is PropertyAccessorElement && element.isSetter;

    int kind;
    if (isGetter) {
      assert(!isSetter);
      // Look for getter or field.
      // FIXME: Verify that this handles fields.
      baseMethod = type.getGetter(memberName);
    } else if (isSetter) {
      baseMethod = type.getSetter(memberName);
    } else {
      if (memberName == '-') {
        // operator- can be overloaded!
        final len = subType.parameters.length;
        for (final method in type.methods) {
          if (method.name == memberName && method.parameters.length == len) {
            baseMethod = method;
            break;
          }
        }
      } else {
        baseMethod = type.getMethod(memberName);
      }
    }
    if (baseMethod != null) {
      // TODO(vsm): Test for generic
      FunctionType baseType = _rules.elementType(baseMethod);
      if (!_rules.isAssignable(subType, baseType))
        return new InvalidOverride(element, type, subType, baseType);

      // Test that we're not overriding a field.
      if (allowFieldOverride == false) {
        for (FieldElement field in type.element.fields) {
          if (field.name == memberName) {
            // TODO(vsm): Is this the right test?
            bool syn = field.isSynthetic;
            if (!syn)
              return new InvalidOverride(element, type, subType, baseType, true);
          }
        }
      }
    }

    if (type.isObject)
      return null;

    allowFieldOverride = allowFieldOverride == null ? false : allowFieldOverride;
    InvalidOverride base = findInvalidOverride(element, type.superclass, allowFieldOverride);
    if (base != null)
      return base;

    for (final parent in type.interfaces) {
      base = findInvalidOverride(element, parent, true);
      if (base != null)
        return base;
    }

    for (final parent in type.mixins) {
      base = findInvalidOverride(element, parent, true);
      if (base != null)
        return base;
    }

    return null;
  }

  void checkInvalidOverride(AstNode node, ExecutableElement element, InterfaceType type) {
    InvalidOverride invalid = findInvalidOverride(element, type);
    if (invalid != null)
      log.severe('$invalid', node);
  }

  AstNode visitMethodDeclaration(MethodDeclaration node) {
    node.visitChildren(this);
    if (node.isStatic) return node;
    final parent = node.parent;
    if (parent is! ClassDeclaration) {
      throw 'Unexpected parent: $parent';
    }
    ClassDeclaration cls = parent as ClassDeclaration;
    // TODO(vsm): Check for generic.
    InterfaceType type = _rules.elementType(cls.element);
    checkInvalidOverride(node, node.element, type);
    return node;
  }

  AstNode visitFieldDeclaration(FieldDeclaration node) {
    node.visitChildren(this);
    // TODO(vsm): Is there always a corresponding synthetic method?  If not, we need to validate here.
    final parent = node.parent;
    if (!node.isStatic && parent is ClassDeclaration) {
      InterfaceType type = _rules.elementType(parent.element);
      for (VariableDeclaration decl in node.fields.variables) {
        final getter = type.getGetter(decl.name.name);
        if (getter != null)
          checkInvalidOverride(node, getter, type);
        final setter = type.getSetter(decl.name.name);
        if (setter != null)
          checkInvalidOverride(node, setter, type);
      }
    }
    return node;
  }

  // Check invocations
  bool checkArgumentList(ArgumentList node) {
    NodeList<Expression> list = node.arguments;
     for (Expression arg in list) {
       ParameterElement element = node.getStaticParameterElementFor(arg);
       if (element == null) {
         return false;
       }
       DartType expectedType = _rules.mapGenericType(_rules.elementType(element));
       if (expectedType == null)
         expectedType = _rules.provider.dynamicType;
       checkAssignment(arg, expectedType);
     }
     return true;
  }

  AstNode visitMethodInvocation(MethodInvocation node) {
    bool checked = checkArgumentList(node.argumentList);
    if (!checked) {
      log.warning('dynamic invoke required for: $node');
    }
    node.visitChildren(this);
    return node;
  }

  AstNode visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    bool checked = checkArgumentList(node.argumentList);
    if (!checked) {
      log.warning('dynamic invoke required for: $node');
    }
    node.visitChildren(this);
    return node;
  }

  AstNode visitRedirectingConstructorInvocation(RedirectingConstructorInvocation node) {
    bool checked = checkArgumentList(node.argumentList);
    if (!checked) {
      log.warning('dynamic invoke required for: $node');
    }
    node.visitChildren(this);
    return node;
  }

  AstNode visitSuperConstructorInvocation(SuperConstructorInvocation node) {
    bool checked = checkArgumentList(node.argumentList);
    if (!checked) {
      log.warning('dynamic invoke required for: $node');
    }
    node.visitChildren(this);
    return node;
  }

  AstNode visitVariableDeclarationList(VariableDeclarationList node) {
    TypeName type = node.type;
    final dartType = getType(type);
    for (VariableDeclaration variable in node.variables) {
      String name = variable.name.name;
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