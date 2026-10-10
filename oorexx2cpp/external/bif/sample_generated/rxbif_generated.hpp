// Generated from upstream BUILTIN C++ by bif2inline.rex; do not edit.
// Compile-time inline call sites; backend is native C++ (no ooRexx runtime).
#pragma once
#include "rxbif.hpp"
#include <algorithm>
#include <stdexcept>
#include <vector>
namespace rxbif_generated {
/* upstream CENTER line 5 [METHOD]: return string->center(length,pad) */
inline rx::Value BIF_CENTER(const std::vector<rx::Value>& a, rxbif::Context& ctx) {
    if (a.size() < 2 || a.size() > 3) throw std::runtime_error("BIF CENTER: arity");
    return rxbif::invoke("CENTER", a, ctx);
}
/* upstream REVERSE line 22 [METHOD]: return string->reverse() */
inline rx::Value BIF_REVERSE(const std::vector<rx::Value>& a, rxbif::Context& ctx) {
    if (a.size() < 1 || a.size() > 1) throw std::runtime_error("BIF REVERSE: arity");
    (void)ctx;
    if (a[0].isObject()) throw std::runtime_error("REVERSE: object conversion unsupported");
    return rx::Value::string(std::string(a[0].bytes.rbegin(), a[0].bytes.rend()));
}
/* upstream WORDS line 35 [METHOD]: return string->words() */
inline rx::Value BIF_WORDS(const std::vector<rx::Value>& a, rxbif::Context& ctx) {
    if (a.size() < 1 || a.size() > 1) throw std::runtime_error("BIF WORDS: arity");
    (void)ctx;
    if (a[0].isObject()) throw std::runtime_error("WORDS: object conversion unsupported");
    std::int64_t total = 0; bool inside = false;
    for (char c : a[0].bytes) {
      if (c == ' ' || c == 9) { inside = false; }
      else if (!inside) { ++total; inside = true; }
    }
    return rx::fromInteger(total);
}
/* upstream TIME line 48 [CLOCK_SUBSET]: context->getTime; qualified subset, not full conversion */
inline rx::Value BIF_TIME(const std::vector<rx::Value>& a, rxbif::Context& ctx) {
    if (a.size() > 3) throw std::runtime_error("BIF TIME: arity");
    return rxbif::invoke("TIME", a, ctx);
}
/* upstream COPIES line 286 [METHOD]: return string->copies(n) */
inline rx::Value BIF_COPIES(const std::vector<rx::Value>& a, rxbif::Context& ctx) {
    if (a.size() < 2 || a.size() > 2) throw std::runtime_error("BIF COPIES: arity");
    (void)ctx;
    (void)ctx; if (a[0].isObject() || a[1].isObject()) throw std::runtime_error("COPIES: object conversion unsupported");
    std::int64_t n = 0;
    if (!rx::tryInteger(a[1], n) || n < 0) throw std::runtime_error("COPIES: bad repeat count");
    const std::string& src = a[0].bytes;
    if (n != 0 && src.size() > 100000000ull / static_cast<std::uint64_t>(n)) throw std::runtime_error("COPIES: qualified size limit");
    std::string out; out.reserve(src.size() * static_cast<std::size_t>(n));
    for (std::int64_t i = 0; i < n; ++i) out += src;
    return rx::Value::string(out);
}
/* upstream C2X line 301 [METHOD]: return string->c2x() */
inline rx::Value BIF_C2X(const std::vector<rx::Value>& a, rxbif::Context& ctx) {
    if (a.size() < 1 || a.size() > 1) throw std::runtime_error("BIF C2X: arity");
    (void)ctx;
    (void)ctx; if (a[0].isObject()) throw std::runtime_error("C2X: object conversion unsupported");
    const std::string& src = a[0].bytes;
    if (src.size() > 50000000) throw std::runtime_error("C2X: qualified output size limit");
    static constexpr char hex[] = "0123456789ABCDEF";
    std::string out; out.reserve(src.size() * 2);
    for (unsigned char c : src) { out += hex[c >> 4]; out += hex[c & 15]; }
    return rx::Value::string(out);
}
/* upstream X2C line 314 [METHOD]: return string->x2c() */
inline rx::Value BIF_X2C(const std::vector<rx::Value>& a, rxbif::Context& ctx) {
    if (a.size() < 1 || a.size() > 1) throw std::runtime_error("BIF X2C: arity");
    return rxbif::invoke("X2C", a, ctx);
}
/* upstream BITAND line 327 [METHOD]: return string1->bitAnd(string2,pad) */
inline rx::Value BIF_BITAND(const std::vector<rx::Value>& a, rxbif::Context& ctx) {
    if (a.size() < 1 || a.size() > 3) throw std::runtime_error("BIF BITAND: arity");
    (void)ctx;
    for (const auto& v : a) if (v.isObject()) throw std::runtime_error("BITAND: object conversion unsupported");
    if (a.size() == 1) return rx::Value::string(a[0].bytes);
    const std::string& first = a[0].bytes; const std::string& second = a[1].bytes;
    if (first.size() > 100000000 || second.size() > 100000000) throw std::runtime_error("BITAND: size limit");
    unsigned char fill = 255;
    if (a.size() == 3) { if (a[2].bytes.size() != 1) throw std::runtime_error("BITAND: invalid pad"); fill = static_cast<unsigned char>(a[2].bytes[0]); }
    std::string out; out.reserve(std::max(first.size(), second.size()));
    for (size_t i = 0; i < std::max(first.size(), second.size()); ++i) {
      unsigned char x = i < first.size() ? static_cast<unsigned char>(first[i]) : fill;
      unsigned char y = i < second.size() ? static_cast<unsigned char>(second[i]) : fill;
      out.push_back(static_cast<char>(x & y));
    }
    return rx::Value::string(out);
}
/* upstream BITOR line 344 [METHOD]: return string1->bitOr(string2,pad) */
inline rx::Value BIF_BITOR(const std::vector<rx::Value>& a, rxbif::Context& ctx) {
    if (a.size() < 1 || a.size() > 3) throw std::runtime_error("BIF BITOR: arity");
    (void)ctx;
    for (const auto& v : a) if (v.isObject()) throw std::runtime_error("BITOR: object conversion unsupported");
    if (a.size() == 1) return rx::Value::string(a[0].bytes);
    const std::string& first = a[0].bytes; const std::string& second = a[1].bytes;
    if (first.size() > 100000000 || second.size() > 100000000) throw std::runtime_error("BITOR: size limit");
    unsigned char fill = 0;
    if (a.size() == 3) { if (a[2].bytes.size() != 1) throw std::runtime_error("BITOR: invalid pad"); fill = static_cast<unsigned char>(a[2].bytes[0]); }
    std::string out; out.reserve(std::max(first.size(), second.size()));
    for (size_t i = 0; i < std::max(first.size(), second.size()); ++i) {
      unsigned char x = i < first.size() ? static_cast<unsigned char>(first[i]) : fill;
      unsigned char y = i < second.size() ? static_cast<unsigned char>(second[i]) : fill;
      out.push_back(static_cast<char>(x | y));
    }
    return rx::Value::string(out);
}
/* upstream BITXOR line 361 [METHOD]: return string1->bitXor(string2,pad) */
inline rx::Value BIF_BITXOR(const std::vector<rx::Value>& a, rxbif::Context& ctx) {
    if (a.size() < 1 || a.size() > 3) throw std::runtime_error("BIF BITXOR: arity");
    (void)ctx;
    for (const auto& v : a) if (v.isObject()) throw std::runtime_error("BITXOR: object conversion unsupported");
    if (a.size() == 1) return rx::Value::string(a[0].bytes);
    const std::string& first = a[0].bytes; const std::string& second = a[1].bytes;
    if (first.size() > 100000000 || second.size() > 100000000) throw std::runtime_error("BITXOR: size limit");
    unsigned char fill = 0;
    if (a.size() == 3) { if (a[2].bytes.size() != 1) throw std::runtime_error("BITXOR: invalid pad"); fill = static_cast<unsigned char>(a[2].bytes[0]); }
    std::string out; out.reserve(std::max(first.size(), second.size()));
    for (size_t i = 0; i < std::max(first.size(), second.size()); ++i) {
      unsigned char x = i < first.size() ? static_cast<unsigned char>(first[i]) : fill;
      unsigned char y = i < second.size() ? static_cast<unsigned char>(second[i]) : fill;
      out.push_back(static_cast<char>(x ^ y));
    }
    return rx::Value::string(out);
}
/* upstream B2X line 378 [METHOD]: return string->b2x() */
inline rx::Value BIF_B2X(const std::vector<rx::Value>& a, rxbif::Context& ctx) {
    if (a.size() < 1 || a.size() > 1) throw std::runtime_error("BIF B2X: arity");
    (void)ctx;
    if (a[0].isObject()) throw std::runtime_error("B2X: object conversion unsupported");
    const std::string& src = a[0].bytes;
    if (src.size() > 100000000) throw std::runtime_error("B2X: size limit");
    if (src.empty()) return rx::Value::string("");
    for (char c : src) if (c != 48 && c != 49) throw std::runtime_error("B2X: unqualified bit-group format");
    static constexpr char hex[] = "0123456789ABCDEF";
    std::string out; out.reserve((src.size() + 3) / 4);
    unsigned nibble = 0, filled = 0;
    for (size_t i = 0; i < (4 - src.size() % 4) % 4; ++i) { nibble <<= 1; ++filled; }
    for (char c : src) { nibble = (nibble << 1) + static_cast<unsigned>(c - 48); if (++filled == 4) { out += hex[nibble]; nibble = 0; filled = 0; } }
    return rx::Value::string(out);
}
/* upstream X2B line 391 [METHOD]: return string->x2b() */
inline rx::Value BIF_X2B(const std::vector<rx::Value>& a, rxbif::Context& ctx) {
    if (a.size() < 1 || a.size() > 1) throw std::runtime_error("BIF X2B: arity");
    (void)ctx;
    if (a[0].isObject()) throw std::runtime_error("X2B: object conversion unsupported");
    const std::string& src = a[0].bytes;
    if (src.size() > 25000000) throw std::runtime_error("X2B: size limit");
    std::string out; out.reserve(src.size() * 4);
    for (char c : src) {
      unsigned x = 0;
      if (c >= 48 && c <= 57) x = static_cast<unsigned>(c - 48);
      else if (c >= 65 && c <= 70) x = static_cast<unsigned>(c - 65 + 10);
      else if (c >= 97 && c <= 102) x = static_cast<unsigned>(c - 97 + 10);
      else throw std::runtime_error("X2B: unqualified hex-group format");
      for (int bit = 3; bit >= 0; --bit) out += (x & (1u << bit)) ? static_cast<char>(49) : static_cast<char>(48);
    }
    return rx::Value::string(out);
}
} // namespace rxbif_generated
