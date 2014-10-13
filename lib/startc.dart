library startc;

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/scanner.dart';

part 'startc/startg.dart';

// The machine word size.  This must match the value in starti.
const WORD_SIZE = 4;

final _buffer = new StringBuffer();

void printf(message) {
  _buffer.write(message.toString());
}

int instruction;
int topOfStack;
Scope globalScope = new Scope();
Node nullObject;

// This function initializes the fields of an object.
void initObject(Node obj, Kind kind, Scope dsc, TypeDesc type, int val) {
  obj.kind = kind;
  obj.dsc = dsc;
  obj.type = type;
  obj.val = val;
}

// Similar to InitObj(), but also initalizes the ENTRY POINT of a procedure.
void initProcObj(Node obj, Kind kind, Scope dsc, TypeDesc type, Node entrypt) {
  obj.kind = kind;
  obj.dsc = dsc;
  obj.type = type;
  obj.entry = entrypt;
}


/*************************************************************************/

Node expression(Scope scope, Expression expr)
{
  if (expr is BooleanLiteral) {
    throw "Boolean literals are unsupported";
  } else if (expr is IntegerLiteral) {
    int val = expr.value;
    Node x = new Node();
    makeConstNodeDesc(x, intType, val);
    return x;
  } else if (expr is PrefixedIdentifier) {
    return load(propertyAccess(scope, expr.prefix, expr.identifier));
  } else if (expr is Identifier) {
    var name = expr.name;
    Node obj = scope.find(name);
    if (obj == null) error("unknown identifier");
    Node x = makeNodeDesc(obj);
    return load(x);
  } else if (expr is PrefixExpression) {
    TokenType op = expr.operator.type;
    Node x = expression(scope, expr.operand);
    return op1(op, x);
  } else if (expr is BinaryExpression) {
    TokenType t = expr.operator.type;
    Node lhs = expression(scope, expr.leftOperand);
    Node rhs = expression(scope, expr.rightOperand);
    if (t.isEqualityOperator || t.isRelationalOperator) {
      return relation(t, lhs, rhs);
    } else if (t.isAdditiveOperator || t.isMultiplicativeOperator) {
      return op2(t, lhs, rhs);
    }
  } else if (expr is InstanceCreationExpression) {
    String typeName = expr.constructorName.type.name.name;
    var ctr = scope.find(typeName);
    if (ctr == null || ctr.kind != KIND_TYPE)
      error("Badly formed constructor $typeName");

    if (ctr.type == listType) {
      // Argument expected.
      Node size = expression(scope, expr.argumentList.arguments[0]);
      size = load(unbox(size));
      return putOpNode(inewlist, size, ctr.type);
    } else {
      return putOpNode(inew, ctr, ctr.type);
    }
  } else if (expr is IndexExpression) {
    Node base = expression(scope, expr.target);
    if (base.type != dynamicType && base.type.form != FORM_LIST) {
      error("array type expected");
    }
    Node index = expression(scope, expr.index);
    return load(indexAddress(base, index));
  } else if (expr is ParenthesizedExpression) {
    return expression(scope, expr.expression);
  } else if (expr is NullLiteral) {
    return nullObject;
  } else if (expr is PropertyAccess) {
    return load(propertyAccess(scope, expr.target, expr.propertyName));
  } else if (expr is IsExpression) {
    Node x = expression(scope, expr.expression);
    String typename = typeName(expr.type);
    Node y = scope.find(typename);
    if (y == null || y.kind != KIND_TYPE)
      error("Invalid type $typename");
    TokenType op = expr.notOperator == null
        ? TokenType.IS
            : expr.notOperator.type;
    return istype(op, x, y);
  } else if (expr is MethodInvocation) {
    return methodCall(scope, expr);
  }
  throw 'Unsupported expression $expr';
}

/*************************************************************************/

String typeName(TypeName type) {
  if (type != null)
    return type.name.name;
  else
    return 'dynamic';
}

void fieldList(TypeDesc type, NodeList<ClassMember> members)
{
  for (ClassMember member in members) {
    if (member is FieldDeclaration) {
      VariableDeclarationList node = member.fields;
      String name = typeName(node.type);
      // FIXME: Allow types in local scope as well.
      TypeDesc desc = typeDesc(globalScope, name);

      for (var decl in node.variables) {
        if (decl.initializer != null) {
          throw 'Field initializers not yet supported';
        }
        ident(type.fields, desc, decl.name.token.value());
      }
    } else {
      throw "Non-field declaration";
    }
  }


  if (type.fields.nodes.length == 0) error("empty structs are not allowed");
  // vtable
  type.size += intType.size;
  for (Node curr in type.fields.nodes) {
    curr.kind = KIND_FIELD;
    curr.val = type.size;
    type.size += intType.size;
    if (type.size > 0x7fffffff) error("struct too large");
  }
}


TypeDesc typeDesc(Scope scope, String name)
{
  Node obj = scope.find(name);
  if (obj == null)
    error("unknown type $name");
  if (obj.kind != KIND_TYPE) error("type expected");
  return obj.type;
}


Node ident(Scope scope, TypeDesc type, String name)
{
  if (type == listType) {
    // List
    type.base = dynamicType;
  }

  Node obj = scope.add(name);

  if (instruction == 0) topOfStack -= intType.size; //type.size;
  initObject(obj, KIND_VAR, null, type, topOfStack);
  return obj;
}

/*************************************************************************/


Node propertyAccess(Scope scope, Expression target, SimpleIdentifier identifier)
{
  Node base = load(designatorM(scope, target));
  String field = identifier.name;
  if (base.type != dynamicType) {
    Node obj = base.type.fields.find(field);
    if (obj == null) error("unknown identifier");
    return fieldAddress(base, obj, true);
  } else {
    Node dyn = new Node();
    makeDynamicNodeDesc(dyn, field);
    return fieldAddress(base, dyn, true);
  }
}

Node designatorM(Scope scope, Expression lhs)
{
  if (lhs is PrefixedIdentifier) {
    return propertyAccess(scope, lhs.prefix, lhs.identifier);
  } else if (lhs is Identifier) {
    String name = lhs.name;
    Node obj = scope.find(name);
    if (obj == null)
      error("unknown identifier $name");
    return makeNodeDesc(obj);

  } else if (lhs is IndexExpression) {
    Node base = load(designatorM(scope, lhs.target));
    if (base.type != dynamicType && base.type.form != FORM_LIST) {
      error("array type expected");
    }
    Node y = expression(scope, lhs.index);
    return indexAddress(base, y);
  } else if (lhs is PropertyAccess) {
    return propertyAccess(scope, lhs.target, lhs.propertyName);
  } else {
    throw 'Unsupported lhs $lhs';
  }
}


void assignmentM(Scope scope, Expression lhs, Expression rhs)
{
  Node x = designatorM(scope, lhs);
  Node y = expression(scope, rhs);
  store(x, y);
  return;
}

Node methodCall(Scope scope, MethodInvocation node) {
  String methodName = node.methodName.name;
  NodeList<Expression> args = node.argumentList.arguments;

  Node obj = scope.find(methodName);
  if (obj == null) error("unknown identifier $methodName");
  Node x = makeNodeDesc(obj);

  if (x.kind == KIND_SYSCALL) {
    Node y;
    if (x.val == 1) {
      y = expression(scope, args[0]);
    } else if (x.val == 2) {
      y = expression(scope, args[0]);
    }
    return ioCall(x, y);
  } else {
    // FIXME: assert(x.type == null);
    if (args.length > 0)
      expList(scope, obj, args);
    return call(x, x.type);
  }
}

void expList(Scope scope, Node proc, NodeList<Expression> args)
{
  assert(args.length > 0);
  Scope procScope = proc.dsc;

  // The first n nodes in proc's scope are parameters.
  // Ensure those match.
  int paramCount = 0;
  for (Node node in procScope.nodes) {
    if (node.dsc == procScope) {
      // Parameter
      paramCount++;
    } else {
      // Local variable.
      break;
    }
  }
  if (paramCount < args.length) {
    error("too many arguments passed");
  } else if (paramCount > args.length) {
    error("too few arguments passed");
  }

  for (int i = 0; i < paramCount; i++) {
    Node curr = procScope.nodes[i];
    if (curr.dsc != procScope) {
      // Not a parameter.
      error("too many arguments passed");
    }
    Node x = expression(scope, args[i]);

    // Type check arguments
    if (x.type != curr.type && x.type != dynamicType
        && curr.type != dynamicType && !isNull(x))
      error("incorrect argument type");
    x = parameter(x, curr.type, curr.kind);
  }
}



/*************************************************************************/

void formalParameters(Scope root, FormalParameterList paramlist)
{
  Node curr;
  int paddr;

  paddr = WORD_SIZE*2;
  for (FormalParameter param in paramlist.parameters) {
    if (param.kind != ParameterKind.REQUIRED)
      throw "Optional parameters not support";
    if (param is! SimpleFormalParameter)
      throw "Unsupported parameter type";
    final id = param.identifier;
    final typename = typeName((param as SimpleFormalParameter).type);
    // FIXME: Type in local scope?
    TypeDesc desc = typeDesc(globalScope, typename);
    Node paramNode = root.add(id.name);
    initObject(paramNode, KIND_VAR, root, desc, 0);
    paddr += intType.size;
  }

  for (Node curr in root.nodes) {
    paddr -= intType.size; //curr.type.size;
    curr.val = paddr;
  }
}


/*************************************************************************/

void printTypes() {
  for(Node sym in globalScope.nodes) {
    if (sym.kind == KIND_TYPE) {
      if (sym.type.form == FORM_CLASS && sym.type != boxedIntType) {
        printf("    type ${sym.name}:");
        for (Node field in sym.type.fields.nodes) {
          final typeName = field.type.name;
          printf(" ${field.name}#${field.val}:$typeName");
        }
        printf("\n");
      }
    }
  }
}

void printGlobals() {
  for(Node sym in globalScope.nodes) {
    if (sym.kind == KIND_VAR) {
      final typeName = sym.type.name;
      printf("    global ${sym.name}#${sym.val}:$typeName");

      printf("\n");
    }
  }
}

void printMethods() {
  for(Node sym in globalScope.nodes) {
    if (sym.kind == KIND_FUNC) {
      printf("    method ${sym.name}@${sym.entry.line}:");
      for (Node param in sym.dsc.nodes) {
        final typeName = param.type.name;
        printf(" ${param.name}#${param.val}:$typeName");
      }

      printf("\n");
    }
  }
}

class StackWalker extends RecursiveAstVisitor {
  final Scope proc;

  StackWalker(this.proc);

  AstNode visitVariableDeclarationList(VariableDeclarationList node) {
    String name = typeName(node.type);
    TypeDesc desc = typeDesc(globalScope, name);

    for (var decl in node.variables) {
      if (decl.initializer != null) {
        throw 'Field initializers not yet supported';
      }
      ident(proc, desc, decl.name.token.value());
    }
    return node;
  }

}

class IRGenerator implements AstVisitor {
  IRGenerator(this._scope);

  AstNode visitAssignmentExpression(AssignmentExpression node) {
    Expression lhs = node.leftHandSide;
    String op = node.operator.lexeme;
    Expression rhs = node.rightHandSide;
    if (op != '=')
      throw 'Unsupported assignment operation $op';
    assignmentM(_scope, lhs, rhs);
  }

  AstNode visitBlock(Block node) {
    // FIXME: Add a scope.
    node.visitChildren(this);
    return node;
  }

  AstNode visitClassDeclaration(ClassDeclaration node) {
    TypeDesc type;
    Node obj;
    int oldinstruct;
    String id = node.name.name;

    type = new TypeDesc(id);
    type.form = FORM_CLASS;
    type.fields = new Scope(globalScope);
    type.size = 0;
    oldinstruct = instruction;
    instruction = 1;
    obj = globalScope.add(id);
    // TODO(vsm): Abstract WORD_SIZE to addr size.
    initObject(obj, KIND_TYPE, null, type, WORD_SIZE);

    fieldList(type, node.members);
    instruction = oldinstruct;
    return node;
  }

  AstNode visitExpressionStatement(ExpressionStatement node) {
    node.visitChildren(this);
    return node;
  }

  AstNode visitFunctionDeclaration(FunctionDeclaration node) {
    String name = node.name.name;
    Node proc = _scope.add(name);
    String typename = typeName(node.returnType);
    TypeDesc desc = typename == "void" ? null : typeDesc(globalScope, typename);
    initProcObj(proc, KIND_FUNC, null, desc, pc);
    proc.dsc = _pushScope(proc);
    topOfStack = 0;
    if (name == "main") entryPoint();

    FunctionExpression expr = node.functionExpression;
    FormalParameterList params = expr.parameters;
    formalParameters(proc.dsc, params);
    StackWalker walker = new StackWalker(proc.dsc);
    FunctionBody body = expr.body;
    body.visitChildren(walker);

    if (-topOfStack > 32768) error("maximum stack frame size of 32kB exceeded");
    enter(-topOfStack);
    body.visitChildren(this);
    // FIXME: Test for jumps.
    // Return if no explicit return.
    Instruction last = pc;
    while (last.op == inop)
      last = last.prv;
    if (last.op != iretv && last.op != iret)
      ret(proc.dsc.returnSize());
    _popScope(proc.dsc);
    return node;
  }

  AstNode visitIfStatement(IfStatement node) {
    Instruction label = initLabel(null);
    Instruction x = expression(_scope, node.condition);

    // TODO(vsm): Restore.
    // CSGTestBool(x);
    fixLink(x.jmpFalse);
    node.thenStatement.visitChildren(this);
    if (node.elseStatement != null) {
      label = forwardJump(label);
      fixLink(x.jmpTrue);
      node.elseStatement.visitChildren(this);
    } else {
      fixLink(x.jmpTrue);
    }
    fixLink(label);
    return node;
  }

  AstNode visitImportDirective(ImportDirective node) {
    final uri = node.uri.toString();
    if (uri != "'stdio.dart'")
      throw 'Unsupported import of $uri';
    return node;
  }

  AstNode visitMethodInvocation(MethodInvocation node) {
    methodCall(_scope, node);
    return node;
  }

  AstNode visitReturnStatement(ReturnStatement node) {
    Node val = expression(_scope, node.expression);
    // FIXME: Type check the result.
    retv(_scope.returnSize(), val, _scope.proc.type);
  }

  AstNode visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    node.visitChildren(this);
    return node;
  }

  AstNode visitWhileStatement(WhileStatement node) {
    Instruction label = setLabel(null);
    Instruction x = expression(_scope, node.condition);
    fixLink(x.jmpFalse);
    node.body.visitChildren(this);
    backJump(label);
    fixLink(x.jmpTrue);
    return node;
  }

  AstNode visitVariableDeclarationList(VariableDeclarationList node) {
    if (_scope.parent != null) return node;

    String name = typeName(node.type);
    // FIXME: Allow types in local scope as well.
    TypeDesc desc = typeDesc(globalScope, name);

    for (var decl in node.variables) {
      if (decl.initializer != null) {
        throw 'Field initializers not yet supported';
      }
      ident(_scope, desc, decl.name.token.value());
    }
    return node;
  }

  AstNode visitVariableDeclarationStatement(VariableDeclarationStatement node) {
    node.visitChildren(this);
    return node;
  }

  noSuchMethod(invocation) {
    throw 'Unimplemented: ${invocation.memberName}';
  }

  Scope _scope;

  Scope _pushScope(Node proc) {
    _scope = new Scope(_scope, proc);
    return _scope;
  }

  void _popScope(Scope scope) {
    scope.validate();
    assert(scope == _scope);
    _scope = _scope.parent;
  }
}


String compile(String input)
{
  initializeParser();
  globalScope.insert(KIND_TYPE, intType, "int", WORD_SIZE);
  globalScope.insert(KIND_TYPE, boxedIntType, "Integer", WORD_SIZE);
  globalScope.insert(KIND_TYPE, listType, "List", WORD_SIZE*2);
  globalScope.insert(KIND_TYPE, dynamicType, "dynamic", WORD_SIZE);
  globalScope.insert(KIND_TYPE, dynamicType, "var", WORD_SIZE);
  globalScope.insert(KIND_SYSCALL, null, "Instrument", 1);
  globalScope.insert(KIND_SYSCALL, null, "WriteLong", 2);
  globalScope.insert(KIND_SYSCALL, null, "WriteLine", 3);

  // TODO(vsm): Make this a built-in token.
  globalScope.insert(KIND_CONST, intType, "null", 0);
  nullObject = globalScope.find("null");

  open();
  topOfStack = 32768;
  instruction = 0;

  CompilationUnit compilationUnit = parseCompilationUnit(input);
  final generator = new IRGenerator(globalScope);
  try {
    compilationUnit.visitChildren(generator);
  } catch (e, trace) {
    print('Error: $e');
  }

  assignLineNumbers();
  printTypes();
  printMethods();
  printGlobals();
  decode();
  return _buffer.toString();
}

