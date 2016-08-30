#!../../../cgi-bin/parser3.cgi

@USE
pf2/lib/web/controllers.p

@main[][locals]
  Controller tests...

  $tc[^testController::create[]]

  $r[^tc.run[]]
  index: $r.body

  $r[^tc.run[^myRequest::create[]]]
  index (cr): $r.body

  Finish tests.^#0A

@print_fields[aObj][locals]
  $f[^reflection:fields[$aObj]]
  ^f.foreach[k;v]{
    $k - $v.CLASS_NAME ^if($v is string){— $v}
  }


@CLASS
testController

@BASE
pfController

@create[aOptions]
  ^BASE:create[$aOptions]

@run[aRequest;aOptions]
  $result[^BASE:run[$aRequest;
    ^hash::create[$aOptions]
    $.returnResponse(true)
  ]]

@onINDEX[aRequest]
  request type — $aRequest.CLASS_NAME


@CLASS
myRequest

@BASE
pfRequest

@create[aOptions]
  ^BASE:create[$aOptions]
