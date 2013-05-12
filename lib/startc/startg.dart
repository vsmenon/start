part of startc;

/* kind */
class Kind {
  const Kind._(this._value);
  final _value;
  toString() => 'KIND_${_value.toUpperCase()}';
}

const KIND_VAR = const Kind._('Var');
const KIND_CONST = const Kind._('Const');
const KIND_FLD = const Kind._('Fld');
const KIND_TYPE = const Kind._('Type');
const KIND_PROC = const Kind._('Proc');
const KIND_SPROC = const Kind._('SProc');
const KIND_ADDR = const Kind._('Addr');
const KIND_DYN_ADDR = const Kind._('DynAddr');
const KIND_INST = const Kind._('Inst');


/* form */
class Form {
  const Form._(this._value);
  final _value;
  toString() => 'FORM_${_value.toUpperCase()}';
}

const FORM_INTEGER = const Form._('Integer');
const FORM_BOOLEAN = const Form._('Boolean');
const FORM_LIST = const Form._('List');
const FORM_CLASS = const Form._('Class');
const FORM_POINTER = const Form._('Pointer');

class TypeDesc {
  TypeDesc(this.name);

  final String name;
  Form form;

  Node fields;  // linked list of the fields in a struct
  int size = 0;  // total size of the type
  TypeDesc base;  // base type (for list or pointer)
  TypeDesc _pointer; // cached pointer type.  Use the ref function.
}

class Node {
  Kind kind;  // Var, Const, Field, Type, Proc, SProc, Addr, Inst
  int lev = 0;  // 0 = global, 1 = local
  Node next;  // linked list of all objects in same scope
  Node dsc;  // Proc: link to procedure scope (head)
  TypeDesc type;  // type
  String name;  // name
  int val = 0;  // Const: value; Var: addr; Fld: offset; SProc: num; Type: size
  Opcode op;  // operation of instruction
  Node x, y, z;  // the operands
  Node prv, nxt;  // previous and next instruction
  int line = 0;  // line number for printing purposes
  Node jmpTrue, jmpFalse;  // Jmp: true and false chains; Proc: true = entry
  Node original;  // Pointer to original node object if a copy was made
}

TypeDesc intType, boolType, dynamicType, listType, boxedIntType;
int currentLevel = 0;
Node pc;

class Opcode {
  const Opcode._(this._value);
  final _value;
  toString() => '$_value';
}

// Math opcodes.
const ineg = const Opcode._('neg');
const iadd = const Opcode._('add');
const isub = const Opcode._('sub');
const imul = const Opcode._('mul');
const idiv = const Opcode._('div');
const imod = const Opcode._('mod');

// Comparison opcodes.
const icmpeq = const Opcode._('cmpeq');
const icmplt = const Opcode._('cmplt');
const icmple = const Opcode._('cmple');
const iisnull = const Opcode._('isnull');
const iistype = const Opcode._('istype');

// Function call opcodes.
const inop = const Opcode._('nop');
const ientrypc = const Opcode._('entrypc');
const iparam = const Opcode._('param');
const icall = const Opcode._('call');
const ienter = const Opcode._('enter');
const iret = const Opcode._('ret');

// Other control flow opcodes.
const iblbs = const Opcode._('blbs');
const iblbc = const Opcode._('blbc');
const ibr = const Opcode._('br');

// Memory / variable access opcodes.
const iload = const Opcode._('load');
const istore = const Opcode._('store');
const imove = const Opcode._('move');

// Output opcodes.
const iwrite = const Opcode._('write');
const iwrl = const Opcode._('wrl');

// Instrumentation.
const icount = const Opcode._('count');

// Memory allocation.
const inew = const Opcode._('new');
const inewlist = const Opcode._('newlist');

// Safety check opcodes.
const ichecknull = const Opcode._('checknull');
const icheckbounds = const Opcode._('checkbounds');
const ichecktype = const Opcode._('checktype');

// Dynamic access opcodes.
const ilddynamic = const Opcode._('lddynamic');
const istdynamic = const Opcode._('stdynamic');

Node code, entrypc, fp, gp;

/*****************************************************************************/

// A pointer to the underlying type.
TypeDesc ref(TypeDesc t) {
  assert(t.form != FORM_POINTER);
  if (t._pointer != null) return t._pointer;
  TypeDesc reftype = new TypeDesc('${t.name}*');
  reftype.form = FORM_POINTER;
  reftype.size = intType.size;
  reftype.base = t;
  t._pointer = reftype;
  return reftype;
}

TypeDesc deref(TypeDesc t) {
  assert(t.form == FORM_POINTER);
  return t.base;
}

// This function adds a new instruction at the end of the instruction list
// and sets the operation to op and the operands to x and y.
Node putOpNodeNodeNode(Opcode op, Node x, Node y, Node z, TypeDesc type)
{
  Node i;

  pc.nxt = new Node();
  i = pc;
  pc = pc.nxt;
  pc.kind = KIND_INST;
  pc.op = inop;
  pc.prv = i;
  pc.nxt = null;

  assert(i != null);
  i.kind = KIND_INST;
  i.op = op;
  i.x = x;
  i.y = y;
  i.z = z;
  i.type = type;
  i.lev = 0;

  return i;
}

Node putOpNodeNode(Opcode op, Node x, Node y, TypeDesc type)
{
  return putOpNodeNodeNode(op, x, y, null, type);
}

Node putOpNode(Opcode op, Node x, TypeDesc type)
{
  return putOpNodeNode(op, x, null, type);
}


Node putOp(Opcode op, TypeDesc type)
{
  return putOpNodeNode(op, null, null, type);
}


void makeDynamicNodeDesc(Node x, String fieldName) {
  x.kind = KIND_FLD;
  x.type = dynamicType;
  x.lev = currentLevel;
  x.name = fieldName;
}


// This function SETS the member fields of a CSGNode object.
void makeConstNodeDesc(Node x, TypeDesc typ, int val)
{
  x.kind = KIND_CONST;
  x.type = typ;
  x.val = val;
  x.lev = currentLevel;
}


// This function make a COPY of a CSGNode object
void makeNodeDesc(Node x, Node y) {
  int i;

  x.kind = y.kind;
  x.type = y.type;
  x.val = y.val;
  x.lev = y.lev;
  x.jmpTrue = y.jmpTrue;
  x.name = y.name;

  // Make the 'original' field of the copy to point back to original Node object
  if (y.original == null) {
    x.original = y;
  } else {
    x.original = y.original;
  }
}


Node dynamicAddr(Node ref, Node field) {
  Node addr = new Node();
  addr.kind = KIND_DYN_ADDR;
  addr.x = ref;
  addr.y = field;
  return addr;
}

/*****************************************************************************/

Node unbox(Node x) {
  if (x.type == intType) return x; // Already unboxed;
  if (x.type == dynamicType) {
    final checked = checkNull(x);
    final boxed = checkType(checked, boxedIntType);
    final ctr = findObj(globalScope, "Integer");
    final field = findObj(ctr.type.fields, "value");
    final addr = fieldAddress(boxed, field, false);
    return load(addr);
  }
  error("Cannot unbox non-int type");
}

Node box(Node x) {
  if (isNull(x)) return x;

  if (x.type == boolType) {
    // TODO(vsm): Support this.
    error("Cannot box bool type");
  }
  if (x.type == intType) {
    final ctr = findObj(globalScope, "Integer");
    final boxed = putOpNode(inew, ctr, boxedIntType);
    final field = findObj(ctr.type.fields, "value");
    final addr = fieldAddress(boxed, field, false);
    store(addr, x);
    return boxed;
  }
  return x;
}

Node checkType(Node x, TypeDesc t) {
  if(x.type == t)
    return x;
  Node type = new Node();
  initObject(type, KIND_TYPE, null, t, WORD_SIZE);
  x = putOpNodeNode(ichecktype, x, type, t);
  return x;
}

void checkBounds(Node list, Node index) {
  putOpNodeNode(icheckbounds, list, index, null);
}

Node checkNull(Node x) {
  x = putOpNode(ichecknull, x, x.type);
  return x;
}

Node load(Node x) {
  if (x.kind == KIND_DYN_ADDR) {
    x = putOpNodeNode(ilddynamic, x.x, x.y, dynamicType);
  } else if (x.kind == KIND_ADDR) {
    x = putOpNode(iload, x, deref(x.type));
  } else if ((x.kind == KIND_VAR) && (x.lev == 0)) {
    final type = x.type;
    x = putOpNodeNode(iadd, x, gp, ref(type));
    x = putOpNode(iload, x, type);
  } else if (x.kind == KIND_VAR) {
    assert(x.lev != 0);
  }
  return x;
}

Node fieldAddress(Node x, Node y, bool testNull) { /* x = x.y */
  if (x.kind == KIND_VAR) {
    if (x.lev == 0) {
      final type = x.type;
      x = putOpNodeNode(iadd, x, gp, ref(type));
      x = putOpNode(iload, x, type);
    }
  }
  if (testNull) x = checkNull(x);
  if (y.type == dynamicType) {
    x = dynamicAddr(x, y);
  } else {
    x = putOpNodeNode(iadd, x, y, ref(y.type));
    x.kind = KIND_ADDR;
  }
  return x;
}


Node indexAddress(Node x, Node y) { /* x = x[y] */
  Node baseoffset = new Node();
  makeConstNodeDesc(baseoffset, intType, intType.size*2);

  final basetype = (x.type == dynamicType) ? dynamicType : x.type.base;
  Node indexoffset = new Node();
  makeConstNodeDesc(indexoffset, intType, intType.size);

  if (x.kind != KIND_ADDR) {
    if (x.kind != KIND_INST) {
      if (x.lev == 0) {
        final type = x.type;
        x = putOpNodeNode(iadd, x, gp, ref(type));
        x = putOpNode(iload, x, type);
      }
    }
  }
  x = checkNull(x);
  x = checkType(x, listType);
  y = unbox(y);
  checkBounds(x, y);
  x = putOpNodeNode(iadd, x, baseoffset, ref(basetype));
  y = op2(TOKEN_TIMES, y, indexoffset);

  x = putOpNodeNode(iadd, x, y, ref(basetype));
  x.kind = KIND_ADDR;
  return x;
}


/*****************************************************************************/


// The following five functions deal with control transfer.  Mostly, they
// remember where the control transferring instructions are so that their
// targets can be set later if the targets have not yet been compiled.


Node initLabel(Node lbl) {
  return null;
}

Node setLabel(Node lbl) {
  return pc;
}


// This function sets the target of a forward jump, call, or branch once
// the target is being compiled.
void fixLink(Node lbl) {
  if (lbl != null) {
    if ((lbl.op == icall) || (lbl.op == ibr)) {
      lbl.x = pc;
    } else {
      lbl.y = pc;
    }
  }
}


void backJump(Node lbl) {
  putOpNode(ibr, lbl, null);
}


Node forwardJump(Node lbl) {
  lbl = putOpNode(ibr, lbl, null);
  lbl = pc.prv;
  return lbl;
}


/*****************************************************************************/


void testInt(Node x) {
  if (x.type.form != FORM_INTEGER) error("type integer expected");
}


void testBool(Node x) {
  if (x.type.form != FORM_BOOLEAN) error("type boolean expected");
}


/*****************************************************************************/


Node op1(Token op, Node x) { /* x = op x */
  x = unbox(x);
  if (op == TOKEN_PLUS) {
    testInt(x);
  } else if (op == TOKEN_MINUS) {
    testInt(x);
    x = putOpNode(ineg, x, x.type);
  }
  return x;
}


Node op2(Token op, Node x, Node y)  /* x = x op y */
{
  assert(x != null);
  assert(y != null);
  x = unbox(x);
  y = unbox(y);

  switch (op) {
    case TOKEN_PLUS: x = putOpNodeNode(iadd, x, y, intType); break;
    case TOKEN_MINUS: x = putOpNodeNode(isub, x, y, intType); break;
    case TOKEN_TIMES: x = putOpNodeNode(imul, x, y, intType); break;
    case TOKEN_DIV: x = putOpNodeNode(idiv, x, y, intType); break;
    case TOKEN_MOD: x = putOpNodeNode(imod, x, y, intType); break;
  }
  return x;
}


Node istype(Token op, Node x, Node y) {
  // TODO(vsm): This should be statically folded.
  // TODO(vsm): Handle bool.
  if (y.type == intType) {
    y = findObj(globalScope, "Integer");
  }

  x = box(x);

  Node t = putOpNodeNode(iistype, x, y, boolType);
  final opcode = (op == TOKEN_IS) ? iblbc : iblbs;
  x = putOpNode(opcode, t, null);
  x.jmpFalse = null;
  x.jmpTrue = pc.prv;
  return x;
}


Node relation(Token op, Node x, Node y)
{
  Node t;

  if (op == TOKEN_EQL || op == TOKEN_NEQ) {
    // isnull
    var ref = null;
    if (isNull(x)) {
      ref = box(y);
    } else if(isNull(y)) {
      ref = box(x);
    }
    if (ref != null) {
      t = putOpNode(iisnull, ref, boolType);
      final opcode = (op == TOKEN_EQL) ? iblbc : iblbs;
      x = putOpNode(opcode, t, null);
      x.jmpFalse = null;
      x.jmpTrue = pc.prv;
      return x;
    }
  }

  x = unbox(x);
  y = unbox(y);

  switch (op) {
    case TOKEN_EQL:
      t = putOpNodeNode(icmpeq, x, y, boolType);
      x = putOpNode(iblbc, t, null);
      break;
    case TOKEN_NEQ:
      t = putOpNodeNode(icmpeq, x, y, boolType);
      x = putOpNode(iblbs, t, null);
      break;
    case TOKEN_LSS:
      t = putOpNodeNode(icmplt, x, y, boolType);
      x = putOpNode(iblbc, t, null);
      break;
    case TOKEN_GTR:
      t = putOpNodeNode(icmple, x, y, boolType);
      x = putOpNode(iblbs, t, null);
      break;
    case TOKEN_LEQ:
      t = putOpNodeNode(icmple, x, y, boolType);
      x = putOpNode(iblbc, t, null);
      break;
    case TOKEN_GEQ:
      t = putOpNodeNode(icmplt, x, y, boolType);
      x = putOpNode(iblbs, t, null);
      break;
  }
  x.jmpFalse = null;
  x.jmpTrue = pc.prv;
  return x;
}


/*****************************************************************************/

bool isNull(Node x) {
  // TODO(vsm): Make this more robust.
  return x.name == "null";
}


void store(Node x, Node y) { /* x = y */
  assert(x != null);
  assert(y != null);

  var storedType = x.type;
  if (x.kind == KIND_INST || x.kind == KIND_ADDR) {
    if (storedType.form != FORM_POINTER) error("expected pointer type");
    storedType = storedType.base;
  } else if (x.kind == KIND_DYN_ADDR) {
    storedType = dynamicType;
  }

  if (y.type == null) return;
  if (storedType == intType) {
    y = unbox(y);
  } else if (storedType == dynamicType) {
    y = box(y);
  } else if (y.type == dynamicType) {
    y = checkType(y, storedType);
  } else {
    if (!isNull(y) &&
        storedType.form != y.type.form) error("incompatible assignment");
  }

  if (x.kind == KIND_DYN_ADDR) {
    x = putOpNodeNodeNode(istdynamic, y, x.x, x.y, null);
  } else if ((x.kind == KIND_INST) || (x.kind == KIND_ADDR)) {
    // TODO(vsm): Restore?
    // assert(x.type.form == FORM_POINTER && x.type.base == y.type);
    putOpNodeNode(istore, y, x, null);
  } else if ((x.kind == KIND_VAR) && (x.lev == 0)) {
    x = putOpNodeNode(iadd, x, gp, ref(x.type));
    putOpNodeNode(istore, y, x, null);
  } else {
    assert(x.kind == KIND_VAR);
    putOpNodeNode(imove, y, x, null);
  }
}


void adjustLevel(int n)
{
  currentLevel += n;
  assert(0 <= currentLevel && currentLevel <= 1);
}


Node parameter(Node x, TypeDesc ftyp, Kind clss)
{
  if (ftyp == dynamicType) {
    x = box(x);
  } else if (ftyp == intType) {
    x = unbox(x);
  } else if (x.type == dynamicType) {
    x = checkType(x, ftyp);
  } else {
    if (x.type != ftyp) error("Incorrect parameter type");
  }
  x = putOpNode(iparam, x, null);
  return x;
}


/*****************************************************************************/


void call(Node x)
{
  putOpNode(icall, x, null);
}


void ioCall(Node x, Node y)
{
  Node z;

  if (x.val < 3) testInt(y);
  if (x.val == 1) {
    y = unbox(y);
    putOpNode(icount, y, null);
  } else if (x.val == 2) {
    y = unbox(y);
    putOpNode(iwrite, y, null);
  } else {
    putOp(iwrl, null);
  }
}


void entryPoint()
{
  if (entrypc != null) error("multiple program entry points");
  entrypc = pc;
  putOp(ientrypc, null);
}


void enter(int size)
{
  /* size: The size of local variables */
  Node x = new Node();
  makeConstNodeDesc(x, intType, size);
  putOpNode(ienter, x, null);
}


void ret(int size)
{
  /* The size of formal parameters, shows how much to unwind the stack */
  Node x = new Node();
  makeConstNodeDesc(x, intType, size);
  putOpNode(iret, x, null);
}


void open()
{
  currentLevel = 0;
  pc = new Node();
  pc.kind = KIND_INST;
  pc.op = inop;
  pc.prv = code;
  pc.nxt = null;
  code.nxt = pc;
}


void printBrakNode(Node x)
{
  assert(x != null);
  if (x.kind != KIND_INST) {
    error("unknown brak kind");
  } else {
    printf(" [${x.line}]");
  }
}


// This function Prints the Node information based on the Node type
void printNode(Node x)
{
  assert(x != null);
  if (x == gp) {
    printf(" GP");
  } else if (x == fp) {
    printf(" FP");
  } else {
    switch (x.kind) {
      case KIND_VAR:
        if (x.lev > 0)
          printf(" ${x.name}#${x.val}");
        else
          printf(" ${x.name}_base#${x.val}");
        break;
      case KIND_CONST: printf(" ${x.val}"); break;
      case KIND_FLD:
        final offset = x.type != dynamicType ? x.val : '?';
        printf(" ${x.name}_offset#$offset");
        break;
      case KIND_INST: case KIND_ADDR: printf(" (${x.line})"); break;
      case KIND_PROC: printf(" [${x.jmpTrue.line}]"); break;
      case KIND_TYPE: printf(" ${x.type.name}_type#${x.type.size}"); break;
      default: error("unknown class ${x.kind}");
    }
  }
}

void assignLineNumbers()
{
  Node i;
  int cnt;

  // assign line numbers
  cnt = 1;
  i = code;
  while (i != null) {
    i.line = cnt;
    cnt++;
    i = i.nxt;
  }
}

void decode()
{
  Node i;

  i = code;
  while (i != null) {
    printf("    instr ${i.line}: ${i.op}");
    switch (i.op) {
      // Binary operations
      case iadd:
      case isub:
      case imul:
      case idiv:
      case imod:
      case icmpeq:
      case icmple:
      case icmplt:
      case iistype:
      case istore:
      case imove:
      case icheckbounds:
      case ichecktype:
      case ilddynamic:
        printNode(i.x);
        printNode(i.y);
        assert(i.z == null);
        break;

      // Unary operations
      case ineg:
      case iisnull:
      case iload:
      case iparam:
      case ienter:
      case iret:
      case icall:
      case iwrite:
      case icount:
      case ichecknull:
      case inew:
      case inewlist:
        printNode(i.x);
        assert(i.y == null);
        assert(i.z == null);
        break;

      // Zero-arg operations
      case ientrypc:
      case iwrl:
      case inop:
        assert(i.x == null);
        assert(i.y == null);
        assert(i.z == null);
        break;

      // Ternary operations:
      case istdynamic:
        printNode(i.x);
        printNode(i.y);
        printNode(i.z);
        break;

      // Branch
      case ibr:
        printBrakNode(i.x);
        assert(i.y == null);
        assert(i.z == null);
        break;

      // Conditional branch
      case iblbc:
      case iblbs:
        printNode(i.x);
        printBrakNode(i.y);
        assert(i.z == null);
        break;

      default: error("unknown instruction");
    }
    if (i.type != null) {
      final type = i.type;
      printf(" :${type.name}");
    }
    printf("\n");
    i = i.nxt;
  }
}


void initializeParser()
{
  entrypc = null;

  code = new Node();
  code.kind = KIND_INST;
  code.op = inop;
  code.prv = null;
  code.nxt = null;

  intType = new TypeDesc('int');
  intType.form = FORM_INTEGER;
  intType.size = WORD_SIZE;

  boxedIntType = new TypeDesc('Integer');
  boxedIntType.form = FORM_CLASS;
  boxedIntType.size = WORD_SIZE*2;
  boxedIntType.fields = new Node();
  boxedIntType.fields.name = "value";
  boxedIntType.fields.type = intType;
  boxedIntType.fields.kind = KIND_FLD;
  boxedIntType.fields.val = intType.size;

  boolType = new TypeDesc('bool');
  boolType.form = FORM_BOOLEAN;
  boolType.size = WORD_SIZE;

  dynamicType = new TypeDesc('dynamic');
  dynamicType.form = FORM_INTEGER;
  dynamicType.size = WORD_SIZE;

  listType = new TypeDesc('List');
  listType.form = FORM_LIST;
  listType.size = WORD_SIZE;
  listType.base = dynamicType;
  listType.fields = new Node();
  listType.fields.name = "length";
  listType.fields.type = intType;
  listType.fields.kind = KIND_FLD;
  listType.fields.val = intType.size;

  gp = new Node();
  intType.form = FORM_INTEGER;
  intType.size = WORD_SIZE;

  fp = new Node();
  intType.form = FORM_INTEGER;
  intType.size = WORD_SIZE;
}
