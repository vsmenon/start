part of startc;

/* kind */
class Kind {
  const Kind._(this._value);
  final _value;
  toString() => 'KIND_${_value.toUpperCase()}';
}

const KIND_VAR = const Kind._('Var');
const KIND_CONST = const Kind._('Const');
const KIND_FIELD = const Kind._('Field');
const KIND_TYPE = const Kind._('Type');
const KIND_FUNC = const Kind._('Func');
const KIND_SYSCALL = const Kind._('SysCall');
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

  Scope fields = new Scope();  // linked list of the fields in a struct
  int size = 0;  // total size of the type
  TypeDesc base;  // base type (for list or pointer)
  TypeDesc _pointer; // cached pointer type.  Use the ref function.
}

class Node {
  Kind kind;  // Var, Const, Field, Type, Proc, SProc, Addr, Inst
  int lev = 0;  // 0 = global, 1 = local
  Scope dsc;  // Proc: link to procedure scope (head)
  TypeDesc type;  // type
  String name;  // name
  int val = 0;  // Const: value; Var: addr; Fld: offset; SProc: num; Type: size

  Node original;  // Pointer to original node object if a copy was made
  Instruction entry;  // For functions
}

class DynamicAddress extends Node {
  DynamicAddress(this.base, this.field);

  final Node base;
  final Node field;
}

class Instruction extends Node {
  Opcode op;
  Node x, y, z;  // the operands
  Instruction prv, nxt;  // previous and next instruction
  int line = 0;  // line number for printing purposes
  Instruction jmpTrue, jmpFalse;  // Jmp: true and false chains; Proc: true = entry
}

class Scope {
  Scope([this.parent = null, this.proc = null]);

  final Scope parent;
  final Node proc;
  final List<Node> nodes = new List<Node>();

  void validate() {
    int depth = 0;
    for (Scope p = parent; p != null; p = p.parent)
      depth++;
    bool params = true;
    for (Node node in nodes) {
      assert(node.lev == depth);
      Scope desc = node.dsc;
      if (params) {
        if (desc != null)
          assert(desc == this);
        else
          params = false;
      } else {
        assert(desc == null);
      }
    }
  }

  Node find(String id) {
    Node node = nodes.firstWhere((Node n) => n.name == id, orElse: () => null);

    if (node != null) {
      return node;
    } else {
      return parent != null ? parent.find(id) : null;
    }
  }

  // This function adds a new object at the end of the object list pointed to
  // by root and returns a pointer to the new node.
  Node add(String id) {
    for (Node current in nodes) {
      if (current.name == id) {
        error("duplicate identifier");
      }
    }

    Node node = new Node();
    node.kind = null;
    node.lev = parent == null ? 0 : 1;
    node.dsc = null;
    node.type = null;
    node.name = id;
    node.val = 0;
    nodes.add(node);
    return node;
  }


  Node insert(Kind kind, TypeDesc type, String name, int val)
  {
    for (Node current in nodes) {
      if (current.name == name)
        error("duplicate symbol");
    }

    Node node = new Node();
    nodes.add(node);
    node.kind = kind;
    node.type = type;
    node.name = name;
    node.val = val;
    node.dsc = null;
    node.lev = 0;
    return node;
  }

  int returnSize() {
    assert(proc != null);
    int size = 0;
    for (Node curr in nodes) {
      if (curr.dsc == proc)
        size += WORD_SIZE;
    }
    return size;
  }
}

TypeDesc intType, boolType, dynamicType, listType, boxedIntType;
Instruction pc;

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
const iretv = const Opcode._('retv');

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

Instruction code, entrypc;
Node fp, gp;

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
Instruction putOpNodeNodeNode(Opcode op, Node x, Node y, Node z, TypeDesc type)
{
  Instruction i;

  pc.nxt = new Instruction();
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

Instruction putOpNodeNode(Opcode op, Node x, Node y, TypeDesc type)
{
  return putOpNodeNodeNode(op, x, y, null, type);
}

Instruction putOpNode(Opcode op, Node x, TypeDesc type)
{
  return putOpNodeNode(op, x, null, type);
}


Instruction putOp(Opcode op, TypeDesc type)
{
  return putOpNodeNode(op, null, null, type);
}


void makeDynamicNodeDesc(Node x, String fieldName) {
  x.kind = KIND_FIELD;
  x.type = dynamicType;
  x.lev = -1;
  x.name = fieldName;
}


// This function SETS the member fields of a CSGNode object.
void makeConstNodeDesc(Node x, TypeDesc typ, int val)
{
  x.kind = KIND_CONST;
  x.type = typ;
  x.val = val;
  x.lev = -1;
}


// This function make a COPY of a CSGNode object
Node makeNodeDesc(Node y) {
  assert(y is! Instruction);
  Node x = new Node();
  int i;

  x.kind = y.kind;
  x.type = y.type;
  x.val = y.val;
  x.lev = y.lev;
  x.name = y.name;
  x.entry = y.entry;

  // Make the 'original' field of the copy to point back to original Node object
  if (y.original == null) {
    x.original = y;
  } else {
    x.original = y.original;
  }
  return x;
}


Node dynamicAddr(Node ref, Node field) {
  final addr = new DynamicAddress(ref, field);
  addr.kind = KIND_DYN_ADDR;
  return addr;
}

/*****************************************************************************/

Node unbox(Node x) {
  if (x.type == intType) return x; // Already unboxed;
  if (x.type == dynamicType) {
    final checked = checkNull(x);
    final boxed = checkType(checked, boxedIntType);
    final ctr = globalScope.find("Integer");
    final field = ctr.type.fields.find("value");
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
    final ctr = globalScope.find("Integer");
    final boxed = putOpNode(inew, ctr, boxedIntType);
    final field = ctr.type.fields.find("value");
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
    final addr = x as DynamicAddress;
    x = putOpNodeNode(ilddynamic, addr.base, addr.field, dynamicType);
  } else if (x.kind == KIND_INST && x.type.form == FORM_POINTER) {
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
  }
  return x;
}


Node indexAddress(Node x, Node y) { /* x = x[y] */
  Node baseoffset = new Node();
  makeConstNodeDesc(baseoffset, intType, intType.size*2);

  final basetype = (x.type == dynamicType) ? dynamicType : x.type.base;
  Node indexoffset = new Node();
  makeConstNodeDesc(indexoffset, intType, intType.size);

  if (x.kind != KIND_INST) {
    if (x.lev == 0) {
      final type = x.type;
      x = putOpNodeNode(iadd, x, gp, ref(type));
      x = putOpNode(iload, x, type);
    }
  }
  x = checkNull(x);
  x = checkType(x, listType);
  y = unbox(y);
  checkBounds(x, y);
  x = putOpNodeNode(iadd, x, baseoffset, ref(basetype));
  y = op2(TokenType.STAR, y, indexoffset);

  x = putOpNodeNode(iadd, x, y, ref(basetype));
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
void fixLink(Instruction lbl) {
  if (lbl != null) {
    if ((lbl.op == icall) || (lbl.op == ibr)) {
      lbl.x = pc;
    } else {
      lbl.y = pc;
    }
  }
}


void backJump(Instruction lbl) {
  putOpNode(ibr, lbl, null);
}


Instruction forwardJump(Instruction lbl) {
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


Node op1(TokenType op, Node x) { /* x = op x */
  x = unbox(x);
  if (op == TokenType.PLUS) {
    testInt(x);
  } else if (op == TokenType.MINUS) {
    testInt(x);
    x = putOpNode(ineg, x, x.type);
  }
  return x;
}


Node op2(TokenType op, Node x, Node y)  /* x = x op y */
{
  assert(x != null);
  assert(y != null);
  x = unbox(x);
  y = unbox(y);

  switch (op) {
    case TokenType.PLUS: x = putOpNodeNode(iadd, x, y, intType); break;
    case TokenType.MINUS: x = putOpNodeNode(isub, x, y, intType); break;
    case TokenType.STAR: x = putOpNodeNode(imul, x, y, intType); break;
    case TokenType.TILDE_SLASH: x = putOpNodeNode(idiv, x, y, intType); break;
    case TokenType.PERCENT: x = putOpNodeNode(imod, x, y, intType); break;
  }
  return x;
}


Node istype(TokenType op, Node x, Node y) {
  // TODO(vsm): This should be statically folded.
  // TODO(vsm): Handle bool.
  if (y.type == intType) {
    y = globalScope.find("Integer");
  }

  x = box(x);

  Instruction test = putOpNodeNode(iistype, x, y, boolType);
  final opcode = (op == TokenType.IS) ? iblbc : iblbs;
  Instruction branch = putOpNode(opcode, test, null);
  branch.jmpFalse = null;
  branch.jmpTrue = pc.prv;
  return branch;
}


Node relation(TokenType op, Node x, Node y)
{
  Instruction test;
  Instruction branch;

  if (op == TokenType.EQ_EQ || op == TokenType.BANG_EQ) {
    // isnull
    var ref = null;
    if (isNull(x)) {
      ref = box(y);
    } else if(isNull(y)) {
      ref = box(x);
    }
    if (ref != null) {
      test = putOpNode(iisnull, ref, boolType);
      final opcode = (op == TokenType.EQ_EQ) ? iblbc : iblbs;
      branch = putOpNode(opcode, test, null);
      branch.jmpFalse = null;
      branch.jmpTrue = pc.prv;
      return branch;
    }
  }

  x = unbox(x);
  y = unbox(y);

  switch (op) {
    case TokenType.EQ_EQ:
      test = putOpNodeNode(icmpeq, x, y, boolType);
      branch = putOpNode(iblbc, test, null);
      break;
    case TokenType.BANG_EQ:
      test = putOpNodeNode(icmpeq, x, y, boolType);
      branch = putOpNode(iblbs, test, null);
      break;
    case TokenType.LT:
      test = putOpNodeNode(icmplt, x, y, boolType);
      branch = putOpNode(iblbc, test, null);
      break;
    case TokenType.GT:
      test = putOpNodeNode(icmple, x, y, boolType);
      branch = putOpNode(iblbs, test, null);
      break;
    case TokenType.LT_EQ:
      test = putOpNodeNode(icmple, x, y, boolType);
      branch = putOpNode(iblbc, test, null);
      break;
    case TokenType.GT_EQ:
      test = putOpNodeNode(icmplt, x, y, boolType);
      branch = putOpNode(iblbs, test, null);
      break;
  }
  branch.jmpFalse = null;
  branch.jmpTrue = pc.prv;
  return branch;
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
  if (x.kind == KIND_INST) {
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
    final addr = x as DynamicAddress;
    x = putOpNodeNodeNode(istdynamic, y, addr.base, addr.field, null);
  } else if (x.kind == KIND_INST) {
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

Node convert(Node x, TypeDesc ftyp)
{
  if (ftyp == dynamicType) {
    x = box(x);
  } else if (ftyp == intType) {
    x = unbox(x);
  } else if (x.type == dynamicType) {
    x = checkType(x, ftyp);
  } else {
    if (x.type != ftyp && !isNull(x)) error("Incorrect parameter type");
  }
  return x;
}

Node parameter(Node x, TypeDesc ftyp, Kind kind)
{
  x = convert(x, ftyp);
  x = putOpNode(iparam, x, null);
  return x;
}


/*****************************************************************************/


Node call(Node x, TypeDesc type)
{
  return putOpNode(icall, x, type);
}


Node ioCall(Node x, Node y)
{
  Node z;

  if (x.val < 3) testInt(y);
  if (x.val == 1) {
    y = unbox(y);
    return putOpNode(icount, y, null);
  } else if (x.val == 2) {
    y = unbox(y);
    return putOpNode(iwrite, y, null);
  } else {
    return putOp(iwrl, null);
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

void retv(int size, Node val, TypeDesc desc) {
  /* The size of formal parameters, shows how much to unwind the stack */
  Node x = new Node();
  makeConstNodeDesc(x, intType, size);
  val = convert(val, desc);
  putOpNodeNode(iretv, x, val, desc);

}

void open()
{
  pc = new Instruction();
  pc.kind = KIND_INST;
  pc.op = inop;
  pc.prv = code;
  pc.nxt = null;
  code.nxt = pc;
}


void printBrakNode(Instruction x)
{
  assert(x != null);
  printf(" [${x.line}]");
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
      case KIND_FIELD:
        final offset = x.type != dynamicType ? x.val : '?';
        printf(" ${x.name}_offset#$offset");
        break;
      case KIND_INST: printf(" (${(x as Instruction).line})"); break;
      case KIND_FUNC: printf(" [${x.entry.line}]"); break;
      case KIND_TYPE: printf(" ${x.type.name}_type#${x.type.size}"); break;
      default: error("unknown class ${x.kind}");
    }
  }
}

void assignLineNumbers()
{
  Instruction i;
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
  Instruction i;

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
      case iretv:
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

  code = new Instruction();
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
  boxedIntType.fields = new Scope();
  boxedIntType.fields.nodes.add(new Node());
  boxedIntType.fields.nodes[0].name = "value";
  boxedIntType.fields.nodes[0].type = intType;
  boxedIntType.fields.nodes[0].kind = KIND_FIELD;
  boxedIntType.fields.nodes[0].val = intType.size;

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
  listType.fields = new Scope();
  listType.fields.nodes.add(new Node());
  listType.fields.nodes[0].name = "length";
  listType.fields.nodes[0].type = intType;
  listType.fields.nodes[0].kind = KIND_FIELD;
  listType.fields.nodes[0].val = intType.size;

  gp = new Node();
  intType.form = FORM_INTEGER;
  intType.size = WORD_SIZE;

  fp = new Node();
  intType.form = FORM_INTEGER;
  intType.size = WORD_SIZE;
}

void error(String msg) {
  var message = "line FIXME error $msg\n";
  print(message);
  throw new Exception(message);
}