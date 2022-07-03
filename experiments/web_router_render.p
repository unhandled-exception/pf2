#!/usr/bin/env parser3

@USE
pf2/lib/web/controllers.p

@main[][locals]
  Router tests [render]...

  $c[^testController::create[]]
  linkTo /: ^c.linkTo[]
  linkTo bot: ^c.linkTo[bot]
  linkTo bot.pt: ^c.linkTo[bot.pt]
  linkTo fake/bot: ^c.linkTo[fake/bot]
  render /bot/: ^c.run[^pfRequest::create[$.URI[bot]];$.returnBody(true)]
  render /fake/bot/: ^c.run[^pfRequest::create[$.URI[fake/bot]];$.returnBody(true)]
  render /: ^c.run[^pfRequest::create[$.URI[/]];$.returnBody(true)]

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
    $.templatePrefix[render]
  ]

#   ^router.assign[/bot/][
#     $.render[
#       $.template[bot.pt]
#     ]
#   ]

  ^router.assign[/bot/;render::bot.pt]

@/NOTFOUND[aRequest]
  The page is not found.

@run[aRequest;aOptions]
## aOptions.returnBody(false)
  $result[^BASE:run[$aRequest;
    ^hash::create[$aOptions]
    $.returnResponse(true)
  ]]
  ^if(^aOptions.returnBody.bool(false)){
    $result[$result.body]
  }
