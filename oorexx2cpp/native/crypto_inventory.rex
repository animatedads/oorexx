parse arg sourcePath outputPath
if sourcePath == '' | outputPath == '' then do
 say 'Usage: rexx native/crypto_inventory.rex crypto.cls output.tsv'
 exit 64
end
if stream(sourcePath, 'C', 'QUERY EXISTS') == '' then do
 say 'Crypto source missing:' sourcePath
 exit 66
end
source = charin(sourcePath, 1, chars(sourcePath))
call stream sourcePath, 'C', 'CLOSE'
report = .RxCryptoInventory~new~analyze(source)
state = stream(outputPath, 'C', 'OPEN WRITE REPLACE')
if left(state,6) \= 'READY:' then exit 73
call charout outputPath, report
call stream outputPath, 'C', 'CLOSE'
exit 0
::requires 'native/CryptoInventory.cls'
