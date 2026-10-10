/* Native inline lowering for proven delegates only. This is the ooRexx
   rule that writes C++ from METHOD IR. Any other method uses a native helper
   call, and clock/activation semantics remain behind an explicit context. */
::class BifInlineBackendRule public
::method body
  use arg node
  select
    when node~name == 'REVERSE' & node~method == 'reverse' then do
      return '    if (a[0].isObject()) throw std::runtime_error("REVERSE: object conversion unsupported");' || '0a'x || ,
             '    return rx::Value::string(std::string(a[0].bytes.rbegin(), a[0].bytes.rend()));'
    end
    when node~name == 'WORDS' & node~method == 'words' then do
      return '    if (a[0].isObject()) throw std::runtime_error("WORDS: object conversion unsupported");' || '0a'x || ,
             '    std::int64_t total = 0; bool inside = false;' || '0a'x || ,
             '    for (char c : a[0].bytes) {' || '0a'x || ,
             "      if (c == ' ' || c == 9) { inside = false; }" || '0a'x || ,
             '      else if (!inside) { ++total; inside = true; }' || '0a'x || ,
             '    }' || '0a'x || ,
             '    return rx::fromInteger(total);'
    end
    when node~name == 'C2X' & node~method == 'c2x' then do
      return '    (void)ctx; if (a[0].isObject()) throw std::runtime_error("C2X: object conversion unsupported");' || '0a'x || ,
        '    const std::string& src = a[0].bytes;' || '0a'x || ,
        '    if (src.size() > 50000000) throw std::runtime_error("C2X: qualified output size limit");' || '0a'x || ,
        '    static constexpr char hex[] = "0123456789ABCDEF";' || '0a'x || ,
        '    std::string out; out.reserve(src.size() * 2);' || '0a'x || ,
        '    for (unsigned char c : src) { out += hex[c >> 4]; out += hex[c & 15]; }' || '0a'x || ,
        '    return rx::Value::string(out);'
    end
    when node~name == 'COPIES' & node~method == 'copies' then do
      return '    (void)ctx; if (a[0].isObject() || a[1].isObject()) throw std::runtime_error("COPIES: object conversion unsupported");' || '0a'x || ,
        '    std::int64_t n = 0;' || '0a'x || ,
        '    if (!rx::tryInteger(a[1], n) || n < 0) throw std::runtime_error("COPIES: bad repeat count");' || '0a'x || ,
        '    const std::string& src = a[0].bytes;' || '0a'x || ,
        '    if (n != 0 && src.size() > 100000000ull / static_cast<std::uint64_t>(n)) throw std::runtime_error("COPIES: qualified size limit");' || '0a'x || ,
        '    std::string out; out.reserve(src.size() * static_cast<std::size_t>(n));' || '0a'x || ,
        '    for (std::int64_t i = 0; i < n; ++i) out += src;' || '0a'x || ,
        '    return rx::Value::string(out);'
    end
    when node~name == 'B2X' & node~method == 'b2x' then do
      return '    if (a[0].isObject()) throw std::runtime_error("B2X: object conversion unsupported");' || '0a'x || ,
        '    const std::string& src = a[0].bytes;' || '0a'x || ,
        '    if (src.size() > 100000000) throw std::runtime_error("B2X: size limit");' || '0a'x || ,
        '    if (src.empty()) return rx::Value::string("");' || '0a'x || ,
        '    for (char c : src) if (c != 48 && c != 49) throw std::runtime_error("B2X: unqualified bit-group format");' || '0a'x || ,
        '    static constexpr char hex[] = "0123456789ABCDEF";' || '0a'x || ,
        '    std::string out; out.reserve((src.size() + 3) / 4);' || '0a'x || ,
        '    unsigned nibble = 0, filled = 0;' || '0a'x || ,
        '    for (size_t i = 0; i < (4 - src.size() % 4) % 4; ++i) { nibble <<= 1; ++filled; }' || '0a'x || ,
        '    for (char c : src) { nibble = (nibble << 1) + static_cast<unsigned>(c - 48); if (++filled == 4) { out += hex[nibble]; nibble = 0; filled = 0; } }' || '0a'x || ,
        '    return rx::Value::string(out);'
    end
    when node~name == 'X2B' & node~method == 'x2b' then do
      return '    if (a[0].isObject()) throw std::runtime_error("X2B: object conversion unsupported");' || '0a'x || ,
        '    const std::string& src = a[0].bytes;' || '0a'x || ,
        '    if (src.size() > 25000000) throw std::runtime_error("X2B: size limit");' || '0a'x || ,
        '    std::string out; out.reserve(src.size() * 4);' || '0a'x || ,
        '    for (char c : src) {' || '0a'x || ,
        '      unsigned x = 0;' || '0a'x || ,
        '      if (c >= 48 && c <= 57) x = static_cast<unsigned>(c - 48);' || '0a'x || ,
        '      else if (c >= 65 && c <= 70) x = static_cast<unsigned>(c - 65 + 10);' || '0a'x || ,
        '      else if (c >= 97 && c <= 102) x = static_cast<unsigned>(c - 97 + 10);' || '0a'x || ,
        '      else throw std::runtime_error("X2B: unqualified hex-group format");' || '0a'x || ,
        '      for (int bit = 3; bit >= 0; --bit) out += (x & (1u << bit)) ? static_cast<char>(49) : static_cast<char>(48);' || '0a'x || ,
        '    }' || '0a'x || ,
        '    return rx::Value::string(out);'
    end
    when node~name == 'BITAND' & node~method == 'bitAnd' then do
      return '    for (const auto& v : a) if (v.isObject()) throw std::runtime_error("BITAND: object conversion unsupported");' || '0a'x || ,
        '    if (a.size() == 1) return rx::Value::string(a[0].bytes);' || '0a'x || ,
        '    const std::string& first = a[0].bytes; const std::string& second = a[1].bytes;' || '0a'x || ,
        '    if (first.size() > 100000000 || second.size() > 100000000) throw std::runtime_error("BITAND: size limit");' || '0a'x || ,
        '    unsigned char fill = 255;' || '0a'x || ,
        '    if (a.size() == 3) { if (a[2].bytes.size() != 1) throw std::runtime_error("BITAND: invalid pad"); fill = static_cast<unsigned char>(a[2].bytes[0]); }' || '0a'x || ,
        '    std::string out; out.reserve(std::max(first.size(), second.size()));' || '0a'x || ,
        '    for (size_t i = 0; i < std::max(first.size(), second.size()); ++i) {' || '0a'x || ,
        '      unsigned char x = i < first.size() ? static_cast<unsigned char>(first[i]) : fill;' || '0a'x || ,
        '      unsigned char y = i < second.size() ? static_cast<unsigned char>(second[i]) : fill;' || '0a'x || ,
        '      out.push_back(static_cast<char>(x & y));' || '0a'x || ,
        '    }' || '0a'x || ,
        '    return rx::Value::string(out);'
    end
    when node~name == 'BITOR' & node~method == 'bitOr' then do
      return '    for (const auto& v : a) if (v.isObject()) throw std::runtime_error("BITOR: object conversion unsupported");' || '0a'x || ,
        '    if (a.size() == 1) return rx::Value::string(a[0].bytes);' || '0a'x || ,
        '    const std::string& first = a[0].bytes; const std::string& second = a[1].bytes;' || '0a'x || ,
        '    if (first.size() > 100000000 || second.size() > 100000000) throw std::runtime_error("BITOR: size limit");' || '0a'x || ,
        '    unsigned char fill = 0;' || '0a'x || ,
        '    if (a.size() == 3) { if (a[2].bytes.size() != 1) throw std::runtime_error("BITOR: invalid pad"); fill = static_cast<unsigned char>(a[2].bytes[0]); }' || '0a'x || ,
        '    std::string out; out.reserve(std::max(first.size(), second.size()));' || '0a'x || ,
        '    for (size_t i = 0; i < std::max(first.size(), second.size()); ++i) {' || '0a'x || ,
        '      unsigned char x = i < first.size() ? static_cast<unsigned char>(first[i]) : fill;' || '0a'x || ,
        '      unsigned char y = i < second.size() ? static_cast<unsigned char>(second[i]) : fill;' || '0a'x || ,
        '      out.push_back(static_cast<char>(x | y));' || '0a'x || ,
        '    }' || '0a'x || ,
        '    return rx::Value::string(out);'
    end
    when node~name == 'BITXOR' & node~method == 'bitXor' then do
      return '    for (const auto& v : a) if (v.isObject()) throw std::runtime_error("BITXOR: object conversion unsupported");' || '0a'x || ,
        '    if (a.size() == 1) return rx::Value::string(a[0].bytes);' || '0a'x || ,
        '    const std::string& first = a[0].bytes; const std::string& second = a[1].bytes;' || '0a'x || ,
        '    if (first.size() > 100000000 || second.size() > 100000000) throw std::runtime_error("BITXOR: size limit");' || '0a'x || ,
        '    unsigned char fill = 0;' || '0a'x || ,
        '    if (a.size() == 3) { if (a[2].bytes.size() != 1) throw std::runtime_error("BITXOR: invalid pad"); fill = static_cast<unsigned char>(a[2].bytes[0]); }' || '0a'x || ,
        '    std::string out; out.reserve(std::max(first.size(), second.size()));' || '0a'x || ,
        '    for (size_t i = 0; i < std::max(first.size(), second.size()); ++i) {' || '0a'x || ,
        '      unsigned char x = i < first.size() ? static_cast<unsigned char>(first[i]) : fill;' || '0a'x || ,
        '      unsigned char y = i < second.size() ? static_cast<unsigned char>(second[i]) : fill;' || '0a'x || ,
        '      out.push_back(static_cast<char>(x ^ y));' || '0a'x || ,
        '    }' || '0a'x || ,
        '    return rx::Value::string(out);'
    end
    otherwise return ''
  end
