/* ooRexx-written source-to-source BIF converter. Independent of rx2cpp. */
parse arg cppfile outdir
if cppfile == '' | outdir == '' then do
  say 'Usage: rexx bif2inline.rex /path/BuiltinFunctions.cpp /existing/output-dir'
  exit 64
end
signal on syntax name failed
signal on error name failed
signal on failure name failed
if stream(cppfile, 'C', 'QUERY EXISTS') == '' then do
  say 'bif2inline: upstream C++ source not found:' cppfile
  exit 66
end
reader = .BifSourceReader~new
entries = reader~scan(cppfile)
if entries~items == 0 then do
  say 'bif2inline: no upstream BUILTIN definitions found'
  exit 65
end
converter = .BifRuleEngine~new
accepted = .array~new
coverage = .array~new
coverage~append('name' || '09'x || 'status' || '09'x || 'line' || '09'x || 'evidence')
do definition over entries
  ir = converter~convert(definition)
  if ir == .nil then do
    coverage~append(definition~name || '09'x || 'REJECTED' || '09'x || definition~line || '09'x || converter~reason)
  end
  else do
    accepted~append(ir)
    coverage~append(definition~name || '09'x || 'ADMITTED_SUBSET' || '09'x || definition~line || '09'x || ir~evidence)
  end
end
if accepted~items == 0 then do
  say 'bif2inline: no recognised/qualified BIFs in input; refusing outputs'
  exit 65
end
writer = .BifEmitter~new
writer~emit(accepted, coverage, outdir)
say 'bif2inline: accepted' accepted~items 'of' entries~items 'upstream BIF definitions'
say 'bif2inline: wrote' outdir'/rxbif_generated.hpp and rxbif.ir.tsv and coverage.tsv'
exit 0
failed:
  say 'bif2inline failure:' condition('O')~at('MESSAGE')
  exit 70
::requires 'compiler/BifSourceReader.cls'
::requires 'compiler/BifRuleEngine.cls'
::requires 'compiler/BifEmitter.cls'
