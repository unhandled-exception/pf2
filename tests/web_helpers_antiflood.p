#!../../../cgi-bin/parser3.cgi

@USE
pf2/lib/web/helpers/antiflood.p

@main[][locals]
Web antiflood test.

  $hf[assets/web/antiflood/af]
  ^try{
    $af[^pfAntiFlood::create[
      $.path[$hf]
    ]]
    $tok[^af.storage.generateToken[]]
    token: $tok
    ^af.field[$tok]

    ^af.process[$.form_token[$tok]]{
    	Valid token!
    }

  }{}{
    ^if(-f "${hf}.dir"){^file:delete[${hf}.dir]}
    ^if(-f "${hf}.pag"){^file:delete[${hf}.pag]}
  }
Finish tests.^#0A

