#!/usr/bin/env rexx
/* mkkit.rex -- assemble the ooDialog Linux kit: the Qt6 renderer, the ooDialog classes it runs, the built
 * ooDialog Designer page, the Designer's tests and examples, and the kit's tools, as one tarball.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-23.
 *
 *   rexx tools/mkkit.rex --version V --wasm OODIALOG_WASM_DIR --designer DESIGNER_PACKAGE_DIR
 *                        --packages ALCHEMY_PACKAGES_DIR --out DIR [--notes FILE]
 *
 * Run in oodialog-qt6 with the library built (build/liboodqt.so).  DESIGNER_PACKAGE_DIR is an
 * oorexx_oodialog_designer package whose site/ has been built (its tools/make.sh).  The alchemy
 * packages give the logging (oorexx_logging_v0.7, oorexx_logging_stream_target_v0.1) and the resource
 * reader (oorexx_win_resources_v0.1).  --notes FILE is added to VERSIONS.txt (the inputs' commits).
 * Writes DIR/oodialog-linux-kit-V/ and DIR/oodialog-linux-kit-V.tar.gz.
 */
parse arg argline
opt. = ""
do while argline \= ""
  parse var argline word value argline
  if word~left(2) \== "--" | value == "" then do
    .error~lineout("usage: rexx tools/mkkit.rex --version V --wasm DIR --designer DIR --packages DIR --out DIR [--notes FILE]")
    exit 2
  end
  opt.[word~substr(3)~upper] = value
end
here = filespec("location", .context~package~name)~strip("T", "/")
here = here~left(here~lastPos("/") - 1)                 -- oodialog-qt6
progress = .ToolProgress~new("mkkit", .context~package, "RUN")
log = progress~logger
do need over .array~of("VERSION", "WASM", "DESIGNER", "PACKAGES", "OUT")
  if opt.need == "" then do
    log~log(.Log~ERROR, "missing --"need~lower)
    exit 2
  end
end
name = "oodialog-linux-kit-"opt.VERSION
kit = opt.OUT"/"name
inputs = .array~of(here"/build/liboodqt.so", opt.WASM"/dist/oodWeb.cls", opt.DESIGNER"/site/designer.html", opt.DESIGNER"/site/rexx.wasm", -
  opt.PACKAGES"/oorexx_logging_v0.7/src/LoggingCore.cls", opt.PACKAGES"/oorexx_logging_stream_target_v0.1/src/LogStreamTarget.cls", -
  opt.PACKAGES"/oorexx_win_resources_v0.1/src/WinResources.cls")
do f over inputs                                          -- check the line and the parachute
  if \sysFileExists(f) then do
    log~log(.Log~ERROR, "missing input:" f)
    exit 1
  end
end
log~log(.Log~INFO, "assembling" kit)
address system 'rm -rf "'kit'" && mkdir -p "'kit'"/lib "'kit'"/rexx "'kit'"/renderer-src "'kit'"/tools "'kit'"/tests "'kit'"/designer'
call copy here"/build/liboodqt.so", kit"/lib/"
do f over .array~of("ooDialog.cls", "oodWeb.cls", "ooShapes.cls")
  call copy opt.WASM"/dist/"f, kit"/rexx/"
end
call copy here"/src/js.cls", kit"/rexx/"
call copy here"/native/oodqt.cpp", kit"/renderer-src/"
call copy here"/native/CMakeLists.txt", kit"/renderer-src/"
call copy here"/RENDERER_CONTRACT.md", kit"/renderer-src/"
call copy here"/README.md", kit"/renderer-src/README-renderer.md"
do p over .array~of("oorexx_logging_v0.7/src/LoggingCore.cls", "oorexx_logging_v0.7/src/MethodInterposition.cls", -
                    "oorexx_logging_stream_target_v0.1/src/LogStreamTarget.cls", "oorexx_win_resources_v0.1/src/WinResources.cls")
  target = kit"/packages/"p
  address system 'mkdir -p "'filespec("location", target)'"'
  call copy opt.PACKAGES"/"p, target
end
address system 'cp "'here'"/kit/tools/* "'kit'"/tools/'
do f over .array~of("oodqt_test.rex", "OodQtTest.cls", "WindowsNames.cls")
  call copy here"/tools/"f, kit"/tools/"
end
-- in the kit the runner finds its logging beside it, not on REXX_PATH
call rewrite kit"/tools/OodQtTest.cls", '::requires "LogStreamTarget.cls"', '::requires "../packages/oorexx_logging_stream_target_v0.1/src/LogStreamTarget.cls"'
address system 'cp -r "'here'"/kit/tests/kit "'kit'"/tests/'
address system 'mkdir -p "'kit'"/tests/designer-qt "'kit'"/tests/designer-gen'
address system 'cd "'opt.DESIGNER'"/tests/qt && cp *.rex *.steps *.expect "'kit'"/tests/designer-qt/ && rm -f "'kit'"/tests/designer-qt/make.rex'
address system 'cp "'opt.DESIGNER'"/tests/gen/* "'kit'"/tests/designer-gen/'
address system 'cp -r "'opt.DESIGNER'"/site/. "'kit'"/designer/'
call copy here"/kit/README.md", kit"/"
-- what went in
versions = .array~new
versions~append("ooDialog Linux kit" opt.VERSION "-- assembled" date("S") time() "by tools/mkkit.rex")
versions~append("Architecture: Tom Dyer.  Kit and renderer: Claude (Opus 5.5).  ooDialog/WASM classes: Claude (Fable 5.2).")
versions~append("Designer: Claude (Opus 5.5); its Database Lab: ChatGPT (GPT-6).  ooRexx/WASM runtime: Josep Maria Blasco.")
versions~append("")
versions~append("renderer: oodialog-qt6" self_version(here"/native/oodqt.cpp"))
if opt.NOTES \== "" then do
  s = .stream~new(opt.NOTES)
  versions~appendAll(s~arrayIn)
  s~close
end
call charout kit"/VERSIONS.txt", versions~makeString("L", "0a"x) || "0a"x
call charout kit"/VERSIONS.txt"
address system 'chmod +x "'kit'"/tools/*.rex'
address system 'cd "'kit'" && find . -type f ! -name MANIFEST.sha256 | sort | xargs -d "\n" sha256sum > MANIFEST.sha256'
address system 'cd "'opt.OUT'" && tar czf "'name'.tar.gz" "'name'"'
if rc \= 0 then do
  log~log(.Log~ERROR, "tar failed")
  exit 1
end
log~log(.Log~INFO, "wrote" opt.OUT"/"name".tar.gz")
exit 0

copy: procedure expose log
  use arg from, to
  address system 'cp "'from'" "'to'"'
  if rc \= 0 then do
    log~log(.Log~ERROR, "could not copy" from)
    exit 1
  end
  return

rewrite: procedure expose log
  use arg file, old, new
  s = .stream~new(file)
  text = s~charIn(1, s~chars)
  s~close
  if text~pos(old) == 0 then do
    log~log(.Log~ERROR, "rewrite: not found in" file":" old)
    exit 1
  end
  s~open("write replace")
  s~charOut(text~changeStr(old, new))
  s~close
  return

self_version: procedure                    -- the version string the renderer reports
  use arg cpp
  s = .stream~new(cpp)
  text = s~charIn(1, s~chars)
  s~close
  parse var text '"oodqt",' . '"' v '"'          -- the package entry: "oodqt", "N.N.N"
  return "v"v

::requires "LogStreamTarget.cls"
