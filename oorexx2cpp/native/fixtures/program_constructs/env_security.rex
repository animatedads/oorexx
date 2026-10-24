/* environment symbols under the package's security manager (PackageClass::findClass): LOCAL and ENVIRONMENT asked */
.local['SECA'] = 'local A'
.environment['SECB'] = 'global B'
say .seca .secb .secc
.context~package~setSecurityManager(.Mgr~new)
say .seca '|' .secb '|' .secc '|' .secd
do i = 1 to 2
  say i .secb
end
say .array~new(1)~size .local~class~id
.Mgr~bad = 1
signal on syntax
say .secq
exit
syntax: say 'error' condition('o')~code condition('o')~message
exit
::class Mgr
::attribute bad class
::method local
  use arg args
  say '  LOCAL asked' args['NAME']
  if args['NAME'] == 'SECC' then do; args['RESULT'] = 'from manager'; return 1; end
  if args['NAME'] == 'SECD' then return 1
  return 0
::method environment
  use arg args
  say '  ENVIRONMENT asked' args['NAME']
  if .Mgr~bad == 1 then return 'maybe'
  if args['NAME'] == 'SECB' then do; args['RESULT'] = .nil; return 1; end
  return 0
::method unknown
  return 0
