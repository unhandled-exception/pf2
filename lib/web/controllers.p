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
## aOptions.mountTo[/] — место монтирования. Вручную передавать не нужно — это сделает assignModule.
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

  $self.mountTo[^self.ifdef[^aOptions.mountTo.trim[end;/]]{/}]
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
  ^self.cleanMethodArgument[]
  $result[]
  $aRequest[^self.ifdef[$aRequest]{^self.ifdef[$self.request]{^pfRequest::create[]}}]
  $self.asRoot(true)
  $lResponse[^self.dispatch[$aRequest.ACTION;$aRequest]]
  ^lResponse.apply[]

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
    $result[$.action[$aAction] $.args[^hash::create[]] $.prefix[]]
  }
  $result.request[$aRequest]
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
## aOptions.passProcessResponse(false)
  $result[]
  $lProcessed(false)
  ^switch[$aException.type]{
    ^case[http.404]{
      ^if($self.onNOTFOUND is junction){
        $result[^self.onNOTFOUND[$aRequest]]
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
    $lPostDispatch[post^result.type.upper[]]
    ^if($self.$lPostDispatch is junction){
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
## aContext — переменные, которые добавляются к тем, что уже заданы через assignVar.
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

@makeLinkURI[aAction;aOptions;aAnchor;aPrefix]
## Формирует url для экшна. Используется в linkTo/linkFor.
## $uriPrefix$aAction?aOptions.foreach[key=value][&]#aAnchor
  ^self.cleanMethodArgument[]
  ^if(def $aAction){$aAction[^aAction.trim[both;/.]]}

  $result[^if(def $aPrefix){^aPrefix.trim[end;/]/}^if(def $aAction){^taint[uri][$aAction]^if($self._appendSlash)[/]}]
  ^if($self._appendSlash && def $result && ^result.match[$self.__pfController__.checkDotRegex]){$result[^result.trim[end;/]]}

  ^if($aOptions is hash && $aOptions){
    $result[${result}?^aOptions.foreach[key;value]{$key=^taint[uri][$value]}[^taint[&]]]
  }

@linkTo[aAction;aOptions;aAnchor]
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
    $result[^self.makeLinkURI[$lReverse.path;$lReverse.args;$aAnchor;$lPrefix]]
  }{
    $result[^self.makeLinkURI[$aAction;$lArgs;$aAnchor;$lPrefix]]
   }

@linkFor[aAction;aObject;aOptions]
## Формирует ссылку на объект.
## aObject[<hash>]
## aOptions.form — поля, которые надо добавить к объекту/маршруту
## aOptions.anchor — «якорь»
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
    $result[^self.makeLinkURI[$lReverse.path;$lReverse.args;$aOptions.anchor;$lPrefix]]
  }{
    $result[^self.makeLinkURI[$aAction;$aOptions.form;$aAnchor;$lPrefix]]
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

#@onINDEX[aRequest] -> [response] или ^self.router.root[$index]
#@onAction[aRequest] -> [response] или ^self.router.assign[action;$actionHandler;$.strict(true)]
#@onNOTFOUND[aRequest] -> [response]

#@postDEFAULT[aResponse] -> [response]
#@postHTML[aResponse] -> [response]

@onINDEX[aRequest]
  ^throw[${self._exceptionPrefix}.index.not.implemented;An onINDEX method is not implemented in the $self.CLASS_NAME class.]

#--------------------------------------------------------------------------------------------------

@CLASS
pfRouter

@BASE
pfClass

@OPTIONS
locals

@create[aController;aOptions]
  ^BASE:create[]
  $self.controller[$aController]

  $self.processors[^hash::create[]]
  ^self.assignProcessor[default;pfRouterDefaultProcessor]
  ^self.assignProcessor[render;pfRouterRenderProcessor]
  ^self.assignProcessor[call;pfRouterCallProcessor]

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
  $self._pfRouterProcessorRegexp[^regex::create[^^(?:\s*(.*?)\s*::)?(.*)^$]]

@assignProcessor[aName;aClassDef;aOptions] -> []
## Регистрирует новый процессор для вызова
## Процессор с именем default считаем процессором по-умолчанию.
  $result[]
  $lProcessor[^hash::create[]]
  $lProcessor.classDef[^pfChainMixin:_parseClassDef[$aClassDef]]
  $lProcessor.options[$aOptions]
  $self.processors.[$aName][$lProcessor]

@where[aWhere]
  $result[]
  ^self._where.add[$aWhere]

@defaults[aDefaults]
  $result[]
  ^self._defaults.add[$aDefaults]

@assignModule[aName;aClassDef;aArgs] -> []
## Алиас для controller.assignModule, если удобнее писать ^router.assignModule[...]
  $result[^self.controller.assignModule[$aName;$aClassDef;$aArgs]]

@assignMiddleware[aObject;aConstructorOptions] -> []
## Алиас для controller.assignMiddleware, если удобнее писать ^router.assignMiddleware[...]
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
  $lRouteTo[^self._makeRouteTo[$aRouteTo]]
  $lRoute[
    $.pattern[$lCompiledPattern.pattern]
    $.regexp[$lCompiledPattern.regexp]
    $.compiledRegexp[^regex::create[$lCompiledPattern.regexp][]]
    $.vars[$lCompiledPattern.vars]
    $.trap[$lCompiledPattern.trap]

    $.routeTo[$lRouteTo.routeTo]

    $.defaults[^hash::create[$aOptions.defaults]]
    $.where[^hash::create[$aOptions.where]]
    $.as[^self.trimPath[^self.ifdef[$aOptions.as]{$lRouteTo.routeTo}]]
  ]
  $lRoute.processor[$lRouteTo.processor]
  $self.routes.[^math:uid64[]][$lRoute]

  ^if(!def $lRoute.pattern){$self.hasRootRoute(true)}

# Добавляем маршрут в обратный индекс
  ^if(def $lRoute.as){
    $self._reverseIndex.[$lRoute.as][^self.ifcontains[$self._reverseIndex;$lRoute.as]{^hash::create[]}]
    $self._reverseIndex.[$lRoute.as].[^math:uid64[]][$lRoute]
  }

@_makeRouteTo[aRouteTo] -> [$.routeTo[] $.processor[]]
  $result[$.routeTo[]]
  ^if($aRouteTo is pfRouterProcessor){
    $result.processor[$aRouteTo]
  }($aRouteTo is hash){
    $result.processor[^self.createProcessor[^aRouteTo.at[first;key];^aRouteTo.at[first;value]]]
  }{
    $lParsedRouteTo[^aRouteTo.match[$self._pfRouterProcessorRegexp]]
    $result.routeTo[$lParsedRouteTo.2]
    $result.processor[^self.createProcessor[$lParsedRouteTo.1;$lParsedRouteTo.2]]
  }

@route[aAction;aRequest;aOptions] -> [$.action $.request $.processor $.defaults]
## Выполняет поиск и преобразование пути по списку маршрутов
  ^self.cleanMethodArgument[]
  $result[^hash::create[]]
  $result.action[^self.trimPath[$aAction]]
  $result.request[$aRequest]

  ^if(def $aAction || $self.hasRootRoute){
    ^self.routes.foreach[k;it]{
      $lParsedPath[^self.parsePathByRoute[$result.action;$it;$.args[$self._defaults]]]
      ^if($lParsedPath){
        ^result.request.assign[$lParsedPath.args]
        $result.action[$lParsedPath.action]
        $result.processor[$it.processor]

        $lDefaults[^hash::create[$self._defaults]]
        ^lDefaults.add[$it.defaults]
        $result.defaults[$lDefaults]
        ^break[]
      }
    }
  }
  $result.processor[^ifdef[$result.processor]{^self.createProcessor[default]}]

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
    ^lRoutes.foreach[k;it]{
      $lPath[^self.applyPath[$it.pattern;$aArgs]]
#     Проверяем соответствует ли полученный путь шаблоу (с ограничениями «where»)
      ^if(^lPath.match[$it.regexp][n]){
#       Добавляем оставшиеся параметры из aArgs или aOptions.form в result.args
        $result.path[$lPath]
        $result.args[^if($lOnlyPatternsVar){^hash::create[$aOptions.form]}{$aArgs}]
        ^result.args.sub[$it.vars]
        ^break[]
      }
    }
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

@OPTIONS
locals

@create[aRouter;aProcessorData;aOptions] ::constructor
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

@create[aRouter;aProcessorData;aOptions]
  ^BASE:create[$aRouter;$aProcessorData;$aOptions]

@process[aAction;aRequest;aPrefix;aOptions]
  $lController[$self.controller]
  $lAction[$aAction]
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

@makeActionName[aAction]
## Формирует имя метода для экшна.
  ^if(def $aAction){
    $aAction[^aAction.lower[]]
    $lSplitted[^pfString:rsplit[$aAction;[/\.]]]
    ^if($lSplitted){
     $result[on^lSplitted.menu{$lStr[$lSplitted.piece]$lFirst[^lStr.left(1)]^lFirst.upper[]^lStr.mid(1)}]
   }
  }{
     $result[onINDEX]
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
  $result[^self.makeActionName[$aAction]]

# Ищем onActionHTTPMETHOD-обработчик
  $lMethod[^aRequest.method.upper[]]
  ^if(def $result && $self.controller.[${result}$lMethod] is junction){
    $result[${result}$lMethod]
  }

# Если обработчика нет, то ищем onDEFAULT.
  ^if(!def $result || !($self.controller.[$result] is junction)){
    $result[^if($self.controller.onDEFAULT is junction){onDEFAULT}]
  }

#--------------------------------------------------------------------------------------------------

@CLASS
pfRouterRenderProcessor

@BASE
pfRouterProcessor

@OPTIONS
locals

@create[aRouter;aProcessorData;aOptions]
  ^BASE:create[$aRouter;$aProcessorData;$aOptions]
  ^if($aProcessorData is hash){
    $self.template[^aProcessorData.template.trim[/ .]]
    $self.context[^hash::create[$aProcessorData.context]]
  }{
     $self.template[^aProcessorData.trim[/ .]]
   }

@process[aAction;aRequest;aPrefix;aOptions]
  $result[^self.controller.render[$self.template;$self.context]]

#--------------------------------------------------------------------------------------------------

@CLASS
pfRouterCallProcessor

@BASE
pfRouterProcessor

@OPTIONS
locals

@create[aRouter;aProcessorData;aOptions]
  ^BASE:create[$aRouter;$aProcessorData;$aOptions]
  $self.functionName[^aProcessorData.trim[/ .]]

@process[aAction;aRequest;aPrefix;aOptions]
  $result[^self.controller.[$self.functionName][$aRequest]]

#--------------------------------------------------------------------------------------------------

@CLASS
pfRequest

## Собирает в одном объекте все параметры http-запроса, доступные в Парсере.

@OPTIONS
locals

@create[aOptions]
## aOptions — хеш с переменными объекта, которые надо заменить. [Для тестов.]
  $aOptions[^hash::create[$aOptions]]

  $self.ifdef[$pfClass:ifdef]
  $self.ifcontains[$pfClass:ifcontains]
  $self.__CONTEXT__[^hash::create[]]

  $self.form[^self.ifdef[$aOptions.form]{$form:fields}]
  $self.tables[^self.ifdef[$aOptions.tables]{$form:tables}]
  $self.files[^self.ifdef[$aOptions.files]{$form:files}]

  $self.cookie[^self.ifdef[$aOptions.cookie]{$cookie:fields}]
  $self.headers[^self.ifdef[$aOptions.headers]{$request:headers}]

  $self.method[^self.ifdef[^aOptions.method.lower[]]{^request:method.lower[]}]
# Если нам пришел post-запрос с полем _method, то берем method из запроса.
  ^if($self.method eq "post" && def $self.form._method){
    $self.method[^self.form._method.lower[]]
  }

  $self.ENV[^self.ifdef[$aOptions.ENV]{$env:fields}]

  $self.URI[^self.ifcontains[$aOptions;URI]{$request:uri}]
  $self.QUERY[^self.ifcontains[$aOptions;QUERY]{$request:query}]
  $self.PATH[^self.URI.left(^self.URI.pos[?])]

  $self.ACTION[^self.ifcontains[$aOptions;ACTION]{^self.PATH.trim[/]}]

  $self.PORT[^self.ifdef[$aOptions.PORT]{^self.ENV.SERVER_PORT.int(80)}]
  $self.isSECURE(^self.ifcontains[$aOptions;isSECURE](^self.ENV.HTTPS.lower[] eq "on" || $self.PORT eq "443"))
  $self.SCHEME[http^if($self.isSECURE){s}]

  $self.HOST[^self.ifdef[$aOptions.HOST]{^self.header[X-Forwarded-Host;^self.header[Host;$self.ENV.SERVER_NAME]]}]
  $self.HOST[$self.HOST^if($self.PORT ne "80" && ($self.isSECURE && $self.PORT ne "443")){:$self.PORT}]

# Проверяет является ли Referer локальным.
  $self.REFERER[^self.header[Referer]]
  $self.isLOCALREFERER(^self.REFERER.pos[${self.SCHEME}://$self.HOST] == 0)

  $self.REMOTE_IP[^self.ifdef[$aOptions.REMOTE_IP]{$ENV.REMOTE_ADDR}]
  $self.DOCUMENT_ROOT[^self.ifcontains[$aOptions;DOCUMENT_ROOT]{$request:document-root}]

  $self.CHARSET[^self.ifdef[$aOptions.CHARSET]{$request:charset}]
  $self.RESPONSE_CHARSET[^self.ifdef[$aOptions.RESPONSE_CHARSET]{^response:charset.lower[]}]
  $self.POST_CHARSET[^self.ifdef[$aOptions.POST_CHARSET]{^request:post-charset.lower[]}]
  $self.BODY_CHARSET[^self.ifdef[$aOptions.BODY_CHARSET]{^request:body-charset.lower[]}]

  $self.BODY[^self.ifdef[$aOptions.BODY]{$request:body}]
  $self._BODY_FILE[$aOptions.BODY_FILE]

@GET[aContext]
  $result($self.form || $self.__CONTEXT__)

@GET_DEFAULT[aName]
  $result[^if(^self.__CONTEXT__.contains[$aName]){$self.__CONTEXT__.[$aName]}{$form.[$aName]}]

@GET_BODY_FILE[]
  $result[^if(def $self._BODY_FILE){$self._BODY_FILE}{$self.request:body-file}]

@GET_isAJAX[]
  $result(^self.ifdef[$aOptions.isAJAX](^self.headers.[X_REQUESTED_WITH].pos[XMLHttpRequest] > -1))

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
  $result[$headers.[^lName.upper[]]]
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

  $self._body[$aBody]
  $self._download[]

  $self._type[^self.ifdef[$aOptions.type]{html}]

  $self.contentType[^self.ifdef[$aOptions.contentType]]
  $self.status(^self.ifdef[$aOptions.status]{200})
  $self.charset[^self.ifdef[$aOptions.charset]{$response:charset}]

  $self.headers[^hash::create[$aOptions.headers]]
  $self.cookie[^hash::create[$aOptions.cookie]]

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
      $.value[^self.ifdef[$self.contentType]{text/html}]
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
## aPath — полный путь для редиректа или uri
## aStatus[302]
  ^BASE:create[;$.type[redirect] $.status[^ifdef[$aStatus]{302}]]
  $self.headers.location[^untaint{$aLocation}]

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
