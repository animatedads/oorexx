/* stems passed to external routines (sorted in place, inserted, deleted, copied, filled), flat and bound */
s.0 = 3; s.1 = 'pear'; s.2 = 'apple'; s.3 = 'fig'
call SysStemSort 's.'
say s.0 s.1 s.2 s.3
call SysStemSort 's.', 'D'
say s.1 s.2 s.3
call SysStemInsert 's.', 2, 'kiwi'
say s.0 s.1 s.2 s.3 s.4
call SysStemDelete 's.', 1
say s.0 s.1 s.2 s.3 s.4
t. = 'none'
t.0 = 2; t.1 = 'b'; t.2 = 'a'
call SysStemSort 't.'
say t.1 t.2 t.3
call SysStemCopy 's.', 'u.'
say u.0 u.1 u.2 u.3
call SysFileTree 'd/*.txt', 'files.', 'FO'
say files.0
call SysStemSort 'files.'
do i = 1 to files.0; say filespec('name', files.i); end
/* external routines declared in the program, under the caller's NUMERIC DIGITS */
numeric digits 12
say Sqrt(2) Exp(1) Ln(10)
name = 'SQRT'
call (name) 16
say result
exit
::Routine Sqrt External "LIBRARY rxmath RxCalcSqrt"
::Routine Exp  External "LIBRARY rxmath RxCalcExp"
::Routine Ln   External "LIBRARY rxmath RxCalcLog"
