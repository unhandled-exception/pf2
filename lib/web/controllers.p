# PF2 Library

@USE
pf2/lib/common.p
pf2/lib/sql/connection.p
pf2/lib/web/auth.p
pf2/lib/web/templates.p


## Веб-фреймворк

@CLASS
pfModule

# Базовый модуль-контроллер. Реализует логику обработки запроса ии поиска обработчика.

@BASE
pfClass

@create[aOptions]
## Конструктор класса
## aOptions.mountPoint[/] - место монтирования. Нужно передавать только в головной модуль,
##                          поскольку метод assignModule будт вычислять точку монтирования самостоятельно.
## aOptions.parentModule - ссылка на объект-контейнер.
## aOptions.appendSlash(false) - нужно ли добавлять к урлам слеш.
  ^BASE:create[]
  $aOptions[^hash::create[$aOptions]]

  ^pfChainMixin:mixin[$self;
    ^hash::create[$aOptions]
    $.exportModulesProperty(true)
  ]

  $_throwPrefix[pfModule]
  $_name[$aOptions.name]

  $_parentModule[$aOptions.parentModule]

  $_mountPoint[^if(def $aOptions.mountPoint){$aOptions.mountPoint}{/}]
  $uriPrefix[$_mountPoint]
  $_localUriPrefix[]

  $_router[]
  $_appendSlash(^aOptions.appendSlash.bool(true))

  $_action[]
  $_activeModule[]
  $_request[]

@auto[]
  $_pfModuleCheckDotRegex[^regex::create[\.[^^/]+?/+^$][n]]
  $_pfModuleRepeatableSlashRegex[^regex::create[/+][g]]

@GET_mountPoint[]
  $result[$_mountPoint]

@GET_uriPrefix[]
  $result[$_uriPrefix]

@SET_uriPrefix[aUriPrefix]
  $_uriPrefix[^aUriPrefix.trim[right;/.]/]
  $_uriPrefix[^_uriPrefix.match[$_pfModuleRepeatableSlashRegex][][/]]

@GET_localUriPrefix[]
  $result[$_localUriPrefix]

@SET_localUriPrefix[aLocalUriPrefix]
  $_localUriPrefix[^aLocalUriPrefix.trim[right;/]]
  $_localUriPrefix[^_localUriPrefix.match[$_pfModuleRepeatableSlashRegex][][/]]

@GET_action[]
  $result[$_action]

@GET_activeModule[]
  $result[$_activeModule]

@GET_request[]
  $result[$_request]

@GET_router[]
  ^if(!def $_router){
    $_router[^pfRouter::create[]]
  }
  $result[$_router]

@GET_appendSlash[]
  $result($_appendSlash)

@SET_appendSlash[aValue]
  $_appendSlash(^aValue.bool(true))

@GET_PARENT[]
  $result[$_parentModule]

@hasModule[aName]
## Проверяет есть ли у нас модуль с имененм aName
  $result(^MODULES.contains[$aName])

@hasAction[aAction][lHandler]
## Проверяем есть ли в модуле обработчик aAction
  $lHandler[^_makeActionName[$aAction]]
  $result($$lHandler is junction)

@assignModule[aName;aClassDef;aOptions][locals]
## aName — имя свойства со ссылкой на модуль.
## aClassDef[path/to/package.p@className::constructor]
## aOptions — параметры, которые передаются конструктору.
## aOptions.mountTo[$aName] - точка монтирования относительно текущего модуля.
  ^cleanMethodArgument[]
  ^pfAssert:isTrue(def $aName)[Не задано имя для модуля.]

  $aName[^aName.lower[]]
  $lMountTo[^if(def $aOptions.mountTo){^aOptions.mountTo.lower[]}{$aName}]
  $lMountTo[^lMountTo.trim[both;/]]

  ^__pfChainMixin__.assignModule[$aName;$aClassDef;$aOptions]

# Добавляем в хэш с модулями данные о модуле
  $lModule[$MODULES.[$aName]]
  $lModule.mountTo[$lMountTo]
  $lModule.mountPoint[${_mountPoint}$lMountTo/]

# Перекрываем uriPrefix, который пришел к нам в $aOptions.args.
# Возможно и не самое удачное решение, но позволяет сохранить цепочку.
  $lModule.args.mountPoint[$lModule.mountPoint]
  $lModule.args.templatePrefix[^ifdef[$lModule.args.templatePrefix]{${_mountPoint}$aName/}]
  $lModule.args.parentModule[^ifdef[$lModule.args.parentModule]{$self}]

@dispatch[aAction;aRequest;aOptions][lProcessed]
## Производим обработку экшна
## aAction    Действие, которое необходимо выполнить
## aRequest   Параметры экшна
## aOptions.prefix
  ^cleanMethodArgument[aRequest]
  ^cleanMethodArgument[]
  $result[]

  $lAction[^if(def $aAction){^aAction.trim[both;/.]}]

  $lProcessed[^processRequest[$lAction;$aRequest;$aOptions]]
  $lProcessed.action[^lProcessed.action.lower[]]

  $_action[$lProcessed.action]
  $_request[$lProcessed.request]

  $result[^processAction[$lProcessed.action;$lProcessed.request;$lProcessed.prefix;^hash::create[$aOptions] $.render[$lProcessed.render]]]
  $result[^processResponse[$result;$lProcessed.action;$lProcessed.request;$aOptions]]

@processRequest[aAction;aRequest;aOptions][locals]
## Производит предобработку запроса
## $result[$.action[] $.request[] $.prefix[] $.render[]] - экшн, запрос, префикс, параметры шаблона, которые будут переданы обработчикам
  $lRewrite[^rewriteAction[$aAction;$aRequest]]
  $aAction[$lRewrite.action]
  ^if($lRewrite.args){
    ^aRequest.assign[$lRewrite.args]
  }
  $result[$.action[$aAction] $.request[$aRequest] $.prefix[$lRewrite.prefix] $.render[$lRewrite.render]]

@rewriteAction[aAction;aRequest;aOtions]
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

@processAction[aAction;aRequest;aLocalPrefix;aOptions][locals]
## Производит вызов экшна.
## aOptions.prefix - префикс, сформированный в processRequest.
  $lAction[$aAction]
  $lRequest[$aRequest]
  ^if(def $aLocalPrefix){$self.localUriPrefix[$aLocalPrefix]}
  ^if(def $aOptions.prefix){$self.uriPrefix[$aOptions.prefix]}

# Формируем специальную переменную $CALLER, чтобы передать текущий контекст
# из которого вызван dispatch. Нужно для того, чтобы можно было из модуля
# получить доступ к контейнеру.
# [На самом деле у нас теперь есть свойство PARENT].
  $CALLER[$self]

# Если у нас в первой части экшна имя модуля, то передаем управление ему
  $lModule[^_findModule[$aAction]]
  ^if(def $lModule){
#   Если у нас есть экшн, совпадающий с именем модуля, то зовем его.
#   При этом отсекая имя модуля от экшна перед вызовом (восстанавливаем после экшна).
    $self._activeModule[$lModule]
    $lModuleMountTo[$MODULES.[$lModule].mountTo]

    ^if(^hasAction[$lModuleMountTo]){
      $self._action[^lAction.match[^^^taint[regex][$lModuleMountTo] (.*)][x]{^match.1.lower[]}]
      $result[^self.[^_makeActionName[$lModuleMountTo]][$lRequest]]
      $self._action[$lAction]
    }{
       $result[^self.[^lModule.lower[]].dispatch[^lAction.mid(^lModuleMountTo.length[]);$lRequest;
         $.prefix[$uriPrefix/^if(def $aLocalPrefix){$aLocalPrefix/}{$lModuleMountTo/}]
       ]]
     }
  }{
#   Если модуля нет, то пытаемся найти и запустить экш из нашего модуля
#   Если не получится, то зовем onDEFAULT, а если и это не получится,
#   то выбрасываем эксепшн.
     $lHandler[^_findHandler[$lAction;$lRequest]]
     ^if(def $lHandler){
       $result[^self.[$lHandler][$lRequest]]
     }{
        ^throw[module.dispatch.action.not.found;Action "$lAction" not found.]
      }
   }

@processResponse[aResponse;aAction;aRequest;aOptions]
## Производит постобработку результата выполнения экшна.
  $result[$aResponse]

@linkTo[aAction;aOptions;aAnchor][locals]
## Формирует ссылку на экшн, выполняя бэкрезолв путей.
## aOptions - объект, который поддерживает свойство $aOptions.fields (хеш, таблица и пр.)
  ^cleanMethodArgument[]
  $lReverse[^router.reverse[$aAction;$aOptions.fields]]
  ^if($lReverse){
    $result[^_makeLinkURI[$lReverse.path;$lReverse.args;$aAnchor;$lReverse.reversePrefix]]
  }{
     $result[^_makeLinkURI[$aAction;$aOptions.fields;$aAnchor]]
   }

@redirectTo[aAction;aOptions;aAnchor]
## Редирект на экшн. Реализация в потомках.
  $result[]

@linkFor[aAction;aObject;aOptions][locals]
## Формирует ссылку на объект
## aObject[<hash>]
## aOptions.form — поля, которые надо добавить к объекту/маршруту
## aOptions.anchor — «якорь»
  ^cleanMethodArgument[]
  $lReverse[^router.reverse[$aAction;$aObject;$.form[$aOptions.form] $.onlyPatternVars(true)]]
  ^if($lReverse){
    $result[^_makeLinkURI[$lReverse.path;$lReverse.args;$aOptions.anchor;$lReverse.reversePrefix]]
  }{
     $result[^_makeLinkURI[$aAction;$aOptions.form;$aAnchor]]
   }

@redirectFor[aAction;aObject;aOptions]
## Редирект на объект. Реализация в потомках.
  $result[]

@_makeLinkURI[aAction;aOptions;aAnchor;aPrefix]
## Формирует url для экшна
## $uriPrefix$aAction?aOptions.foreach[key=value][&]#aAnchor
  ^cleanMethodArgument[]
  ^if(def $aAction){$aAction[^aAction.trim[both;/.]]}

  $result[${uriPrefix}^if(def $aPrefix){^aPrefix.trim[both;/]/}{^if(def $localUriPrefix){$localUriPrefix/}}^if(def $aAction){^taint[uri][$aAction]^if($_appendSlash){/}}]
  ^if($_appendSlash && def $result && ^result.match[$_pfModuleCheckDotRegex]){$result[^result.trim[end;/]]}

  ^if($aOptions is hash && $aOptions){
    $result[${result}?^aOptions.foreach[key;value]{$key=^taint[uri][$value]}[^taint[&]]]
  }
  ^if(def $aAnchor){$result[${result}#$aAnchor]}

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
        $result[$k]
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
pfHTTPRequest

## Собирает в одном объекте все параметры http-запроса, доступные в Пасрере.

@create[aOptions][ifdef]
## aOptions — хеш с переменными объекта, которые надо заменить. [Для тестов.]
  $ifdef[$pfClass:ifdef]
  $__CONTEXT__[^hash::create[]]

  $fields[^ifdef[$aOptions.fields]{$form:fields}]
  $tables[^ifdef[$aOptions.tables]{$form:tables}]
  $files[^ifdef[$aOptions.files]{$form:files}]

  $cookies[^ifdef[$aOptions.cookies]{$cookie:fields}]
  $headers[^ifdef[$aOptions.headers]{$request:headers}]

  $method[^ifdef[^aOptions.method.lower[]]{^request:method.lower[]}]
# Если нам пришел post-запрос с полем _method, то берем method из запроса.
  ^if($method eq "post" && def $fields._method){
    $method[^switch[^fields._method.lower[]]{
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

  $ACTION[^ifdef[$aOptions.ACTION]{^ifdef[$fields.action]{$fields._action}}]

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
  $result($fields || $__CONTEXT__)

@GET_DEFAULT[aName]
  $result[^if(^__CONTEXT__.contains[$aName]){$__CONTEXT__.[$aName]}{$fields.[$aName]}]

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
  $result(^__CONTEXT__.contains[$aName] || ^fields.contains[$aName])

@foreach[aKeyName;aValueName;aCode;aSeparator][locals]
  $lFields[^hash::create[$fields]]
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

@absoluteUrl[aLocation]
## Возвращает полный url для запроса.
## aLocation — адрес страницы вместо URI.
  $aLocation[^pfClass:ifdef[$aLocation]{$URI}]
  ^if(^aLocation.left(1) ne "/"){
    $aLocation[/$aLocation]
  }
  $result[${SCHEME}://${HOST}$aLocation]

#--------------------------------------------------------------------------------------------------

@CLASS
pfHTTPResponse

## Класс с http-ответом.

@BASE
pfClass

@create[aBody;aOptions]
## aBody
## aOptions.type[html] - тип ответа
## aOptions.status(200) - http-статус
## aOptions.contentType[]
## aOptions.charset[]
## aOptions.canDownload(false)
  ^cleanMethodArgument[]

  $_body[$aBody]

  $_type[^if(def $aOptions.type){$aOptions.type}{html}]
  $_contentType[^if(def $aOptions.contentType){$aOptions.contentType}]
  $_status(^if(def $aOptions.status){$aOptions.status}{200})
  $_charset[^if(def $aOptions.charset){$aOptions}]

  $_canDownload($aOptions.canDownload)

  $_headers[^hash::create[]]
  $_cookie[^hash::create[]]

@GET_type[]
  $result[$_type]

@SET_type[aType]
  $_type[$aType]

@GET_body[]
  $result[$_body]

@SET_body[aBody]
  $_body[$aBody]

@GET_canDownload[]
  $result($_canDownload)

@GET_download[]
  $result[^if($canDownload){$body}]

@GET_contentType[]
  $result[$_contentType]

@SET_contentType[aContentType]
  $_contentType[$aContentType]

@GET_content-type[]
# Для совместимости
  $result[$_contentType]

@SET_content-type[aContentType]
  $_contentType[$aContentType]

@GET_status[]
  $result($_status)

@SET_status[aStatus]
  $_status($aStatus)

@GET_charset[]
  $result[$_charset]

@SET_charset[aCharset]
  $_charset[$aCharset]

@GET_headers[]
  $result[$_headers]

@GET_cookie[]
  $result[$_cookie]


## Наследники класса http-ответа с разными статусами.

@CLASS
pfHTTPResponseRedirect

@BASE
pfHTTPResponse

@create[aPath]
## aPath - полный путь для редиректа или uri
  ^BASE:create[;$.type[redirect] $.status(302)]
  $headers.location[^untaint{$aPath}]


@CLASS
pfHTTPResponsePermanentRedirect

@BASE
pfHTTPResponse

@create[aPath]
## aPath - полный путь для редиректа или uri
  ^BASE:create[;$.type[redirect] $.status(301)]
  $headers.location[^untaint{$aPath}]


@CLASS
pfHTTPResponseNotFound

@BASE
pfHTTPResponse

@create[aBody;aOptions]
  ^BASE:create[$aBody;$aOptions]
  $status(404)


@CLASS
pfHTTPResponseBadRequest

@BASE
pfHTTPResponse

@create[aBody;aOptions]
  ^BASE:create[$aBody;$aOptions]
  $status(400)


@CLASS
pfHTTPResponseNotModified

@BASE
pfHTTPResponse

@create[aBody;aOptions]
  ^BASE:create[$aBody;$aOptions]
  $status(304)


@CLASS
pfHTTPResponseNotAllowed

@BASE
pfHTTPResponse

@create[aBody;aOptions]
  ^BASE:create[$aBody;$aOptions]
  $status(405)


@CLASS
pfHTTPResponseForbidden

@BASE
pfHTTPResponse

@create[aBody;aOptions]
  ^BASE:create[$aBody;$aOptions]
  $status(403)


@CLASS
pfHTTPResponseGone

@BASE
pfHTTPResponse

@create[aBody;aOptions]
  ^BASE:create[$aBody;$aOptions]
  $status(410)


@CLASS
pfHTTPResponseServerError

@BASE
pfHTTPResponse

@create[aBody;aOptions]
  ^BASE:create[$aBody;$aOptions]
  $status(500)

#--------------------------------------------------------------------------------------------------

@CLASS
pfSiteModule

@BASE
pfModule

@create[aOptions]
## Создаем модуль. Если нам передали объекты ($.sql, и т.п.),
## то используем их, иначе вызываем соотвествующие фабрики и передаем
## им параметры xxxType, xxxOptions.
## aOptions.asManager(false) — использовать модуль как менеджер.
## aOptions.passDefaultPost(!asManager) — пропустить постобработку.
## aOptions.sql
## aOptions.sqlConnectString[$MAIN:SQL.connect-string]
## aOptions.sqlOptions
## aOptions.auth
## aOptions.authType
## aOptions.authOptions
## aOptions.template
## aOptions.templateOptions
## aOptions.templatePrefix
## aOptions.request
## aOptions.uriProtocol
## aOptions.uriServerName
  ^cleanMethodArgument[]

  $aOptions.exportFields[
    ^hash::create[$aOptions.exportFields]
    $.sql[CSQL]
    $.auth[AUTH]
    $.template[TEMPLATE]
    $.templateOptions[_templateOptions]
  ]

  ^BASE:create[$aOptions]

  $_asManager(^aOptions.asManager.bool(false))
  $_passDefaultPost(^aOptions.passDefaultPost.bool(!$_asManager))

  $_redirectExceptionName[pf.site.module.redirect]
  $_permanentRedirectExceptionName[pf.site.module.permanent_redirect]

  $_responseType[html]
  $_createOptions[$aOptions]

  $templatePath[^if(^aOptions.contains[templatePrefix]){$aOptions.templatePrefix}{$mountPoint}]
  $_templateOptions[$aOptions.templateOptions]

  $_sql[$aOptions.sql]
  $_auth[$aOptions.auth]
  $_template[$aOptions.template]

  $_templateVars[^hash::create[]]

# Переменные для менеджера
  $_REQUEST[$aOptions.request]
  $_uriProtocol[$aOptions.uriProtocol]
  $_uriServerName[$aOptions.uriServerName]

@auto[]
# Дополнительная таблица mime-типов
# Можно расширить в наследниках для поддержки нужных типов.
  $_PFSITEMODULE_EXT_MIME[
    $.css[text/css]
    $.csv[text/csv]
    $.docx[application/vnd.openxmlformats-officedocument.wordprocessingml.document]
    $.flv[video/x-flv]
    $.gz[application/x-gzip]
    $.json[application/json]
    $.js[application/javascript]
    $.odc[application/vnd.oasis.opendocument.chart]
    $.odf[application/vnd.oasis.opendocument.formula]
    $.odg[application/vnd.oasis.opendocument.graphics]
    $.odi[application/vnd.oasis.opendocument.image]
    $.odp[application/vnd.oasis.opendocument.presentation]
    $.ods[application/vnd.oasis.opendocument.spreadsheet]
    $.odt[application/vnd.oasis.opendocument.text]
    $.ogg[audio/ogg]
    $.pptx[application/vnd.openxmlformats-officedocument.presentationml.presentation]
    $.rar[application/x-rar-compressed]
    $.rdf[application/rdf+xml]
    $.rss[application/rss+xml]
    $.tar[application/x-tar]
    $.woff[application/font-woff]
    $.xlsx[application/vnd.openxmlformats-officedocument.spreadsheetml.sheet]
    $.xul[application/vnd.mozilla.xul+xml]
  ]
# Стандартный mime-тип
  $_PFSITEMODULE_DEFAULT_MIME[application/octet-stream]

@processAction[aAction;aRequest;aPrefix;aOptions][lRedirectPath]
## aOptions.passWrap(false) - не формировать объект вокруг ответа из строк и чисел.
## aOptions.passRedirect(false) - не обрабатывать эксепшн от редиректа.
  ^cleanMethodArgument[]
  ^try{
    ^if(def $aOptions.render && def $aOptions.render.template){
      $result[^render[$aOptions.render.template;$.vars[$aOptions.render.vars]]]
    }{
       $result[^BASE:processAction[$aAction;$aRequest;$aPrefix;$aOptions]]
     }

    ^if(!^aOptions.passWrap.bool(false)){
      ^switch(true){
        ^case($result is hash){
          ^if(!def $result.type){$result.type[$_responseType]}
          ^if(!def $result.status){$result.status[200]}
          ^if(!def $result.headers){$result.headers[^hash::create[]]}
          ^if(!def $result.cookie){$result.cookie[^hash::create[]]}
        }
        ^case($result is string || $result is double){
          $result[^pfHTTPResponse::create[$result;$.type[$responseType]]]
        }
      }
    }

  }{
    ^if(!^aOptions.passRedirect.bool(false)){
      ^switch[$exception.type]{
        ^case[$_redirectExceptionName;$_permanentRedirectExceptionName]{
          $exception.handled(true)
          $lRedirectPath[^if(^exception.comment.match[^^https?://][n]){$exception.comment}{^aRequest.absoluteUrl[$exception.comment]}]
          ^if($exception.type eq $_permanentRedirectExceptionName){
            $result[^pfHTTPResponsePermanentRedirect::create[$lRedirectPath]]
          }{
             $result[^pfHTTPResponseRedirect::create[$lRedirectPath]]
           }
        }
      }
    }
  }

@processResponse[aResponse;aAction;aRequest;aOptions][lPostDispatch]
## aOptions.passPost(false) - не делать постобработку запроса.
  ^cleanMethodArgument[]
  $result[^BASE:processResponse[$aResponse;$aAction;$aRequest;$aOptions]]

  ^if(!^aOptions.passPost.bool(false)){
    $lPostDispatch[post^result.type.upper[]]
    ^if($self.[$lPostDispatch] is junction){
      $result[^self.[$lPostDispatch][$result]]
    }{
       ^if($postDEFAULT is junction){
         $result[^postDEFAULT[$result]]
       }
     }
  }

@render[aTemplateName;aOptions][lTemplatePrefix;lVars]
## Вызывает шаблон с именем "путь/$aTemplateName[.pt]"
## Если aTemplateName начинается со "/", то не подставляем текущий перфикс.
## Если переменная aTemplateName не задана, то зовем шаблон default.
## aOptions.vars - переменные, которые добавляются к тем, что уже заданы через assignVar.
  ^cleanMethodArgument[]
  ^if(!def $aTemplateName || ^aTemplateName.left(1) ne "/"){
     $lTemplatePrefix[$templatePath]
  }

  $lVars[^hash::create[$_templateVars]]
  ^if(def $aOptions.vars){^lVars.add[$aOptions.vars]}
  ^if(!^lVars.contains[REQUEST]){$lVars.REQUEST[$request]}
  ^if(!^lVars.contains[ACTION]){$lVars.ACTION[$action]}
  ^if(!^lVars.contains[linkTo]){$lVars.linkTo[$linkTo]}
  ^if(!^lVars.contains[redirectTo]){$lVars.redirectTo[$redirectTo]}
  ^if(!^lVars.contains[linkFor]){$lVars.linkFor[$linkFor]}
  ^if(!^lVars.contains[redirectFor]){$lVars.redirectFor[$redirectFor]}

  $result[^TEMPLATE.render[${lTemplatePrefix}^if(def $aTemplateName){$aTemplateName^if(!def ^file:justext[$aTemplateName]){.pt}}{default.pt};
    $.vars[$lVars]
    $.force($aOptions.force)
    $.engine[$aOptions.engine]
  ]]

@assignVar[aVarName;aValue]
## Задает переменную для шаблона
  $_templateVars.[$aVarName][$aValue]
  $result[]

@multiAssignVar[aVars]
## Задает сразу несколько переменных в шаблон.
  ^aVars.foreach[k;v]{
    ^assignVar[$k;$v]
  }

@redirectTo[aAction;aOptions;aAnchor;aIsPermanent]
  ^throw[^if(^aIsPermanent.bool(false)){$_permanentRedirectExceptionName}{$_redirectExceptionName};$action;^if(^aAction.match[^^https?://][n]){$aAction}{^linkTo[$aAction;$aOptions;$aAnchor]}]

@redirectFor[aAction;aObject;aOptions]
## aOptions - аналогично linkFor
## aOptions.permanent(false)
  ^cleanMethodArgument[]
  ^throw[^if(^aOptions.permanent.bool(false)){$_permanentRedirectExceptionName}{$_redirectExceptionName};$action;^if(^aAction.match[^^https?://][n]){$aAction}{^linkFor[$aAction;$aObject;$aOptions]}]


#----- Методы менеджера -----

@run[aOptions][locals]
## Основной процесс обработки запроса (как правило перекрывать не нужно).
## Не забудьте задать в конструкторе параметр asManager, чтобы сработала постобработка.
  $lRequest[$REQUEST]
  $lAction[$lRequest._action]
  ^authenticate[$lAction;$lRequest]
  $result[^dispatch[$lAction;$lRequest]]

@authenticate[aAction;aRequest]
## Производит авторизацию.
  ^if(^AUTH.identify[$aRequest]){
    $result[^onAUTHSUCCESS[$aRequest]]
   }{
      $result[^onAUTHFAILED[$aRequest]]
    }

#----- Свойства -----

@GET_asManager[]
  $result($_asManager)

@GET_AUTH[]
  ^if(!def $_auth){
     $_auth[^authFactory[$_createOptions.authType;$_createOptions.authOptions]]
  }
  $result[$_auth]

@GET_CSQL[]
  ^if(!def $_sql){
      $_sql[^sqlFactory[^if(def $_createOptions.sqlConnectString){$_createOptions.sqlConnectString}{$MAIN:SQL.connect-string};$_createOptions.sqlOptions]]
  }
  $result[$_sql]

@GET_TEMPLATE[]
  ^if(!def $_template){
     $_template[^templateFactory[$_createOptions.templateOptions]]
  }
  $result[$_template]

@SET_templatePath[aPath]
  $_templatePath[^if(def $aPath){^aPath.trim[both;/]}/]

@GET_templatePath[]
  $result[$_templatePath]

@GET_responseType[]
  $result[$_responseType]

@SET_responseType[aValue]
  $_responseType[$aValue]

@GET_uriProtocol[]
  ^if(!def $uriProtocol){
    $_uriProtocol[^if($REQUEST.isSECURE){https}{http}]
  }
  $result[$_uriProtocol]

@GET_uriServerName[]
  ^if(!def $_uriServerName){
    $_uriServerName[$REQUEST.META.SERVER_NAME]
  }
  $result[$_uriServerName]

@GET_REQUEST[]
  ^if(!def $_REQUEST){
    $_REQUEST[^pfHTTPRequest::create[]]
  }
  $result[$_REQUEST]

#----- События и обработчики ответов -----

# Обработчик ответа будет вызываться после диспатча по следующему алгоритму:
# сначала пытаемся вызвать обработчик postTYPE, а если его нет, то зовем
# postDEFAULT.

#@postHTML[aResponse]
#@postXML[aResponse]
#@postTEXT[aResponse]
#@postREDIRECT[aResponse]
#@postDEFAULT[aResponse]

# aResponse[$.type[as-is|html|xml|file|text|...|redirect] $.body[] ...] - хэш с данными ответа.
# Поля, которые могут быть обработаны контейнерами:
# $.content-type[] $.charset[] $.headers[] $.status[] $.cookie[]
# Для типа "file" можно положить ответ не в поле body, а в поле download.

@onNOTFOUND[aRequest]
## Переопределить, если необходима отдельная обработка неизвестного экшна (аналог "404").
  $result[]
  ^if($self.onINDEX is junction || $self.onDEFAULT is junction){
    ^redirectTo[/]
  }{
     ^throw[pfSiteModule.action.not.found;Action "$action" not found.]
   }

@onAUTHSUCCESS[aRequest]
## Вызывается при удачной авторизации.
  $result[]

@onAUTHFAILED[aRequest]
## Вызывается при неудачной авторизации
  $result[]

#---- Пост-обработчики для менеджера ----

@postDEFAULT[aResponse]
  $result[$aResponse]
  ^if(!$_passDefaultPost){
    ^throw[pfSiteModule.postDEFAULT;Unknown response type "$aResponse.type".]
  }

@postAS-IS[aResponse]
  ^if($_passDefaultPost){
    $result[^postDEFAULT[$aResponse]]
  }{
    $result[]
    ^_setResponseHeaders[$aResponse]
    ^if(def $aResponse.download){
      $response:download[$aResponse.download]
    }{
       $response:body[$aResponse.body]
     }
  }

@postHTML[aResponse]
  ^if($_passDefaultPost){
    $result[^postDEFAULT[$aResponse]]
  }{
    ^if(!def $aResponse.[content-type]){
      $aResponse.content-type[text/html]
    }
    ^_setResponseHeaders[$aResponse]
    $result[$aResponse.body]
  }

@postXML[aResponse]
  ^if($_passDefaultPost){
    $result[^postDEFAULT[$aResponse]]
  }{
    ^if(!def $aResponse.[content-type]){
     $aResponse.content-type[text/xml]
    }
    ^_setResponseHeaders[$aResponse]
    $result[^untaint[xml]{$aResponse.body}]
  }

@postTEXT[aResponse]
  ^if($_passDefaultPost){
    $result[^postDEFAULT[$aResponse]]
  }{
    ^if(!def $aResponse.[content-type]){
      $aResponse.content-type[text/plain]
    }
    ^_setResponseHeaders[$aResponse]
    $result[^untaint[as-is]{$aResponse.body}]
  }

@postFILE[aResponse]
  ^if($_passDefaultPost){
    $result[^postDEFAULT[$aResponse]]
  }{
    $result[]
    ^if(!def $aResponse.[content-type]){
      $aResponse.content-type[application/octet-stream]
    }
    ^if(def $aResponse.download){
      $response:download[$aResponse.download]
    }{
       $response:body[$aResponse.body]
     }
    ^_setResponseHeaders[$aResponse]
  }

@postREDIRECT[aResponse]
  ^if($_passDefaultPost){
    $result[^postDEFAULT[$aResponse]]
  }{
    $result[]
    ^_setResponseHeaders[$aResponse]
  }

#----- Private -----

@_getMimeByExt[aExt]
## Возвращает mime-тип для файла.
## Полезно, если нужно сделать выдачу файлов в браузер.
  ^if(^MAIN:MIME-TYPES.locate[ext;$aExt]){
    $result[$MAIN:MIME-TYPES.mime-type]
  }(^_PFSITEMODULE_EXT_MIME.contains[$aExt]){
     $result[$_PFSITEMODULE_EXT_MIME.[$aExt]]
#    Хак: добавляем тип в MAIN:MIME-TYPES, чтобы он работал для файлов в response:body
     ^MAIN:MIME-TYPES.append{$aExt  $result}
  }{
     $result[$_PFSITEMODULE_DEFAULT_MIME]
   }

@_findHandler[aAction;aRequest][lActionName;lMethod]
## Ищет и возвращает имя функции-обработчика для экшна.
  $result[^BASE:_findHandler[$aAction;$aRequest]]

# Ищем onActionHTTPMETHOD-обработчик
  $lMethod[^if(def $aRequest.METHOD){^aRequest.METHOD.upper[]}]
  ^if(def $lMethod){
    $lActionName[^_makeActionName[$aAction]]
    ^if(def $lActionName && $self.[${lActionName}$lMethod] is junction){$result[${lActionName}$lMethod]}
  }

# Если не определен onDEFAULT, то зовем onNOTFOUND.
  ^if(!def $result && $onNOTFOUND is junction){$result[onNOTFOUND]}

@_setResponseHeaders[aResponse]
  $result[]
  ^if(def $aResponse.charset){$response:charset[$aResponse.charset]}
  $response:content-type[
    $.value[^if(def ${aResponse.content-type}){$aResponse.content-type}{text/html}]
    $.charset[$response:charset]
  ]

  ^if(def $aResponse.headers && $aResponse.headers is hash){
    ^aResponse.headers.foreach[k;v]{
      $response:$k[$v]
    }
  }

  ^if(def $aResponse.cookie && $aResponse.cookie is hash){
    ^aResponse.cookie.foreach[k;v]{
      $cookie:$k[$v]
    }
  }

  ^if(^aResponse.status.int(-1) >= 0){
    $response:status[$aResponse.status]
  }

#----- Фабрики объектов -----

@sqlFactory[aConnectString;aSqlOptions]
# Возвращает sql-объект
  ^if(!def $aConnectString){^throw[pfSiteModule.sqlFactory.fail;Не задана строка соединения с sql-сервером.]}
  $result[^pfSQLConnection::create[$aConnectString;$aOptions]]

@authFactory[aAuthType;aAuthOptions]
# Возвращает auth-объект на основании aAuthType
  ^switch[$aAuthType]{
    ^case[base;DEFAULT]{
      $result[^pfAuthBase::create[$aAuthOptions]]
    }
    ^case[apache]{
      $result[^pfAuthApache::create[$aAuthOptions]]
    }
    ^case[cookie]{
      $result[^pfAuthCookie::create[$aAuthOptions]]
    }
  }

@templateFactory[aTemplateOptions]
# Возвращает template-объект
  $result[^pfTemplate::create[$aTemplateOptions]]

#--------------------------------------------------------------------------------------------------

@CLASS
pfSiteApp

## Модуль для модулей-приложений с отдельной файловой структурой.

@BASE
pfSiteModule

@create[aOptions]
## aOptions.serveStatic(false) — обрабатывать статику на уровне приложения.
## aOptions.appRoot[] — путь к корневой папке приложения.
## aOptions.publicFolder[public]
## aOptions.viewsFolder[views]
  ^cleanMethodArgument[]
  ^BASE:create[$aOptions]

  ^pfAssert:isTrue(def $aOptions.appRoot)[Не задан путь к корневой папке приложения (appRoot).]
  ^pfAssert:isTrue(-d $aOptions.appRoot)[Папка «${aOptions.appRoot}» (appRoot) не найдена.]
  $_appRoot[^aOptions.appRoot.trim[end;/\]]
  ^defReadProperty[appRoot]

  $_publicFolder[^if(def $aOptions.publicFolder){$aOptions.publicFolder}{public}]
  $_viewsFolder[^if(def $aOptions.viewsFolder){$aOptions.viewsFolder}{views}]
  $templatePath[$_appRoot/$_viewsFolder]
  ^TEMPLET.appendPath[/]

  $_serveStatic(^aOptions.serveStatic.bool(false))
  $_publicPath[$_appRoot/$_publicFolder]

@onNOTFOUND[aRequest][locals]
  $lFileName[$_publicPath/$action]
  ^if($_serveStatic && -f $lFileName){
#   Выдаем статику в браузер, если включен режим serveStatic.
#   Штука очень простая и подходит только для отладки.
#   Для работы лучше сделать симлинк или алиас средствами веб-сервера.
    $result[
      $.type[file]
      $.content-type[^_getMimeByExt[^file:justext[$lFileName]]]
      $.body[
        $.file[$lFileName]
      ]
    ]
  }{
     $result[^on404[$aRequest]]
   }

@on404[aRequest]
  $result[^pfHTTPResponseNotFound::create[]]
