/* Built-in function argument errors, one per function: trunk reports the function's 40.x where r13196 gave the method's 93.x (BuiltinFunctionScope). Claude (Opus 5.5), 2026-11-19. */
signal on syntax name e1; x = abs('a'); say 'abs(''a'') ->' x; signal n1
e1: say 'abs(''a'') ->' rc condition('o')~message
n1:
signal on syntax name e2; x = sign('a'); say 'sign(''a'') ->' x; signal n2
e2: say 'sign(''a'') ->' rc condition('o')~message
n2:
signal on syntax name e3; x = trunc('a'); say 'trunc(''a'') ->' x; signal n3
e3: say 'trunc(''a'') ->' rc condition('o')~message
n3:
signal on syntax name e4; x = trunc(1,-1); say 'trunc(1,-1) ->' x; signal n4
e4: say 'trunc(1,-1) ->' rc condition('o')~message
n4:
signal on syntax name e5; x = trunc(1,'x'); say 'trunc(1,''x'') ->' x; signal n5
e5: say 'trunc(1,''x'') ->' rc condition('o')~message
n5:
signal on syntax name e6; x = format('a'); say 'format(''a'') ->' x; signal n6
e6: say 'format(''a'') ->' rc condition('o')~message
n6:
signal on syntax name e7; x = format(1,-1); say 'format(1,-1) ->' x; signal n7
e7: say 'format(1,-1) ->' rc condition('o')~message
n7:
signal on syntax name e8; x = max('a',1); say 'max(''a'',1) ->' x; signal n8
e8: say 'max(''a'',1) ->' rc condition('o')~message
n8:
signal on syntax name e9; x = min(1,'b'); say 'min(1,''b'') ->' x; signal n9
e9: say 'min(1,''b'') ->' rc condition('o')~message
n9:
signal on syntax name e10; x = max(1,2,'c'); say 'max(1,2,''c'') ->' x; signal n10
e10: say 'max(1,2,''c'') ->' rc condition('o')~message
n10:
signal on syntax name e11; x = pos('a','b',0); say 'pos(''a'',''b'',0) ->' x; signal n11
e11: say 'pos(''a'',''b'',0) ->' rc condition('o')~message
n11:
signal on syntax name e12; x = lastpos('a','b',0); say 'lastpos(''a'',''b'',0) ->' x; signal n12
e12: say 'lastpos(''a'',''b'',0) ->' rc condition('o')~message
n12:
signal on syntax name e13; x = insert('a','b',-1); say 'insert(''a'',''b'',-1) ->' x; signal n13
e13: say 'insert(''a'',''b'',-1) ->' rc condition('o')~message
n13:
signal on syntax name e14; x = overlay('a','b',0); say 'overlay(''a'',''b'',0) ->' x; signal n14
e14: say 'overlay(''a'',''b'',0) ->' rc condition('o')~message
n14:
signal on syntax name e15; x = changestr('a','b','c',-1); say 'changestr(''a'',''b'',''c'',-1) ->' x; signal n15
e15: say 'changestr(''a'',''b'',''c'',-1) ->' rc condition('o')~message
n15:
signal on syntax name e16; x = countstr('a',1,'x'); say 'countstr(''a'',1,''x'') ->' x; signal n16
e16: say 'countstr(''a'',1,''x'') ->' rc condition('o')~message
n16:
signal on syntax name e17; x = wordpos('a','b',0); say 'wordpos(''a'',''b'',0) ->' x; signal n17
e17: say 'wordpos(''a'',''b'',0) ->' rc condition('o')~message
n17:
signal on syntax name e18; x = substr('a',0); say 'substr(''a'',0) ->' x; signal n18
e18: say 'substr(''a'',0) ->' rc condition('o')~message
n18:
signal on syntax name e19; x = left('a',-1); say 'left(''a'',-1) ->' x; signal n19
e19: say 'left(''a'',-1) ->' rc condition('o')~message
n19:
signal on syntax name e20; x = right('a',-1); say 'right(''a'',-1) ->' x; signal n20
e20: say 'right(''a'',-1) ->' rc condition('o')~message
n20:
signal on syntax name e21; x = copies('a',-1); say 'copies(''a'',-1) ->' x; signal n21
e21: say 'copies(''a'',-1) ->' rc condition('o')~message
n21:
signal on syntax name e22; x = center('a',5,'xy'); say 'center(''a'',5,''xy'') ->' x; signal n22
e22: say 'center(''a'',5,''xy'') ->' rc condition('o')~message
n22:
signal on syntax name e23; x = datatype('a','Q'); say 'datatype(''a'',''Q'') ->' x; signal n23
e23: say 'datatype(''a'',''Q'') ->' rc condition('o')~message
n23:
signal on syntax name e24; x = verify('a','b','Q'); say 'verify(''a'',''b'',''Q'') ->' x; signal n24
e24: say 'verify(''a'',''b'',''Q'') ->' rc condition('o')~message
n24:
signal on syntax name e25; x = translate('a',,,'xy'); say 'translate(''a'',,,''xy'') ->' x; signal n25
e25: say 'translate(''a'',,,''xy'') ->' rc condition('o')~message
n25:
signal on syntax name e26; x = x2d('g'); say 'x2d(''g'') ->' x; signal n26
e26: say 'x2d(''g'') ->' rc condition('o')~message
n26:
signal on syntax name e27; x = d2x(-1); say 'd2x(-1) ->' x; signal n27
e27: say 'd2x(-1) ->' rc condition('o')~message
n27:
signal on syntax name e28; x = d2c('a'); say 'd2c(''a'') ->' x; signal n28
e28: say 'd2c(''a'') ->' rc condition('o')~message
n28:
signal on syntax name e29; x = c2d('abcdefghijklmnopqrstu'); say 'c2d(''abcdefghijklmnopqrstu'') ->' x; signal n29
e29: say 'c2d(''abcdefghijklmnopqrstu'') ->' rc condition('o')~message
n29:
signal on syntax name e30; x = space('a b',-1); say 'space(''a b'',-1) ->' x; signal n30
e30: say 'space(''a b'',-1) ->' rc condition('o')~message
n30:
signal on syntax name e31; x = strip('a','Q'); say 'strip(''a'',''Q'') ->' x; signal n31
e31: say 'strip(''a'',''Q'') ->' rc condition('o')~message
n31:
signal on syntax name e32; x = subword('a',0); say 'subword(''a'',0) ->' x; signal n32
e32: say 'subword(''a'',0) ->' rc condition('o')~message
n32:
signal on syntax name e33; x = word('a',0); say 'word(''a'',0) ->' x; signal n33
e33: say 'word(''a'',0) ->' rc condition('o')~message
n33:
signal on syntax name e34; x = words(.nil); say 'words(.nil) ->' x; signal n34
e34: say 'words(.nil) ->' rc condition('o')~message
n34:
signal on syntax name e35; x = length(.object~new); say 'length(.object~new) ->' x; signal n35
e35: say 'length(.object~new) ->' rc condition('o')~message
n35:
signal on syntax name e36; x = reverse(.object~new); say 'reverse(.object~new) ->' x; signal n36
e36: say 'reverse(.object~new) ->' rc condition('o')~message
n36:
signal on syntax name e37; x = abbrev('a','b',-1); say 'abbrev(''a'',''b'',-1) ->' x; signal n37
e37: say 'abbrev(''a'',''b'',-1) ->' rc condition('o')~message
n37:
signal on syntax name e38; x = compare('a','b','xy'); say 'compare(''a'',''b'',''xy'') ->' x; signal n38
e38: say 'compare(''a'',''b'',''xy'') ->' rc condition('o')~message
n38:
signal on syntax name e39; x = delstr('a',0); say 'delstr(''a'',0) ->' x; signal n39
e39: say 'delstr(''a'',0) ->' rc condition('o')~message
n39:
signal on syntax name e40; x = delword('a',0); say 'delword(''a'',0) ->' x; signal n40
e40: say 'delword(''a'',0) ->' rc condition('o')~message
n40:
signal on syntax name e41; x = justify('a',-1); say 'justify(''a'',-1) ->' x; signal n41
e41: say 'justify(''a'',-1) ->' rc condition('o')~message
n41:
signal on syntax name e42; x = xrange('ab'); say 'xrange(''ab'') ->' x; signal n42
e42: say 'xrange(''ab'') ->' rc condition('o')~message
n42:
signal on syntax name e43; x = bitand('a','b','xy'); say 'bitand(''a'',''b'',''xy'') ->' x; signal n43
e43: say 'bitand(''a'',''b'',''xy'') ->' rc condition('o')~message
n43:
signal on syntax name e44; x = b2x('2'); say 'b2x(''2'') ->' x; signal n44
e44: say 'b2x(''2'') ->' rc condition('o')~message
n44:
signal on syntax name e45; x = x2b('g'); say 'x2b(''g'') ->' x; signal n45
e45: say 'x2b(''g'') ->' rc condition('o')~message
n45:
signal on syntax name e46; x = random(5,1); say 'random(5,1) ->' x; signal n46
e46: say 'random(5,1) ->' rc condition('o')~message
n46:
signal on syntax name e47; x = random('a'); say 'random(''a'') ->' x; signal n47
e47: say 'random(''a'') ->' rc condition('o')~message
n47:
signal on syntax name e48; x = lower('a',0); say 'lower(''a'',0) ->' x; signal n48
e48: say 'lower(''a'',0) ->' rc condition('o')~message
n48:
signal on syntax name e49; x = upper('a',1,-1); say 'upper(''a'',1,-1) ->' x; signal n49
e49: say 'upper(''a'',1,-1) ->' rc condition('o')~message
n49:
signal on syntax name e50; x = linein(,'x'); say 'linein(,''x'') ->' x; signal n50
e50: say 'linein(,''x'') ->' rc condition('o')~message
n50:
signal on syntax name e51; x = errortext(100); say 'errortext(100) ->' x; signal n51
e51: say 'errortext(100) ->' rc condition('o')~message
n51:
signal on syntax name e52; x = condition('Q'); say 'condition(''Q'') ->' x; signal n52
e52: say 'condition(''Q'') ->' rc condition('o')~message
n52:
signal on syntax name e53; x = arg(0); say 'arg(0) ->' x; signal n53
e53: say 'arg(0) ->' rc condition('o')~message
n53:
signal on syntax name e54; x = digits(1); say 'digits(1) ->' x; signal n54
e54: say 'digits(1) ->' rc condition('o')~message
n54:
signal on syntax name e55; x = date('Q'); say 'date(''Q'') ->' x; signal n55
e55: say 'date(''Q'') ->' rc condition('o')~message
n55:
signal on syntax name e56; x = time('Q'); say 'time(''Q'') ->' x; signal n56
e56: say 'time(''Q'') ->' rc condition('o')~message
n56:
signal on syntax name e57; x = sourceline(-1); say 'sourceline(-1) ->' x; signal n57
e57: say 'sourceline(-1) ->' rc condition('o')~message
n57:
signal on syntax name e58; x = value(1); say 'value(1) ->' x; signal n58
e58: say 'value(1) ->' rc condition('o')~message
n58:
signal on syntax name e59; x = round(1); say 'round(1) ->' x; signal n59
e59: say 'round(1) ->' rc condition('o')~message
n59:
signal on syntax name e60; x = chars(,'x'); say 'chars(,''x'') ->' x; signal n60
e60: say 'chars(,''x'') ->' rc condition('o')~message
n60:
signal on syntax name e61; x = x2c('g'); say 'x2c(''g'') ->' x; signal n61
e61: say 'x2c(''g'') ->' rc condition('o')~message
n61:
signal on syntax name e62; x = c2x(.object~new); say 'c2x(.object~new) ->' x; signal n62
e62: say 'c2x(.object~new) ->' rc condition('o')~message
n62:
signal on syntax name e63; x = d2x(1,-1); say 'd2x(1,-1) ->' x; signal n63
e63: say 'd2x(1,-1) ->' rc condition('o')~message
n63:
signal on syntax name e64; x = x2d('ff',-1); say 'x2d(''ff'',-1) ->' x; signal n64
e64: say 'x2d(''ff'',-1) ->' rc condition('o')~message
n64:
signal on syntax name e65; x = format(1,,,,-1); say 'format(1,,,,-1) ->' x; signal n65
e65: say 'format(1,,,,-1) ->' rc condition('o')~message
n65:
signal on syntax name e66; x = trunc(1e1000); say 'trunc(1e1000) ->' x; signal n66
e66: say 'trunc(1e1000) ->' rc condition('o')~message
n66:
signal on syntax name e67; x = abs(1e1000); say 'abs(1e1000) ->' x; signal n67
e67: say 'abs(1e1000) ->' rc condition('o')~message
n67:
signal on syntax name e68; x = max(); say 'max() ->' x; signal n68
e68: say 'max() ->' rc condition('o')~message
n68:
signal on syntax name e69; x = min(); say 'min() ->' x; signal n69
e69: say 'min() ->' rc condition('o')~message
n69:
exit
