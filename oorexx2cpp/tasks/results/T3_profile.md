# T3 profile report

Machine: x86_64, Intel(R) Core(TM) Ultra 7 155H

Performance line from step 2 (plain run, no valgrind): `Performance: 1726245 REXX clauses per second`

Under callgrind the same program ran at `Performance: 25731 REXX clauses per second` (valgrind slows it about 67x, so use the callgrind run for percentages only).

Program: `tasks/results/cps_small.rex` (5 averaging loops), built with `./build.sh`, run as `/tmp/prof/small.bin` under `valgrind --tool=callgrind`. Total cost 3,241,106,165 Ir.

Note: names are shortened where C++ template arguments made them very long. Percentages are unchanged.

## Top 15 functions by self cost

```
10.04%  libgcc_s.so.1 (unnamed address 0x1fdd0)
 7.15%  libstdc++.so.6 (unnamed address 0xc8cc0)
 4.58%  rx::parseRexxDecimal(rx::Value const&)
 4.22%  __memcpy_avx_unaligned_erms [libc]
 3.59%  boost::multiprecision cpp_int_base::resize
 3.55%  boost::multiprecision eval_multiply (cpp_int)
 3.52%  boost::multiprecision cpp_int_backend::do_get_string
 3.00%  __gxx_personality_v0 [libstdc++]
 2.60%  __strlen_avx2 [libc]
 2.39%  bool std::operator==(std::string const&, char const*)
 2.29%  _Unwind_Find_FDE [libgcc_s]
 2.17%  std::string::_M_construct<true>(char const*, unsigned long)
 2.10%  free [libc]
 2.05%  boost::multiprecision add_unsigned (cpp_int)
 2.05%  libgcc_s.so.1 (unnamed address 0x21260)
```

## Top 15 functions by inclusive cost

```
100.00%  ld-linux-x86-64.so.2 (unnamed address 0x223c0)
 99.91%  _start (glibc csu/start.S)
 99.91%  __libc_start_main [libc]
 99.91%  (below main) [libc]
 99.89%  main [small.bin]
 64.55%  rx::sendBinary(rx::Value const&, std::string const&, rx::Value const&, rx::ActivationNumeric const&)
 46.95%  rx::numericCompare(rx::Value const&, std::string const&, rx::Value const&, rx::ActivationNumeric const&)
 46.22%  rx::parseRexxDecimal(rx::Value const&)
 20.65%  __cxa_throw [libstdc++]
 20.57%  unnamed address 0x4915090
 20.57%  _Unwind_RaiseException [libgcc_s]
 16.62%  unnamed address 0x227c0 [libgcc_s]
 16.35%  unnamed address 0x21260 [libgcc_s]
 15.53%  rx::numericAdd(rx::Value const&, rx::Value const&, rx::ActivationNumeric const&)
 13.59%  rx::decimalDigits(boost::multiprecision::number<cpp_int>, const&)
```

## Split by area (sum of self-cost percentages across the whole profile)

Some lines can match more than one pattern, so the percentages overlap a little.

- (a) BIF entry (`rxkernel::`, `ApiContext`, `ProtectedObject`): **0.29%**
- (b) Variable store and strings (`unordered_map`, `hash`, `basic_string`): **21.79%**
- (c) Number engine (`Decimal`, `decimal`): **7.81%**
- (d) Other large costs:
  - Exception unwinding and C++ runtime (`libgcc_s`, `libstdc++`, `__gxx_personality`, `_Unwind`): **39.82%**. The inclusive list shows `__cxa_throw` at 20.65%, so exception throwing is a large part of this.
  - Boost big-integer arithmetic (`cpp_int`): **15.19%**. This is not counted in (c), because the pattern is `cpp_int`, not `decimal`.

No source was changed. The only file written is this report.
