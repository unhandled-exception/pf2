#!../../../cgi-bin/parser3.cgi

@USE
pf2/lib/web/controllers.p

@main[][locals]
  Controller tests...

  $tc[^testController::create[]]
  ^tc.run[^myRequest::create[]]

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

@onINDEX[aRequest]
  $aRequest.CLASS_NAME


@CLASS
myRequest

@BASE
pfRequest

@create[aOptions]
  ^BASE:create[$aOptions]
