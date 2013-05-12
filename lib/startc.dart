library startc;

part 'startc/startg.dart';
part 'startc/starts.dart';

// The machine word size.  This must match the value in starti.
const WORD_SIZE = 4;

final _buffer = new StringBuffer();

void printf(message) {
  _buffer.write(message.toString());
}

Token token;
int instruction;
int topOfStack;
Node globalScope = new Node();
Node nullObject;


// This function searches for an object named id in the root scope.  If
// found, a pointer to the object is returned.  Otherwise, null is returned.
Node findObj(Node root, String id) {
  int maxlev;
  Node curr;
  Node obj;

  maxlev = -1;
  curr = root;
  obj = null;
  while (curr != null) {
    while ((curr != null) && ((strcmp(curr.name, id) != 0)
        || (curr.lev <= maxlev))) {
      curr = curr.next;
    }
    if (curr != null) {
      obj = curr;
      maxlev = curr.lev;
      curr = curr.next;
    }
  }
  if (obj != null) {
    if (((obj.kind == KIND_VAR) || (obj.kind == KIND_FLD)) && ((obj.lev != 0)
        && (obj.lev != currentLevel))) {
      error("object cannot be accessed");
    }
  }
  return obj;
}


// This function adds a new object at the end of the object list pointed to
// by root and returns a pointer to the new node.
Node addToList(Node root, String id) {
  Node curr;

  curr = null;
  if (root == null) {  // first object
    curr = new Node();
    root = curr;
    curr.kind = null;
    curr.lev = currentLevel;
    curr.next = null;
    curr.dsc = null;
    curr.type = null;
    curr.name = id;
    curr.val = 0;
  } else {  // linked list is not empty, add to the end of the list
    curr = root;
    while (((curr.lev != currentLevel) || (strcmp(curr.name, id) != 0))
        && (curr.next != null)) {
      curr = curr.next;
    }
    if ((strcmp(curr.name, id) == 0) && (curr.lev == currentLevel)) {
      error("duplicate identifier");
    } else {
      curr.next = new Node();
      curr = curr.next;
      curr.kind = null;
      curr.lev = currentLevel;
      curr.next = null;
      curr.dsc = null;
      curr.type = null;
      curr.name = id;
      curr.val = 0;
    }
  }
  return curr;
}


// This function initializes the fields of an object.
void initObject(Node obj, Kind clss, Node dsc, TypeDesc type, int val) {
  obj.kind = clss;
  obj.next = null;
  obj.dsc = dsc;
  obj.type = type;
  obj.val = val;
}


// Similar to InitObj(), but also initalizes the ENTRY POINT of a procedure.
void initProcObj(Node obj, Kind clss, Node dsc, TypeDesc type, Node entrypt) {
  obj.kind = clss;
  obj.next = null;
  obj.dsc = dsc;
  obj.type = type;
  obj.jmpTrue = entrypt;
}


/*************************************************************************/

Node factor(Node x)
{
  Node obj;

  switch (token) {
    case TOKEN_NEW:
      token = nextToken();
      var ctr = findObj(globalScope, currentAsString);
      if (ctr == null || ctr.kind != KIND_TYPE)
        error("Badly formed constructor $currentAsString");

      token = nextToken();
      if (token != TOKEN_LPAREN) error("'(' expected");
      token = nextToken();
      if (ctr.type == listType) {
        // Argument expected.
        var size = new Node();
        size = expression(size);
        size = load(unbox(size));
        x = putOpNode(inewlist, size, ctr.type);
      } else {
        x = putOpNode(inew, ctr, ctr.type);
      }
      if (token != TOKEN_RPAREN) error("')' expected");
      token = nextToken();
      break;
    case TOKEN_IDENT:
      obj = findObj(globalScope, currentAsString);
      if (obj == null) error("unknown identifier");
      makeNodeDesc(x, obj);
      token = nextToken();  // consume ident before calling Designator
      x = designatorM(x);
      x = load(x);
      break;
    case TOKEN_NUMBER:
      makeConstNodeDesc(x, intType, currentAsInt);
      token = nextToken();
      break;
    case TOKEN_LPAREN:
      token = nextToken();
      x = expression(x);
      if (token != TOKEN_RPAREN) error("')' expected");
      token = nextToken();
      break;
    default: error("factor expected"); break;
  }
  return x;
}


Node term(Node x)
{
  Token op;
  Node y;

  x = factor(x);
  while ((token == TOKEN_TIMES) || (token == TOKEN_DIV) || (token == TOKEN_MOD)) {
    op = token;
    token = nextToken();
    y = new Node();
    y = factor(y);
    x = op2(op, x, y);
  }
  return x;
}


Node simpleExpression(Node x)
{
  Token op;
  Node y;

  if ((token == TOKEN_PLUS) || (token == TOKEN_MINUS)) {
    op = token;
    token = nextToken();
    x = term(x);
    x = op1(op, x);
  } else {
    x = term(x);
  }
  while ((token == TOKEN_PLUS) || (token == TOKEN_MINUS)) {
    op = token;
    token = nextToken();
    y = new Node();
    y = term(y);
    x = op2(op, x, y);
  }
  return x;
}


Node equalityExpr(Node x)
{
  Token op;
  Node y;

  x = simpleExpression(x);
  if ((token == TOKEN_LSS) || (token == TOKEN_LEQ) || (token == TOKEN_GTR)
      || (token == TOKEN_GEQ)) {
    y = new Node();
    op = token;
    token = nextToken();
    y = simpleExpression(y);
    x = relation(op, x, y);
  } else if (token == TOKEN_IS || token == TOKEN_ISNOT) {
    op = token;
    token = nextToken();
    y = findObj(globalScope, currentAsString);
    if (y == null || y.kind != KIND_TYPE)
      error("Invalid type $currentAsString");
    x = istype(op, x, y);
    token = nextToken();
  }
  return x;
}


Node expression(Node x)
{
  Token op;
  Node y;

  x = equalityExpr(x);
  if ((token == TOKEN_EQL) || (token == TOKEN_NEQ)) {
    op = token;
    token = nextToken();
    y = new Node();
    y = equalityExpr(y);
    x = relation(op, x, y);
  }
  return x;
}

/*************************************************************************/


void fieldList(TypeDesc type)
{
  Node curr;

  type.fields = variableDeclaration(type.fields);
  while (token != TOKEN_RBRACE) {
    type.fields = variableDeclaration(type.fields);
  }
  curr = type.fields;
  if (curr == null) error("empty structs are not allowed");
  // vtable
  type.size += intType.size;
  while (curr != null) {
    curr.kind = KIND_FLD;
    curr.val = type.size;
    type.size += intType.size;
    if (type.size > 0x7fffffff) error("struct too large");
    curr = curr.next;
  }
}


TypeDesc classType()
{
  TypeDesc type;
  Node obj;
  int oldinstruct;
  String id;

  assert(token == TOKEN_CLASS);
  token = nextToken();
  if (token != TOKEN_IDENT) error("identifier expected");
  id = currentAsString;
  token = nextToken();
  if (token != TOKEN_LBRACE) {
    obj = findObj(globalScope, id);
    if (obj == null) error("unknown struct type");
    if ((obj.kind != KIND_TYPE) || (obj.type.form != FORM_CLASS))
      error("struct type expected");
    type = obj.type;
  } else {
    token = nextToken();
    type = new TypeDesc(id);
    type.form = FORM_CLASS;
    type.fields = null;
    type.size = 0;
    oldinstruct = instruction;
    instruction = 1;
    obj = addToList(globalScope, id);
    // TODO(vsm): Abstract WORD_SIZE to addr size.
    initObject(obj, KIND_TYPE, null, type, WORD_SIZE);

    fieldList(type);
    instruction = oldinstruct;
    if (token != TOKEN_RBRACE) error("'}' expected");
    token = nextToken();
  }
  return type;
}


TypeDesc typeDesc(TypeDesc t)
{
  Node obj;

  if (token != TOKEN_IDENT) error("identifier expected");
  obj = findObj(globalScope, currentAsString);
  if (obj == null) error("unknown type $currentAsString");
  if (obj.kind != KIND_TYPE) error("type expected");
  t = obj.type;
  token = nextToken();
  return t;
}


Node ident(Node root, TypeDesc type)
{
  Node obj;

  if (type == listType) {
    // List
    type.base = dynamicType;
  }

  if (token != TOKEN_IDENT) error("identifier expected");
  obj = addToList(root, currentAsString);
  if (root == null) root = obj;
  token = nextToken();

  if (instruction == 0) topOfStack -= intType.size; //type.size;
  initObject(obj, KIND_VAR, null, type, topOfStack);
  return root;
}


Node identList(Node root, TypeDesc type)
{
  root = ident(root, type);
  while (token == TOKEN_COMMA) {
    token = nextToken();
    root = ident(root, type);
  }
  return root;
}


Node variableDeclaration(Node root)
{
  TypeDesc type;

  type = typeDesc(type);
  root = identList(root, type);
  if (token != TOKEN_SEMICOLON) error("';' expected");
  token = nextToken();
  return root;
}


/*************************************************************************/


Node designatorM(Node x)
{
  Node obj;
  Node y;

  // CSSident already consumed
  bool first = true;
  while ((token == TOKEN_PERIOD) || (token == TOKEN_LBRAK)) {
    if (!first) {
      x = load(x);
    } else {
      first = false;
    }
    if (token == TOKEN_PERIOD) {
      token = nextToken();
      //if (x.type.form != CSGStruct) CSSError("struct type expected");
      if (token != TOKEN_IDENT) error("field identifier expected");
      if (x.type != dynamicType) {
        obj = findObj(x.type.fields, currentAsString);
        token = nextToken();
        if (obj == null) error("unknown identifier");
        x = fieldAddress(x, obj, true);
      } else {
        Node dyn = new Node();
        makeDynamicNodeDesc(dyn, currentAsString);
        token = nextToken();
        x = fieldAddress(x, dyn, true);
      }
    } else {
      token = nextToken();
      if (x.type != dynamicType && x.type.form != FORM_LIST) {
        error("array type expected");
      }
      y = new Node();
      y = expression(y);
      x = indexAddress(x, y);
      if (token != TOKEN_RBRAK) error("']' expected");
      token = nextToken();
    }
  }
  return x;
}


void assignmentM(Node x)
{
  Node y;

  assert(x != null);
  // CSSident already consumed
  y = new Node();
  x = designatorM(x);
  if (token != TOKEN_BECOMES) error("'=' expected");
  token = nextToken();
  y = expression(y);
  store(x, y);
  if (token != TOKEN_SEMICOLON) error("';' expected");
  token = nextToken();
}


void expList(Node proc)
{
  Node curr;
  Node x;

  x = new Node();
  curr = proc.dsc;
  x = expression(x);
  if ((curr == null) || (curr.dsc != proc)) error("too many parameters");
  if (x.type != curr.type && x.type != dynamicType
      && curr.type != dynamicType) error("incorrect type");
  x = parameter(x, curr.type, curr.kind);
  curr = curr.next;
  while (token == TOKEN_COMMA) {
    x = new Node();
    token = nextToken();
    x = expression(x);
    if ((curr == null) || (curr.dsc != proc)) error("too many parameters");
    // if (x.type != curr.type) CSSError("incorrect type");
    x = parameter(x, curr.type, curr.kind);
    curr = curr.next;
  }
  if ((curr != null) && (curr.dsc == proc)) error("too few parameters");
}


void procedureCallM(Node obj, Node x)
{
  Node y;

  // CSSident already consumed
  makeNodeDesc(x, obj);
  if (token != TOKEN_LPAREN) error("'(' expected");
  token = nextToken();
  if (x.kind == KIND_SPROC) {
    y = new Node();
    if (x.val == 1) {
      y = expression(y);
    } else if (x.val == 2) {
      y = expression(y);
    }
    ioCall(x, y);
  } else {
    assert(x.type == null);
    if (token != TOKEN_RPAREN) {
      expList(obj);
    } else {
      if ((obj.dsc != null) && (obj.dsc.dsc == obj)) {
        error("too few parameters");
      }
    }
    call(x);
  }
  if (token != TOKEN_RPAREN) error("')' expected");
  token = nextToken();
  if (token != TOKEN_SEMICOLON) error("';' expected");
  token = nextToken();
}


// This function parses if statements - helpful for CFG creation.
void ifStatement()
{
  Node label;
  Node x;

  x = new Node();
  assert(token == TOKEN_IF);
  token = nextToken();
  label = initLabel(label);
  if (token != TOKEN_LPAREN) error("'(' expected");
  token = nextToken();
  x = expression(x);
  // TODO(vsm): Restore.
  // CSGTestBool(x);
  fixLink(x.jmpFalse);
  if (token != TOKEN_RPAREN) error("')' expected");
  token = nextToken();
  if (token != TOKEN_LBRACE) error("'{' expected");
  token = nextToken();
  statementSequence();
  if (token != TOKEN_RBRACE) error("'}' expected");
  token = nextToken();
  if (token == TOKEN_ELSE) {
    token = nextToken();
    label = forwardJump(label);
    fixLink(x.jmpTrue);
    if (token != TOKEN_LBRACE) error("'{' expected");
    token = nextToken();
    statementSequence();
    if (token != TOKEN_RBRACE) error("'}' expected");
    token = nextToken();
  } else {
    fixLink(x.jmpTrue);
  }
  fixLink(label);
}


// This function parses while statements - helpful for CFG creation.
void whileStatement()
{
  Node label;
  Node x;

  x = new Node();
  assert(token == TOKEN_WHILE);
  token = nextToken();
  if (token != TOKEN_LPAREN) error("'(' expected");
  token = nextToken();
  label = setLabel(label);
  x = expression(x);
  // CSGTestBool(x);
  fixLink(x.jmpFalse);
  if (token != TOKEN_RPAREN) error("')' expected");
  token = nextToken();
  if (token != TOKEN_LBRACE) error("'{' expected");
  token = nextToken();
  statementSequence();
  if (token != TOKEN_RBRACE) error("'}' expected");
  token = nextToken();
  backJump(label);
  fixLink(x.jmpTrue);
}


void statement()
{
  Node obj;
  Node x;

  switch (token) {
    case TOKEN_IF: ifStatement(); break;
    case TOKEN_WHILE: whileStatement(); break;
    case TOKEN_IDENT:
      obj = findObj(globalScope, currentAsString);
      if (obj == null) error("unknown identifier $currentAsString");
      token = nextToken();
      x = new Node();
      if (token == TOKEN_LPAREN) {
        procedureCallM(obj, x);
      } else {
        makeNodeDesc(x, obj);
        assignmentM(x);
      }
      break;
    case TOKEN_SEMICOLON: break;  /* empty statement */
    default: error("unknown statement");
  }
}


void statementSequence()
{
  while (token != TOKEN_RBRACE) {
    statement();
  }
}


/*************************************************************************/


int formalParameter(Node root, int paddr)
{
  Node obj;
  TypeDesc type;

  type = typeDesc(type);

  if (token != TOKEN_IDENT) error("identifier expected");
  assert(root != null);
  obj = addToList(root, currentAsString);
  token = nextToken();
  if (token == TOKEN_LBRAK) error("no array parameters allowed");
  initObject(obj, KIND_VAR, root, type, 0);
  paddr += intType.size;
  return paddr;
}


void formalParameters(Node root)
{
  Node curr;
  int paddr;

  paddr = WORD_SIZE*2;
  paddr = formalParameter(root, paddr);
  while (token == TOKEN_COMMA) {
    token = nextToken();
    paddr = formalParameter(root, paddr);
  }
  curr = root.next;
  while (curr != null) {
    paddr -= intType.size; //curr.type.size;
    curr.val = paddr;
    curr = curr.next;
  }
}


Node procedureHeading(Node proc)
{
  String name;

  if (token != TOKEN_IDENT) error("function name expected");
  name = currentAsString;
  proc = addToList(globalScope, name);
  initProcObj(proc, KIND_PROC, null, null, pc);
  adjustLevel(1);
  token = nextToken();
  if (token != TOKEN_LPAREN) error("'(' expected");
  token = nextToken();
  if (token != TOKEN_RPAREN) {
    formalParameters(proc);
  }
  if (token != TOKEN_RPAREN) error("')' expected");
  token = nextToken();
  if (strcmp(name, "main") == 0) entryPoint();
  return proc;
}


Node procedureBody(Node proc)
{
  int returnsize;
  Node curr;

  topOfStack = 0;
  while ((token == TOKEN_IDENT) &&
      (findObj(globalScope, currentAsString).kind == KIND_TYPE)) {
    proc = variableDeclaration(proc);
  }
  assert(proc.dsc == null);
  proc.dsc = proc.next;
  if (-topOfStack > 32768) error("maximum stack frame size of 32kB exceeded");
  enter(-topOfStack);
  returnsize = 0;
  curr = proc.dsc;
  while ((curr != null) && (curr.dsc == proc)) {
    returnsize += WORD_SIZE;
    curr = curr.next;
  }
  statementSequence();
  ret(returnsize);
  adjustLevel(-1);
  return proc;
}


void procedureDeclaration()
{
  Node proc;

  assert(token == TOKEN_VOID);
  token = nextToken();
  proc = procedureHeading(proc);
  if (token != TOKEN_LBRACE) error("'{' expected");
  token = nextToken();
  proc = procedureBody(proc);
  if (token != TOKEN_RBRACE) error("'}' expected");
  token = nextToken();
  proc.next = null;  // cut off rest of list
}


void program()
{
  open();
  topOfStack = 32768;
  instruction = 0;
  while ((token != TOKEN_VOID) && (token != TOKEN_EOF)) {
    if (token == TOKEN_CLASS) {
      classType();
    } else {
      globalScope = variableDeclaration(globalScope);
    }
  }
  if (token != TOKEN_VOID) error("procedure expected");
  while (token == TOKEN_VOID) {
    procedureDeclaration();
  }
  if (token != TOKEN_EOF) error("unrecognized characters at end of file");
}


/*************************************************************************/


Node insertObj(Node root, Kind clss, TypeDesc type, String name, int val)
{
  Node curr;

  if (root == null) {
    root = new Node();
    curr = root;
  } else {
    curr = root;
    if (strcmp(curr.name, name) == 0) error("duplicate symbol");
    while (curr.next != null) {
      curr = curr.next;
      if (strcmp(curr.name, name) == 0) error("duplicate symbol");
    }
    curr.next = new Node();
    curr = curr.next;
  }
  curr.next = null;
  curr.kind = clss;
  curr.type = type;
  curr.name = name;
  curr.val = val;
  curr.dsc = null;
  curr.lev = 0;
  return root;
}

void printTypes() {
  for(var sym = globalScope; sym != null; sym = sym.next) {
    if (sym.kind == KIND_TYPE) {
      if (sym.type.form == FORM_CLASS && sym.type != boxedIntType) {
        printf("    type ${sym.name}:");
        for (var field = sym.type.fields; field != null;
            field = field.next) {
          final typeName = field.type.name;
          printf(" ${field.name}#${field.val}:$typeName");
        }
        printf("\n");
      }
    }
  }
}

void printGlobals() {
  for(var sym = globalScope; sym != null; sym = sym.next) {
    if (sym.kind == KIND_VAR) {
      final typeName = sym.type.name;
      printf("    global ${sym.name}#${sym.val}:$typeName");

      printf("\n");
    }
  }
}

void printMethods() {
  for(var sym = globalScope; sym != null; sym = sym.next) {
    if (sym.kind == KIND_PROC) {
      printf("    method ${sym.name}@${sym.jmpTrue.line}:");
      for (var param = sym.dsc; param != null; param = param.next) {
        final typeName = param.type.name;
        printf(" ${param.name}#${param.val}:$typeName");
      }

      printf("\n");
    }
  }
}

String compile(String input)
{
  initializeParser();
  globalScope = null;
  globalScope = insertObj(globalScope, KIND_TYPE, intType, "int", WORD_SIZE);
  globalScope = insertObj(globalScope, KIND_TYPE, boxedIntType, "Integer", WORD_SIZE);
  globalScope = insertObj(globalScope, KIND_TYPE, listType, "List", WORD_SIZE*2);
  globalScope = insertObj(globalScope, KIND_TYPE, dynamicType, "dynamic", WORD_SIZE);
  globalScope = insertObj(globalScope, KIND_TYPE, dynamicType, "var", WORD_SIZE);
  globalScope = insertObj(globalScope, KIND_SPROC, null, "Instrument", 1);
  globalScope = insertObj(globalScope, KIND_SPROC, null, "WriteLong", 2);
  globalScope = insertObj(globalScope, KIND_SPROC, null, "WriteLine", 3);

  // TODO(vsm): Make this a built-in token.
  globalScope = insertObj(globalScope, KIND_CONST, intType, "null", 0);
  nullObject = findObj(globalScope, "null");

  initializeTokenizer(input);
  token = nextToken();
  program();
  assignLineNumbers();
  printTypes();
  printMethods();
  printGlobals();
  decode();
  return _buffer.toString();
}

