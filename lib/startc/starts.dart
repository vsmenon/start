part of startc;

// Tokenizer

class Token {
  const Token._(this._value);
  final _value;
  toString() => 'TOKEN_${_value.toUpperCase()}';
}

const TOKEN_TIMES = const Token._('times');
const TOKEN_DIV = const Token._('div');
const TOKEN_MOD = const Token._('mod');
const TOKEN_PLUS = const Token._('plus');
const TOKEN_MINUS = const Token._('minus');
const TOKEN_EQL = const Token._('eql');
const TOKEN_NEQ = const Token._('neq');
const TOKEN_LSS = const Token._('lss');
const TOKEN_LEQ = const Token._('leq');
const TOKEN_GTR = const Token._('gtr');
const TOKEN_GEQ = const Token._('geq');
const TOKEN_IS = const Token._('is');
const TOKEN_ISNOT = const Token._('isnot');
const TOKEN_PERIOD = const Token._('period');
const TOKEN_COMMA = const Token._('comma');
const TOKEN_RPAREN = const Token._('rparen');
const TOKEN_RBRAK = const Token._('rbrak');
const TOKEN_RBRACE = const Token._('rbrace');
const TOKEN_LPAREN = const Token._('lparen');
const TOKEN_LBRAK = const Token._('lbrak');
const TOKEN_LBRACE = const Token._('lbrace');
const TOKEN_BECOMES = const Token._('becomes');
const TOKEN_NUMBER = const Token._('number');
const TOKEN_IDENT = const Token._('ident');
const TOKEN_SEMICOLON = const Token._('semicolon');
const TOKEN_ELSE = const Token._('else');
const TOKEN_IF = const Token._('if');
const TOKEN_WHILE = const Token._('while');
const TOKEN_CLASS = const Token._('class');
const TOKEN_VOID = const Token._('void');
const TOKEN_EOF = const Token._('eof');
const TOKEN_NEW = const Token._('new');

const MAX_ID_LENGTH = 16;

int _currentAsInt = null;
int get currentAsInt {
  assert(_currentAsInt != null);
  final current = _currentAsInt;
  _currentAsInt = null;
  return current;
}

StringBuffer _currentBuffer = null;
String get currentAsString {
  assert(_currentBuffer != null);
  String current = _currentBuffer.toString();
  return current;
}

// Current line / position / character in the script.
String _script;
int _ch;
int _line;
int _position = 0;

// Support for C-style processing.
final int EOF = null;

int getc(String file) {
  if (_position >= file.length) return EOF;
  int result = file.codeUnitAt(_position);
  _position++;
  return result;
}

int strcmp(String str1, String str2) {
  return str1.compareTo(str2);
}

void error(String msg) {
  var message = " line $_line error $msg\n";
  print(message);
  throw new Exception(message);
}

int _int(String char) {
  assert(char.length == 1);
  return char.codeUnitAt(0);
}

void identifier() {
  int i;

  i = 0;
  _currentBuffer = new StringBuffer();
  while (((_int('a') <= _ch) && (_ch <= _int('z'))) ||
         ((_int('A') <= _ch) && (_ch <= _int('Z'))) ||
         ((_int('0') <= _ch) && (_ch <= _int('9'))) ||
         (_ch == _int('_'))) {
    if (i < MAX_ID_LENGTH) _currentBuffer.writeCharCode(_ch);
    i++;
    _ch = getc(_script);
  }
  if (i >= MAX_ID_LENGTH) error("identifier too long");
}


void number()
{
  _currentAsInt = 0;
  while ((_int('0') <= _ch) && (_ch <= _int('9')) &&
         ((0x8000000000000000 + _int('0') - _ch) ~/ 10 >= _currentAsInt)) {
    _currentAsInt = _currentAsInt * 10 + _ch - _int('0');
    _ch = getc(_script);
  }
  if ((_int('0') <= _ch) && (_ch <= _int('9'))) {
    error("number too large");
  }
}


void comment()
{
  _ch = getc(_script);
  do {
    while ((_ch != EOF) && (_ch != _int('*'))) {
      if (_ch == _int('\n')) _line++;
      _ch = getc(_script);
    }
    _ch = getc(_script);
  } while ((_ch != EOF) && (_ch != _int('/')));
  _ch = getc(_script);
}


void commentLine()
{
  do {
    _ch = getc(_script);
  } while ((_ch != EOF) && (_ch != _int('\n')));
}


Token nextToken()
{
  Token sym;

  while ((_ch != EOF) && (_ch <= _int(' '))) {
    if (_ch == _int('\n')) _line++;
    _ch = getc(_script);
  }
  if (_ch == null) {
    sym = TOKEN_EOF;
  } else {
    switch (new String.fromCharCode(_ch)) {
      case '+':
        sym = TOKEN_PLUS;
        _ch = getc(_script);
        break;
      case '-':
        sym = TOKEN_MINUS;
        _ch = getc(_script);
        break;
      case '*':
        sym = TOKEN_TIMES;
        _ch = getc(_script);
        break;
      case '%':
        sym = TOKEN_MOD;
        _ch = getc(_script);
        break;
      case '~':
        _ch = getc(_script);
        if (_ch != _int('/')) error("illegal symbol encountered");
        sym = TOKEN_DIV;
        _ch = getc(_script);
        break;
      case '/':
        sym = TOKEN_DIV;
        _ch = getc(_script);
        if (_ch == _int('/')) {
          commentLine();
          sym = nextToken();
        } else if (_ch == _int('*')) {
          comment();
          sym = nextToken();
        }
        break;
      case '=':
        sym = TOKEN_BECOMES;
        _ch = getc(_script);
        if (_ch == _int('=')) {
          sym = TOKEN_EQL;
          _ch = getc(_script);
        }
        break;
      case '#':
        commentLine();
        sym = nextToken();
        break;
      case '.':
        sym = TOKEN_PERIOD;
        _ch = getc(_script);
        break;
      case ',':
        sym = TOKEN_COMMA;
        _ch = getc(_script);
        break;
      case ';':
        sym = TOKEN_SEMICOLON;
        _ch = getc(_script);
        break;
      case '!':
        _ch = getc(_script);
        if (_ch != _int('=')) error("illegal symbol encountered");
        sym = TOKEN_NEQ;
        _ch = getc(_script);
        break;
      case '(':
        sym = TOKEN_LPAREN;
        _ch = getc(_script);
        break;
      case '[':
        sym = TOKEN_LBRAK;
        _ch = getc(_script);
        break;
      case '{':
        sym = TOKEN_LBRACE;
        _ch = getc(_script);
        break;
      case ')':
        sym = TOKEN_RPAREN;
        _ch = getc(_script);
        break;
      case ']':
        sym = TOKEN_RBRAK;
        _ch = getc(_script);
        break;
      case '}':
        sym = TOKEN_RBRACE;
        _ch = getc(_script);
        break;
      case '<':
        sym = TOKEN_LSS;
        _ch = getc(_script);
        if (_ch == _int('=')) {
          sym = TOKEN_LEQ;
          _ch = getc(_script);
        }
        break;
      case '>':
        sym = TOKEN_GTR;
        _ch = getc(_script);
        if (_ch == _int('=')) {
          sym = TOKEN_GEQ;
          _ch = getc(_script);
        }
        break;

      case '0': case '1': case '2': case '3': case '4':
      case '5': case '6': case '7': case '8': case '9':
        sym = TOKEN_NUMBER;
        number();
        break;

      case 'c':
          sym = TOKEN_IDENT; identifier();
          if (strcmp(currentAsString, "class") == 0) sym = TOKEN_CLASS;
          break;
      case 'e':
        sym = TOKEN_IDENT;
        identifier();
        if (strcmp(currentAsString, "else") == 0) sym = TOKEN_ELSE;
        break;
      case 'i':
        sym = TOKEN_IDENT;
        identifier();
        if (strcmp(currentAsString, "if") == 0) {
          sym = TOKEN_IF;
        } else if (strcmp(currentAsString, "is") == 0) {
          if (_ch != _int('!')) {
            sym = TOKEN_IS;
          } else {
            sym = TOKEN_ISNOT;
            _ch = getc(_script);
          }
        } else if (strcmp(currentAsString, "import") == 0) {
          commentLine();
          sym = nextToken();
        }
        break;
      case 's':
        sym = TOKEN_IDENT;
        identifier();
        if (strcmp(currentAsString, "struct") == 0) sym = TOKEN_CLASS;
        break;
      case 'v':
        sym = TOKEN_IDENT;
        identifier();
        if (strcmp(currentAsString, "void") == 0) sym = TOKEN_VOID;
        break;
      case 'w':
        sym = TOKEN_IDENT;
        identifier();
        if (strcmp(currentAsString, "while") == 0) sym = TOKEN_WHILE;
        break;
      case 'n':
        sym = TOKEN_IDENT;
        identifier();
        if (strcmp(currentAsString, "new") == 0) sym = TOKEN_NEW;
        break;

      case 'a': case 'b': case 'd': case 'f': case 'g': case 'h': case 'j':
      case 'k': case 'l': case 'm': case 'o': case 'p': case 'q':
      case 'r': case 't': case 'u': case 'x': case 'y': case 'z': case '_':
      case 'A': case 'B': case 'C': case 'D': case 'E': case 'F': case 'G':
      case 'H': case 'I': case 'J': case 'K': case 'L': case 'M': case 'N':
      case 'O': case 'P': case 'Q': case 'R': case 'S': case 'T': case 'U':
      case 'V': case 'W': case 'X': case 'Y': case 'Z':
        sym = TOKEN_IDENT;
        identifier();
        break;
      default: error("illegal symbol encountered");
    }
  }
  return sym;
}


void initializeTokenizer(String script)
{
  _line = 0;
  _position = 0;
  _script = script;
  if (_script == null) error("could not open file");
  _line = 1;
  _ch = getc(_script);
}
