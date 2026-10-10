/* SELECT/WHEN first true branch, test no fallthrough. */
a = 2
select
  when a = 1 then say 'wrong first'
  when a = 2 then say 'two'
  when a = 2 then say 'wrong third'
  otherwise say 'wrong otherwise'
end
say 'done'
