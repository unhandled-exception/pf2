#!../../../cgi-bin/parser3.cgi

@USE
pf2/lib/web/controllers.p

@main[][locals]
  Controller tests...

  $tc[^testController::create[]]

  index: ^tc.run[;$.returnBody(true)]

  index (cr): ^tc.run[^myRequest::create[];$.returnBody(true)]

  paged: ^tc.run[^pfRequest::create[$.URI[/134]];$.returnBody(true)]

  pager index: ^tc.run[^pfRequest::create[$.URI[pager/]];$.returnBody(true)]

  pager page: ^tc.run[^pfRequest::create[$.URI[pager/567]];$.returnBody(true)]

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

  ^router.assign[pager/:page;pager;$.where[$.page[\d+]] $.as[paged]]
  ^router.assign[pager/;pager;$.as[paged]]

  ^router.assign[:page;/;$.where[$.page[\d+]] $.as[root]]
  ^router.assign[/;/;$.as[root]]

@run[aRequest;aOptions]
## aOptions.returnBody(false)
  $result[^BASE:run[$aRequest;
    ^hash::create[$aOptions]
    $.returnResponse(true)
  ]]
  ^if(^aOptions.returnBody.bool(false)){
    $result[$result.body]
  }

@/[aRequest]
  request type — $aRequest.CLASS_NAME
  action - "$aRequest.ACTION"
  path - "$aRequest.PATH"
  link to index — ^linkTo[root]
  link to page - ^linkTo[root/;$.page[567]], ^linkTo[root;$.page[678]]
  global link to page - ^linkTo[::root;$.page[4444]]
#   ^router.routes.foreach[k;v]{{$k, as: "$v.as", pattern: "$v.pattern", regexp: "$v.regexp"}}[,^#0A]

@/pager[aRequest]
  action — "$aRequest.ACTION", path — "$aRequest.path"
  page — "$aRequest.page"
  link to pager — ^linkTo[paged/], ^linkTo[pager]
  linkTo to pager page — ^linkTo[paged;$.page[789]], ^linkTo[pager;$.page[789]]

@/NOTFOUND[aRequest]
  Not found!
  action - "$aRequest.ACTION"
  path - "$aRequest.PATH"
  routes: ^router.routes.foreach[k;v]{{$k, $v.pattern, $v.regexp, "$v.as"}}[, ]


@CLASS
myRequest

@BASE
pfRequest

@create[aOptions]
  ^BASE:create[$aOptions]
