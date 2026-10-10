::class PrivateBridge public
::method join
  return helperPrivate('red', 'blue')
::method constant
  return helperExplicit()
::routine helperPrivate private external "LIBRARY rx2cpp_private_test RX2CPP_PRIVATE_HELPERPRIVATE"
::routine helperExplicit private external "LIBRARY rx2cpp_private_test RX2CPP_PRIVATE_HELPEREXPLICIT"
