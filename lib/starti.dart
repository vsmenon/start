library starti;

import 'dart:typed_data';

// The machine word size.  This must match the value in startc.
const WORD_SIZE = 4;

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
    "nop": 0,
    "new": 10,
    "lddynamic": 100,
    "stdynamic": 100,
    "box": 12,
    "unbox": 3,
    "istype": 2,
    "checktype": 2,
    "checkbounds": 3,
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

  int get size => fieldMap.length * WORD_SIZE + WORD_SIZE;
}

int _parse(String bytecode, List<Instruction> instructions) {
  int entrypc;
  // Read in the program from stdin
  for (final line in bytecode.split('\n')) {
    var words = line.trim().split(" ");
    if (line.trim() == "") continue;
    if (words[0][0] == "#") continue;
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
  // Amount of global space in bytes and longs.
  static const GLOBAL_DATA_SIZE = 32768;
  static const GLOBAL_DATA_WORD_SIZE = GLOBAL_DATA_SIZE ~/ WORD_SIZE;

  // Amount of stack space in bytes and longs.
  static const STACK_SIZE = 65536;
  static const STACK_WORD_SIZE = STACK_SIZE ~/ WORD_SIZE;

  // Amount of heap space in bytes and longs.
  static const HEAP_SIZE = 1048576;
  static const HEAP_WORD_SIZE = HEAP_SIZE ~/ WORD_SIZE;

  static const MEMORY_WORD_SIZE = GLOBAL_DATA_WORD_SIZE + STACK_WORD_SIZE
      + HEAP_WORD_SIZE;
  static const MEMORY_SIZE = MEMORY_WORD_SIZE * WORD_SIZE;

  // Flat memory of values with globals followed by stack
  final _memory = new Int32List(MEMORY_WORD_SIZE);

  Memory() {
    _check(GLOBAL_DATA_SIZE % WORD_SIZE == 0,
        "Global memory must evenly divide into words");
    _check(STACK_SIZE % WORD_SIZE == 0,
        "Stack must evenly divide into words");
    _check(HEAP_SIZE % WORD_SIZE == 0,
        "Heap must evenly divide into words");
    fp = gp;
    sp = fp;
    hp = STACK_SIZE + GLOBAL_DATA_SIZE;
    _allocatedBytes = 0;
  }

  int _address2slot(addr) {
    _check(addr % WORD_SIZE == 0, "Unaligned load");
    return addr~/WORD_SIZE;
  }
  int _slot2address(slot) => (slot*WORD_SIZE);

  // Load the value at the given address.
  int load(int addr) => _memory[_address2slot(addr)];

  // Store the value to the given address.
  void store(int addr, int value) {
    _memory[_address2slot(addr)] = value;
  }

  // Global data pointer.
  const gp = STACK_SIZE;

  // Stack frame pointer.
  int fp;

  // Stack pointer.
  int sp;

  // Heap pointer.
  int hp;
  int _allocatedBytes;

  // Allocate an object of the given [size] in bytes on the heap.
  int malloc(int size) {
    _check(size > 0 && size % WORD_SIZE == 0,
        "Malloc request must divide into words");
    int chunk = hp;
    hp = hp + size;
    // Check if we're out of memory.
    if (hp >= MEMORY_SIZE) return 0;
    _allocatedBytes += size;
    return chunk;
  }

  // Push a value on the stack.
  void push(int value) {
    sp -= WORD_SIZE;
    store(sp, value);
  }

  // Pop a value from the stack.
  int pop() {
    final result = load(sp);
    // Clear out the old stack slot to catch errors.
    store(sp, 0);
    sp += WORD_SIZE;
    return result;
  }

  // Push [n] zero values onto the stack.
  void pushN(int n) {
    sp -= n * WORD_SIZE;
  }

  // Pop [n] values from the stack and discard.
  void popN(int n) {
    for (int i = 0; i < n; ++i)
      pop();
  }

  // Validate the state of memory.
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

  void _debug() {
    _debugGlobals();
    _debugHeap();
    print("Stack: ${_memory.sublist(_address2slot(sp),
        _address2slot(gp))}");
  }

  void _debugGlobals() {
    final map = new Map<int, int>();
    final first = _address2slot(gp);
    for (int i = first; i < first + GLOBAL_DATA_WORD_SIZE; ++i) {
      if (_memory[i] != 0) {
        map[_slot2address(i)] = _memory[i];
      }
    }
    print("Globals: $map");
  }

  void _debugHeap() {
    final map = new Map<int, int>();
    final first = _address2slot(gp) + GLOBAL_DATA_WORD_SIZE;
    for (int i = first; i < _address2slot(hp); ++i) {
      if (_memory[i] != 0) {
        map[_slot2address(i)] = _memory[i];
      }
    }
    print("Heap: $map");
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

// Resolve the value of the operand string from input.
int resolveOperand(Memory memory, RegisterStack reg, String operand) {
  if (operand == "GP")
    return memory.gp;
  else if (operand == "FP")
    return memory.fp;
  else if ((operand.indexOf("_base#") > 0)
      || (operand.indexOf("_offset#") > 0)
      || (operand.indexOf("_type#") > 0))
    return int.parse(operand.split("#")[1]);
  else if (operand.indexOf("#") > 0) {
    final offset = int.parse(operand.split("#")[1]);
    //return offset;
    // TODO(vsm): Delete this and clean up base above.
    return memory.load(memory.fp+offset);
  } else if (operand[0] == "(")
    return reg[int.parse(operand.substring(1, operand.length - 1))];
  else if (operand[0] == "[")
    return int.parse(operand.substring(1, operand.length - 1));
  else
    return int.parse(operand);
}

String execute(String bytecode, { bool debug: false }) {
  // Builtin types.
  Type.idMap = new Map();
  Type.typeMap = new Map();
  Type._idgen = 0;
  final inttype = new Type("int", []);
  final booltype = new Type("bool", []);
  final listtype = new Type("List", ["length#$WORD_SIZE:int"]);
  final boxedIntType = new Type("Integer", ["value#$WORD_SIZE:int"]);
  final dynamicType = new Type("dynamic", []);

  // Instructions indexed by pc-1
  final instructions = [];
  final entrypc = _parse(bytecode, instructions);

  final memory = new Memory();
  final reg = new RegisterStack();

  // Initial pc
  var pc = entrypc;

  // Convenience wrapper to resolve operand string.
  int op(String arg) => resolveOperand(memory, reg, arg);

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
  final counters = new Map<dynamic, int>();

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
      memory._debug();
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
    else if (opc == "isnull")
      reg[pc] = (op(args[0]) == 0) ? 1 : 0;
    else if (opc == "istype") {
      final ref = op(args[0]);
      if (ref == 0) {
        // Null is always false.
        reg[pc] = 0;
      } else {
        final reftypeid = memory.load(ref);
        final typename = args[1].split("_type")[0];
        final type = Type.typeMap[typename];
        final match = (type == dynamicType) ? true : (type.id == reftypeid);
        reg[pc] =  match ? 1 : 0;
      }
    }
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
        final boxed = memory.malloc(WORD_SIZE*2);
        if (boxed == 0) {
          print("OutOfMemoryError");
          break;
        }
        memory.store(boxed, boxedIntType.id);
        memory.store(boxed+WORD_SIZE, value);
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
        _check(memory.load(value) == boxedIntType.id, "Invalid boxed int");
        value = memory.load(value+WORD_SIZE);
      }
      memory.store(ref+offset, value);
    }
    else if (opc == "box") {
      final value = op(args[0]);
      final boxed = memory.malloc(WORD_SIZE*2);
      if (boxed == 0) {
        print("OutOfMemoryError");
        break;
      }
      memory.store(boxed, boxedIntType.id);
      memory.store(boxed+WORD_SIZE, value);
      reg[pc] = boxed;
    }
    else if (opc == "unbox") {
      final ref = op(args[0]);
      final reftypeid = memory.load(ref);
      if (reftypeid != boxedIntType.id) {
        print("UnboxError");
        break;
      }
      reg[pc] = memory.load(ref+WORD_SIZE);
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
      final typename = args[0].split("_type#")[0];
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
    else if (opc == "newlist") {
      final length = op(args[0]);
      final list = memory.malloc(WORD_SIZE*2+WORD_SIZE*length);
      if (list == 0) {
        print("OutOfMemoryError");
        break;
      }
      reg[pc] = list;
      memory.store(list, listtype.id);
      memory.store(list+WORD_SIZE, length);
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
      final length = memory.load(list+WORD_SIZE);
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
      memory.pushN(op(args[0]) ~/ WORD_SIZE);
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
    else if (opc == "count") {
      var counterId = args[0];
      if (counterId[0] != r'$') {
        // If the counterId doesn't start with a $ then unpack it.
        counterId = op(counterId);
      } else {
        // Trim the quotes around the arg name.
        counterId = counterId.substring(1, counterId.length);
      }
      if (!counters.containsKey(counterId))
        counters[counterId] = 0;
      counters[counterId]++;
    }
    else
      _check(false, "Unknown opcode $opc");
    if (debug && reg._current != null)
      print("reg[$pc] == ${reg[pc]}");
    pc = pc + 1;
  }
  final stats = """
-------------------------
- Dynamic cycles : $cycles
- Instruction count : $instructionCount
- Instruction cache misses : $icacheMisses
- Branch mispredicts : $branchMispredicts
- Allocated bytes: ${memory._allocatedBytes}
""";
  var counts = "";
  if (!counters.isEmpty) {
    counts = "- Counts : ";
    var keys = counters.keys.toList();
    var counterCompare = (a, b) {
      // Sort nums ahead of strings.
      if (a is num && b is! num) {
        return -1;
      } else if (a is! num && b is num) {
        return 1;
      } else {
        return Comparable.compare(a, b);
      }
    };
    keys.sort(counterCompare);
    for (var key in keys) {
      counts += "\n  $key: ${counters[key]}";
    }
  }
  return stats + counts;
}
