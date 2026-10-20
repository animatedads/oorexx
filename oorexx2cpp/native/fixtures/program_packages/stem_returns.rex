s. = mk()
say s.1 s.0
o = .holder~new
t. = o~get
say t.1 t.0
say o~local~class~id
u. = o~st.
say u.1 u.0
::routine mk public
  s.0 = 1; s.1 = 'routine stem'
  return s.
::class holder public
::attribute st. get
::method init
  expose st.
  st.0 = 1; st.1 = 'method stem'
::method get
  expose st.
  return st.
::method local
  q.1 = 'x'
  return q.
