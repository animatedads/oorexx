w = .weakReference~new(.LifetimeTest~new~make1)
do i = 1 to 20; g = gc('F'); do 10; x = .object~new; end; if w~value == .nil then leave; end
say 'returned object collected after' i
o = .object~new; w = .weakReference~new(o); .LifetimeTest~new~make2(o); drop o
do i = 1 to 20; g = gc('F'); do 10; x = .object~new; end; if w~value == .nil then leave; end
say 'argument object collected after' i
w = .LifetimeTest~new~make3(.object~new)
do i = 1 to 20; g = gc('F'); do 10; x = .object~new; end; if w~value == .nil then leave; end
say 'object made in the interpreter collected after' i
say 'churn collected:' .LifetimeTest~new~churn
do 5; .LifetimeTest~new~make2(.object~new); end
do i = 1 to 20; g = gc('F'); do 10; x = .object~new; end; if .LifetimeTest~uninits >= 5 then leave; end
say 'uninits ran:' (.LifetimeTest~uninits >= 5)
