#!/usr/bin/env parser3

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

  Sub mount module: ^c.test[/mount/1/to/two]
  Sub mount module: ^c.test[/mount/2/to/two/and/one/action]

  ^c.test[reverse]
  ^c.test[clients/reverse]
  ^c.test[mount/456/to/three/reverse]

  ^c.test[clients/mount2/reverse]
  ^c.test[clients/mount2/about]

  Global routing:
    clients index: ^c.clients.linkTo[::/edit;$.clientID[456]]
    mount action: ^c.mount.linkTo[::/action;$.var1[676] $.var2[345]]
    mount account: ^c.mount.linkTo[::/account;$.var1[676] $.var2[345] $.clientID[123]]
    mount account obj: ^c.mount.linkFor[::/account;$.var1[676] $.var2[345] $.clientID[123] $.empty[null]]

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
    $.templatePrefix[root]
  ]

  ^router.where[$.var2[\w+]]
  ^router.module[clients;testSubModule]
  ^router.module[mount;testSubMountModule;
    $.mountTo[mount/:var1/to/:var2]
    $.mountToWhere[$.var1[\d+]]
  ]
  ^router.assign[users/:userID;users]

@test[aAction]
  $lReq[^pfRequest::create[]]
  $result[^self.dispatch[$aAction;$lReq]]
  $result[$result.body]

@/[aRequest]
  $result[Index page]

@/reverse[aRequest]
  $result[Main module reverse...
    index: ^linkTo[/]
    action: ^linkTo[action/with/sub/uri]
    mount: ^linkTo[mount;$.var1[123] $.var2[test]]
    parent class: $self.PARENT.CLASS_NAME
    template prefix: $self.templatePrefix
  ]

@/NOTFOUND[aRequest]
  $result[Manager not found.]

@/users[aRequest]
  $result[User — $aRequest.userID]



@CLASS
testSubMountModule

@BASE
pfController

@OPTIONS
locals

@create[aOptions]
  ^BASE:create[$aOptions]
  ^router.assign[account/:clientID;account]

@/INDEX[aRequest]
  $result[Vars: $aRequest.var1, $aRequest.var2 Action — $self.action Prefix — $self.uriPrefix MountTo — $self.mountTo]

@/reverse[aRequest]
  $result[Sub mount module reverse...
    index: ^linkTo[/]
    action: ^linkTo[action/with/sub/uri]
    account: ^linkTo[account;$.clientID[123]]
    parent class: $self.PARENT.CLASS_NAME
    template prefix: $self.templatePrefix
  ]

@/NOTFOUND[aRequest]
  $result[Mount module not found. Vars: $aRequest.var1, $aRequest.var2 Action — $self.action Prefix — $self.uriPrefix MountTo — $self.mountTo]

@/about[aRequest]
  $result[Sub mount module about render — ^render[about.pt]]


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

  ^router.module[mount2;testSubMountModule]

  ^router.assign[/;call::root;$.as[root]]
  ^router.assign[about;$.render[about.pt];$.as[about]]
  ^router.assign[about2;$.render[$.template[about.pt] $.context[$.var[Temp var]] $.status[404] $.type[text]]]
  ^router.assign[:clientID/about;render::/about.pt]

  ^router.assign[:clientID/edit;call->edit;$.as[edit]]

  ^router.assign[:clientID/*trap;client]

@/[aRequest]
  $result[Sub module's Index page. Filter — $aRequest.filter]

@root[aRequest]
  $result[Sub module's Root page. Filter — $aRequest.filter]

@/reverse[aRequest]
  $result[Sub module reverse...
    index: ^linkTo[/]
    root: ^linkTo[root]
    action: ^linkTo[action/with/sub/uri]
    client: ^linkTo[client;$.clientID[234]]
    edit: ^linkTo[edit;$.clientID[234]]
    edit for: ^linkFor[edit;$.clientID[234] $.var[value]]
    template prefix: $self.templatePrefix
  ]

@/NOTFOUND[aRequest]
  $result[Sub module not found.]

@/client[aRequest]
  $result[Client page — $aRequest.clientID Trap — $aRequest.trap  Prefix — $self.uriPrefix Filter — $aRequest.filter]

@edit[aRequest]
  $result[Edit client page. clientID — $aRequest.clientID]
