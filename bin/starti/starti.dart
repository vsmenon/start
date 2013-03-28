library starti;

final _bufferedPrint = () {
  var _buffer = new StringBuffer();
  return (message) {
    final str = message.toString();
    final list = str.split('\n');
    assert(list.length > 0);
    _buffer.write(list[0]);
    if (list.length > 1) {
      print(_buffer.toString());
      _buffer = new StringBuffer();
      for (int i = 1; i < list.length - 1; ++i) {
        print(list[i]);
      }
      _buffer.write(list.last);
    }
  };
}();

void _check(bool flag, String message) {
  if (!flag) {
    print(message);
    throw new Exception(message);
  }
}

int cost(String opc) {
  final costMap = {
    "new": 10,
    "lddynamic": 100,
    "stdynamic": 100,
    "box": 12,
    "unbox": 3,
  };
  if (costMap.containsKey(opc)) {
    return costMap[opc];
  } else {
    return 1;
  }
}

class Instruction {
  final opcode;
  final args;

  Instruction(this.opcode, this.args);
}

class Type {
  static int _idgen = 0;

  final String name;
  final int id;

  final Map<String, int> fieldMap = new Map();
  final Map<String, String> fieldTypes = new Map();

  static Map<int, Type> idMap = new Map();
  static Map<String, Type> typeMap = new Map();

  Type(this.name, List<String> fields) :
    id = _idgen++ {
    idMap[id] = this;
    typeMap[name] = this;

    for (final field in fields) {
      final parts = field.split(new RegExp(r'#|:'));
      final fieldName = parts[0];
      final offset = int.parse(parts[1]);
      final typeName = parts[2];
      fieldMap[fieldName] = offset;
      fieldTypes[fieldName] = typeName;
    }
  }

  int get size => fieldMap.length * 8 + 8;
}

int _parse(String bytecode, List<Instruction> instructions) {
  int entrypc;
  // Read in the program from stdin
  for (final line in bytecode.split('\n')) {
    var words = line.trim().split(" ");
    if (line.trim() == "") continue;
    if (words[0] == "type") {
      final typename = words[1].substring(0, words[1].length-1);
      final type = new Type(typename, words.sublist(2));
      continue;
    }
    if (words[0] == "method") continue;
    if (words[0] == "global") continue;
    _check(words[0] == "instr", "Invalid instruction $line");
    final index = int.parse(words[1].replaceFirst(':', ''));
    _check(index == (instructions.length + 1), "Invalid index $index");
    final opcode = words[2];
    final args = words.sublist(3, words.length);
    instructions.add(new Instruction(opcode, args));
    if (opcode == "entrypc")
      entrypc = instructions.length;
  }
  _check(entrypc != null, "Invalid bytecode: no entry");
  return entrypc;
}

class Memory {
  // The "machine" word size.
  static const slotsize = 8;

  // Amount of global space in bytes and longs.
  static const gsize = 32768;
  static const glongsize = gsize ~/ slotsize;

  // Amount of stack space in bytes and longs.
  static const ssize = 65536;
  static const slongsize = ssize ~/ slotsize;

  // Amount of heap space in bytes and longs.
  static const hsize = 1048576;
  static const hlongsize = hsize ~/ slotsize;

  static const longsize = glongsize + slongsize + hlongsize;
  static const bytesize = longsize * slotsize;

  // Flat memory of long values with globals followed by stack
  final memory = new List.filled(longsize, 0);

  Memory() {
    _check(gsize % slotsize == 0,
        "Global memory must evenly divide into slots");
    _check(ssize % slotsize == 0,
        "Stack must evenly divide into slots");
    _check(hsize % slotsize == 0,
        "Heap must evenly divide into slots");
    fp = gp;
    sp = fp;
    hp = ssize + gsize;
    allocated = 0;
  }

  int _address2slot(addr) => (addr~/slotsize);
  int _slot2address(slot) => (slot*slotsize);

  int load(int addr) => memory[_address2slot(addr)];
  void store(int addr, int value) {
    memory[_address2slot(addr)] = value;
  }

  const gp = ssize;
  int fp;
  int sp;
  int hp;
  int allocated;

  int malloc(int bytes) {
    _check(bytes > 0 && bytes % slotsize == 0, "Malloc request must divide into slots");
    int chunk = hp;
    hp = hp + bytes;
    // Check if we're out of memory.
    if (hp >= bytesize) return 0;
    allocated += bytes;
    return chunk;
  }

  void push(int value) {
    sp -= slotsize;
    memory[_address2slot(sp)] = value;
  }

  int pop() {
    final result = memory[_address2slot(sp)];
    memory[_address2slot(sp)] = 0;
    sp += slotsize;
    return result;
  }

  void pushN(int newSlots) {
    sp -= newSlots * slotsize;
  }

  void popN(int oldSlots) {
    for (int i = 0; i < oldSlots; ++i)
      pop();
  }

  void printGlobals() {
    final map = new Map<int, int>();
    final first = _address2slot(gp);
    for (int i = first; i < first + glongsize; ++i) {
      if (memory[i] != 0) {
        map[_slot2address(i)] = memory[i];
      }
    }
    print("Globals: $map");
  }

  void printHeap() {
    final map = new Map<int, int>();
    final first = _address2slot(gp) + glongsize;
    for (int i = first; i < _address2slot(hp); ++i) {
      if (memory[i] != 0) {
        map[_slot2address(i)] = memory[i];
      }
    }
    print("Heap: $map");
  }

  bool validate() {
    if (sp <= 0) {
      print("StackOverflowError");
      return false;
    }
    _check(sp > 0,
        "Stack overflow: sp == $sp <= 0}");
    _check(fp <= gp,
        "Stack underflow: fp == $fp > gp == $gp");
    _check(sp <= fp,
        "Frame is corrupt: fp == $fp > sp == $sp");
    return true;
  }

  void dump() {
    printGlobals();
    printHeap();
    print("Stack: ${memory.sublist(_address2slot(sp),
        _address2slot(gp))}");
  }
}

// TODO(vsm): Should we make these caller-save?
// Register set : assume each method has its own private set of registers
class RegisterStack {
  final _stack = <Map>[];
  Map<int, int> _current = null;

  void push() {
    if (_current != null) _stack.add(_current);
    _current = new Map<int, int>();
  }

  void pop() {
    assert(!_stack.isEmpty);
    _current = _stack.removeLast();
  }

  int operator[](int i) => _current[i];
  void operator[]=(int i, int val) {
    _current[i] = val;
  }
}

String execute(String bytecode, { bool debug: false }) {
  // Instructions indexed by pc-1
  final instructions = [];
  final entrypc = _parse(bytecode, instructions);

  final inttype = new Type("int", []);
  final booltype = new Type("bool", []);
  final listtype = new Type("List", []);

  final memory = new Memory();
  final reg = new RegisterStack();

  // Initial pc
  var pc = entrypc;

  // Resolve operand
  int op(String arg) {
    if (arg == "GP")
      return memory.gp;
    else if (arg == "FP")
      return memory.fp;
    else if ((arg.indexOf("_base#") > 0)
          || (arg.indexOf("_offset#") > 0)
          || (arg.indexOf("_type#") > 0))
      return int.parse(arg.split("#")[1]);
    else if (arg.indexOf("#") > 0) {
      final offset = int.parse(arg.split("#")[1]);
      //return offset;
      // TODO(vsm): Delete this and clean up base above.
      return memory.load(memory.fp+offset);
    } else if (arg[0] == "(")
      return reg[int.parse(arg.slice(1,-1))];
    else if (arg[0] == "[")
      return int.parse(arg.slice(1,-1));
    else
      return int.parse(arg);
  };

  // Set operand to val
  void set(String lvalue, int val) {
    final offset = int.parse(lvalue.split("#")[1]);
    memory.store(memory.fp+offset, val);
  };

  // Instrumentation
  var cycles = 0;
  var instructionCount = 0;
  var icacheMisses = 0;
  var branchMispredicts = 0;

  // Instruction cache simulator
  final icachesize = 256;
  final icachelinebits = 2;
  final icachelinesize = 1 << icachelinebits;
  final icachelines = icachesize >> icachelinebits;
  final icache = new List.filled(icachelines, 0);
  final icacheMissCost = 10;

  void icacheFetch(int pc) {
    // Get directly mapped icache slot for this pc
    final line = pc >> icachelinebits;
    final slot =  line % icachelines;
    if (icache[slot] != line) {
      icache[slot] = line;
      icacheMisses = icacheMisses + 1;
      cycles = cycles + icacheMissCost;
    }
  };

  Instruction instructionFetch(int pc) {
    icacheFetch(pc);
    return instructions[pc-1];
  };

  // Branch prediction simulator
  final mispredictCost = 1;

  void conditionalBranch(bool condition, int newpc) {
    // Test for branch misprediction
    final predict = (newpc < pc);
    if (predict != condition) {
      branchMispredicts = branchMispredicts + 1;
      cycles = cycles + mispredictCost;
    }
    if (condition) {
      pc = newpc - 1;
    }
  };

  // Execute until top function returns
  while (true) {
    final inst = instructionFetch(pc);
    final opc = inst.opcode;
    final args = inst.args;

    if (!memory.validate()) break;

    if (debug) {
      memory.dump();
      print("\nExecuting ($pc, ${memory.fp}, ${memory.sp}): $opc $args");
    }

    cycles = cycles + cost(opc);
    instructionCount = instructionCount + 1;
    if (opc == "add")
      reg[pc] = op(args[0]) + op(args[1]);
    else if (opc == "sub")
      reg[pc] = op(args[0]) - op(args[1]);
    else if (opc == "mul")
      reg[pc] = op(args[0]) * op(args[1]);
    else if (opc == "div")
      reg[pc] = op(args[0]) ~/ op(args[1]);
    else if (opc == "mod")
      reg[pc] = op(args[0]) % op(args[1]);
    else if (opc == "neg")
      reg[pc] = -op(args[0]);
    else if (opc == "cmpeq")
      reg[pc] = (op(args[0]) == op(args[1])) ? 1 : 0;
    else if (opc == "cmple")
      reg[pc] = (op(args[0]) <= op(args[1])) ? 1 : 0;
    else if (opc == "cmplt")
      reg[pc] = (op(args[0]) < op(args[1])) ? 1 : 0;
    else if (opc == "br")
      pc = op(args[0]) - 1;
    else if (opc == "blbc")
      conditionalBranch(op(args[0]) == 0, op(args[1]));
    else if (opc == "blbs")
      conditionalBranch(op(args[0]) != 0, op(args[1]));
    else if (opc == "call") {
      // Push old pc and set new one
      memory.push(pc);
      pc = op(args[0]) - 1;
      // Push old fp and set new one
      memory.push(memory.fp);
      memory.fp = memory.sp;
    }
    else if (opc == "load") {
      reg[pc] = memory.load(op(args[0]));
      if (debug)
        print("Loading ${reg[pc]} at ${op(args[0])}");
    }
    else if (opc == "store") {
      if (debug)
        print("Storing ${op(args[0])} at ${op(args[1])}");
      memory.store(op(args[1]), op(args[0]));
    }
    else if (opc == "lddynamic") {
      final ref = op(args[0]);
      final fieldname = args[1].split("_offset")[0];
      final reftypeid = memory.load(ref);
      final dynamicType = Type.idMap[reftypeid];
      final offset = dynamicType.fieldMap[fieldname];
      if (offset == null) {
        print("DynamicError");
        break;
      }
      final value = memory.load(ref+offset);
      // Auto-box int values.
      final fieldTypeName = dynamicType.fieldTypes[fieldname];
      if (fieldTypeName == inttype.name) {
        // Auto-box.
        // TODO(vsm): Factor out.
        final boxed = memory.malloc(16);
        if (boxed == 0) {
          print("OutOfMemoryError");
          break;
        }
        memory.store(boxed, inttype.id);
        memory.store(boxed+8, value);
        reg[pc] = boxed;
      } else {
        // Already a boxed type.
        reg[pc] = value;
      }
    }
    else if (opc == "stdynamic") {
      var value = op(args[0]);
      final ref = op(args[1]);
      final fieldname = args[2].split("_offset")[0];
      final reftypeid = memory.load(ref);
      final dynamicType = Type.idMap[reftypeid];
      final offset = dynamicType.fieldMap[fieldname];
      if (offset == null) {
        print("DynamicError");
        break;
      }
      // Auto-unbox int values based on static type.
      final fieldTypeName = dynamicType.fieldTypes[fieldname];
      if (fieldTypeName == inttype.name) {
        _check(memory.load(value) == inttype.id, "Invalid boxed int");
        value = memory.load(value+8);
      }
      memory.store(ref+offset, value);
    }
    else if (opc == "box") {
      final value = op(args[0]);
      final boxed = memory.malloc(16);
      if (boxed == 0) {
        print("OutOfMemoryError");
        break;
      }
      memory.store(boxed, inttype.id);
      memory.store(boxed+8, value);
      reg[pc] = boxed;
    }
    else if (opc == "unbox") {
      final ref = op(args[0]);
      final reftypeid = memory.load(ref);
      if (reftypeid != inttype.id) {
        print("UnboxError");
        break;
      }
      reg[pc] = memory.load(ref+8);
    }
    else if (opc == "move") {
      if (debug)
        print("Moving ${op(args[0])} to ${args[1]}");
      set(args[1], op(args[0]));
    }
    else if (opc == "write") {
      _bufferedPrint(" ${op(args[0])}");
      if (debug)
        _bufferedPrint("\n");
    }
    else if (opc == "wrl")
      _bufferedPrint("\n");
    else if (opc == "param") {
      if (debug)
        print("Pushing ${op(args[0])} at ${memory.sp}");
      // Push arg
      memory.push(op(args[0]));
    }
    else if (opc == "new") {
      final typename = args[0].split("_type")[0];
      // TODO(vsm): Install vtable.
      // TODO(vsm): Replace with newlist.
      if (typename.startsWith('List')) {
        final length = op(args[1]);
        final list = memory.malloc(16+8*length);
        if (list == 0) {
          print("OutOfMemoryError");
          break;
        }
        reg[pc] = list;
        memory.store(list, listtype.id);
        memory.store(list+8, length);
      } else {
        final type = Type.typeMap[typename];
        _check(type.size == op(args[0]),
            "Incorrect size ${op(args[0])} for ${type.name} (expected ${type.size})");
        final obj = memory.malloc(type.size);
        if (obj == 0) {
          print("OutOfMemoryError");
          break;
        }

        memory.store(obj, type.id);
        reg[pc] = obj;
      }
    }
    else if (opc == "newlist") {
      final length = op(args[0]);
      final list = memory.malloc(16+8*length);
      if (list == 0) {
        print("OutOfMemoryError");
        break;
      }
      reg[pc] = list;
      memory.store(list, listtype.id);
      memory.store(list+8, length);
    }
    else if (opc == "checknull") {
      final ref = op(args[0]);
      if (ref == 0) {
        print('NullPointerError');
        break;
      }
      reg[pc] = ref;
    }
    else if (opc == "checkbounds") {
      final list = op(args[0]);
      final index = op(args[1]);
      final length = memory.load(list+8);
      if (index < 0 || length <= index) {
        print('RangeError');
        break;
      }
    }
    else if (opc == "checktype") {
      final ref = op(args[0]);
      final reftypeid = memory.load(ref);
      final typename = args[1].split("_type")[0];
      final type = Type.typeMap[typename];
      if (type.id != reftypeid) {
        print('TypeError');
        break;
      }
      reg[pc] = ref;
    }
    else if (opc == "enter") {
      // New register window
      reg.push();
      // Allocate locals
      memory.pushN(op(args[0]) ~/ Memory.slotsize);
    }
    else if (opc == "ret") {
      // Pop locals
      memory.sp = memory.fp;
      if (memory.fp == memory.gp)
        // Top-level method is returning.
        break;
      // Restore fp and pc
      memory.fp = memory.pop();
      pc = memory.pop();
      // Pop arguments
      final args2pop = op(args[0]);
      memory.sp = memory.sp + args2pop;
      // Restore registers
      reg.pop();
    }
    else if ((opc == "entrypc") || (opc == "nop"))
      pc = pc;
    else
      _check(false, "Unknown opcode $opc");
    if (debug)
      print("reg[$pc] == ${reg[pc]}");
    pc = pc + 1;
  }
  final stats = """
-------------------------
- Dynamic cycles : $cycles
- Instruction count : $instructionCount
- Instruction cache misses : $icacheMisses
- Branch mispredicts : $branchMispredicts
- Allocated bytes: ${memory.allocated}
""";
  return stats;
}
