/* BIF control-state original interpreter oracle -- exact source line 1 */
say 'COUNT' sourceline()
say 'FIRST' sourceline(1)
say 'TRACE_READ' trace()
say 'TRACE_PREV' trace('O')
say 'TRACE_READ2' trace()
say 'TRACE_RESET' trace('N')
say 'CONDITION_I' '['condition()']'
say 'CONDITION_C' '['condition('C')']'
say 'CONDITION_D' '['condition('D')']'
say 'CONDITION_S' '['condition('S')']'
say 'CONDITION_E' '['condition('E')']'
say 'CONDITION_R' '['condition('R')']'
