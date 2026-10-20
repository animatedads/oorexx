/* RX2CPP_SEPARATE_PACKAGES=1: each required package keeps its own package */
say filespec('name', .context~package~name)
say lookup('NULL.CLAUSE')
say lookup('HIDDENROUTINE')
say whereami()
h = makeHidden()
say h~class~id h~hello
say .context~package~findRoutine('LOOKUP') \== .nil
say .context~package~findRoutine('HIDDENROUTINE') == .nil
say .local['PKGSEP.PROLOG']
::requires 'pkgsep.cls'
