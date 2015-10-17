# PF2 Library

@USE
pf2/lib/common.p

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




#--------------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------------
