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

  Sub module render 1: ^c.test[clients/about]
  Sub module render 2: ^c.test[clients/about2]
  Sub module render 3: ^c.test[clients/123/about]

  Sub module call: ^c.test[/clients/345/edit]

  Sub mount module: ^c.test[/mount/to/1/two]
  Sub mount module: ^c.test[/mount/to/2/two/and/one/action]

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
  ^BASE:create[
    $.templateFolder[assets/router/templates/]
  ]

  ^router.where[$.var2[\w+]]

  ^assignModule[clients;testSubModule]
  ^assignModule[mount;testSubMountModule;
    $.mountTo[mount/to/:var1/:var2]
    $.mountToWhere[$.var1[\d+]]
  ]
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
testSubMountModule

@BASE
pfController

@OPTIONS
locals

@create[aOptions]
  ^BASE:create[$aOptions]

@onINDEX[aRequest]
  $result[Vars: $aRequest.var1, $aRequest.var2 Action — $self.action Prefix — $self.uriPrefix MountTo — $self.mountTo]

@onNOTFOUND[aRequest]
  $result[Mount module not found. Vars: $aRequest.var1, $aRequest.var2 Action — $self.action Prefix — $self.uriPrefix MountTo — $self.mountTo ^json:string[$self.mountToWhere]]


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

  ^router.assign[about;$.render[about.pt]]
  ^router.assign[about2;$.render[$.template[about.pt] $.context[$.var[Temp var]]]]
  ^router.assign[:clientID/about;render::/about.pt]

  ^router.assign[:clientID/edit;call::edit]

  ^router.assign[:clientID/*trap;client]

@onINDEX[aRequest]
  $result[Sub module's Index page. Filter — $aRequest.filter]

@onNOTFOUND[aRequest]
  $result[Sub module not found.]

@onClient[aRequest]
  $result[Client page — $aRequest.clientID Trap — $aRequest.trap  Prefix — $self.uriPrefix Filter — $aRequest.filter]

@edit[aRequest]
  $result[Edit client page. clientID — $aRequest.clientID]
