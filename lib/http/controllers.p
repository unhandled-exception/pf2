# PF2 Library

@USE
pf2/lib/common.p

## HTTP-фреймворк. Минимальная версия Парсера — 3.4.4.

@CLASS
_pfHTTPRequest

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
# Если метод нам пришел post с полем _method, то берем method из поля.
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

  $isAJAX(^ifdef[$aOptions.isAJAX](^headers.[X_REQUESTED_WITH].pos[XMLHttpRequest] > -1))
  $clientAcceptsJSON(^headers.ACCEPT.pos[application/json] >= 0)
  $clientAcceptsXML(^headers.ACCEPT.pos[application/xml] >= 0)

@GET_DEFAULT[aName]
  $result[^if(^__CONTEXT__.contains[$aName]){$__CONTEXT__.[$aName]}{$fields.[$aName]}]

@GET_BODY_FILE[]
  $result[^if(def $_BODY_FILE){$_BODY_FILE}{$request:body-file}]

@assign[*aArgs]
## Добавляет в запрос поля.
## ^assign[name;value]
## ^assign[$.name[value] ...]
  ^if($aArgs.0 is hash){
    $__CONTEXT__.add[$aArgs.0]
  }{
     $__CONTEXT__.[$aArgs.0][$aArgs.1]
   }

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
pfHTTPRouter

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
