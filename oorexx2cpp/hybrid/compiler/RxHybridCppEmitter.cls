/* Native class backend. C++ is produced from the parsed ooRexx ::CLASS and
   ::METHOD bodies, not from hand-authored substitutes. Methods are distinct
   C++ dispatch arms; unsupported value/object ABI must be rejected. */
::class RxHybridCppEmitter public
::method emit
  use arg unit, legacyFactory, options
  if arg(2, 'O') then legacyFactory = .true
  suffix = unit~className
  lines = .array~new
  lines~append('// rx2cpp ooRexx class compiler output: scalar/two-argument ABI v0.30.2')
  lines~append('#include "generated.hpp"')
  lines~append('#include "minirexx_runtime.hpp"')
  lines~append('#include <memory>')
  lines~append('#include <stdexcept>')
  lines~append('namespace rx2cpp {')
  lines~append('class GeneratedObject_' || suffix || ' final : public CompiledObject, public rx::ObjectDispatch {')
  lines~append('  rx::Variables fields_;')
  lines~append('public:')
  lines~append('  std::string invoke0(const std::string &selector) override {')
  self~dispatch(lines, unit, 0, options)
  lines~append('    throw std::runtime_error("unsupported or wrong-arity native selector: " + selector);')
  lines~append('  }')
  lines~append('  std::string invoke(const std::string &selector, const std::string &argument) override {')
  lines~append('    (void)argument;')
  self~dispatch(lines, unit, 1, options)
  lines~append('    throw std::runtime_error("unsupported or wrong-arity native selector: " + selector);')
  lines~append('  }')
  lines~append('  std::string invoke2(const std::string &selector, const std::string &first, const std::string &second) override {')
  lines~append('    (void)first; (void)second;')
  self~dispatch(lines, unit, 2, options)
  lines~append('    throw std::runtime_error("unsupported or wrong-arity native selector: " + selector);')
  lines~append('  }')
  lines~append('};')
  lines~append('std::shared_ptr<CompiledObject> makeGeneratedObject_' || suffix || '() {')
  lines~append('  return std::make_shared<GeneratedObject_' || suffix || '>();')
  lines~append('}')
  if legacyFactory then do
    lines~append('std::shared_ptr<CompiledObject> makeGeneratedObject() {')
    lines~append('  return makeGeneratedObject_' || suffix || '();')
    lines~append('}')
  end
  lines~append('}')
  out = ''
  do l over lines
    out = out || l || '0a'x
  end
  return out
::method dispatch private
  use arg lines, unit, arity, options
  do method over unit~methods
    count = 0
    if method~parameter \== '' then count += 1
    if method~secondParameter \== '' then count += 1
    if count \= arity then iterate
    lines~append('    if (selector == ' || .RxQuote~cpp(method~selector) || ') {')
    lines~append('      rx::Variables vars;')
    hasOptions = .false
    if arg(4, 'E') then hasOptions = options~present
    if hasOptions then do
      lines~append('      vars.numeric.digits = ' || options~digits || ';')
      lines~append('      vars.numeric.fuzz = ' || options~fuzz || ';')
      if options~form == 'ENGINEERING' then
        lines~append('      vars.numeric.engineering = true;')
    end
    do field over method~exposed
      lines~append('      rx::set(vars, ' || .RxQuote~cpp(field) || ', rx::get(fields_, ' || .RxQuote~cpp(field) || '));')
    end
    if arity > 0 then do
      firstName = 'argument'
      if arity > 1 then firstName = 'first'
      lines~append('      rx::set(vars, ' || .RxQuote~cpp(method~parameter) || ', rx::Value::string(' || firstName || '));')
      if method~exposed~hasItem(method~parameter) then
        lines~append('      rx::set(fields_, ' || .RxQuote~cpp(method~parameter) || ', rx::get(vars, ' || .RxQuote~cpp(method~parameter) || '));')
    end
    if arity > 1 then do
      lines~append('      rx::set(vars, ' || .RxQuote~cpp(method~secondParameter) || ', rx::Value::string(second));')
      if method~exposed~hasItem(method~secondParameter) then
        lines~append('      rx::set(fields_, ' || .RxQuote~cpp(method~secondParameter) || ', rx::get(vars, ' || .RxQuote~cpp(method~secondParameter) || '));')
    end
    do statement over method~instructions
      lines~append('      ' || statement)
    end
    if method~selector == 'INIT' then lines~append('      return "";')
    lines~append('    }')
  end
::requires 'core/RxQuote.cls'
