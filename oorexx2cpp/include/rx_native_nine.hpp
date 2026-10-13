#pragma once
// RX2CPP ooRexx host-API lane only; included after EnvObject and native Array.
// These are native fast-path object implementations with faithful promotion to
// the interpreter for messages not proved equivalent. No alternative BIF code.
#include <deque>
#include <unordered_map>
#include <unordered_set>
#include <map>
namespace rx {

inline Value nativeNineClass(const std::string &name);
inline bool nineScalar(const Value &v) { return !v.isObject(); }
inline Value nineNumber(std::size_t n) { return Value::string(std::to_string(n)); }
inline Value nineTruth(bool b) { return Value::string(b ? "1" : "0"); }
inline bool nineSame(const Value &a, const Value &b) {
    return a.isObject() && b.isObject() && a.object.get() == b.object.get();
}

struct NativeNineBase : NativeRefBase {
    std::string kind;
    std::vector<Value> constructorArgs;
    std::optional<Value> real;
    struct Event { std::string method; std::vector<Value> arguments; };
    std::vector<Event> history;
    explicit NativeNineBase(std::string n, std::vector<Value> a = {}) : kind(std::move(n)), constructorArgs(std::move(a)) {}
    Value &promote() {
        if (!real) {
            MessageResult made = envClass(kind).object->sendMessage("NEW", constructorArgs);
            if (!made || !made->isObject()) throw std::runtime_error("native " + kind + " cannot materialize");
            real = *made;
            for (const Event &event : history) real->object->sendMessage(event.method, event.arguments);
            history.clear();
        }
        return *real;
    }
    void *materialize() override {
        auto *e = dynamic_cast<EnvObject *>(promote().object.get());
        if (!e) throw std::runtime_error("native " + kind + " materialization did not return interpreter object");
        return e->handle;
    }
    MessageResult forward(const std::string &s, const std::vector<Value> &a) { return promote().object->sendMessage(s,a); }
    void record(const std::string &s, const std::vector<Value> &a) { history.push_back({s,a}); }
    MessageResult common(const std::string &s, const std::vector<Value> &a) {
        if (s == "CLASS" && a.empty()) return nativeNineClass(kind);
        if (s == "ISA" && a.size() == 1 && a[0].isObject()) {
            const Value cls = nativeNineClass(kind);
            if (nineSame(a[0], cls)) return nineTruth(true);
        }
        return forward(s, a);
    }
    Value sendBinary(const std::string &s, const Value &v) override {
        if (!real && (s=="=" || s=="==" || s=="\\=" || s=="\\==" || s=="<>" || s=="><")) {
            const bool same = v.isObject() && v.object.get()==this;
            return nineTruth((s=="=" || s=="==") ? same : !same);
        }
        return promote().object->sendBinary(s,v);
    }
    Value sendUnary(const std::string &s) override { return promote().object->sendUnary(s); }
    std::string display() const override {
        MessageResult r = const_cast<NativeNineBase *>(this)->forward("STRING", {});
        return r ? r->bytes.str() : std::string();
    }
};

// LIST: indices are durable numeric tokens (0, 1, ...). All unsupported
// mutations promote, replaying the original message sequence in order.
struct NativeList final : NativeNineBase {
    std::map<std::size_t,Value> items;
    std::size_t next = 0;
    NativeList() : NativeNineBase("LIST") {}
    MessageResult sendMessage(const std::string &s,const std::vector<Value> &a) override {
        if (real) return real->object->sendMessage(s,a);
        if (s=="APPEND" && a.size()==1 && !NativeArray::omitted(a[0])) {
            const std::size_t idx=next++;
            items.emplace(idx,a[0]); record(s,a); return nineNumber(idx);
        }
        if (s=="ITEMS" && a.empty()) return nineNumber(items.size());
        if (s=="ISEMPTY" && a.empty()) return nineTruth(items.empty());
        if (s=="FIRST" && a.empty()) return items.empty()?nil():nineNumber(items.begin()->first);
        if (s=="LAST" && a.empty()) return items.empty()?nil():nineNumber(items.rbegin()->first);
        if (s=="FIRSTITEM" && a.empty()) return items.empty()?nil():items.begin()->second;
        if (s=="LASTITEM" && a.empty()) return items.empty()?nil():items.rbegin()->second;
        if ((s=="AT" || s=="HASINDEX" || s=="[]") && a.size()==1 && nineScalar(a[0])) {
            // List indexes are opaque to the language; only the canonical tokens issued
            // by our own APPEND fast path are eligible for native lookup.
            for (const auto &entry:items) if (a[0].bytes==std::to_string(entry.first))
                return s=="HASINDEX"?nineTruth(true):entry.second;
            if (s=="HASINDEX" || s=="AT" || s=="[]") return common(s,a);
            return nil();
        }
        return common(s,a);
    }
};

struct NativeQueue final : NativeNineBase {
    std::deque<Value> items;
    NativeQueue() : NativeNineBase("QUEUE") {}
    MessageResult sendMessage(const std::string &s,const std::vector<Value> &a) override {
        if (real) return real->object->sendMessage(s,a);
        if (s=="QUEUE" && a.size()==1 && !NativeArray::omitted(a[0])) {
            items.push_back(a[0]); record(s,a); return std::nullopt;
        }
        if (s=="PUSH" && a.size()==1 && !NativeArray::omitted(a[0])) {
            items.push_front(a[0]); record(s,a); return std::nullopt;
        }
        if (s=="PULL" && a.empty()) {
            if (items.empty()) return nil();
            Value value=items.front(); items.pop_front(); record(s,a); return value;
        }
        if (s=="PEEK" && a.empty()) return items.empty()?nil():items.front();
        if (s=="ITEMS" && a.empty()) return nineNumber(items.size());
        if (s=="ISEMPTY" && a.empty()) return nineTruth(items.empty());
        return common(s,a);
    }
};

// TABLE/SET/BAG/RELATION: only scalar-index operations are handled without
// interpreter dispatch. Object keys, hashing protocol, equality, order,
// enumeration and advanced set operations retain the interpreter's authority.
struct NativeAssociative : NativeNineBase {
    std::unordered_map<std::string,Value> table;
    std::unordered_map<std::string,std::size_t> multiplicity;
    std::size_t count = 0;
    explicit NativeAssociative(std::string name):NativeNineBase(std::move(name)){}
    MessageResult sendMessage(const std::string &s,const std::vector<Value> &a) override {
        if (real) return real->object->sendMessage(s,a);
        const bool keyed = kind=="TABLE" || kind=="RELATION";
        if ((s=="PUT" || s=="[]=") && a.size()==(keyed?2u:1u) && nineScalar(a[keyed?1:0]) && !NativeArray::omitted(a[0])) {
            const std::string key = keyed ? a[1].bytes.str() : a[0].bytes.str();
            if (kind=="TABLE") { if (!table.count(key)) ++count; table.insert_or_assign(key,a[0]); }
            else if (kind=="SET") { if (!multiplicity.count(key)) {multiplicity[key]=1; ++count;} }
            else { ++multiplicity[key]; ++count; }
            record(s,a);
            return std::nullopt;
        }
        if (s=="ITEMS" && a.empty()) return nineNumber(count);
        if (s=="ISEMPTY" && a.empty()) return nineTruth(count==0);
        if ((s=="HASINDEX" || (s=="HASITEM" && (kind=="SET" || kind=="BAG"))) && a.size()==1 && nineScalar(a[0])) {
            const std::string key=a[0].bytes.str();
            return nineTruth(kind=="TABLE" ? table.count(key)>0 : multiplicity.count(key)>0);
        }
        if ((s=="AT" || s=="[]") && a.size()==1 && nineScalar(a[0]) && kind=="TABLE") {
            auto it=table.find(a[0].bytes.str()); return it==table.end()?nil():it->second;
        }
        return common(s,a);
    }
};
struct NativeTable final : NativeAssociative { NativeTable():NativeAssociative("TABLE"){} };
struct NativeSet final : NativeAssociative { NativeSet():NativeAssociative("SET"){} };
struct NativeBag final : NativeAssociative { NativeBag():NativeAssociative("BAG"){} };
struct NativeRelation final : NativeAssociative { NativeRelation():NativeAssociative("RELATION"){} };

// A supplier of two dense arrays: ITEM/INDEX/AVAILABLE/NEXT are native.
// For anything else it is reconstructed and stepped to its current position.
struct NativeSupplier final : NativeNineBase {
    std::vector<Value> values,indexes;
    std::size_t position=0;
    explicit NativeSupplier(std::vector<Value> args, std::vector<Value> v,std::vector<Value> i)
        :NativeNineBase("SUPPLIER",std::move(args)),values(std::move(v)),indexes(std::move(i)){}
    MessageResult sendMessage(const std::string &s,const std::vector<Value> &a) override {
        if (real) return real->object->sendMessage(s,a);
        if (s=="AVAILABLE" && a.empty()) return nineTruth(position<values.size());
        if (s=="NEXT" && a.empty()) {
            if (position>=values.size()) return common(s,a);  // ooRexx raises 93.937 when exhausted
            ++position; record(s,a); return std::nullopt;
        }
        if (s=="ITEM" && a.empty() && position<values.size()) return values[position];
        if (s=="INDEX" && a.empty() && position<indexes.size()) return indexes[position];
        return common(s,a);
    }
};

// MESSAGE: preserve the kernel's asynchronous lifecycle (START/WAIT/NOTIFY/
// CANCEL) rather than implement a fake scheduler. Native immutable constructor
// projections are cached, all lifecycle transitions use the real Message.
struct NativeMessage final : NativeNineBase {
    explicit NativeMessage(std::vector<Value> args,Value obj):NativeNineBase("MESSAGE",std::move(args)) { real=std::move(obj); }
    MessageResult sendMessage(const std::string &s,const std::vector<Value> &a) override {
        if (s=="TARGET" && a.empty() && !constructorArgs.empty()) return constructorArgs[0];
        if (s=="MESSAGENAME" && a.empty() && constructorArgs.size()>1 && nineScalar(constructorArgs[1]))
            return Value::string([](std::string n){ for(char &c:n)c=static_cast<char>(std::toupper(static_cast<unsigned char>(c))); return n; }(constructorArgs[1].bytes.str()));
        return common(s,a);
    }
};

// DateTime constructed by ooRexx; native cached immutable field projections.
// Timezones, calendars, mutation, formatting and arithmetic remain owned by
// ooRexx. Never synthesize a date from a guessed timezone or locale.
struct NativeDateTime final : NativeNineBase {
    std::unordered_map<std::string,Value> cache;
    explicit NativeDateTime(std::vector<Value> args,Value obj):NativeNineBase("DATETIME",std::move(args)) {real=std::move(obj);}
    MessageResult sendMessage(const std::string &s,const std::vector<Value> &a) override {
        if (a.empty() && (s=="YEAR" || s=="MONTH" || s=="DAY" || s=="HOURS" ||
            s=="MINUTES" || s=="SECONDS" || s=="ISODATE" || s=="DAYNAME" || s=="MONTHNAME")) {
            auto it=cache.find(s);
            if (it!=cache.end()) return it->second;
            MessageResult r=forward(s,a);
            if (r && !r->isObject()) cache.emplace(s,*r);
            return r;
        }
        // DateTime mutations are not assumed immutable: clear cached fields.
        cache.clear(); return common(s,a);
    }
};

// Class objects are dual-representation too: interpreter CLASS/ISA/identity,
// native NEW for the supported cases. The original class remains visible
// through materialize(), so interpreted callers always see real Rexx objects.
struct NativeNineClass final : NativeRefBase {
    std::string kind;
    explicit NativeNineClass(std::string k):kind(std::move(k)){}
    void *materialize() override {
        auto *env=dynamic_cast<EnvObject *>(envClass(kind).object.get());
        if(!env) throw std::runtime_error("cannot resolve class "+kind);
        return env->handle;
    }
    MessageResult sendMessage(const std::string &s,const std::vector<Value> &a) override {
        if (s=="NEW") {
            if (a.empty()) {
                if(kind=="LIST") return Value::fromObject(std::make_shared<NativeList>());
                if(kind=="QUEUE") return Value::fromObject(std::make_shared<NativeQueue>());
                if(kind=="TABLE") return Value::fromObject(std::make_shared<NativeTable>());
                if(kind=="SET") return Value::fromObject(std::make_shared<NativeSet>());
                if(kind=="BAG") return Value::fromObject(std::make_shared<NativeBag>());
                if(kind=="RELATION") return Value::fromObject(std::make_shared<NativeRelation>());
            }
            if(kind=="SUPPLIER" && a.size()==2) {
                auto extract=[](const Value &v)->std::optional<std::vector<Value>> {
                    if(!v.isObject()) return std::nullopt;
                    if(auto *native=dynamic_cast<NativeArray *>(v.object.get())) return native->snapshotItems();
                    // Real interpreter Arrays are queried at the public message boundary.
                    auto cls=v.object->sendMessage("ISA",{envClass("ARRAY")});
                    if(!cls || cls->isObject() || cls->bytes!="1") return std::nullopt;
                    auto size=v.object->sendMessage("ITEMS",{});
                    if(!size || size->isObject()) return std::nullopt;
                    std::size_t n=0;
                    const std::string str=size->bytes.str();
                    if(str.empty() || str.size()>7) return std::nullopt;
                    for(char c:str) {if(c<'0'||c>'9') return std::nullopt; n=n*10+static_cast<std::size_t>(c-'0');}
                    if(n>1000000) return std::nullopt;
                    std::vector<Value> out;out.reserve(n);
                    for(std::size_t i=1;i<=n;++i) {
                        auto item=v.object->sendMessage("AT",{nineNumber(i)});
                        if(!item) return std::nullopt;
                        out.push_back(*item);
                    }
                    return out;
                };
                auto values=extract(a[0]),indexes=extract(a[1]);
                if(values && indexes && values->size()==indexes->size())
                    return Value::fromObject(std::make_shared<NativeSupplier>(a,std::move(*values),std::move(*indexes)));
            }
            if(kind=="MESSAGE" || kind=="DATETIME") {
                MessageResult made=envClass(kind).object->sendMessage(s,a);
                if(!made || !made->isObject()) return made;
                if(kind=="MESSAGE") return Value::fromObject(std::make_shared<NativeMessage>(a,*made));
                return Value::fromObject(std::make_shared<NativeDateTime>(a,*made));
            }
        }
        return envClass(kind).object->sendMessage(s,a);
    }
    Value sendBinary(const std::string &s,const Value &v) override {return envClass(kind).object->sendBinary(s,v);}
    std::string display() const override {return "The "+kind+" class";}
};
inline Value nativeNineClass(const std::string &name) {
    // Values are unique per class and thread; classes preserve ooRexx identity
    // through materialisation at the host boundary.
    static thread_local std::unordered_map<std::string,Value> classes;
    auto it=classes.find(name); if(it!=classes.end())return it->second;
    Value v=Value::fromObject(std::make_shared<NativeNineClass>(name));
    classes.emplace(name,v);return v;
}
} // namespace rx
