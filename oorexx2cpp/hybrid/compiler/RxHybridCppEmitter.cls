/* Native class backend. C++ is produced from the parsed ooRexx ::CLASS and
   ::METHOD bodies, not from hand-authored substitutes. Methods are distinct
   C++ dispatch arms; unsupported value/object ABI must be rejected. */
::class RxHybridCppEmitter public
::method emit
  use arg unit, legacyFactory, options
  if arg(2, 'O') then legacyFactory = .true
  suffix = unit~className
  lines = .array~new
  lines~append('// rx2cpp ooRexx class compiler output: ARGLIST ABI (any number of arguments)')
  lines~append('#include "generated.hpp"')
  lines~append('#include "minirexx_runtime.hpp"')
  lines~append('#include "rx_object_bridge.hpp"')
  if .RxBuiltinRules~externalEnabled then do
    lines~append('#include "rx_bif_integration.hpp"')
    lines~append('#ifndef RX2CPP_BIF_HELPER')
    lines~append('#define RX2CPP_BIF_HELPER')
    lines~append('namespace { [[maybe_unused]] rx::BifRuntime &rx2cppBif() { static thread_local rx::BifRuntime runtime; return runtime; } }')
    lines~append('#endif')
  end
  lines~append('#include <memory>')
  lines~append('#include <stdexcept>')
  lines~append('namespace rx2cpp {')
  lines~append('class GeneratedObject_' || suffix || ' final : public CompiledObject, public rx::ObjectDispatch {')
  lines~append('  rx::Variables fields_;')
  lines~append('public:')
  /* One entry point: the ooRexx ARGLIST, any length. invoke0/invoke/invoke2 are thin adapters for
     host code that still calls them; they carry no arity logic. */
  lines~append('  std::string invokeArgs(const std::string &selector, const std::vector<std::optional<std::string>> &arguments) override {')
  lines~append('    (void)arguments;')
  self~dispatch(lines, unit, options)
  lines~append('    throw std::runtime_error("unsupported native selector: " + selector);')
  lines~append('  }')
  lines~append('  std::string invoke0(const std::string &selector) override { return invokeArgs(selector, {}); }')
  lines~append('  std::string invoke(const std::string &selector, const std::string &argument) override { return invokeArgs(selector, {argument}); }')
  lines~append('  std::string invoke2(const std::string &selector, const std::string &first, const std::string &second) override { return invokeArgs(selector, {first, second}); }')
  if suffix == 'RX2CPP_ROUTINE_IMPL' then do
    lines~append('  std::string invokeMany(const std::string &selector, const std::vector<std::optional<std::string>> &arguments) override {')
    lines~append('    (void)arguments;')
    self~dispatchMany(lines, unit, options)
    lines~append('    throw std::runtime_error("unsupported or wrong-arity native routine: " + selector);')
    lines~append('  }')
  end
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
  use arg lines, unit, options
  do method over unit~methods
    lines~append('    if (selector == ' || .RxQuote~cpp(method~selector) || ') {')
    lines~append('      rx::Variables vars;')
    lines~append('      std::vector<rx::Value> _rxProgramArgs;')
    lines~append('      for (const auto &_a : arguments) _rxProgramArgs.push_back(rx::Value::string(_a ? *_a : std::string()));')
    lines~append('      (void)_rxProgramArgs;')
    hasOptions = .false
    if arg(3, 'E') then hasOptions = options~present
    if hasOptions then do
      lines~append('      vars.numeric.digits = ' || options~digits || ';')
      lines~append('      vars.numeric.fuzz = ' || options~fuzz || ';')
      if options~form == 'ENGINEERING' then
        lines~append('      vars.numeric.engineering = true;')
    end
    do field over method~exposed
      lines~append('      rx::set(vars, ' || .RxQuote~cpp(field) || ', rx::get(fields_, ' || .RxQuote~cpp(field) || '));')
    end
    do position = 1 to method~parameters~items
      name = method~parameters[position]
      lines~append('      if (arguments.size() > ' || (position - 1) || ' && arguments[' || (position - 1) || ']) {')
      lines~append('        rx::set(vars, ' || .RxQuote~cpp(name) || ', rx::Value::string(*arguments[' || (position - 1) || ']));')
      if method~exposed~hasItem(name) then
        lines~append('        rx::set(fields_, ' || .RxQuote~cpp(name) || ', rx::get(vars, ' || .RxQuote~cpp(name) || '));')
      lines~append('      }')
    end
    do statement over method~instructions
      lines~append('      ' || statement)
    end
    if method~selector == 'INIT' then lines~append('      return "";')
    lines~append('    }')
  end
/* Vector invocation belongs only to synthetic package-routine classes.
   Each invocation owns fresh local variables; scalar byte strings are bound
   positionally and no object/class state is introduced. */
::method dispatchMany private
  use arg lines, unit, options
  do method over unit~methods
    count = method~parameters~items
    lines~append('    if (selector == ' || .RxQuote~cpp(method~selector) || ') {')
    lines~append('      rx::Variables vars;')
    lines~append('      std::vector<rx::Value> _rxProgramArgs;')
    lines~append('      for (const auto &_a : arguments) _rxProgramArgs.push_back(rx::Value::string(_a ? *_a : std::string()));')
    lines~append('      (void)_rxProgramArgs;')
    hasOptions = .false
    if arg(3, 'E') then hasOptions = options~present
    if hasOptions then do
      lines~append('      vars.numeric.digits = ' || options~digits || ';')
      lines~append('      vars.numeric.fuzz = ' || options~fuzz || ';')
      if options~form == 'ENGINEERING' then lines~append('      vars.numeric.engineering = true;')
    end
    do position = 1 to count
      name = method~parameters[position]
      lines~append('      if (arguments.size() > ' || (position - 1) || ' && arguments[' || (position - 1) || '])')
      lines~append('        rx::set(vars, ' || .RxQuote~cpp(name) || ', rx::Value::string(*arguments[' || (position - 1) || ']));')
    end
    do statement over method~instructions
      lines~append('      ' || statement)
    end
    lines~append('    }')
  end
::requires 'core/RxQuote.cls'
::requires 'rules/RxBuiltinRules.cls'
