# Task cards for a small model (Haiku-class)

Architecture: Tom Dyer. Coding: ChatGPT / Claude. Cards written by Sonnet 5.5.

Rules for every card
1. Do exactly the numbered steps, in order. Copy commands exactly. Do not improvise or "improve".
2. Work only in `tasks/results/` and any file the card names. Never edit `external/`, `core/`, `rules/`, `include/`, `inspector/`.
3. If a command fails or output differs from "Expect", do NOT fix the code. Copy the full output into the report and stop.
4. Never run two builds at once. Never use `sleep` longer than 60 seconds. Never poll in a loop.
5. Commit only the files the card names. Commit message = one line of what you did, then these two lines:
   `Architecture: Tom Dyer. Coding: ChatGPT / Claude. Writer: <your model name>.`
   `Co-Authored-By: <your model name> <noreply@anthropic.com>`
6. The report is a file `tasks/results/<card>.md` with: what you ran, the last 20 lines of each command output, PASS or FAIL.

Setup (once per session)
    export OO_ROOT=<ooRexx install root that contains bin/rexx and lib/>
    export PATH=$OO_ROOT/bin:$PATH REXX_PATH=$PWD LD_LIBRARY_PATH=$OO_ROOT/lib
    cd <this repo>/oorexx2cpp

Cards
- T1_build_kernel.md   build the compiled-in ooRexx kernel and the probe program.
- T2_bif_cases.md      write test cases for 56 built-in functions and compare against the interpreter.
