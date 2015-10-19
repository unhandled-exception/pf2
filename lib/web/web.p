# PF2 Library

@USE
pf2/lib/common.p
lib/sql/connection.p
lib/web/auth.p
lib/web/templates.p


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
  ^cleanMethodArgument[]
  $_throwPrefix[pfModule]
  $_name[$aOptions.name]

  $_parentModule[$aOptions.parentModule]

  $_MODULES[^hash::create[]]
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

@GET_MODULES[]
  $result[$_MODULES]

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
  $result(^_MODULES.contains[^aName.lower[]])

@hasAction[aAction][lHandler]
## Проверяем есть ли в модуле обработчик aAction
  $lHandler[^_makeActionName[$aAction]]
  $result($$lHandler is junction)

@assignModule[aName;aOptions][locals]
## Добавляет модуль aName
## aOptions.class - имя класса (если не задано, то пробуем его взять из имени файла)
## aOptions.file - файл с текстом класса
## aOptions.source - строка с текстом класса (если определена, то плюем на file)
## aOptions.compile(0) - откомпилировать модуль сразу
## aOptions.args - опции, которые будут переданы конструктору.
## aOptions.mountTo[$aName] - точка монтирования относительно текущего модуля.

## Experimental:
## aOptions.faсtory - метод, который будет вызван для создания модуля
##                    Если определен, то при компиляции модуля вызывается код,
##                    который задан в этой переменной. Предполагается, что в качестве
##                    кода выступает метод, который возвращает экземпляр.
##                    Если определена $aOptions.args, то эта переменная будет
##                    передана методу в качестве единственного параметра.
##                    Пример:
##                     ^addModule[test;$.factory[$moduleFactory] $.args[test]]
##
##                     @moduleFactory[aArgs]
##                       $result[^pfModule::create[$aArgs]]
##
  ^cleanMethodArgument[]
  ^pfAssert:isTrue(def $aName)[Не задано имя для модуля.]
  $aName[^aName.lower[]]
  $lMountTo[^if(def $aOptions.mountTo){^aOptions.mountTo.lower[]}{$aName}]
  $lMountTo[^lMountTo.trim[both;/]]

#  Добавляем в хэш с модулями данные о модуле
   $_MODULES.[$aName][
       $.mountTo[$lMountTo]
       $.file[$aOptions.file]
       $.source[$aOptions.source]
       $.class[^if(!def $aOptions.class && def $aOptions.file){^file:justname[$aOptions.file]}{$aOptions.class}]

       ^if($aOptions.factory is junction){
         $.factory[$aOptions.factory]
         $.hasFactory(1)
       }{
          $.factory[]
          $.hasFactory(0)
        }

       $.args[^if(def $aOptions.args){$aOptions.args}{^hash::create[]} $.parentModule[$self]]
       $.object[]

       $.isCompiled(0)
       $.makeAction(^aOptions.makeAction.int(1))
       $.mountPoint[${_mountPoint}$lMountTo/]
   ]

#  Перекрываем uriPrefix, который пришел к нам в $aOptions.args.
#  Возможно и не самое удачное решение, но позволяет сохранить цепочку.
   $_MODULES.[$aName].args.mountPoint[$_MODULES.[$aName].mountPoint]
   ^if(!def $_MODULES.[$aName].args.templatePrefix){
     $_MODULES.[$aName].args.templatePrefix[${_mountPoint}$aName/]
   }

   ^if(^aOptions.compile.int(0)){
     ^compileModule[$aName]
   }

@GET_DEFAULT[aName][lName]
## Эмулирует свойства modModule
  $result[]
  ^if(^aName.left(3) eq "mod"){
    $lName[^aName.mid(3)]
    $lName[^lName.lower[]]
    ^if(^_MODULES.contains[$lName]){
      ^if(!$_MODULES.[$lName].isCompiled){
        ^compileModule[$lName]
      }
      $result[$_MODULES.[$lName].object]
    }
  }

@compileModule[aName][lFactory]
## Компилирует модуль
## Если модуль задан не в виде ссылки на файл, а в виде строки (source),
## то компилируем ее, не обращая при этом, внимания на файл.
## Если для модуля есть фабрика, то зовем именно ее.
  $result[]
  $aName[^aName.lower[]]
  ^if($_MODULES.[$aName]){
    ^if($_MODULES.[$aName].hasFactory){
      $lFactory[$_MODULES.[$aName].factory]
      ^if(def $_MODULES.[$aName].args){
        $_MODULES.[$aName].object[^lFactory[$_MODULES.[$aName].args]]
      }{
         $_MODULES.[$aName].object[^lFactory[]]
       }
      $_MODULES.[$aName].isCompiled(1)
    }{
      ^if(def $_MODULES.[$aName].source){
        ^process[$MAIN:CLASS]{^taint[as-is][$_MODULES.[$aName].source]}
      }{
        ^if(def $_MODULES.[$aName].file){
          ^try{
            ^use[$_MODULES.[$aName].file;$.replace(true)]
          }{
#           Для совместимости с парсером до 3.4.3, который не поддерживает ключ replace в use.
            ^if($exception.type eq "parser.runtime"){
              ^use[$_MODULES.[$aName].file]
              $exception.handled(true)
            }
          }
        }
       }
      $_MODULES.[$aName].object[^reflection:create[$_MODULES.[$aName].class;create;$_MODULES.[$aName].args $.appendSlash[$appendSlash]]]
      $_MODULES.[$aName].isCompiled(1)
     }
  }{
     ^throw[pfModule.compile;Module "$aName" not found.]
   }

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

@processRequest[aAction;aRequest;aOptions][lRewrite]
## Производит предобработку запроса
## $result[$.action[] $.request[] $.prefix[] $.render[]] - экшн, запрос, префикс, параметры шаблона, которые будут переданы обработчикам
  $lRewrite[^rewriteAction[$aAction;$aRequest]]
  $aAction[$lRewrite.action]
  ^if($lRewrite.args){
#   Пытаемся воспользоваться методом рефлексии.
    ^if($aRequest.__add is junction){
      ^aRequest.__add[$lRewrite.args]
    }{
       ^aRequest.add[$lRewrite.args]
     }
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
       $result[^self.[mod^_makeSpecialName[^lModule.lower[]]].dispatch[^lAction.mid(^lModuleMountTo.length[]);$lRequest;
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
    ^_MODULES.foreach[k;v]{
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

## Класс, объединяющий все данные запроса от клиента в один объект.

@BASE
pfClass

@create[aOptions]
  ^cleanMethodArgument[]
  ^BASE:create[]

  $FIELDS[^if(def $aOptions.fields){$aOptions.fields}{$form:fields}]
  $QTAIL[^if(def $aOptions.qtail){$aOptions.qtail}{$form:qtail}]
  $IMAP[^if(def $aOptions.imap){$aOptions.imap}{$form:imap}]
  $TABLES[^if(def $aOptions.tables){$aOptions.tables}{$form:tables}]
  $FILES[^if(def $aOptions.files){$aOptions.files}{$form:files}]
  $COOKIE[^if(def $aOptions.cookie){$aOptions.cookie}{$cookie:fields}]

  $META[^if(def $aOptions.meta){$aOptions.meta}{^pfHTTPRequestMeta::create[]}]
  $HEADERS[^if(def $aOptions.headers){$aOptions.headers}{^pfHTTPRequestHeaders::create[]}]

  $_HOST[]
  $_PATH[]

@GET[]
## Return request fields count
  $result($FIELDS)

@GET_DEFAULT[aName]
## Return request field
  $result[^get[$aName]]

@GET_isSECURE[]
## Проверяет пришел ли нам запрос по протоколу HTTPS.
  $result((def $META.HTTPS && ^META.HTTPS.lower[] eq "on") || ^META.SERVER_PORT.int(80) == 443)

@GET_METHOD[]
## Возвращает http-метод запроса в нижнем регистре
  $result[^META.REQUEST_METHOD.lower[]]
  ^if($result eq "post" && def $FIELDS._method){
    $result[^switch[^FIELDS._method.lower[]]{
      ^case[DEFAULT]{post}
      ^case[delete]{delete}
      ^case[put]{put}
    }]
  }

@GET_isGET[]
  $result($METHOD eq "get")

@GET_isPOST[]
  $result($METHOD eq "post")

@GET_isHEAD[]
  $result($METHOD eq "head")

@GET_isPUT[]
  $result($METHOD eq "put")

@GET_isDELETE[]
  $result($METHOD eq "delete")

@GET_isAJAX[]
  $result(^HEADERS.[X_Requested_With].pos[XMLHttpRequest] > -1)

@GET_URI[]
## Return request:uri
  $result[$request:uri]

@GET_PATH[][lPos]
## Return the request:uri without a query part
  ^if(!def $_PATH){
    $lPos(^request:uri.pos[?])
    $_PATH[^if($lPos >= 0){^request:uri.left($lPos)}{$request:uri}]
  }
  $result[$_PATH]

@GET_ACTION[]
  $result[$FIELDS._action]

@GET_QUERY[]
## Return request:query
  $result[$request:query]

@GET_CHARSET[]
## Return request:charset
  $result[$request:charset]

@GET_RESPONSE-CHARSET[]
## Return $response:charset
  $response[$response:charset]

@GET_POST-CHARSET[]
## Return request:post-charset
  $result[$request:post-charset]

@GET_BODY[]
## Return request:body
  $result[$request:body]

@GET_DOCUMENT-ROOT[]
## Return request:document-root
  $result[$request:document-root]

@GET_HOST[][lPort]
## Return host.
  ^if(!def $_HOST){
    $_HOST[^HEADERS.get[X_Forwarded_Host;^HEADERS.get[Host]]]
    ^if(!def $_HOST){
      $_HOST[^META.get[SERVER_NAME]]
    }
    $lPort[^META.get[SERVER_PORT]]
    $_HOST[${_HOST}^if($lPort ne "80" && ($isSECURE && $lPort ne "443")){:$lPort}]
  }
  $result[$_HOST]

@get[aName;aDefault]
  $result[$FIELDS.[$aName]]
  ^if($result is junction){$result[]}
  ^if(!def $result && def $aDefault){
    $result[$aDefault]
  }

@contains[aName]
  $result(^FIELDS.contains[$aName])

@getFullPath[]
## Returns the path, plus an appended query string, if applicable.
  $result[$request:uri]

@buildAbsoluteUri[aLocation]
## Returns the absolute URI form of location.
## If no location is provided, the location will be set to getFullPath
  ^if(!def $aLocation){
    $aLocation[^getFullPath[]]
  }
  ^if(^aLocation.left(1) ne "/"){
    $aLocation[/$aLocation]
  }
  $result[http^if($isSECURE){s}://${HOST}$aLocation]

@foreach[aKeyName;aValueName;aCode;aSeparator]
## Iterate all request fields
  $result[^FIELDS.foreach[k;v]{$caller.[$aKeyName][$k]$caller.[$aValueName][$v]$aCode}{$aSeparator}]

@__add[aNewFields]
## Add new fields in to request
  ^pfAssert:isTrue($aNewFields is hash)[New fields must be a hash.]
  ^FIELDS.add[$aNewFields]
  $result[]


@CLASS
pfHTTPRequestMeta

## Вспомогательный класс для работы с переменными окружения в запросе.

@BASE
pfClass

@create[]
  ^BASE:create[]

@GET_DEFAULT[aName]
  $result[^get[$aName]]

@get[aName;aDefault]
  $result[$env:[$aName]]
  ^if(!def $result && def $aDefault){
    $result[$aDefault]
  }


@CLASS
pfHTTPRequestHeaders

## Вспомогательный класс для работы с заголовками http-запроса.

@BASE
pfClass

@create[]
  ^BASE:create[]

@GET_DEFAULT[aName]
  $result[^get[$aName]]

@get[aName;aDefault]
## Возвращает поле запроса.
## Позволяет задать имя в привычном виде (например, User-Agent).
  ^if(def $aName){
    $lName[^aName.trim[both][ :]]
    $lName[^aName.match[[-\s]][g][_]]
    $result[$env:[HTTP_^lName.upper[]]]
  }{
     $result[]
   }
  ^if(!def $result && def $aDefault){
    $result[$aDefault]
  }

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
  ^BASE:create[$aOptions]

  $_asManager(^aOptions.asManager.bool(false))
  $_passDefaultPost(^aOptions.passDefaultPost.bool(!$_asManager))

  $_redirectExceptionName[pf.site.module.redirect]
  $_permanentRedirectExceptionName[pf.site.module.permanent_redirect]

  $_responseType[html]
  $_createOptions[$aOptions]

  $templatePath[^if(^aOptions.contains[templatePrefix]){$aOptions.templatePrefix}{$mountPoint}]

  $_sql[$aOptions.sql]
  $_auth[$aOptions.auth]
  $_template[$aOptions.template]

  $_templateVars[^hash::create[]]

# Метод display лучше не использовать (deprecated).
  ^alias[display;$render]

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

@assignModule[aName;aOptions][lArgs]
# Если нам не передали aOptions.args, то формируем штатный заменитель.
  ^cleanMethodArgument[]
  $lArgs[
    $.sql[$CSQL]
    $.auth[$AUTH]
    $.templateOptions[$_createOptions.templateOptions]
    $.template[$TEMPLATE]
  ]
  ^if(!def $aOptions.args){
    $aOptions.args[$lArgs]
  }{
     $aOptions.args[^aOptions.args.union[$lArgs]]
   }
  ^BASE:assignModule[$aName;$aOptions]

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
          $lRedirectPath[^if(^exception.comment.match[^^https?://][n]){$exception.comment}{^aRequest.buildAbsoluteUri[$exception.comment]}]
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
  ^pfAssert:isTrue($aVars.foreach is junction)[aVars не поддерживает foreach.]
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
  ^if($_asManager && $self.onAuthSuccess is junction){
    $result[^onAuthSuccess[$aRequest]]
  }{
     $result[]
  }

@onAUTHFAILED[aRequest]
## Вызывается при неудачной авторизации
  ^if($_asManager && $self.onAuthFailed is junction){
    $result[^onAuthFailed[$aRequest]]
  }{
     $result[]
  }

# Пост-обработчики для менеджера

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

  $_now[^date::now[]]
  $_today[^date::today[]]

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
