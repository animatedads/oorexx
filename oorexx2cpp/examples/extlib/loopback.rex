/* TCP loopback through rxsock: stems and result variables are addressed BY NAME in the caller's pool */
s = SockSocket('AF_INET','SOCK_STREAM',0)
say 'setopt' SockSetSockOpt(s,'SOL_SOCKET','SO_REUSEADDR',1)
a.family = 'AF_INET'; a.address = '127.0.0.1'; a.port = 0
say 'bind' SockBind(s,'a.')
say 'listen' SockListen(s,3)
say 'getsockname' SockGetSockName(s,'n.') n.family n.addr (n.port > 0)
c = SockSocket('AF_INET','SOCK_STREAM',0)
say 'connect' SockConnect(c,'n.')
a2 = SockAccept(s,'peer.')
say 'accept>0' (a2 > 0) peer.family peer.addr
say 'send' SockSend(c,'hello world')
say 'recv' SockRecv(a2,'xxx',100) '['xxx']'
say 'send2' SockSend(a2,'pong')
say 'recv2' SockRecv(c,'yyy',100) '['yyy']'
say 'getsockopt' SockGetSockOpt(s,'SOL_SOCKET','SO_REUSEADDR','val') val
say 'peername' SockGetPeerName(c,'pn.') pn.addr
say 'select' SockSelect('r.','','','0.01')
say 'close' SockClose(c) SockClose(a2) SockClose(s)
say 'byname' SockGetHostByName('localhost','h.') h.addr h.name
exit
::requires 'rxsock' LIBRARY
