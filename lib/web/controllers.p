# PF2 Library

@USE
pf2/lib/common.p
pf2/lib/web/templates.p

@CLASS
pfController

@OPTIONS
locals

@BASE
pfClass

@create[aOptions]
## aOptions.mountTo[/] — место монтирования. Вручную надо передавать только для рутового модуля, если он смонтирован не в корень сайта.
## aOptions.mountToWhere
## aOptions.parentModule — ссылка на объект-контейнер.
## aOptions.appendSlash(true) — нужно ли добавлять к урлам слеш.
## aOptions.router
## aOptions.rootController
## aOptions.parentController
## aOptions.template[]
## aOptions.templateFolder[]
## aOptions.templatePrefix[]
## aOptions.request — объект запроса, если мы хотим передать его не в метод run, а в конструктор.
## aOptions.exportFields[$.name1[] $.name2[field_name]] — список полей объекта, которые надо передать параметрами конструктору модулей. Ключ — имя переменной конструктора, значение — имя переменно в контролере. Значение можно не указывать, если оно совпадает с ключем.

  ^self.cleanMethodArgument[]

  ^pfChainMixin:mixin[$self;
    ^hash::create[$aOptions]
    $.exportModulesProperty(true)
    $.exportFields[
      ^hash::create[$aOptions.exportFields]
      $.template[template]
      $.rootController[_rootController]
    ]
  ]

  $self.router[^self.ifdef[$aOptions.router]{^pfRouter::create[$self]}]

  $self._exceptionPrefix[controller]
  $self._parentController[$aOptions.parentController]
  $self._rootController[^self.ifdef[$aOptions.rootController]{$self}]

  $self.mountTo[/^aOptions.mountTo.trim[both;/]]
  $self.mountToWhere[^hash::create[$aOptions.mountToWhere]]
  $self._compiledMountTo[^self.router.compilePattern[$aOptions.mountTo;$.asPrefix(true)]]

  $self._uriPrefix[^if(!$self.compiledMountTo.hasVars){$self.mountTo}]

  $self._appendSlash(^aOptions.appendSlash.bool(true))

  $self.template[^self.ifdef[$aOptions.template]{^pfTemplate::create[$.searchPath[$aOptions.templateFolder]]}]
  $self._templatePrefix[^aOptions.templatePrefix.trim[both;/]]
  $self._templateVars[^hash::create[]]

  $self._defaultResponseType[html]

  $self.activeModule[]
  $self.action[]
  $self.request[$aOptions.request]

  $self.MIDDLEWARES[^hash::create[]]

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
  $self._uriPrefix[^self._uriPrefix.match[$self.__pfController__.repeatableSlashRegex][][/]]

@GET_templatePrefix[]
  $result[$self._templatePrefix]

@run[aRequest;aOptions] -> []
## Запускает процесс. Если вызван метод run, то модуль становится «менеджером».
## aOptions.returnResponse(false) — вернуть объет ответа вместо вызова response.apply
## aOptions.useXForwarded(false) — передать объекту запроса параметр $.useXForwarded.
  ^self.cleanMethodArgument[]
  $result[]
  $aRequest[^self.ifdef[$aRequest]{^self.ifdef[$self.request]{^pfRequest::create[$.useXForwarded(^aOptions.useXForwarded.bool(false))]}}]
  $self.asRoot(true)

  $lAction[/^aRequest.PATH.trim[both;/]]
  ^if($self.mountTo ne "/"){
    $lAction[^lAction.mid(^self.mountTo.length[])]
  }

  $lResponse[^self.dispatch[$lAction;$aRequest;$.prefix[$self.mountTo]]]
  ^if(^aOptions.returnResponse.bool(false)){
    $result[$lResponse]
  }{
     ^lResponse.apply[]
   }

@assignModule[aName;aClassDef;aArgs] -> []
## aName — имя свойства со ссылкой на модуль.
## aClassDef[path/to/package.p@className::constructor]
## aArgs — параметры, которые передаются конструктору.
## aArgs.mountTo[$aName] — точка монтирования относительно текущего модуля.
## aArgs.mountToWhere — регулярные выражения для проверки переменных в mountTo.
  $result[]
  ^self.cleanMethodArgument[aArgs]
  $aName[^aName.trim[both;/]]

  ^self.__pfChainMixin__.assignModule[$aName;$aClassDef;$aArgs]
  $lModule[$self.MODULES.[$aName]]
  $lModule.mountTo[^if(def $aArgs.mountTo){^aArgs.mountTo.trim[both;/]}{$aName}]
  $lModule.compiledMountTo[^self.router.compilePattern[$lModule.mountTo;
    $.asPrefix(true)
    $.where[$aArgs.mountToWhere]
  ]]

  $lModule.args.parentController[$self]

  $lModule.args.mountTo[^if($self.mountTo ne "/"){$self.mountTo}/$lModule.mountTo]
  $lModule.args.mountToWhere[^hash::create[$self.mountToWhere]]
  ^lModule.args.mountToWhere.add[$lModule.compiledMountTo.where]

  $lModule.args.templatePrefix[^self.ifcontains[$lModule.args;templatePrefix]{$self._templatePrefix/$aName}]

@hasModule[aName]
## Проверяет есть ли у нас модуль с имененм aName
  $result(^self.MODULES.contains[$aName])

@assignMiddleware[aObject;aConstructorOptions] -> []
## aObject[class def|middleware object] — определение класса или вызов конструктора
## aConstructorOptions
  $result[]
  ^self.assert(def $aObject){A middleware object not defined.}
  ^if($aObject is string){
     $lMiddleware[^pfString:parseClassDef[$aObject]]
     ^if(def $lMiddleware.package){
       ^use[$lMiddleware.package]
     }
     $lMiddleware[^reflection:create[$lMiddleware.className;$lMiddleware.constructor;$aConstructorOptions]]
  }{
     $lMiddleware[$aObject]
   }
  $self.MIDDLEWARES.[^math:uid64[]][$lMiddleware]

@dispatch[aAction;aRequest;aOptions] -> [response]
## aOptions.prefix — вычисленный префикс для модуля
  $result[]
  $self.action[^aAction.trim[/]]
  $self.request[$aRequest]

  $lOldPrefix[$self.uriPrefix]
  $self.uriPrefix[$aOptions.prefix]

  ^self.MIDDLEWARES.foreach[_;lMiddleware]{
    $result[^lMiddleware.processRequest[$aAction;$aRequest;$self;$aOptions]]
    ^if(def $result){^break[]}
  }

  ^if(!def $result){
    $lResult[^self.processRequest[$self.action;$aRequest;$aOptions]]
    $result[$lResult.response]
  }

  ^if(!def $result){
    $self.action[$lResult.action]
    $self.request[$lResult.request]
    ^try{
      $result[^self.processAction[$self.action;$self.request;$lResult.prefix;$lResult.processor;$aOptions]]
      $result[^self.processResponse[$self.action;$self.request;$result;$aOptions]]
    }{
       $result[^self.processException[$self.action;$self.request;$exception;$aOptions]]
     }
    ^for[i](1;$self.MIDDLEWARES){
      $lMiddleware[^self.MIDDLEWARES._at(-$i)]
      $result[^lMiddleware.processResponse[$self.action;$self.request;$result;$self;$aOptions]]
    }
  }

  $self.uriPrefix[$lOldPrefix]

@processRequest[aAction;aRequest;aOptions] -> [$.action[] $.request[] $.prefix[] $.response[] $.processor[]]
## Производит предобработку запроса
  $result[^self.router.route[$aAction;$aRequest]]
  ^if(!$result){
    $result[$.action[$aAction] $.request[$aRequest] $.args[^hash::create[]] $.prefix[]]
  }
  ^if($result.defaults){
    ^result.request.assign[$result.defaults]
  }
  ^if($result.args){
    ^result.request.assign[$result.args]
  }

@processAction[aAction;aRequest;aLocalPrefix;aProcessor;aOptions] -> [response]
## Производит вызов экшна.
## aOptions.prefix — префикс, сформированный в processRequest.
  $result[]
  ^if(def $aProcessor){
    $result[^aProcessor.process[$aAction;$aRequest;$aLocalPrefix;$aOptions]]
  }

@processException[aAction;aRequest;aException;aOptions] -> [response]
## Обрабатывает исключительную ситуацию, возникшую в обработчике.
## Ищет и вызывает функции catch<exception.type> или catch<*> в контролере.
## aOptions.passProcessResponse(false) — не вызывать фунуцию processResponse.
  $result[]

  $lCatchFunctions[
    $.on[catch<$aException.type>]
    $.else[catch<*>]
  ]
  ^lCatchFunctions.foreach[_;func]{
    ^if($self.[$func] is junction){
      $aException.handled(true)
      $result[^self.[$func][$aRequest;$aException]]
      ^if(!^aOptions.passProcessResponse.bool(false)){
        $result[^self.processResponse[$aAction;$aRequest;$result;$aOptions]]
      }
      ^break[]
    }
  }

@catch<http.404>[aRequest;aException]
  $lNotFoundFunctions[
    $.nf_c[/NOTFOUND]
  ]

  $result[]
  $lProcessed(false)
  ^lNotFoundFunctions.foreach[_;name]{
    ^if($self.[$name] is junction){
      $result[^self.[$name][$aRequest]]
      $lProcessed(true)
      ^break[]
    }
  }

  ^if(!$lProcessed){
    ^throw[$aException.type;$aException.source;$aException.comment]
  }

@catch<http.301>[aRequest;aException]
  $result[^pfResponseRedirect::create[$aException.source;301]]

@catch<http.302>[aRequest;aException]
  $result[^pfResponseRedirect::create[$aException.source;302]]

@processResponse[aAction;aRequest;aResponse;aOptions] -> [response]
## aOptions.passPost(false) — не делать постобработку запроса.
## aOptions.passWrap(false) — не формировать объект вокруг ответа из строк и чисел.
  $result[$aResponse]
  ^if(!^aOptions.passWrap.bool(false)){
    ^switch[$result.CLASS_NAME]{
      ^case[hash]{
        $result.type[^self.ifdef[$result.type]{$self._defaultResponseType}]
        $result[^pfResponse::create[$result.body;$result]]
      }
      ^case[string;double;int]{
        $result[^pfResponse::create[$result;$.type[$self._defaultResponseType]]]
      }
    }
  }
  ^if(!^aOptions.passPost.bool(false)){
    $lPostFunctions[
      $.resp[response<^result.type.lower[]>]
      $.resp_ast[response<*>]
    ]
    ^lPostFunctions.foreach[_;name]{
      ^if($self.[$name] is junction){
        ^self.[$name][$result]
        ^break[]
      }
    }
  }

@render[aTemplateName;aContext]
## Вызывает шаблон с именем "путь/$aTemplateName[.pt]"
## Если aTemplateName начинается со "/", то не подставляем текущий перфикс.
## Если переменная aTemplateName не задана, то зовем шаблон default.
## aContext — переменные, которые добавляются к тем, что уже заданы через assignVar.
  $aTemplateName[^aTemplateName.trim[]]
  $lVars[^hash::create[$self._templateVars]]
  $lVars[^lVars.union[^self.templateDefaults[]]]
  ^lVars.add[$aContext]
  $result[^self.template.render[^if(^aTemplateName.left(1) ne "/"){$self._templatePrefix/}$aTemplateName;
    $.context[$lVars]
  ]]

@templateDefaults[]
## Задает переменные шаблона по умолчанию.
  $result[
    $.CONTROLLER[$self]
    $.PARENT[$self.PARENT]
    $.ROOT[$self.ROOT]
    $.REQUEST[$self.request]
    $.ACTION[$self.action]
    $.linkTo[$self.linkTo]
    $.redirectTo[$self.redirectTo]
    $.linkFor[$self.linkFor]
    $.redirectFor[$self.redirectFor]
  ]

@abort[aStatus;aData]
  ^throw[http.^aStatus.int(500);$aData]

@makeLinkURI[aAction;aOptions;aPrefix]
## Формирует url для экшна. Используется в linkTo/linkFor.
## $uriPrefix$aAction?aOptions.foreach[key=value][&]
  ^self.cleanMethodArgument[]
  ^if(def $aAction){$aAction[^aAction.trim[both;/.]]}

  $result[^if(def $aPrefix){^aPrefix.trim[end;/]/}^if(def $aAction){^taint[uri][$aAction]^if($self._appendSlash)[/]}]
  ^if($self._appendSlash && def $result && ^result.match[$self.__pfController__.checkDotRegex]){$result[^result.trim[end;/]]}

  ^if($aOptions is hash && $aOptions){
    $result[${result}?^aOptions.foreach[key;value]{$key=^taint[uri][$value]}[^taint[&]]]
  }

@linkTo[aAction;aOptions]
## Формирует ссылку на экшн, выполняя бэкрезолв путей.
## aOptions — объект, который поддерживает свойство $aOptions.fields (хеш, таблица и пр.)
  ^self.cleanMethodArgument[]
  $aAction[^aAction.trim[both;/]]
  $lArgs[^hash::create[$aOptions.fields]]

  ^if(^aAction.left(2) eq "::"){
#   Для глобального маршрута вычисляем префикс модуля динамически
    $aAction[^aAction.mid(2)]
    ^if($self._compiledMountTo.hasVars){
      $lPrefix[/^self.router.applyPath[$self._compiledMountTo.pattern;$lArgs]]
      ^lArgs.sub[$self._compiledMountTo.vars]
    }{
       $lPrefix[$self.mountTo]
     }
  }{
     $lPrefix[$self.uriPrefix]
   }

  $lReverse[^self.router.reverse[$aAction;$lArgs]]
  ^if($lReverse){
    $result[^self.makeLinkURI[$lReverse.path;$lReverse.args;$lPrefix]]
  }{
    $result[^self.makeLinkURI[$aAction;$lArgs;$lPrefix]]
   }

@linkFor[aAction;aObject;aOptions]
## Формирует ссылку на объект.
## aObject[<hash>]
## aOptions.form — поля, которые надо добавить к объекту/маршруту
  ^self.cleanMethodArgument[]
  $aAction[^aAction.trim[both;/]]

  ^if(^aAction.left(2) eq "::"){
#   Для глобального маршрута вычисляем префикс модуля динамически
    $aAction[^aAction.mid(2)]
    ^if($self._compiledMountTo.hasVars){
      $lPrefix[/^self.router.applyPath[$self._compiledMountTo.pattern;$aObject;$aOptions.form]]
    }{
       $lPrefix[$self.mountTo]
     }
  }{
     $lPrefix[$self.uriPrefix]
   }

  $lReverse[^self.router.reverse[$aAction;$aObject;$.form[$aOptions.form] $.onlyPatternVars(true)]]
  ^if($lReverse){
    $result[^self.makeLinkURI[$lReverse.path;$lReverse.args;$lPrefix]]
  }{
    $result[^self.makeLinkURI[$aAction;$aOptions.form;$lPrefix]]
   }

@redirect[aURL;aStatus]
  ^self.abort(^aStatus.int(302))[$aURL]

@redirectTo[aAction;aOptions]
  ^self.abort(302)[^self.linkTo[$aAction;$aOptions]]

@redirectFor[aAction;aObject;aOptions]
  ^self.abort(302)[^self.linkFor[$aAction;$aObject;$aOptions]]

@assignVar[aName;aValue]
  $result[]
  $self._templateVars.[$aName][$aValue]

@assignVars[aVars]
  $result[]
  $aVars[^hash::create[$aVars]]
  ^aVars.foreach[k;v]{
    $self._templateVars.[$k][$v]
  }

#--------------------------------------------------------------------------------------------------

@CLASS
pfRouter

@BASE
pfClass

@OPTIONS
locals

@create[aController;aOptions]
  ^BASE:create[]
  ^self.assert(def $aController)[Не задан контролер для роутера.]
  $self.controller[$aController]

  $self.processors[^hash::create[]]
  ^self.processor[default;pfRouterDefaultProcessor]
  ^self.processor[render;pfRouterRenderProcessor]
  ^self.processor[redirect;pfRouterRedirectProcessor]
  ^self.processor[call;pfRouterCallProcessor]

  $self.routes[^hash::create[]]
  $self._reverseIndex[^hash::create[]]

  $self._where[^hash::create[]]
  $self._defaults[^hash::create[]]

  $self.hasRootRoute(false)

@auto[]
  $self._pfRouterPatternVar[([:\*])\{?([\p{L}\p{Nd}_\-]+)\}?]
  $self._pfRouterPatternRegex[^regex::create[$self._pfRouterPatternVar][g]]
  $self._pfRouteRootRegex[^regex::create[^^^$]]
  $self._pfRouterSegmentSeparators[\./]
  $self._pfRouterVarRegexp[[^^$self._pfRouterSegmentSeparators]+]
  $self._pfRouterTrapRegexp[(.*)]
  $self._pfRouterProcessorRegexp[^regex::create[^^(?:\s*(.*?)\s*(?:::|->))?(.*)^$]]

@where[aWhere]
  $result[]
  ^self._where.add[$aWhere]

@defaults[aDefaults]
  $result[]
  ^self._defaults.add[$aDefaults]

@processor[aName;aClassDef;aOptions] -> []
## Регистрирует новый процессор для вызова
## Процессор с именем default считаем процессором по-умолчанию.
  $result[]
  $lProcessor[^hash::create[]]
  $lProcessor.classDef[^pfString:parseClassDef[$aClassDef]]
  $lProcessor.options[$aOptions]
  $self.processors.[$aName][$lProcessor]

@module[aName;aClassDef;aArgs] -> []
## Алиас для controller.assignModule, если удобнее писать ^router.module[...]
  $result[^self.controller.assignModule[$aName;$aClassDef;$aArgs]]

@middleware[aObject;aConstructorOptions] -> []
## Алиас для controller.assignMiddleware, если удобнее писать ^router.middleware[...]
  $result[^self.controller.assignMiddleware[$aObject;$aConstructorOptions]]

@assign[aPattern;aRouteTo;aOptions] -> []
## Добавляет новый маршрут в роутер.
## aRouteTo — новый маршрут (может содержать переменные)
## aOptions.as[] — имя шаблона (используется в reverse)
## aOptions.defaults[] — хеш со значениями переменных шаблона "по-умолчанию"
## aOptions.where[] — хеш с регулярными выражениями для проверки переменных шаблона
  ^self.cleanMethodArgument[]
  $result[]
  $lCompiledPattern[^self.compilePattern[$aPattern;$aOptions]]
  $lRouteTo[^self._makeRouteTo[$aRouteTo;$aOptions]]
  $lRoute[
    $.pattern[$lCompiledPattern.pattern]
    $.regexp[$lCompiledPattern.regexp]
    $.compiledRegexp[^regex::create[$lCompiledPattern.regexp][]]
    $.vars[$lCompiledPattern.vars]
    $.trap[$lCompiledPattern.trap]

    $.routeTo[$lRouteTo.routeTo]

    $.defaults[^hash::create[$aOptions.defaults]]
    $.where[^hash::create[$aOptions.where]]
    $.as[$lRouteTo.as]
  ]
  $lRoute.processor[$lRouteTo.processor]
  $self.routes.[^math:uid64[]][$lRoute]

  ^if(!def $lRoute.pattern){$self.hasRootRoute(true)}

# Добавляем маршрут в обратный индекс
  ^if($lRouteTo.appendToReverseIndex){
    $self._reverseIndex.[$lRoute.routeTo][^self.ifcontains[$self._reverseIndex;$lRoute.routeTo]{^hash::create[]}]
    $self._reverseIndex.[$lRoute.routeTo].[^math:uid64[]][$lRoute]
  }

  ^if($lRoute.routeTo ne $lRoute.as){
    $self._reverseIndex.[$lRoute.as][^self.ifcontains[$self._reverseIndex;$lRoute.as]{^hash::create[]}]
    $self._reverseIndex.[$lRoute.as].[^math:uid64[]][$lRoute]
  }

@_makeRouteTo[aRouteTo;aOptions] -> [$.routeTo[] $.processor[] $.appendToReverseIndex(true)]
  $result[
    $.routeTo[]
    $.appendToReverseIndex(true)
  ]
  ^if($aRouteTo is pfRouterProcessor){
    $result.processor[$aRouteTo]
    $result.appendToReverseIndex(false)
    $result.as[$aOptions.as]
  }($aRouteTo is hash){
    $result.processor[^self.createProcessor[^aRouteTo.at[first;key];^aRouteTo.at[first;value]]]
    $result.appendToReverseIndex(false)
    $result.as[^self.ifdef[$aOptions.as]{$aRouteTo.as}]
  }{
    $lParsedRouteTo[^aRouteTo.match[$self._pfRouterProcessorRegexp]]
    $result.routeTo[$lParsedRouteTo.2]
    $result.processor[^self.createProcessor[$lParsedRouteTo.1;$lParsedRouteTo.2]]
    $result.as[^self.ifdef[$aOptions.as]{$result.routeTo}]
  }
  $result.as[^self.trimPath[$result.as]]

@route[aAction;aRequest;aOptions] -> [$.action $.args $.request $.processor $.defaults]
## Выполняет поиск и преобразование пути по списку маршрутов
  ^self.cleanMethodArgument[]
  $result[^hash::create[]]
  $result.action[^self.trimPath[$aAction]]
  $result.request[$aRequest]

  ^if(def $aAction || $self.hasRootRoute){
    ^self.routes.foreach[k;it]{
      $lParsedPath[^self.parsePathByRoute[$result.action;$it;$.args[$self._defaults]]]
      ^if($lParsedPath){
        $result.args[$lParsedPath.args]
        $result.action[$lParsedPath.action]
        $result.processor[$it.processor]

        $lDefaults[^hash::create[$self._defaults]]
        ^lDefaults.add[$it.defaults]
        $result.defaults[$lDefaults]
        ^break[]
      }
    }
  }
  $result.processor[^self.ifdef[$result.processor]{^self.createProcessor[default]}]

@createProcessor[aName;aProcessorData;aOptions]
  $lProcessor[^self.ifcontains[$self.processors;$aName]{$self.processors.default}]
  $result[^reflection:create[$lProcessor.classDef.className;$lProcessor.classDef.constructor;$self;$aProcessorData;$aOptions]]

@reverse[aAction;aArgs;aOptions] -> [$.path[] $.args[]]
## aAction — имя экшна или роута
## aArgs — хеш с параметрами для преобразования
## aOptions.form — дополнительные параметры для маршрута
## aOptions.onlyPatternVars(false) — использовать только те переменные из aArgs, которые определены в маршруте или aOptions.form
  ^self.cleanMethodArgument[]
  $result[^hash::create[]]
  $lOnlyPatternsVar(^aOptions.onlyPatternVars.bool(false))

  $aAction[^self.trimPath[$aAction]]
  $aArgs[^if($aArgs is table){$aArgs.fields}{^hash::create[$aArgs]}]
  ^aArgs.add[$aOptions.form]

  $lModule[$self.controller.MODULES.[$aAction]]
  ^if($lModule){
#   Если нам передали имя модуля, то вычисляем путь к нему
    $result.args[^if($lOnlyPatternsVar){^hash::create[$aOptions.form]}{$aArgs}]
    ^if($lModule.compiledMountTo.hasVars){
      $result.path[^self.applyPath[$lModule.compiledMountTo.pattern;$aArgs]]
      ^result.args.sub[$lModule.compiledMountTo.vars]
    }{
      $result.path[$lModule.mountTo]
    }
  }(^self._reverseIndex.contains[$aAction]){
    $lRoutes[$self._reverseIndex.[$aAction]]
    ^lRoutes.foreach[_;lRoute]{
      $result[^self.matchRoute[$lRoute;$aArgs;$aOptions]]
      ^if($result){^break[]}
    }
  }

@matchRoute[aRoute;aArgs;aOptions]
  $result[^hash::create[]]

  $lOnlyPatternsVar(^aOptions.onlyPatternVars.bool(false))

  $lPath[^self.applyPath[$aRoute.pattern;$aArgs]]
# Проверяем соответствует ли полученный путь шаблоу (с ограничениями «where»)
  ^if(^lPath.match[$aRoute.regexp][n]){
#   Добавляем оставшиеся параметры из aArgs или aOptions.form в result.args
    $result.path[$lPath]
    $result.args[^if($lOnlyPatternsVar){^hash::create[$aOptions.form]}{$aArgs}]
    ^result.args.sub[$aRoute.vars]
  }

@compilePattern[aRoute;aOptions]
## aOptions.asPrefix(false) — компилировать как префикс
## aOptions.where — регулярные выражения для переменных
## result[$.pattern[] $.regexp[] $.vars[] $.trap[] $.hasVars]
  $result[
    $.vars[^hash::create[]]
    $.pattern[^self.trimPath[$aRoute]]
    $.trap[]
    $.hasVars(0)
  ]
  $lPattern[^untaint[regex]{/$result.pattern}]

# Разбиваем шаблон на сегменты и компилируем их в регулярные выражения
  $lSegments[^hash::create[]]
  $lParts[^lPattern.match[([$self._pfRouterSegmentSeparators])([^^$self._pfRouterSegmentSeparators]+)][g]]
  $lWhere[^hash::create[$self._where]]
  ^lWhere.add[$aOptions.where]
  ^lParts.menu{
     $lHasVars(false)
     $lHasTrap(false)
     $lRegexp[^lParts.2.match[$self._pfRouterPatternRegex][]{^if($match.1 eq ":"){(^if(def $lWhere.[$match.2]){^lWhere.[$match.2].match[\((?!\?[=!<>])][g]{(?:}}{$self._pfRouterVarRegexp})}{$self._pfRouterTrapRegexp}^if($match.1 eq "*"){$result.trap[$match.2]$lHasTrap(true)}$result.vars.[$match.2](true)$lHasVars(true)}]
     $lSegments.[^eval($lSegments + 1)][
       $.prefix[$lParts.1]
       $.regexp[$lRegexp]
       $.hasVars($lHasVars)
       $.hasTrap($lHasTrap)
     ]
     ^if($lHasVars){^result.hasVars.inc[]}
  }
  $result.where[$lWhere]

# Собираем регулярное выражение для всего шаблона.
# Закрывающие скобки ставим в обратном порядке. :)
  $result.regexp[^^^lSegments.foreach[k;it]{^if($it.hasVars){(?:}^if($k>1){\$it.prefix}$it.regexp}^for[i](1;$lSegments){$it[^lSegments._at(-$i)]^if($it.hasVars){)^if($it.hasTrap){?}}}^if(^aOptions.asPrefix.bool(false)){(?:/|^$)}{^$}]

@trimPath[aPath]
  $result[^aPath.trim[both;/. ^#0A]]

@parsePathByRoute[aPath;aRoute;aOptions]
## Преобразует aPath по правилу aRoute.
## aOptions.args
## result[$.action $.args $.prefix]
  $result[^hash::create[]]
  $lVars[^aPath.match[$aRoute.compiledRegexp]]
  ^if($lVars){
    $result.args[^hash::create[$aOptions.args]]
    ^if($aRoute.vars){
      $i(1)
      ^aRoute.vars.foreach[k;v]{
        ^if(def $lVars.$i){
          $result.args.[$k][$lVars.$i]
        }
        ^i.inc[]
      }
    }
    ^if(def $aRoute.routeTo){
      $result.action[^self.applyPath[$aRoute.routeTo;$result.args;$aOptions.args]]
    }
  }

@applyPath[aPath;aVars;aArgs]
## Заменяет переменные в aPath. Значения переменных ищутся в aVars и aArgs.
  ^self.cleanMethodArgument[aVars;aArgs]
  $result[^if(def $aPath){^aPath.match[$self._pfRouterPatternRegex][]{^if(^aVars.contains[$match.2]){$aVars.[$match.2]}{^if(^aArgs.contains[$match.2] || $match.1 eq "*"){$aArgs.[$match.2]}}}}]

#--------------------------------------------------------------------------------------------------

@CLASS
pfRouterProcessor

@BASE
pfClass

@OPTIONS
locals

@create[aRouter;aProcessorData;aOptions] ::constructor
  ^BASE:create[]
  $self.router[$aRouter]
  $self.controller[$aRouter.controller]

@process[aAction;aRequest;aPrefix;aOptions]
  $result[]

#--------------------------------------------------------------------------------------------------

@CLASS
pfRouterDefaultProcessor

@BASE
pfRouterProcessor

@OPTIONS
locals

@auto[]
  $self.__pfRouterDefaultProcessor__[
    $.httpMethods[^regex::create[\p{Ll}(GET|HEAD|TRACE|OPTIONS|POST|PUT|DELETE|PATCH|CONNECT)^$]]
  ]

@create[aRouter;aProcessorData;aOptions]
  ^BASE:create[$aRouter;$aProcessorData;$aOptions]

@process[aAction;aRequest;aPrefix;aOptions]
  $lController[$self.controller]
  $lAction[^self.router.trimPath[$aAction]]
  $lRequest[$aRequest]

  ^if(def $aOptions.prefix){$lController.uriPrefix[$aOptions.prefix]}

  $lModule[^self.findModule[$aAction;$lRequest]]
  ^if($lModule){
#   Если у нас в первой части экшна имя модуля, то передаем управление модулю
    $lController.activeModule[$lModule.module.name]
    $result[^lController.[$lModule.module.name].dispatch[$lModule.action;$lRequest;
      $.prefix[$lController.uriPrefix/$lModule.prefix]
    ]]
  }{
#    Если модуля нет, то пытаемся найти и запустить экш из нашего модуля
     $lHandler[^self.findHandler[$lAction;$lRequest]]
     ^if(def $lHandler){
       $result[^lController.[$lHandler][$lRequest]]
     }{
        ^lController.abort(404)[Action "$lAction" not found.]
      }
   }

@findModule[aAction;aRequest] -> [$.module $.prefix $.action]
## Ищет модуль по имени экшна
  $result[^hash::create[]]
  $aAction[^aAction.trim[/]]
  ^if(def $aAction){
    $lModule[$self.controller.MODULES.[$aAction]]
    ^if(def $lModule){
      $result.module[$lModule]
      $result.prefix[$aAction]
      $result.action[]
    }{
      ^self.controller.MODULES.foreach[k;v]{
        $lFound[^aAction.match[$v.compiledMountTo.regexp][ix']]
        ^if($lFound){
          $result.module[$v]
          $result.prefix[^lFound.match.trim[/]]
          $result.action[$lFound.postmatch]
          ^if($v.compiledMountTo.hasVars){
            $lArgs[^hash::create[]]
            $i(1)
            ^v.compiledMountTo.vars.foreach[k;_]{
              $lArgs.[$k][$lFound.[$i]]
              ^i.inc[]
            }
            ^aRequest.assign[$lArgs]
          }
          ^break[]
        }
      }
    }
  }

@findHandler[aAction;aRequest]
## Ищет и возвращает имя функции-обработчика для экшна.
  $result[]
  $lFunctions[^self.makeActionNames[$aAction;$aRequest]]
  ^lFunctions.foreach[_;name]{
    ^if($self.controller.[$name] is junction){
      $result[$name]
      ^break[]
    }
  }

@makeActionNames[aAction;aRequest] -> [hash]
## Возвращает имена возможных функций для экшнов.
  $result[^hash::create[]]
  $aAction[^aAction.lower[]]
  $aAction[^aAction.trim[/]]
  $aAction[^aAction.left(^aAction.pos[<])]
  $lMethod[^aRequest.method.lower[]]

  ^if(def $aAction){
    $result.uri_m[/$aAction<${lMethod}>]
    $result.uri[/$aAction]
  }{
#    Рутовый маршрут
     $result.index_u_m[/INDEX<${lMethod}>]
     $result.index_slash_m[/<${lMethod}>]
     $result.index_u[/INDEX]
     $result.index_slash[/]
   }

# Дефолтный маршрут
  $result.default[/DEFAULT]

#--------------------------------------------------------------------------------------------------

@CLASS
pfRouterRenderProcessor

@BASE
pfRouterProcessor

@OPTIONS
locals

## ^router.assign[/some/action;render->action.pt]
## ^router.assign[/some/action;render::action.pt]
## ^router.assign[/some/action;$.render[$.template[action.pt] $.context[$.var[value]]]]

@create[aRouter;aProcessorData;aOptions]
## aProcessorData[string|hash]
## aProcessorData.template — имя шаблона
## aProcessorData.context — переменные шаблона
## aProcessorData.status[200] — http-статус ответа
## aProcessorData.type[controller.defaultResponseType] — тип ответа
  ^BASE:create[$aRouter;$aProcessorData;$aOptions]
  ^if($aProcessorData is hash){
    $self.template[^aProcessorData.template.trim[/ .]]
    $self.context[^hash::create[$aProcessorData.context]]
    $self.status[$aProcessorData.status]
    $self.type[$aProcessorData.type]
  }{
     $self.template[^aProcessorData.trim[/ .]]
   }

@process[aAction;aRequest;aPrefix;aOptions]
  $result[
    $.type[^self.ifdef[$self.type]{$self.controller.defaultResponseType}]
    $.status[^self.ifdef[$self.status]{200}]
    $.body[^self.controller.render[$self.template;$self.context]]
  ]

#--------------------------------------------------------------------------------------------------

@CLASS
pfRouterCallProcessor

@BASE
pfRouterProcessor

@OPTIONS
locals

## ^router.assign[/some/action;call->someActionHandler]
## ^router.assign[/some/action;call::someActionHandler]

@create[aRouter;aProcessorData;aOptions]
## aProcessorData[function name] — имя функции для экшна
  ^BASE:create[$aRouter;$aProcessorData;$aOptions]
  $self.functionName[$aProcessorData]

@process[aAction;aRequest;aPrefix;aOptions]
  $result[^self.controller.[$self.functionName][$aRequest]]

#--------------------------------------------------------------------------------------------------

@CLASS
pfRouterRedirectProcessor

@BASE
pfRouterProcessor

@OPTIONS
locals

## ^router.assign[/some/action;redirect->/another/location]
## ^router.assign[/some/action/:var;redirect->/another/:var/location]
## ^router.assign[/some/action/:var;redirect->http://some.domain/action/:var]
## ^router.assign[/some/action;redirect->/another/location <301>]
## ^router.assign[/some/action;redirect->^linkTo[/redirected] <302>]
## ^router.assign[/some/action;redirect::/another/location]
## ^router.assign[/some/action;$.redirect[/another/action] $.status[301]]

@create[aRouter;aProcessorData;aOptions]
## aProcessorData[string|hash]
## aProcessorData[$.location $.status(302)]
  ^BASE:create[$aRouter;$aProcessorData;$aOptions]

  $self._defaultHTTPCode(302)

  ^if($aProcessorData is hash){
    $self.redirect[
      $.status(^aProcessorData.status.int($self._defaultHTTPCode))
    ]

    ^if(def $aProcessorData.to){
      $self.redirect.location[$aProcessorData.to]
    }(^aProcessorData.contains[action]){
      $self.redirect.location[^self.controller.linkTo[$aProcessorData.action;$aProcessorData.args]]
    }
  }{
    ^aProcessorData.match[^^\s*(\S+?)\s*(?:<(\d+)>\s*)?^$][]{
      $self.redirect[
        $.location[${match.1}]
        $.status(^match.2.int($self._defaultHTTPCode))
      ]
    }
  }

@process[aAction;aRequest;aPrefix;aOptions]
  $lLocation[^self.router.applyPath[$self.redirect.location;$aRequest;$aOptions.args]]
  $result[^pfResponseRedirect::create[$lLocation;$self.redirect.status]]

#--------------------------------------------------------------------------------------------------

@CLASS
pfRequest

## Собирает в одном объекте все параметры http-запроса, доступные в Парсере.

@OPTIONS
locals

@create[aOptions]
## aOptions — хеш с переменными объекта, которые надо заменить. [Для тестов.]
## aOptions.useXForwarded(false) — использовать для полей HOST и PORT заголовки X-Forwarded-Host и X-Forwarded-Port.
## aOptions.protect — хэш защищённых полей: их значения можно установить только через @assign, не через форму.
  $aOptions[^hash::create[$aOptions]]

  $self.ifdef[$pfClass:ifdef]
  $self.ifcontains[$pfClass:ifcontains]
  $self.__CONTEXT__[^hash::create[]]
  $self.__PROTECT__[^hash::create[$aOptions.protect]]

  $self.form[^hash::create[^self.ifdef[$aOptions.form]{$form:fields}]]
  $self.tables[^hash::create[^self.ifdef[$aOptions.tables]{$form:tables}]]
  $self.files[^hash::create[^self.ifdef[$aOptions.files]{$form:files}]]
  $self.elements[^hash::create[^self.ifdef[$aOptions.elements]{$form:elements}]]

  $self.cookie[^hash::create[^self.ifdef[$aOptions.cookie]{$cookie:fields}]]
  $self.headers[^hash::create[^self.ifdef[$aOptions.headers]{$request:headers}]]

  $self.method[^self.ifdef[^aOptions.method.lower[]]{^request:method.lower[]}]
# Если нам пришел post-запрос с полем _method, то берем method из запроса.
  ^if($self.method eq "post" && def $self.form._method){
    $self.method[^self.form._method.lower[]]
  }

  $self.ENV[^self.ifdef[$aOptions.ENV]{$env:fields}]

  $self.URI[^self.ifcontains[$aOptions;URI]{$request:uri}]
  $self.QUERY[^self.ifcontains[$aOptions;QUERY]{$request:query}]
  $self.PATH[^self.URI.left(^self.URI.pos[?])]
  ^pfClass:unsafe{
#   Раскодируем неанглийские буквы в PATH.
    $self.PATH[^taint[^string:unescape[uri][$self.PATH]]]
  }

  $self.ACTION[^self.ifcontains[$aOptions;ACTION]{^self.PATH.trim[/]}]

  ^if(def $aOptions.HOST){
    $self.HOST[$aOptions.HOST]
  }{
    $self.HOST[^self.header[Host]{$self.ENV.SERVER_NAME}]
    ^if(^aOptions.useXForwarded.bool(false)
      && def ^self.header[X-Forwarded-Host]
    ){
       $self.HOST[^self.header[X-Forwarded-Host]]
    }
  }
  $self.HOST[^self.HOST.trim[]]
  $self.DOMAIN[^self.HOST.match[^^(.+?):\d+^$][]{$match.1}]

  ^if(def $aOptions.PORT){
    $aOptions.PORT
  }{
#   Порт может приходить в X-Forwarded-Port, Host, env.SERVER_PORT
    ^self.HOST.match[^^.+?:(\d+)^$][]{$lHostPort[$match.1]}
    $self.PORT[^ifdef[$lHostPort]{^self.ENV.SERVER_PORT.int(80)}]
    ^if(^aOptions.useXForwarded.bool(false)
      && def ^self.header[X-Forwarded-Port]
    ){
      $self.PORT[^self.header[X-Forwarded-Port]]
    }
  }

  $self.isSECURE(^self.ifcontains[$aOptions;isSECURE](^self.ENV.HTTPS.lower[] eq "on" || $self.PORT eq "443"))

  $self.HOST[$self.HOST^if(!^self.HOST.match[:\d+^$] && $self.PORT ne "80" && ($self.isSECURE && $self.PORT ne "443")){:$self.PORT}]

  $self.SCHEME[http^if($self.isSECURE){s}]

# Проверяет является ли Referer локальным.
  $self.REFERER[^self.header[Referer]]
  $self.isLOCALREFERER(^self.REFERER.pos[${self.SCHEME}://$self.HOST] == 0)

  $self.isAJAX(^self.ifdef[$aOptions.isAJAX](^self.headers.X_REQUESTED_WITH.pos[XMLHttpRequest] > -1))

  $self.REMOTE_IP[^self.ifdef[$aOptions.REMOTE_IP]{$ENV.REMOTE_ADDR}]
  $self.DOCUMENT_ROOT[^self.ifcontains[$aOptions;DOCUMENT_ROOT]{$request:document-root}]

  $self.CHARSET[^self.ifdef[$aOptions.CHARSET]{$request:charset}]
  $self.RESPONSE_CHARSET[^self.ifdef[$aOptions.RESPONSE_CHARSET]{^response:charset.lower[]}]
  $self.POST_CHARSET[^self.ifdef[$aOptions.POST_CHARSET]{^request:post-charset.lower[]}]
  $self.BODY_CHARSET[^self.ifdef[$aOptions.BODY_CHARSET]{^request:body-charset.lower[]}]

  $self.BODY[^self.ifdef[$aOptions.BODY]{$request:body}]
  $self._BODY_FILE[$aOptions.BODY_FILE]

@GET[aContext]
  ^switch[$aContext]{
#   def, expression, bool, double, hash, table или file.
    ^case[def]{$result(true)}
    ^case[expression;double;bool]{$result($self.form || $self.__CONTEXT__)}
    ^case[DEFAULT]{$result[$self]}
  }

@GET_DEFAULT[aName]
  $result[^if(^self.__CONTEXT__.contains[$aName]){$self.__CONTEXT__.[$aName]}(!^self.__PROTECT__.contains[$aName]){$form.[$aName]}]

@GET_BODY_FILE[]
  $result[^if(def $self._BODY_FILE){$self._BODY_FILE}{$request:body-file}]

@GET_clientAcceptsJSON[]
  $result(^self.headers.ACCEPT.pos[application/json] >= 0)

@GET_clientAcceptsXML[]
  $result(^self.headers.ACCEPT.pos[application/xml] >= 0)

@GET_isGET[]
  $result($self.method eq "get")

@GET_isPOST[]
  $result($self.method eq "post")

@GET_isPUT[]
  $result($self.method eq "put")

@GET_isDELETE[]
  $result($self.method eq "delete")

@GET_isPATCH[]
  $result($self.method eq "patch")

@GET_isHEAD[]
  $result($self.method eq "head")

@assign[*aArgs]
## Добавляет в запрос поля.
## ^assign[name;value]
## ^assign[$.name[value] ...]
  ^if($aArgs.0 is hash){
    ^self.__CONTEXT__.add[$aArgs.0]
  }{
     $self.__CONTEXT__.[$aArgs.0][$aArgs.1]
   }

@contains[aName]
  $result(^self.__CONTEXT__.contains[$aName] || ^self.form.contains[$aName])

@foreach[aKeyName;aValueName;aCode;aSeparator]
  $lFields[^hash::create[$form]]
  ^lFields.add[$self.__CONTEXT__]
  $result[^lFields.foreach[k;v]{$caller.[$aKeyName][$k]$caller.[$aValueName][$v]$aCode}{$aSeparator}]

@header[aHeaderName;aDefaultValue]
## Возвращает заголовок запроса.
## aDefaultValue — результат функции, если заголовок не определен.
  $lName[^aHeaderName.trim[both; :]]
  $lName[^lName.replace[-;_]]
  $lName[^lName.replace[ ;_]]
  $result[$self.headers.[^lName.upper[]]]
  ^if(!def $result){
    $result[$aDefaultValue]
  }

@absoluteURL[aLocation]
## Возвращает полный url для запроса.
## aLocation — адрес страницы вместо URI.
  $aLocation[^self.ifdef[$aLocation]{$self.URI}]
  ^if(^aLocation.left(1) ne "/"){
    $aLocation[/$aLocation]
  }
  $result[${self.SCHEME}://${self.HOST}$aLocation]

#--------------------------------------------------------------------------------------------------

@CLASS
pfResponse

## Класс с http-ответом.

## Методы для работы с заголовками нужно использовать в мидлваре для измениня уже существующих объектов.
## Если явно создаем объект, то заголовки лучше передать в конструктор.

@OPTIONS
locals

@BASE
pfClass

@create[aBody;aOptions]
## aBody
## aOptions.type[html] — тип ответа
## aOptions.status(200) — http-статус
## aOptions.contentType[text/html]
## aOptions.charset[$response:charset]
## aOptions.download[] — если задан, то заменяет aBody
## aOptions.headers[] — заголовки ответа
## aOptions.cookie[] — куки
## aOptions.fields[hash] — поля объекта
  ^self.cleanMethodArgument[]

  ^if($aOptions.fields){
#   Если нам передали aOptions.fields,
#   то устанавливаем сначала поля объекта
    ^aOptions.fields.foreach[k;v]{
      $self.[$k][$v]
    }
  }

  $self.body[$aBody]
  $self.download[$aOptions.download]
  $self.type[^self.ifdef[$aOptions.type]{html}]
  $self.status(^self.ifdef[$aOptions.status]{200})
  $self.contentType[^self.ifdef[$aOptions.contentType]{text/html}]
  $self.charset[^self.ifdef[$aOptions.charset]{$response:charset}]

  $self.headers[^hash::create[$aOptions.headers]]
  $self.cookie[^hash::create[$aOptions.cookie]]

@hasHeader[aName] -> [bool]
## Проверяет установлен ли заголовок.
  $result(false)
  ^self.headers.foreach[k;v]{
    ^if($aName eq ^k.upper[]){
      $result(true)
      ^break[]
    }
  }

@getHeader[aName;aDefault] -> [value or aDefault]
## Возвращает заголовок или aDefault
  $result[$aDefault]
  $aName[^aName.upper[]]
  ^self.headers.foreach[k;v]{
    ^if($aName eq ^k.upper[]){
      $result[$v]
      ^break[]
    }
  }

@setHeader[aName;aValue] -> []
## Устанавливает заголовок.
  $result[]
  $lSetHeader(true)
  ^self.headers.foreach[k;v]{
    ^if($aName eq ^k.upper[]){
      $self.headers.[$k][$aValue]
      $lSetHeader(false)
      ^break[]
    }
  }
  ^if($lSetHeader){
    $self.headers.[$aName][$aValue]
  }

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

  $lHasContentTypeHeader(false)
  ^self.headers.foreach[k;v]{
    $response:$k[$v]
    ^if(^k.lower[] eq "content-type"){
      $lHasContentTypeHeader(true)
    }
  }
  ^self.cookie.foreach[k;v]{
    $cookie:$k[$v]
  }
  $response:status[$self.status]

  ^if(!$lHasContentTypeHeader){
    ^if(def $self.charset){$response:charset[$self.charset]}
    $response:content-type[
      $.value[$self.contentType]
      $.charset[$response:charset]
    ]
  }

#--------------------------------------------------------------------------------------------------

@CLASS
pfResponseRedirect

@OPTIONS
locals

@BASE
pfResponse

@create[aLocation;aStatus]
## aLocation — полный путь для редиректа или uri
## aStatus[302]
  ^BASE:create[;$.type[redirect] $.status[^self.ifdef[$aStatus]{302}]]
  $self.headers.location[^untaint{$aLocation}]

@GET_location[]
  $result[$self.headers.location]

#--------------------------------------------------------------------------------------------------

@CLASS
pfMiddleware

## Базовый предок для классов мидлваре. Показывает какой интерфейс должен быть у мидлваре.
## Методы process* надо реализовывать только если классу надо встроиться в конкретный этап обработки запросов.
##
## Мидлваре в контролере образуют цепочку. Запрос проходит методы processRequest в порядке добавления мидлваре,
## а processResponse в обратном порядке.

@OPTIONS
locals

@BASE
pfClass

@create[aOptions]

@processRequest[aAction;aRequest;aController;aProcessOptions] -> [response|null]
# если ничего не возвращает, то продолжаем обработку, если возвращает pfResponse, то прерываем обработку и не зовем другие middleware.
  $result[]

@processResponse[aAction;aRequest;aResponse;aController;aProcessOptions] -> [response]
# возвращает respone
  $result[$aResponse]
