#pragma once
// Native ooRexx DATATYPE S/V recognizer, ASCII/Linux ooRexx 5.3 symbol table.
// Mirrors the symbol-category decision tree in LanguageParser::scanSymbol.
// No interpreter link, no activation state, no allocations on the scan path.
// IMPORTANT: This is NOT a generalized Rexx parser. It only classifies names.
#include <cstddef>
#include <string>

namespace rxbif_symbol {
enum class Category { Bad, Literal, Variable };
inline bool digit(unsigned char c) { return c >= '0' && c <= '9'; }
inline bool letter(unsigned char c) {
    return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z');
}
inline bool symbolChar(unsigned char c) {
    return letter(c) || digit(c) || c == '!' || c == '?' || c == '_' || c == '.';
}
inline bool exponent(unsigned char c) { return c == 'e' || c == 'E'; }
inline Category classify(const std::string& s) {
    // ooRexx LanguageParser::MAX_SYMBOL_LENGTH is 250 bytes.
    if (s.empty() || s.size() > 250) return Category::Bad;
    std::size_t i = 0, dots = 0;
    while (i < s.size() && symbolChar(static_cast<unsigned char>(s[i]))) {
        if (s[i] == '.') ++dots;
        ++i;
    }
    bool signedExponent = false;
    if (i < s.size()) {
        // Only +/- following E/e and followed by at least one digit is
        // admissible; all remaining characters must be ASCII decimal digits.
        if (i == 0 || i + 1 == s.size() || (s[i] != '+' && s[i] != '-') ||
            !exponent(static_cast<unsigned char>(s[i-1]))) return Category::Bad;
        ++i;
        for (; i < s.size(); ++i)
            if (!digit(static_cast<unsigned char>(s[i]))) return Category::Bad;
        signedExponent = true;
    }
    if (s[0] == '.' || digit(static_cast<unsigned char>(s[0]))) {
        if (s.size() == 1 && dots == 1) return Category::Literal;
        if (dots > 1) return signedExponent ? Category::Bad : Category::Literal;
        std::size_t j = 0;
        while (j < s.size() && (digit(static_cast<unsigned char>(s[j])) || s[j] == '.')) ++j;
        if (j == s.size()) return Category::Literal; // numeric token
        if (exponent(static_cast<unsigned char>(s[j]))) {
            ++j;
            if (j < s.size() && (s[j] == '+' || s[j] == '-')) return Category::Literal;
            for (; j < s.size(); ++j)
                if (!digit(static_cast<unsigned char>(s[j]))) return Category::Literal;
            return Category::Literal;
        }
        return Category::Literal;
    }
    return Category::Variable;
}
inline bool datatype(const std::string& s, char option) {
    const Category c = classify(s);
    return option == 'S' ? c != Category::Bad : c == Category::Variable;
}
} // namespace rxbif_symbol
