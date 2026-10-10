/* Default standard output, including an embedded NUL written with CHAROUT. */
say 'before'
say 'lineout-return=' || lineout(,'ABC')
say 'charout-return=' || charout(,'410042'x)
say ''
say 'after'
