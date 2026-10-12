say c2x(d2c(0)) c2x(d2c(255)) c2x(d2c(256)) c2x(d2c(65,1)) c2x(d2c(-1,2)) c2x(d2c(300,1)) c2x(d2c(-129,1)) c2x(d2c(5,4))
say c2d('') c2d('FF'x) c2d('FF'x,1) c2d('FF'x,2) c2d('80'x,1) c2d('0102'x) c2d('FFFF'x,1) c2d('00FF'x, 1) c2d('1234'x,0)
say d2x(0) d2x(255) d2x(-1,2) d2x(4096,6) x2d('FF') x2d('FF',2) x2d('81',2) x2d('') x2c('41 42') c2x('AB')
numeric digits 30
say c2d('FFFFFFFFFFFFFFFF'x) c2x(d2c(18446744073709551615))
