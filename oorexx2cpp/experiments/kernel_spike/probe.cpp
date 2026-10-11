// Reads cases (NAME|arg|arg|...) from a file; an EMPTY field is an omitted argument, the field <empty> is the null string.
// Calls the compiled-in real handler builtin_function_NAME and prints:  NAME|args => [result]   or   NAME|args => ERROR
#include "RexxCore.h"
#include "StringClass.hpp"
#include "IntegerClass.hpp"
#include "RexxActivation.hpp"
#include "Activity.hpp"
#include "ExpressionStack.hpp"
#include "BuiltinFunctions.hpp"
#include "ContextApi.hpp"
#include "oorexxapi.h"
#include <cstdio>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <cstring>
#include "bif_decls.inc"
struct Entry { const char *name; RexxObject *(*fn)(RexxActivation *, size_t, ExpressionStack *); };
static const Entry table[] = {
#include "bif_table.inc"
};
int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: probe cases.txt\n"); return 64; }
    RexxInstance *inst; RexxThreadContext *thr;
    if (!RexxCreateInterpreter(&inst, &thr, nullptr)) { fprintf(stderr, "no interpreter (is rexx.img in the current directory?)\n"); return 1; }
    std::ifstream in(argv[1]); std::string line;
    {
        ApiContext ctx(thr);
        while (std::getline(in, line)) {
            if (line.empty() || line[0] == '#') continue;
            std::vector<std::string> f; std::stringstream ss(line); std::string x;
            while (std::getline(ss, x, '|')) f.push_back(x);
            if (!line.empty() && line.back() == '|') f.push_back("");
            const Entry *e = nullptr;
            for (const Entry &t : table) if (f[0] == t.name) e = &t;
            printf("%s => ", line.c_str());
            if (!e) { puts("NOTPURE"); continue; }
            RexxInternalObject *frame[64]; ExpressionStack st(frame, 64);
            for (size_t i = 1; i < f.size(); i++) {
                if (f[i].empty()) st.push(OREF_NULL);
                else st.push(new_string(f[i] == "<empty>" ? "" : f[i].c_str()));
            }
            try {
                RexxObject *r = e->fn(NULL, f.size() - 1, &st);
                if (r == OREF_NULL) puts("(none)"); else printf("[%s]\n", r->stringValue()->getStringData());
            } catch (...) { puts("ERROR"); }
        }
    }
    inst->Terminate();
}
