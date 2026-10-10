/* Benchmark kernel, NOT the full RexxCPS algorithm.
   Shape derived from shipped rexxcps.rex: timed averaging DO/DO count.
   Deliberately retains a per-iteration operation to prevent empty-loop folding.
*/
count = 1000
averaging = 1000
total = 0
do i = 1 to averaging
  do count
    total += i
  end
end
say total
