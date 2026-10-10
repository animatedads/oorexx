# DATE and TIME — source-guided native semantics (v0.4)

The converter, source reader, emission rules and RBI1 generator are **ooRexx
classes**. These native C++ functions are the qualified execution backend;
rx2cpp is intentionally untouched. The real ooRexx implementation is
`interpreter/expression/BuiltinFunctions.cpp`, especially `BUILTIN(DATE)`
and `BUILTIN(TIME)`, which delegate conversion to `RexxDateTime`.

## Date and time are not the same as a generic Unix clock

* `rxbif::Context` captures `activationTime` on creation. Calls to `DATE()` and
  `TIME()` with that context share an instant. Do **not** manufacture a new
  Context per built-in invocation.
* The local timezone offset is derived from that captured instant, not from
  the target date. `TIME('O')` reports that offset **in microseconds**.
* In ooRexx, `DATE('B')` counts civil days from 1 January year 1 **starting
  at zero**, so `DATE('B','2024-02-29','I') == 738944`.
* `DATE('F')` and `TIME('F')` are **microseconds from the base-date origin**.
  `DATE('F','2024-02-29','I') == 63844761600000000`, and
  `TIME('F','13:02:03','N') == 46923000000`.
* `DATE('T')` and `TIME('T')` are civil seconds relative to the Unix epoch.
  Unlike a conventional timezone-adjusted timestamp, ooRexx's conversion
  here is **unchanged by TZ**. Oracle comparison covers five timezones.
* `TIME('E')` / `TIME('R')` are context-local elapsed/reset timers in this
  backend, using `steady_clock`. The exact ooRexx activation/statement clock
  rollover and microsecond scheduling effects are not fully qualified.

## Accepted DATE output/input styles

DATE output: `B D E F I L M N O S T U W`. Input conversion: `B D E F I N O S T U`.
Input `D` uses the **current captured year**. Date input parsing supports
canonical forms (including `N`, `E`, `O`, `U`, `I`, `S`, base and epoch values).
Formatting supports the fourth-argument output separator and fifth-argument
input separator, if each is an empty or single non-alphanumeric byte and the
chosen styles allow it. Without a distinct omission marker, the current
`std::vector<rx::Value>` entrypoint cannot express a *missing middle argument*
(e.g. `DATE('I',date,'I',,'/')`). Do not confuse an empty string with an
omitted Rexx argument; a future native call ABI will need explicit omission.

## Accepted TIME styles

Output `C E F H L M N O R S T`; input conversion `C F H L M N S T`.
The upstream input `O` mode, which changes the timezone offset, is still
**unsupported**, as it needs a richer context model. `E`/`R` output cannot
be combined with an explicit input time. Current parser accepts canonical
`C` and `N` formats and one-to-six fractional digits with `L`.

## Admission and verification

`rules/BifClockRule.cls` validates crucial actual upstream constructs,
including the argument range, activation time, clock conversion branches,
time-zone offset, and elapsed/reset operations. Generated `.cls` rules record
`CLOCK_SUBSET`, not full equivalence. `DATE` is emitted by the converter when
it receives a full upstream source file. The offline `BuiltinFunctions.excerpt.cpp`
fixture contains the **verbatim TIME definition** but **not DATE**; do not
mistake offline-generated coverage for full upstream DATE admission.

Reference cases: `tests/clock_differential.cpp` (49 examples compared by
byte-accurate hex output), `tests/clock_contract.cpp` (invalid inputs, fixed
activation and epoch conversions). Baseline ooRexx: 5.3.0 r13196. Results
have been checked using `TZ=UTC`, `Europe/London`, `America/New_York`,
`Asia/Kolkata`, and `Pacific/Auckland`. These are selected microcases, not
complete upstream ooTest group qualification.
