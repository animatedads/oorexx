/* ooRexx augmented assignment operators, currently an explicit subset.
   Each operator is a message to the *previous value* of the named variable;
   do not reduce this to C++ scalar operators or reinterpret \=.
   This class owns only statement syntax; RxCompoundAssignmentOps is the
   independently loadable selector table and the native runtime owns method
   dispatch. Other augmented operators remain intentionally unsupported. */
::class RxStmtCompoundAssign public
::method accepts
  use arg ctx
  s = ctx~stream
  return s~peek~kind == 'IDENT' & .RxCompoundAssignmentOps~isSupported(s~lookAheadText(1))
::method emit
  use arg ctx, depth
  s = ctx~stream
  name = s~next~text
  augmented = s~next~text
  selector = .RxCompoundAssignmentOps~selector(augmented)
  rhs = ctx~logicalExpr~parse(ctx)
  serial = ctx~label
  variable = .RxQuote~cpp(name)
  /* Explicit sequencing avoids unspecified C++ function-argument evaluation
     order and evaluates the LHS value exactly once. */
  ctx~line(depth, '{')
  ctx~line(depth + 1, 'const rx::Value _lhs' || serial || ' = rx::getSymbol(vars, ' || variable || ');')
  ctx~line(depth + 1, 'const rx::Value _rhs' || serial || ' = ' || rhs || ';')
  ctx~line(depth + 1, 'rx::setSymbol(vars, ' || variable || ', rx::sendBinary(_lhs' || serial || ', ' || .RxQuote~cpp(selector) || ', _rhs' || serial || '));')
  ctx~line(depth, '}')
  s~separator
::requires 'rules/CompoundAssignmentOps.cls'
::requires 'core/RxQuote.cls'
