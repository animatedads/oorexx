/* xheap.rex: a compiled object holding an instance of an Array subclass (made natively, arrayNewTable) that holds
   compiled objects referring back to it: each pass leaves the previous one unreachable. The collector must free it
   (an Array-subclass state without an interpreter object is not held from outside). */
do pass = 1 to 8
  h = .Holder~new
  do i = 1 to 800; h~add(i); end
  say "pass" pass h~size
end
::requires "xheaplib.cls"
