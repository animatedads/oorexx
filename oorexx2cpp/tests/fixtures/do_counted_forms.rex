do i = 1 to 3; say 'a' i; end
do i = 5 by -2 for 3; say 'b' i; end
do i = 1 while i < 4; say 'c' i; end
do i = 1 to 10 until i >= 3; say 'd' i; end
do i = 1 for 0; say 'never'; end
j = 0; do i = 1 to 5 by 2 while j < 2; j = j + 1; say 'e' i j; end
do i = 1 to 3; if i = 2 then iterate; say 'f' i; end
say 'final' i
x = 0; do i = 1 until x; x = 1; say 'g' i; end
