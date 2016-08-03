#!../../../cgi-bin/parser3.cgi

@USE
pf2/lib/web/controllers.p

@main[][locals]
  Router tests...

  $c[^testController::create[]]

  Index: ^c.test[/]
  Not found: ^c.test[404]
  User page: ^c.test[users/123]

  Sub module index: ^c.test[clients]
  Sub module client page: ^c.test[clients/123]
  Sub module client page: ^c.test[clients/123/action/subaction]
  Invalid client page: ^c.test[clients/sumo/action/subaction]

  Finish tests.^#0A

@print_fields[aObj][locals]
  $f[^reflection:fields[$aObj]]
  ^f.foreach[k;v]{
    $k - $v.CLASS_NAME ^if($v is string){— $v}
  }



@CLASS
testController

@OPTIONS
locals

@BASE
pfController

@create[aOptions]
  ^BASE:create[$aOptions]

  ^assignModule[clients;testSubModule]
  ^router.assign[users/:userID;users]

@test[aAction]
  $lReq[^pfRequest::create[]]
  $result[^self.dispatch[$aAction;$lReq]]
  $result[$result.body]

@onINDEX[aRequest]
  $result[Index page]

@onNOTFOUND[aRequest]
  $result[Manager not found.]

@onUsers[aRequest]
  $result[User — $aRequest.userID]



@CLASS
testSubModule

@BASE
pfController

@OPTIONS
locals

@create[aOptions]
  ^BASE:create[$aOptions]

  ^router.where[$.clientID[\d+]]
  ^router.defaults[$.filter[by_client]]

  ^router.assign[:clientID/*trap;client]

@onINDEX[aRequest]
  $result[Sub module's Index page. Filter — $aRequest.filter]

@onNOTFOUND[aRequest]
  $result[Sub module not found.]

@onClient[aRequest]
  $result[Client page — $aRequest.clientID Trap — $aRequest.trap  Prefix — $self.uriPrefix Filter — $aRequest.filter]
