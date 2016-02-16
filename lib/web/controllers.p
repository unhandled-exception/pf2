# PF2 Library

@USE
pf2/lib/common.p
pf2/lib/web/templates.p

@CLASS
pfController

@BASE
pfClass

@OPTIONS
locals

@create[aOptions]
## aOptions.mountTo[/] - место монтирования. Нужно передавать только в головной модуль,
##                       поскольку метод assignModule будт вычислять точку монтирования самостоятельно.
## aOptions.parentModule - ссылка на объект-контейнер.
## aOptions.appendSlash(false) - нужно ли добавлять к урлам слеш.
## aOptions.router
## aOptions.rootController
## aOptions.parentController
## aOptions.template[]
## aOptions.templateFolder[]
## aOptions.templatePrefix[]

  ^cleanMethodArgument[]

  ^pfChainMixin:mixin[$self;
    ^hash::create[$aOptions]
    $.exportModulesProperty(true)
    $.exportFields[
      $.template[template]
      $.parentController[_parentController]
      $.rootController[_rootController]
    ]
  ]

  $self._exceptionPrefix[controller]
  $self._parentController[$aOptions.parent]
  $self._rootController[^ifdef[$aOptions.rootController]{$self}]

  $self.mountTo[^ifdef[^aOptions.mountTo.trim[end;/]]{/}]
  $self._appendSlash(^aOptions.appendSlash.bool(true))

  $self.uriPrefix[$self.mountTo]
  $self._localUriPrefix[]

  $self.template[^ifdef[$aOptions.template]{^pfTemplate::create[$.templateFolder[$aOptions.templateFolder]]}]
  $self._templatePrefix[^aOptions.templatePrefix.trim[both;/]]
  $self._templateVars[^hash::create[]]

  $self._defaultResponseType[html]

  $self.activeModule[]
  $self.action[]
  $self.request[]

  $self.router[$aOptions.router]
  ^if(!def $aOptions.router){
    $self.router[^pfRouter::create[]]
  }

  $self.MIDDLEWARE[^hash::create[]]

# Контролер становится рутовым, если вызвали метод run.
  $self.asRoot(false)

@auto[]
  $self.__pfController__[
    $.checkDotRegex[^regex::create[\.[^^/]+?/+^$][n]]
    $.repeatableSlashRegex[^regex::create[/+][g]]
  ]

@GET_PARENT[]
  $result[$self._parentController]

@GET_ROOT[]
  $result[$self._rootController]

@GET_uriPrefix[]
  $result[$self._uriPrefix]

@SET_uriPrefix[aUriPrefix]
  $self._uriPrefix[^aUriPrefix.trim[right;/.]/]
  $self._uriPrefix[^_uriPrefix.match[$__pfController__.repeatableSlashRegex][][/]]

@GET_localUriPrefix[]
  $result[$self._localUriPrefix]

@SET_localUriPrefix[aLocalUriPrefix]
  $self._localUriPrefix[^aLocalUriPrefix.trim[right;/]]
  $self._localUriPrefix[^_localUriPrefix.match[$__pfController__.repeatableSlashRegex][][/]]

@run[aRequest;aOptions] -> []
## Запускает процесс. Если вызван метод run, то модуль становится «менеджером».
  ^cleanMethodArgument[]
  $result[]
  $aRequest[^ifdef[$aRequest]{^pfRequest::create[]}]
  $self.asRoot(true)
  $lResponse[^self.dispatch[$aRequest.ACTION;$aRequest]]
  ^lResponse.apply[]

@assignModule[aName;aClassDef;aArgs] -> []
## aName — имя свойства со ссылкой на модуль.
## aClassDef[path/to/package.p@className::constructor]
## aArgs — параметры, которые передаются конструктору.
## aArgs.mountTo[$aName] - точка монтирования относительно текущего модуля.
  $result[]
  ^cleanMethodArgument[]
  $aName[^aName.trim[both;/]]

  ^self.__pfChainMixin__.assignModule[$aName;$aClassDef;$aArgs]
  $lModule[$MODULES.[$aName]]
  $lModule.mountTo[^if(def $aArgs.mountTo){^aArgs.mountTo.trim[both;/]}{$aName}]

  $lModule.args.mountTo[$self.mountTo/$lModule.mountTo]
  $lModule.args.templatePrefix[^ifdef[$lModule.args.templatePrefix]{$self._templatePrefix/$aName}]

@hasModule[aName]
## Проверяет есть ли у нас модуль с имененм aName
  $result(^self.MODULES.contains[$aName])

@hasAction[aAction][lHandler]
## Проверяем есть ли в модуле обработчик aAction
  $lHandler[^_makeActionName[$aAction]]
  $result($$lHandler is junction)

@assignMiddleware[aObject;aConstructorOptions] -> []
## aObject[class def|middleware object] — определение класса или вызов конструктора
## aConstructorOptions
  $result[]
  ^pfAssert:isTrue(def $aObject){A middleware object not defined.}
  ^if($aObject is string){
     $lMiddleware[^pfChainMixin:_parseClassDef[$aObject]]
     ^if(def $lMiddleware.package){
       ^use[$lMiddleware.package]
     }
     $lMiddleware[^reflection:create[$lMiddleware.className;$lMiddleware.constructor;$aConstructorOptions]]
  }{
     $lMiddleware[$aObject]
   }
  $self.MIDDLEWARE.[^eval($self.MIDDLEWARE + 1)][$lMiddleware]

@dispatch[aAction;aRequest;aOptions] -> [response]
## aOptions.prefix
  $result[]
  $self.action[$aAction]

  ^self.MIDDLEWARE.foreach[_;lMiddleware]{
    $result[^lMiddleware.processRequest[$aAction;$aRequest;$self;$aOptions]]
    ^if(def $result){$lStop(true)^break[]}
  }

  ^if(!def $result){
    $lResult[^self.processRequest[$self.action;$aRequest;$aOptions]]
    $result[$lResult.response]
  }

  ^if(!def $result){
    $self.action[$lResult.action]
    $self.request[$lResult.request]
    ^try{
      $result[^self.processAction[$self.action;$self.request;$lResult.prefix;$aOptions]]
      $result[^self.processResponse[$self.action;$self.request;$result;$aOptions]]
    }{
       $result[^self.processException[$self.action;$self.request;$exception;$aOptions]]
     }
    $lMiddlewareCount($self.MIDDLEWARE)
    ^for[i](1;$lMiddlewareCount){
      $lMiddleware[^self.MIDDLEWARE._at($lMiddlewareCount - $i)]
      $result[^lMiddleware.processResponse[$self.action;$self.request;$result;$self;$aOptions]]
    }
  }

@processRequest[aAction;aRequest;aOptions] -> [$.action[] $.request[] $.prefix[] $.response[]]
## Производит предобработку запроса
## $result[$.action[] $.request[] $.prefix[] $.render[]] - экшн, запрос, префикс, параметры шаблона, которые будут переданы обработчикам
  $lRewrite[^rewriteAction[$aAction;$aRequest;$aOptions]]
  $aAction[$lRewrite.action]
  ^if($lRewrite.args){
    ^aRequest.assign[$lRewrite.args]
  }
  $result[
    $.action[$aAction]
    $.request[$aRequest]
    $.prefix[$lRewrite.prefix]
    $.render[$lRewrite.render]
  ]

@rewriteAction[aAction;aRequest;aOptions]
## Вызывается каждый раз перед диспатчем - внутренний аналог mod_rewrite.
## $result.action - новый экшн.
## $result.args - параметры, которые надо добавить к аргументам и передать обработчику.
## $result.prefix - локальный префикс, который необходимо передать диспетчеру
## Стандартный обработчик проходит по карте преобразований и ищет подходящий шаблон,
## иначе возвращает оригинальный экшн.
  $result[^router.route[$aAction;$.args[$aRequest]]]
  ^if(!$result){
    $result[$.action[$aAction] $.args[] $.prefix[]]
  }
  ^if(!def $result.args){$result.args[^hash::create[]]}

@processAction[aAction;aRequest;aLocalPrefix;aOptions] -> [response]
#  $result[^pfResponse::create[Action create!]]

## Производит вызов экшна.
## aOptions.prefix - префикс, сформированный в processRequest.
  $lAction[$aAction]
  $lRequest[$aRequest]
  ^if(def $aLocalPrefix){$self.localUriPrefix[$aLocalPrefix]}
  ^if(def $aOptions.prefix){$self.uriPrefix[$aOptions.prefix]}

# Если у нас в первой части экшна имя модуля, то передаем управление ему
  $lModule[^self._findModule[$aAction]]
  ^if(def $lModule){
#   Если у нас есть экшн, совпадающий с именем модуля, то зовем его.
#   При этом отсекая имя модуля от экшна перед вызовом (восстанавливаем после экшна).
    $self.activeModule[$lModule.name]
    $lModuleMountTo[$lModule.mountTo]

    ^if(^self.hasAction[$lModuleMountTo]){
      $self.action[^lAction.match[^^^taint[regex][$lModuleMountTo] (.*)][x]{^match.1.lower[]}]
      $result[^self.[^self._makeActionName[$lModuleMountTo]][$lRequest]]
      $self.action[$lAction]
    }{
       $result[^self.[$lModule.name].dispatch[^lAction.mid(^lModuleMountTo.length[]);$lRequest;
         $.prefix[$uriPrefix/^if(def $aLocalPrefix){$aLocalPrefix/}{$lModuleMountTo/}]
       ]]
     }
  }{
#    Если модуля нет, то пытаемся найти и запустить экш из нашего модуля
     $lHandler[^self._findHandler[$lAction;$lRequest]]
     ^if(def $lHandler){
       $result[^self.[$lHandler][$lRequest]]
     }{
        ^self.abort(404)[Action "$lAction" not found.]
      }
   }

@processException[aAction;aRequest;aException;aOptions] -> [response]
## Обрабатывает исключительную ситуацию, возникшую в обработчике.
## aOptions.passProcessResponse(false)
  $result[]
  $lProcessed(false)
  ^switch[$aException.type]{
    ^case[http.404]{
      ^if($self.onNOTFOUND is junction){
        $result[^onNOTFOUND[$aRequest]]
        $lProcessed(true)
      }
    }
    ^case[http.301]{
      $result[^pfResponseRedirect::create[$aException.source;301]]
      $lProcessed(true)
    }
    ^case[http.302]{
      $result[^pfResponseRedirect::create[$aException.source]]
      $lProcessed(true)
    }
  }

  ^if($lProcessed){
    $aException.handled(true)
    ^if(!^aOptions.passProcessResponse.bool(false)){
      $result[^self.processResponse[$aAction;$aRequest;$result;$aOptions]]
    }
  }

@processResponse[aAction;aRequest;aResponse;aOptions] -> [response]
## aOptions.passPost(false) - не делать постобработку запроса.
## aOptions.passWrap(false) - не формировать объект вокруг ответа из строк и чисел.
  $result[$aResponse]
  ^if(!^aOptions.passWrap.bool(false)){
    ^switch(true){
      ^case($result is hash){
        $result.type[^ifdef[$result.type]{$self._defaultResponseType}]
        $result[^pfResponse::create[$result.body;$result]]
      }
      ^case($result is string || $result is double || $result is int){
        $result[^pfResponse::create[$result;$.type[$self._defaultResponseType]]]
      }
    }
  }
  ^if(!^aOptions.passPost.bool(false)){
    $lPostDispatch[post^result.type.upper[]]
    ^if($self.[$lPostDispatch] is junction){
      $result[^self.[$lPostDispatch][$result]]
    }{
       ^if($self.postDEFAULT is junction){
         $result[^self.postDEFAULT[$result]]
       }
     }
  }

@render[aTemplateName;aContext]
## Вызывает шаблон с именем "путь/$aTemplateName[.pt]"
## Если aTemplateName начинается со "/", то не подставляем текущий перфикс.
## Если переменная aTemplateName не задана, то зовем шаблон default.
## aContext - переменные, которые добавляются к тем, что уже заданы через assignVar.
  $lVars[^hash::create[$self._templateVars]]
  ^lVars.add[$aContext]
  ^if(!^lVars.contains[REQUEST]){$lVars.REQUEST[$self.request]}
  ^if(!^lVars.contains[ACTION]){$lVars.ACTION[$self.action]}
  ^if(!^lVars.contains[PARENT]){$lVars.PARENT[$self.PARENT]}
  ^if(!^lVars.contains[ROOT]){$lVars.ROOT[$self.ROOT]}
  ^if(!^lVars.contains[linkTo]){$lVars.linkTo[$self.linkTo]}
  ^if(!^lVars.contains[redirectTo]){$lVars.redirectTo[$self.redirectTo]}
  ^if(!^lVars.contains[linkFor]){$lVars.linkFor[$self.linkFor]}
  ^if(!^lVars.contains[redirectFor]){$lVars.redirectFor[$self.redirectFor]}
  $result[^self.template.render[$self._templatePrefix/$aTemplateName;$.vars[$lVars]]]

@abort[aStatus;aData]
  ^throw[http.^aStatus.int(500);$aData]

@linkTo[aAction;aOptions;aAnchor][locals]
## Формирует ссылку на экшн, выполняя бэкрезолв путей.
## aOptions - объект, который поддерживает свойство $aOptions.fields (хеш, таблица и пр.)
  ^cleanMethodArgument[]
  $aAction[^aAction.trim[both;/]]
  $lReverse[^router.reverse[$aAction;$aOptions.fields]]
  ^if($lReverse){
    $result[^_makeLinkURI[$lReverse.path;$lReverse.args;$aAnchor;$lReverse.reversePrefix]]
  }(^MODULES.contains[$aAction]){
    $result[^_makeLinkURI[$MODULES.[$aAction].mountTo;$aOptions.fields;$aAnchor]]
  }{
    $result[^_makeLinkURI[$aAction;$aOptions.fields;$aAnchor]]
   }

@linkFor[aAction;aObject;aOptions][locals]
## Формирует ссылку на объект.
## aObject[<hash>]
## aOptions.form — поля, которые надо добавить к объекту/маршруту
## aOptions.anchor — «якорь»
  ^cleanMethodArgument[]
  $lReverse[^router.reverse[$aAction;$aObject;$.form[$aOptions.form] $.onlyPatternVars(true)]]
  ^if($lReverse){
    $result[^_makeLinkURI[$lReverse.path;$lReverse.args;$aOptions.anchor;$lReverse.reversePrefix]]
  }(^MODULES.contains[$aAction]){
    $result[^_makeLinkURI[$MODULES.[$aAction].mountTo;$aOptions.form;$aAnchor]]
  }{
    $result[^_makeLinkURI[$aAction;$aOptions.form;$aAnchor]]
   }

@redirect[aURL;aStatus]
  ^self.abort(^aStatus.int(302))[$aURL]

@redirectTo[aAction;aOptions;aAnchor]
  ^self.abort(302)[^self.linkTo[$aAction;$aOptions;$aAnchor]]

@redirectFor[aAction;aObject;aOptions]
  ^self.abort[http.302;^self.linkFor[$aAction;$aOptions;$aAnchor]]

@assignVar[aName;aValue]
  $result[]
  $self._templateVars.[$aName][$aValue]

@assignVars[aVars]
  $result[]
  $aVars[^hash::create[$aVars]]
  ^aVars.foreach[k;v]{
    $self._templateVars.[$k][$v]
  }

#@onINDEX[aRequest] -> [response] или ^router.root[$index]
#@onAction[aRequest] -> [response] или ^router.assign[action;$actionHandler;$.strict(true)]
#@onNOTFOUND[aRequest] -> [response]

#@postDEFAULT[aResponse] -> [response]
#@postHTML[aResponse] -> [response]

@onINDEX[aRequest]
  ^throw[${_exceptionPrefix}.index.not.implemented;An onINDEX method is not implemented in the ${self.CLASS_NAME} class.]

#----- Private -----

@_makeLinkURI[aAction;aOptions;aAnchor;aPrefix]
## Формирует url для экшна
## $uriPrefix$aAction?aOptions.foreach[key=value][&]#aAnchor
  ^cleanMethodArgument[]
  ^if(def $aAction){$aAction[^aAction.trim[both;/.]]}

  $result[${uriPrefix}^if(def $aPrefix){^aPrefix.trim[both;/]/}{^if(def $localUriPrefix){$localUriPrefix/}}^if(def $aAction){^taint[uri][$aAction]^if($self._appendSlash){/}}]
  ^if($self._appendSlash && def $result && ^result.match[$__pfController__.checkDotRegex]){$result[^result.trim[end;/]]}

  ^if($aOptions is hash && $aOptions){
    $result[${result}?^aOptions.foreach[key;value]{$key=^taint[uri][$value]}[^taint[&]]]
  }

@_makeActionName[aAction][lSplitted;lFirst]
## Формирует имя метода для экшна.
  ^if(def $aAction){
    $aAction[^aAction.lower[]]
    $lSplitted[^pfString:rsplit[$aAction;[/\.]]]
    ^if($lSplitted){
     $result[on^lSplitted.menu{^_makeSpecialName[$lSplitted.piece]}]
   }
  }{
     $result[onINDEX]
   }

@_makeSpecialName[aStr][lFirst]
## Возвращает aStr в которой первая буква прописная
  $lFirst[^aStr.left(1)]
  $result[^lFirst.upper[]^aStr.mid(1)]

@_findModule[aAction][k;v]
## Ищет модуль по имени экшна
  $result[]
  ^if(def $aAction){
    ^MODULES.foreach[k;v]{
      ^if(^aAction.match[^^^taint[regex][$v.mountTo] (/|^$)][ixn]){
        $result[$v]
        ^break[]
      }
    }
  }

@_findHandler[aAction;aRequest]
## Ищет и возвращает имя функции-обработчика для экшна.
  $result[^_makeActionName[$aAction]]
  ^if(!def $result || !($self.[$result] is junction)){
    $result[^if($onDEFAULT is junction){onDEFAULT}]
  }

# Ищем onActionHTTPMETHOD-обработчик
  $lMethod[^if(def $aRequest.METHOD){^aRequest.METHOD.upper[]}]
  ^if(def $lMethod){
    $lActionName[^_makeActionName[$aAction]]
    ^if(def $lActionName && $self.[${lActionName}$lMethod] is junction){$result[${lActionName}$lMethod]}
  }

#--------------------------------------------------------------------------------------------------

@CLASS
pfRequest

## Собирает в одном объекте все параметры http-запроса, доступные в Пасрере.

@create[aOptions][ifdef]
## aOptions — хеш с переменными объекта, которые надо заменить. [Для тестов.]
  $ifdef[$pfClass:ifdef]
  $__CONTEXT__[^hash::create[]]

  $form[^ifdef[$aOptions.form]{$form:fields}]
  $tables[^ifdef[$aOptions.tables]{$form:tables}]
  $files[^ifdef[$aOptions.files]{$form:files}]

  $cookie[^ifdef[$aOptions.cookie]{$cookie:fields}]
  $headers[^ifdef[$aOptions.headers]{$request:headers}]

  $method[^ifdef[^aOptions.method.lower[]]{^request:method.lower[]}]
# Если нам пришел post-запрос с полем _method, то берем method из запроса.
  ^if($method eq "post" && def $form._method){
    $method[^switch[^form._method.lower[]]{
      ^case[DEFAULT]{post}
      ^case[put]{put}
      ^case[delete]{delete}
      ^case[patch]{patch}
    }]
  }

  $ENV[^ifdef[$aOptions.ENV]{$env:fields}]

  $URI[^ifdef[$aOptions.URI]{$request:uri}]
  $QUERY[^ifdef[$aOptions.QUERY]{$request:query}]
  $PATH[^URI.left(^URI.pos[?])]

  $ACTION[^ifdef[$aOptions.ACTION]{^ifdef[$form.action]{$form._action}}]

  $PORT[^ifdef[$aOptions.PORT]{^ENV.SERVER_PORT.int(80)}]
  $isSECURE(^ifdef[$aOptions.isSECURE](^ENV.HTTPS.lower[] eq "on" || $PORT eq "443"))
  $SCHEME[http^if($isSECURE){s}]

  $HOST[^ifdef[$aOptions.HOST]{^header[X-Forwarded-Host;^header[Host;$ENV.SERVER_NAME]]}]
  $HOST[$HOST^if($PORT ne "80" && ($isSECURE && $PORT ne "443")){:$PORT}]

  $REMOTE_IP[^ifdef[$aOptions.REMOTE_IP]{$ENV.REMOTE_ADDR}]
  $DOCUMENT_ROOT[^ifdef[$aOptions.DOCUMENT_ROOT]{$request:document-root}]

  $CHARSET[^ifdef[$aOptions.CHARSET]{$request:charset}]
  $RESPONSE_CHARSET[^ifdef[$aOptions.RESPONSE_CHARSET]{^response:charset.lower[]}]
  $POST_CHARSET[^ifdef[$aOptions.POST_CHARSET]{^request:post-charset.lower[]}]
  $BODY_CHARSET[^ifdef[$aOptions.BODY_CHARSET]{^request:body-charset.lower[]}]

  $BODY[^ifdef[$aOptions.BODY]{$request:body}]
  $_BODY_FILE[$aOptions.BODY_FILE]

@GET[aContext]
  $result($form || $__CONTEXT__)

@GET_DEFAULT[aName]
  $result[^if(^__CONTEXT__.contains[$aName]){$__CONTEXT__.[$aName]}{$form.[$aName]}]

@GET_BODY_FILE[]
  $result[^if(def $_BODY_FILE){$_BODY_FILE}{$request:body-file}]

@GET_isAJAX[]
  $result(^ifdef[$aOptions.isAJAX](^headers.[X_REQUESTED_WITH].pos[XMLHttpRequest] > -1))

@GET_clientAcceptsJSON[]
  $result(^headers.ACCEPT.pos[application/json] >= 0)

@GET_clientAcceptsXML[]
  $result(^headers.ACCEPT.pos[application/xml] >= 0)

@GET_isGET[]
  $result($method eq "get")

@GET_isPOST[]
  $result($method eq "post")

@GET_isPUT[]
  $result($method eq "put")

@GET_isDELETE[]
  $result($method eq "delete")

@GET_isPATCH[]
  $result($method eq "patch")

@GET_isHEAD[]
  $result($method eq "head")

@assign[*aArgs]
## Добавляет в запрос поля.
## ^assign[name;value]
## ^assign[$.name[value] ...]
  ^if($aArgs.0 is hash){
    ^__CONTEXT__.add[$aArgs.0]
  }{
     $__CONTEXT__.[$aArgs.0][$aArgs.1]
   }

@contains[aName]
  $result(^__CONTEXT__.contains[$aName] || ^form.contains[$aName])

@foreach[aKeyName;aValueName;aCode;aSeparator][locals]
  $lFields[^hash::create[$form]]
  ^lFields.add[$__CONTEXT__]
  $result[^lFields.foreach[k;v]{$caller.[$aKeyName][$k]$caller.[$aValueName][$v]$aCode}{$aSeparator}]

@header[aHeaderName;aDefaultValue][CONTEXT]
## Возвращает заголовок запроса.
## aDefaultValue — результат функции, если заголовок не определен.
  $lName[^aHeaderName.trim[both; :]]
  $lName[^lName.replace[-;_]]
  $lName[^lName.replace[ ;_]]
  $result[$headers.[^lName.upper[]]]
  ^if(!def $result){
    $result[$aDefaultValue]
  }

@absoluteURL[aLocation]
## Возвращает полный url для запроса.
## aLocation — адрес страницы вместо URI.
  $aLocation[^pfClass:ifdef[$aLocation]{$URI}]
  ^if(^aLocation.left(1) ne "/"){
    $aLocation[/$aLocation]
  }
  $result[${SCHEME}://${HOST}$aLocation]

#--------------------------------------------------------------------------------------------------


@CLASS
pfResponse

## Класс с http-ответом.

@BASE
pfClass

@OPTIONS
locals

@create[aBody;aOptions]
## aBody
## aOptions.type[html] - тип ответа
## aOptions.status(200) - http-статус
## aOptions.contentType[]
## aOptions.charset[]
## aOptions.canDownload(false)
## aOptions.headers[]
## aOptions.cookie[]
  ^cleanMethodArgument[]

  $self._body[$aBody]
  $self._download[]

  $self._type[^ifdef[$aOptions.type]{html}]

  $self.contentType[^ifdef[$aOptions.contentType]]
  $self.status(^ifdef[$aOptions.status]{200})
  $self.charset[^ifdef[$aOptions.charset]{$response:charset}]

  $self.headers[^hash::create[]]
  $self.cookie[^hash::create[]]

@GET_type[]
  $result[$self._type]

@SET_type[aType]
  $self._type[$aType]

@GET_body[]
  $result[$self._body]

@SET_body[aBody]
  $self._body[$aBody]

@GET_download[]
  $result[$self._download]

@SET_download[aDownload]
  $self._download[$aDownload]

@apply[aOptions] -> []
## Записывает ответ в переменные Парсера
  $result[]
  ^self._applyHeaders[]
  ^self._applyBody[]

@_applyBody[]
  $result[]
  ^if(def $self.download){
    $response:download[$self.download]
  }{
     $response:body[$self.body]
   }

@_applyHeaders[]
  $result[]
  ^self.headers.foreach[k;v]{
    $response:$k[$v]
  }
  ^self.cookie.foreach[k;v]{
    $cookie:$k[$v]
  }
  $response:status[$self.status]

  ^if(def $self.charset){$response:charset[$self.charset]}
  $response:content-type[
    $.value[^ifdef[$self.contentType]{text/html}]
    $.charset[$response:charset]
  ]

#--------------------------------------------------------------------------------------------------

@CLASS
pfResponseRedirect

@BASE
pfResponse

@create[aLocation;aStatus]
## aPath - полный путь для редиректа или uri
## aStatus[302]
  ^BASE:create[;$.type[redirect] $.status[^ifdef[$aStatus]{302}]]
  $self.headers.location[^untaint{$aLocation}]

#--------------------------------------------------------------------------------------------------

@CLASS
pfRouter

## Модуль для преобразования url'ов. Реализует микроязык для поиска переменных в строках запроса.

@BASE
pfClass

@create[aOptions]
  ^cleanMethodArgument[]
  ^BASE:create[]

  $_routes[^hash::create[]]
  $_segmentSeparators[\./]
  $_varRegexp[[^^$_segmentSeparators]+]
  $_trapRegexp[(.*)]

  $_rootRoute[]
  ^root[]

@auto[]
  $_pfRouterPatternVar[([:\*])\{?([\p{L}\p{Nd}_\-]+)\}?]
  $_pfRouterPatternRegex[^regex::create[$_pfRouterPatternVar][g]]
  $_pfRouteRootRegex[^regex::create[^^^$]]

@assign[aPattern;aRouteTo;aOptions][locals]
## Добавляет новый шаблон aPattern в список маршрутов
## aRouteTo - новый маршрут (может содержать переменные)
## aOptions.defaults[] - хеш со значениями переменных шаблона "по-умолчанию"
## aOptions.requirements[] - хеш с регулярными выражениями для проверки переменных шаблона
## aOptions.prefix[] - дополнительный, вычисляемый префикс для путей (может содержать переменные)
## aOptions.reversePrefix[] - префикс маршрута при бэкрезолве
## aOptions.name[] - имя шаблона (используется в reverse, нечувствительно к регистру)
## aOptions.ignoreCase(true) - игнорироавть регистр букв при обработке шаблона
## aOptions.strict(false) - включает "строгий" режим проверки шаблона.
## aOptions.render[$.name $.template] - хеш с параметрами шаблона, который надо выполнить.
  ^cleanMethodArgument[]
  $result[]

  ^if(!def $aOptions.defaults){$aOptions.defaults[^hash::create[]]}
  ^if(!def $aOptions.requirements){$aOptions.requirements[^hash::create[]]}

  $lCompiledPattern[^_compilePattern[$aPattern;$aOptions]]
  $_routes.[^eval($_routes + 1)][
    $.pattern[$lCompiledPattern.pattern]
    $.regexp[^regex::create[$lCompiledPattern.regexp][^if(^aOptions.ignoreCase.bool(true)){i}]]
    $.ignoreCase(^aOptions.ignoreCase.bool(true))
    $.vars[$lCompiledPattern.vars]
    $.trap[$lCompiledPattern.trap]

    $.routeTo[^_trimPath[$aRouteTo]]
    $.prefix[$aOptions.prefix]
    $.reversePrefix[$aOptions.reversePrefix]

    $.defaults[$aOptions.defaults]
    $.requirements[$aOptions.requirements]
    $.name[^if(def $aOptions.name){^aOptions.name.lower[]}]
    $.strict(^aOptions.strict.bool(false))
    $.render[$aOptions.render]
  ]

@root[aRouteTo;aOptions]
## Добавляет действие для пустого роута
## aRouteTo - новый маршрут (может содержать переменные)
## aOptions.defaults[] - хеш со значениями переменных шаблона "по-умолчанию"
## aOptions.prefix[] - дополнительный, вычисляемый префикс для путей (может содержать переменные)
## aOptions.render[$.template $.vars] - хеш с параметрами шаблона, который надо выполнить.
  ^cleanMethodArgument[]
  ^if(!def $aOptions.defaults){$aOptions.defaults[^hash::create[]]}
  ^if(!def $aOptions.requirements){$aOptions.requirements[^hash::create[]]}
  $_rootRoute[
    $.routeTo[^_trimPath[$aRouteTo]]
    $.prefix[^if(def $aOptions.prefix){$aOptions.prefix}{^_trimPath[$aRouteTo]}]
    $.defaults[$aOptions.defaults]
    $.regexp[$_pfRouteRootRegex]
    $.vars[^table::create{var}]
    $.render[$aOptions.render]
  ]

@route[aPath;aOptions][locals]
## Выполняет поиск и преобразование пути по списку маршрутов
## aOptions.args
## result[$.action $.args $.prefix $.render]
  ^cleanMethodArgument[]
  $result[^hash::create[]]
  $aPath[^_trimPath[$aPath]]
  ^if(def $aPath){
    ^_routes.foreach[k;it]{
      $lParsedPath[^_parsePathByRoute[$aPath;$it;$.args[$aOptions.args]]]
      ^if($lParsedPath){
        $result[$lParsedPath]
        ^break[]
      }
    }
  }{
     $result[^_parsePathByRoute[$aPath;$_rootRoute;$.args[$aOptions.args]]]
   }

@reverse[aAction;aArgs;aOptions][locals]
## aAction — имя экшна или роута
## aArgs — хеш с параметрами для преобразования
## aOptions.form — дополнительные параметры для маршрута
## aOptions.onlyPatternVars(false) — использовать только те переменные из aArgs, которые определены в маршруте или aOptions.form
## result[$.path[] $.prefix[] $.reversePrefix[] $.args[]] — если ничего не нашли, возвращаем пустой хеш
  ^cleanMethodArgument[]
  $result[^hash::create[]]
  $lOnlyPatternsVar(^aOptions.onlyPatternVars.bool(false))

  $aAction[^_trimPath[$aAction]]
  $aArgs[^if($aArgs is table){$aArgs.fields}{^hash::create[$aArgs]}]
  ^aArgs.add[$aOptions.form]
  ^_routes.foreach[k;it]{
#   Ищем подходящий маршрут по action (если в routeTo содержатся переменные, то лучше использовать name для маршрута)
    ^if((def $it.name && $aAction eq $it.name) || $aAction eq $it.routeTo){
      $lPath[^_applyPath[$it.pattern;$aArgs]]
#     Проверяем соотвтетствует ли полученный путь шаблоу (с ограничениями requirements)
      ^if(^lPath.match[$it.regexp]){
#       Добавляем оставшиеся параметры из aArgs или aOptions.form в result.args
        $result.path[$lPath]
        $result.prefix[^_applyPath[$it.prefix;$aArgs]]
        $result.reversePrefix[^_applyPath[$it.reversePrefix;$aArgs]]
        ^if($lOnlyPatternsVar){
          $result.args[^hash::create[$aOptions.form]]
        }{
           $result.args[$aArgs]
         }
        ^result.args.sub[$it.vars]
        ^break[]
      }
    }
  }

  ^if(!$result && $aAction eq $_rootRoute.routeTo){
#   Если не нашли реверс, то проверяем рутовый маршрут
    $result.path[]
    $result.prefix[^_applyPath[$_rootRoute.prefix;$aArgs]]
    $result.args[$aArgs]
  }

@_trimPath[aPath]
  $result[^if(def $aPath){^aPath.trim[both;/. ^#0A]}]

@_compilePattern[aRoute;aOptions][locals]
## result[$.pattern[] $.regexp[] $.vars[] $.trap[]]
  $result[
    $.vars[^hash::create[]]
    $.pattern[^_trimPath[$aRoute]]
    $.trap[]
  ]
  $lPattern[^untaint[regex]{/$result.pattern}]

# Разбиваем шаблон на сегменты и компилируем их в регулярные выражения
  $lSegments[^hash::create[]]
  $lParts[^lPattern.match[([$_segmentSeparators])([^^$_segmentSeparators]+)][g]]
  ^lParts.menu{
     $lHasVars(false)
     $lHasTrap(false)
     $lRegexp[^lParts.2.match[$_pfRouterPatternRegex][]{^if($match.1 eq ":"){(^if(def $aOptions.requirements.[$match.2]){^aOptions.requirements.[$match.2].match[\((?!\?[=!<>])][g]{(?:}}{$_varRegexp})}{$_trapRegexp}^if($match.1 eq "*"){$result.trap[$match.2]$lHasTrap(true)}$result.vars.[$match.2](true)$lHasVars(true)}]
     $lSegments.[^eval($lSegments + 1)][
       $.prefix[$lParts.1]
       $.regexp[$lRegexp]
       $.hasVars($lHasVars)
       $.hasTrap($lHasTrap)
     ]
  }

# Собираем регулярное выражение для всего шаблона.
# Закрывающие скобки ставим в обратном порядке. :)
  $result.regexp[^^^lSegments.foreach[k;it]{^if($it.hasVars){(?:}^if($k>1){\$it.prefix}$it.regexp}^for[i](1;$lSegments){$it[^lSegments._at(-$i)]^if($it.hasVars){)^if(!$aOptions.strict || $it.hasTrap){?}}}^$]

@_parsePathByRoute[aPath;aRoute;aOptions][locals]
## Преобразует aPath по правилу aOptions.
## aOptions.args
## result[$.action $.args $.prefix]
  $result[^hash::create[]]
  $lVars[^aPath.match[$aRoute.regexp]]
  ^if($lVars){
    $result.args[^hash::create[$aRoute.defaults]]
    ^if($aRoute.vars){
      $i(1)
      ^aRoute.vars.foreach[k;v]{
        ^if(def $lVars.$i){
          $result.args.[$k][$lVars.$i]
        }
        ^i.inc[]
      }
    }
    $result.action[^_applyPath[$aRoute.routeTo;$result.args;$aOptions.args]]
    $result.prefix[^_applyPath[$aRoute.prefix;$result.args;$aOptions.args]]
    $result.render[$aRoute.render]
  }

@_applyPath[aPath;aVars;aArgs]
## Заменяет переменные в aPath. Значения переменных ищутся в aVars и aArgs.
  ^cleanMethodArgument[aVars]
  ^cleanMethodArgument[aArgs]
  $result[^if(def $aPath){^aPath.match[$_pfRouterPatternRegex][]{^if(^aVars.contains[$match.2]){$aVars.[$match.2]}{^if(^aArgs.contains[$match.2] || $match.1 eq "*"){$aArgs.[$match.2]}}}}]

#--------------------------------------------------------------------------------------------------

@CLASS
pfMiddleware

## Базовый предок для классов мидлваре. Показывает какой интерфейс должен быть у мидлваре.
## Методы process* надо реализовывать только если классу надо встроиться в конкретный этап обработки запросов.
##
## Мидлваре в контролере образуют цепочку. Запрос проходит методы processRequest в порядке добавления мидлваре,
## а processResponse в обратном порядке.

@BASE
pfClass

@OPTIONS
locals

@create[aOptions]

@processRequest[aAction;aRequest;aController;aProcessOptions] -> [response|null]
# если ничего не возвращает, то продолжаем обработку, если возвращает pfResponse, то прерываем обработку и не зовем другие middleware.
  $result[]

@processResponse[aAction;aRequest;aResponse;aController;aProcessOptions] -> [response]
# возвращает respone
  $result[$aResponse]
