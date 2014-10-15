library subtype;

import 'dart:collection';
import 'dart:mirrors';

bool isPrimitive(TypeMirror m) {
  Type t = m.reflectedType;
  if (t == int || t == double || t == bool)
    return true;
  return false;
}

bool isFunctionSubType(TypeMirror t1, TypeMirror t2) {
  final f1 = t1 as FunctionTypeMirror;
  final f2 = t2 as FunctionTypeMirror;

  final params1 = f1.parameters;
  final params2 = f2.parameters;
  final ret1 = f1.returnType;
  final ret2 = f2.returnType;

  if (!isSubType(ret1, ret2)) {
    // Covariant return types.
    return false;
  }

  if (params1.length < params2.length) {
    return false;
  }

  for (int i = 0; i < params2.length; ++i) {
    ParameterMirror p1 = params1[i];
    ParameterMirror p2 = params2[i];

    // Contravariant parameter types.
    if (!isSubType(p2.type, p1.type))
      return false;

    // If the base param is optional, the sub param must be optional:
    // - either neither are named or
    // - both are named with the same name
    // If the base param is required, the sub may be optional, but not named.
    if (p2.isOptional) {
      if (!p1.isOptional)
        return false;
      if (p2.isNamed)
        if (!p1.isNamed || p1.simpleName != p2.simpleName)
          return false;
    } else {
      if (p1.isNamed)
        return false;
    }
  }
  return true;
}

bool isClassSubType(ClassMirror m1, ClassMirror m2) {
  // Note: this essentially imposes invariance on generics
  // instead of Dart's covariance.

  if (m1 == m2)
    return true;

  if (m1.reflectedType == Object)
    return false;

  if (isClassSubType(m1.superclass, m2))
    return true;

  for (final parent in m1.superinterfaces) {
    if (isClassSubType(parent, m2))
      return true;
  }

  return false;
}

bool isSubType(TypeMirror t1, TypeMirror t2) {
  if (t1 == t2)
    return true;

  // Primitives are standalone types.  Unless boxed, they do not subtype
  // Object and are not subtyped by dynamic.
  if (isPrimitive(t1) || isPrimitive(t2))
    return false;

  // Trivially true for non-primitives.
  if (t2.reflectedType == Object)
    return true;

  // Trivially false.
  if (t1.reflectedType == Object)
    return false;

  // How do we handle dynamic?
  if (t1.reflectedType == dynamic)
    return false;
  if (t2.reflectedType == dynamic)
    return true;

  // Replace typedefs with underlying Function types.
  if (t1 is TypedefMirror)
    t1 = (t1 as TypedefMirror).referent;
  if (t2 is TypedefMirror)
    t2 = (t2 as TypedefMirror).referent;

  // "Traditional" name-based subtype check.
  final c1 = t1 as ClassMirror;
  final c2 = t2 as ClassMirror;
  if (isClassSubType(c1, c2)) {
    return true;
  }

  if (t1 is! FunctionTypeMirror || t2 is! FunctionTypeMirror)
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
  return isFunctionSubType(c1 as FunctionTypeMirror, c2 as FunctionTypeMirror);
}

bool instanceOf(Object obj, Type staticType) {
  if (obj == null) {
    // This is different from Dart where null is Object returns true.
    return false;
  }

  Type runtimeType = obj.runtimeType;
  return isSubType(reflectType(runtimeType), reflectType(staticType));
}

// Test code

class A {
  int x;
}

class B extends A {
  int y;
}

class C extends B {
  int z;
}

class AA<T, U> {
  T x;
  U y;
}

class BB<T, U> extends AA<U, T> {
  T z;
}

class CC extends BB<String, List> {
}


typedef B Foo(B b, String s);

A bar1(C c, String s) => null;
bar2(B b, String s) => null;
B bar3(B b, Object o) => null;
B bar4(B b, o) => null;
C bar5(A a, Object o) => null;

void test(a, Type t, {bool dart: true, bool start: true}) {
  TypeMirror runtimeType = reflectType(a.runtimeType);
  TypeMirror staticType = reflectType(t);

  bool subInDart = runtimeType.isSubtypeOf(staticType);
  bool subInStart = isSubType(runtimeType, staticType);

  assert(dart == subInDart);
  assert(start == subInStart);
}

void main() {
  // int and dynamic are different
  test(5, dynamic, dart: true, start: false);

  // trivially true
  test(5, int);

  // different
  test(5, Object, dart: true, start: false);
  test(5, num, dart: true, start: false);

  // trivially true
  test("foo", String);

  // String subtypes Object
  test("foo", Object);

  // String is dynamic?
  test("foo", dynamic, dart: true, start: true);

  final m1 = new Map<String, String>();
  final m2 = new Map<Object, Object>();
  final m3 = new Map();
  final m4 = new HashMap<dynamic, dynamic>();

  // Invariant generics vs Dart's covariance.
  test(m1, Map, dart: true, start: false);

  // Non-primitives are Objects.
  test(m1, Object);

  // Instance of self
  test(m1, m1.runtimeType);

  // No covariance on generics
  test(m1, m2.runtimeType, dart: true, start: false);

  // No contravariance on generics.
  test(m2, m1.runtimeType, dart: false, start: false);

  // Null is the same
  assert(!instanceOf(null, Map));
  assert(null is! Map);

  // ... except for Object?
  assert(!instanceOf(null, Object));
  assert(null is Object);

  // Raw generic types
  test(new LinkedHashMap(), Map, dart: true, start: true);
  test(m4, Map, dart: true, start: true);

  AA<String, List> aa = new AA<String, List>();
  final aatype= aa.runtimeType;
  BB<String, List> bb = new BB<String, List>();
  final bbtype = bb.runtimeType;
  CC cc = new CC();
  final cctype = cc.runtimeType;

  test(cc, aatype, dart: false, start: false);
  test(cc, bbtype, dart: true, start: true);

  // Functions.
  test(bar1, Foo, dart: true, start: false);
  test(bar2, Foo, dart: true, start: false);
  test(bar3, Foo, dart: true, start: true);
  test(bar4, Foo, dart: true, start: true);
  test(bar5, Foo, dart: true, start: true);
  print('done');
}