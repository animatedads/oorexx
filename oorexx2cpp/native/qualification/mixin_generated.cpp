// rx2cpp ooRexx class compiler output: scalar/one-argument ABI v0.9
#include "generated.hpp"
#include "minirexx_runtime.hpp"
#include <memory>
#include <stdexcept>
namespace rx2cpp {
class GeneratedObject_ROOT final : public CompiledObject, public rx::ObjectDispatch {
  rx::Variables fields_;
public:
  std::string invoke0(const std::string &selector) override {
    if (selector == "ROOTVALUE") {
      rx::Variables vars;
      rx::set(vars, "VALUE", rx::get(fields_, "VALUE"));
      const rx::Value result = rx::get(vars, "VALUE");
      if (result.isObject()) throw std::runtime_error("non-scalar return requires interpreter proxy");
      return result.bytes;
    }
    if (selector == "WHO") {
      rx::Variables vars;
      const rx::Value result = rx::Value::string("root");
      if (result.isObject()) throw std::runtime_error("non-scalar return requires interpreter proxy");
      return result.bytes;
    }
    throw std::runtime_error("unsupported or wrong-arity native selector: " + selector);
  }
  std::string invoke(const std::string &selector, const std::string &argument) override {
    if (selector == "INIT") {
      rx::Variables vars;
      rx::set(vars, "VALUE", rx::get(fields_, "VALUE"));
      rx::set(vars, "VALUE", rx::Value::string(argument));
      rx::set(fields_, "VALUE", rx::get(vars, "VALUE"));
      return "";
    }
    throw std::runtime_error("unsupported or wrong-arity native selector: " + selector);
  }
};
std::shared_ptr<CompiledObject> makeGeneratedObject_ROOT() {
  return std::make_shared<GeneratedObject_ROOT>();
}
}
// rx2cpp ooRexx class compiler output: scalar/one-argument ABI v0.9
#include "generated.hpp"
#include "minirexx_runtime.hpp"
#include <memory>
#include <stdexcept>
namespace rx2cpp {
class GeneratedObject_SALT final : public CompiledObject, public rx::ObjectDispatch {
  rx::Variables fields_;
public:
  std::string invoke0(const std::string &selector) override {
    if (selector == "SALTVALUE") {
      rx::Variables vars;
      rx::set(vars, "VALUE", rx::get(fields_, "VALUE"));
      const rx::Value result = rx::get(vars, "VALUE");
      if (result.isObject()) throw std::runtime_error("non-scalar return requires interpreter proxy");
      return result.bytes;
    }
    if (selector == "WHO") {
      rx::Variables vars;
      const rx::Value result = rx::Value::string("salt");
      if (result.isObject()) throw std::runtime_error("non-scalar return requires interpreter proxy");
      return result.bytes;
    }
    throw std::runtime_error("unsupported or wrong-arity native selector: " + selector);
  }
  std::string invoke(const std::string &selector, const std::string &argument) override {
    if (selector == "SALTSET") {
      rx::Variables vars;
      rx::set(vars, "VALUE", rx::get(fields_, "VALUE"));
      rx::set(vars, "VALUE", rx::Value::string(argument));
      rx::set(fields_, "VALUE", rx::get(vars, "VALUE"));
      const rx::Value result = rx::get(vars, "VALUE");
      if (result.isObject()) throw std::runtime_error("non-scalar return requires interpreter proxy");
      return result.bytes;
    }
    throw std::runtime_error("unsupported or wrong-arity native selector: " + selector);
  }
};
std::shared_ptr<CompiledObject> makeGeneratedObject_SALT() {
  return std::make_shared<GeneratedObject_SALT>();
}
}
// rx2cpp ooRexx class compiler output: scalar/one-argument ABI v0.9
#include "generated.hpp"
#include "minirexx_runtime.hpp"
#include <memory>
#include <stdexcept>
namespace rx2cpp {
class GeneratedObject_PEPPER final : public CompiledObject, public rx::ObjectDispatch {
  rx::Variables fields_;
public:
  std::string invoke0(const std::string &selector) override {
    if (selector == "PEPPERVALUE") {
      rx::Variables vars;
      rx::set(vars, "VALUE", rx::get(fields_, "VALUE"));
      const rx::Value result = rx::get(vars, "VALUE");
      if (result.isObject()) throw std::runtime_error("non-scalar return requires interpreter proxy");
      return result.bytes;
    }
    if (selector == "WHO") {
      rx::Variables vars;
      const rx::Value result = rx::Value::string("pepper");
      if (result.isObject()) throw std::runtime_error("non-scalar return requires interpreter proxy");
      return result.bytes;
    }
    throw std::runtime_error("unsupported or wrong-arity native selector: " + selector);
  }
  std::string invoke(const std::string &selector, const std::string &argument) override {
    if (selector == "PEPPERSET") {
      rx::Variables vars;
      rx::set(vars, "VALUE", rx::get(fields_, "VALUE"));
      rx::set(vars, "VALUE", rx::Value::string(argument));
      rx::set(fields_, "VALUE", rx::get(vars, "VALUE"));
      const rx::Value result = rx::get(vars, "VALUE");
      if (result.isObject()) throw std::runtime_error("non-scalar return requires interpreter proxy");
      return result.bytes;
    }
    throw std::runtime_error("unsupported or wrong-arity native selector: " + selector);
  }
};
std::shared_ptr<CompiledObject> makeGeneratedObject_PEPPER() {
  return std::make_shared<GeneratedObject_PEPPER>();
}
}
// rx2cpp ooRexx class compiler output: scalar/one-argument ABI v0.9
#include "generated.hpp"
#include "minirexx_runtime.hpp"
#include <memory>
#include <stdexcept>
namespace rx2cpp {
class GeneratedObject_DISH final : public CompiledObject, public rx::ObjectDispatch {
  rx::Variables fields_;
public:
  std::string invoke0(const std::string &selector) override {
    if (selector == "DISHVALUE") {
      rx::Variables vars;
      rx::set(vars, "VALUE", rx::get(fields_, "VALUE"));
      const rx::Value result = rx::get(vars, "VALUE");
      if (result.isObject()) throw std::runtime_error("non-scalar return requires interpreter proxy");
      return result.bytes;
    }
    throw std::runtime_error("unsupported or wrong-arity native selector: " + selector);
  }
  std::string invoke(const std::string &selector, const std::string &argument) override {
    if (selector == "DISHSET") {
      rx::Variables vars;
      rx::set(vars, "VALUE", rx::get(fields_, "VALUE"));
      rx::set(vars, "VALUE", rx::Value::string(argument));
      rx::set(fields_, "VALUE", rx::get(vars, "VALUE"));
      const rx::Value result = rx::get(vars, "VALUE");
      if (result.isObject()) throw std::runtime_error("non-scalar return requires interpreter proxy");
      return result.bytes;
    }
    throw std::runtime_error("unsupported or wrong-arity native selector: " + selector);
  }
};
std::shared_ptr<CompiledObject> makeGeneratedObject_DISH() {
  return std::make_shared<GeneratedObject_DISH>();
}
}
// rx2cpp ooRexx class compiler output: scalar/one-argument ABI v0.9
#include "generated.hpp"
#include "minirexx_runtime.hpp"
#include <memory>
#include <stdexcept>
namespace rx2cpp {
class GeneratedObject_GRAND final : public CompiledObject, public rx::ObjectDispatch {
  rx::Variables fields_;
public:
  std::string invoke0(const std::string &selector) override {
    if (selector == "GRANDVALUE") {
      rx::Variables vars;
      rx::set(vars, "VALUE", rx::get(fields_, "VALUE"));
      const rx::Value result = rx::get(vars, "VALUE");
      if (result.isObject()) throw std::runtime_error("non-scalar return requires interpreter proxy");
      return result.bytes;
    }
    throw std::runtime_error("unsupported or wrong-arity native selector: " + selector);
  }
  std::string invoke(const std::string &selector, const std::string &argument) override {
    if (selector == "GRANDSET") {
      rx::Variables vars;
      rx::set(vars, "VALUE", rx::get(fields_, "VALUE"));
      rx::set(vars, "VALUE", rx::Value::string(argument));
      rx::set(fields_, "VALUE", rx::get(vars, "VALUE"));
      const rx::Value result = rx::get(vars, "VALUE");
      if (result.isObject()) throw std::runtime_error("non-scalar return requires interpreter proxy");
      return result.bytes;
    }
    throw std::runtime_error("unsupported or wrong-arity native selector: " + selector);
  }
};
std::shared_ptr<CompiledObject> makeGeneratedObject_GRAND() {
  return std::make_shared<GeneratedObject_GRAND>();
}
}
