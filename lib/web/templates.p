# PF2 library

@USE
pf2/lib/common.p

## Шиблонный движок.

@CLASS
pfTemplate

@BASE
pfClass

@create[aOptions]
## aOptions.templateFolder - путь к базовому каталогу с шаблонами
## aOptions.force(false) - принудительно отменяет кеширование в стораджах и пр. местах
## aOptions.defaultEnginePattern[(?:pt|htm|html)^$] - шаблон для дефолтного энжина
## aOptions.defaultEngineOptions[] — опции, которые надо передать дефолтному энжину
## Дефолтный энжин — parser
  ^cleanMethodArgument[]
  ^BASE:create[$aOptions]

# Массив путей для поиска шаблонов (hash[$.0 $.1 ...])
  $_templatePath[^hash::create[]]
  ^appendPath[^if(def $aOptions.templateFolder){$aOptions.templateFolder}{/../views}]

  $_force($aOptions.force)

  $_storages[^hash::create[]]
  ^registerStorage[file;pfTemplateStorage;$.force($_force)]
  $_defaultStorage[file]

  $_engines[^hash::create[]]
  $_defaultEnginePattern[^if(def $aOptions.defaultEnginePattern){$aOptions.defaultEnginePattern}{(?:pt|htm|html)^$}]
  ^registerEngine[parser;;pfTemplateParserEngine;$.options[$aOptions.defaultEngineOptions]]
  $_defaultEngine[parser]

  $_globalVars[^hash::create[]]
  $_profiles[^hash::create[]]

@GET_templatePath[]
  $result[$_templatePath]

@GET_defaultStorage[]
  $result[$_defaultStorage]

@SET_defaultStorage[aName]
  $_defaultStorage[$aName]

@GET_defaultEngine[]
  $result[$_defaultEngine]

@SET_defaultEngine[aName]
  $_defaultEngine[$aName]

@GET_defaultEnginePattern[]
  $result[$_defaultEnginePattern]

@SET_defaultEnginePattern[aName]
  $_defaultEnginePattern[$aName]

@GET_VARS[]
  $result[$_globalVars]

@appendPath[aPath]
## Добавляет путь для поиска шаблонов
  ^if(def $aPath){
    $_templatePath.[^_templatePath._count[]][$aPath]
  }
  $result[]

@registerStorage[aStorageName;aClassName;aOptions]
## aOptions.file - имя файла с классом
## aOptions.options - переменные, которые надо передать конструктору стораджа
  ^cleanMethodArgument[]
  ^pfAssert:isTrue(def $aStorageName)[Не задано имя стораджа.]
  ^pfAssert:isTrue(def $aClassName)[Не задано имя класса стораджа.]
  $_storages.[$aStorageName][
    $.className[$aClassName]
    $.file[$aOptions.file]
    $.options[$aOptions.options]
    $.object[]
  ]
  $result[]

@registerEngine[aEngineName;aPattern;aClassName;aOptions]
## aPattern[] - регулярное выражение для определения типа движка по имени шаблона, если не задано, то опеределяем движок
## aOptions.file - имя файла с классом
## aOptions.options - переменные, которые надо передать конструктору энжина
  ^cleanMethodArgument[]
  ^pfAssert:isTrue(def $aEngineName)[Не задано имя энжина.]
  ^pfAssert:isTrue(def $aClassName)[Не задано имя класса энжина.]
  $_engines.[$aEngineName][
    $.pattern[^if(def $aPattern){$aPattern}]
    $.className[$aClassName]
    $.file[$aOptions.file]
    $.options[$aOptions.options]
    $.object[]
  ]
  $result[]

@loadTemplate[aTemplateName;aOptions][lParsed;lStorage]
## Загружает шаблон
## result: $.body $.path
  ^cleanMethodArgument[]
  $result[^hash::create[]]
  $lParsed[^_parseTemplateName[$aTemplateName]]
  $lStorage[^_getStorage[$lParsed.protocol]]
  $result[^lStorage.load[$aTemplateName;$aOptions]]

@assign[aVarName;aValue]
## Добавляет переменную в шаблон.
  $_globalVars.[$aVarName][$aValue]
  $result[]

@multiAssign[aVars][k;v]
## Добавляет сразу несколько переменных в шаблон.
  ^aVars.foreach[k;v]{
    ^assign[$k;$v]
  }
  $result[]

@clearAllAssigned[]
  $_globalVars[^hash::create[]]
  $result[]

@render[aTemplateName;aOptions][lEngine;lTemplate]
## Рендрит шаблон
## $aTemplateName может быть задан в форме protocol:path/to/template/
## Если протокол не указан, то используем дефолтный - file
## aOptions.vars - переменные, которые необходимо передать шаблону (замещают VARS)
## aOptions.force(false) - принудительно перекомпилировать шаблон и отменить кеширование
## aOptions.engine[] - принудительно рендрит щаблон с помощью конкретного энжина
  ^cleanMethodArgument[]
  $lEngine[^findEngine[$aTemplateName;$aOptions.engine]]
  $lTemplate[^loadTemplate[$aTemplateName;$.force($_force || $aOptions.force)]]
  $result[^lEngine.render[$lTemplate;$.vars[$aOptions.vars] $.force($_force || $aOptions.force)]]

@_getStorage[aStorageName][lStorage]
## Возвращает объект стораджа
  ^if(^_storages.contains[$aStorageName]){
    $lStorage[$_storages.[$aStorageName]]
    ^if(!def $lStorage.object){
      ^if(def $lStorage.file){
        ^use[$lStorage.file]
      }
      $lStorage.object[^reflection:create[$lStorage.className;create;$self;$lStorage.options]]
    }
    $result[$lStorage.object]
  }{
     ^throw[template.runtime;Не зарегистрирован сторадж "$aStorageName".]
   }

@_getEngine[aEngineName][lEngine]
  ^if(^_engines.contains[$aEngineName]){
    $lEngine[$_engines.[$aEngineName]]
    ^if(!def $lEngine.object){
      ^if(def $lEngine.file){
        ^use[$lEngine.file]
      }
      $lEngine.object[^reflection:create[$lEngine.className;create;$self;$lEngine.options]]
    }
    $result[$lEngine.object]
  }{
     ^throw[runtime;Не зарегистрирован энжин "$aEngineName".]
   }

@findEngine[aTemplateName;aEngineName][lEngineName;k;v]
## Ищет энжин для шаблона по имени или по типу энжина.
  ^_engines.foreach[k;v]{
    ^if($k eq $aEngineName || ^aTemplateName.match[^if(def $v.pattern){$v.pattern}{$_defaultEnginePattern}][n]){
      $lEngineName[$k]
      ^break[]
    }
  }
  ^if(def $aEngineName){$lEngineName[$aEngineName]}
  ^if(!def $lEngineName){$lEngineName[$_defaultEngine]}
  ^if(def $lEngineName){
    $result[^_getEngine[$lEngineName]]
  }{
     ^throw[template.engine.not.found;Не найден энжин для шаблона "$aTemplateName".]
   }

@_parseTemplateName[aTemplateName][lTemp;lProtocol;lPath]
## Разбирает строку с именем шаблона и возвращает
## хэш: $.protocol $.path
  $lTemp[^aTemplateName.match[(?:(.*?):(?://)?)?(.*)]]
  $lProtocol[$lTemp.1]
  $lPath[$lTemp.2]
  ^if(!def $lProtocol || !def $_storages.$lProtocol){
    $lProtocol[$defaultStorage]
  }
  ^if(!def $lProtocol){
    ^throw[templet.runtime;Storage "$lProtocol" not found.]
  }
  $result[$.protocol[$lProtocol] $.path[$lPath]]

#---------------------------------------------------------------------------------------------------

@CLASS
pfTemplateStorage

@BASE
pfClass

@create[aTemplate;aOptions]
## aTemplate - ссылка на объект темпла, которому принадлежит сторадж
## aOptions.force(false)
  ^cleanMethodArgument[]
  ^pfAssert:isTrue(def $aTemplate)[Не задан объект Темпла.]

  $_temple[$aTemplate]
  $_isForce($aOptions.force)
  $_cache[^hash::create[]]

@load[aTemplateName;aOptions][lPath;lFile;v;i;c]
## Возвращает шаблон
## aOptions.base[] - базовый путь в котором начинается поиск шаблона
## aOptions.force(false)
## result: $.body $.path
## throw: tepmlate.not.found - возбуждается, если шаблон не найден
  ^cleanMethodArgument[]
  $result[^hash::create[]]

# Ищем файл
  $lPath[^if(def $aOptions.base && -f "$aOptions.base/$aTemplateName"){$aOptions.base/$aTemplateName}]
  ^if(!def $lPath){
    $c($_temple.templatePath)
    ^for[i](1;$c){
      $v[$_temple.templatePath.[^eval($c - $i)]]
      ^if(-f "$v/$aTemplateName"){
        $lPath[$v/$aTemplateName]
        ^break[]
      }
    }
  }

# Загружаем файл или достаем его из кеша
  ^if(def $lPath){
    $result.path[$lPath]
    ^if((!$_isForce || !$aOptions.force) && ^_cache.contains[$lPath]){
      $result.body[$_cache.[$lPath]]
    }{
       $lFile[^file::load[text;$lPath]]
       $result.body[$lFile.text]
       ^if(!$_isForce){
         $_cache.[$lPath][$result.body]
       }
     }
  }{
     ^throw[template.not.found;Шаблон "$aTemplateName" не найден.]
   }

@flushCache[]
## Очищает кеш
  $_cache[^hash::create[]]

#---------------------------------------------------------------------------------------------------

@CLASS
pfTemplateEngine

@BASE
pfClass

@create[aTemplate;aOptions]
## aTemplate - ссылка на объект темпла, которому принадлежит энжин
  ^pfAssert:isTrue($aTemplate is pfTemplate)[Не передан объект pfTemplate.]
  $_temple[$aTemplate]

@GET_TEMPLE[]
  $result[$_temple]

@render[aTemplate;aOptions]
## aTemplate[$.body $.path]
## aOptions.vars[]
  ^_abstractMethod[]

@applyImports[aTemplate;lClass]
  $result[]

#---------------------------------------------------------------------------------------------------

@CLASS
pfTemplateParserEngine

@BASE
pfTemplateEngine

@create[aTemplate;aOptions]
## aTemplate - ссылка на объект темпла, которому принадлежит энжин
## aOptions.locals(false) — включить options locals в классе-обертке шаблона
  ^cleanMethodArgument[]
  ^BASE:create[$aTemplate;$aOptions]
  $self._locals(^aOptions.locals.bool(false))

@render[aTemplate;aOptions][lPattern]
## aTemplate[$.body $.path]
## aOptions.vars[]
  ^cleanMethodArgument[]
  $lClassName[^_compileToPattern[$aTemplate]]

  $lPattern[^reflection:create[$lClassName;create;$.temple[$TEMPLE] $.file[$aTemplate.path]]]
  $result[^lPattern.__process__[$.global[$TEMPLE.VARS] $.local[$aOptions.vars]]]

@_compileToPattern[aTemplate;aBaseName][lBases;lClass;lParent;lTemplateName]
  $result[^_buildClassName[$aTemplate.path]]

# Обрабатываем наследование
  $lBases[^aTemplate.body.match[^^#@base\s+(.+)^$][gmi]]
  ^if($lBases > 1){^throw[template.base.fail;У шаблона "$aTemplate.path" может быть только один предок.]}
  ^if($lBases){
    $lTemplateName[^lBases.1.trim[both; ]]
    ^if($lTemplateName eq ^file:basename[$aTemplate.path]){^throw[template.base.fail;Шаблон "$aTemplate.path" не может быть собственным предком.]}
    $lParent[^_compileToPattern[^TEMPLE.loadTemplate[$lTemplateName;$.base[^file:dirname[$aTemplate.path]]];$lParent]]
  }

# Компилируем текущий шаблон
  ^_buildClass[$result;$lParent;$aTemplate]

@_buildClassName[aFileName]
  $result[^math:uid64[]]

@_buildClass[aClassName;aBaseName;aTemplate][lClass;lImports;lTempl;lBase;lTemplateName;lImportName]
## Формирует пустой класс aClassName с предком aBaseName
$result[]

# Компилируем базовый клас с учетом наследования
^process{
^@CLASS
$aClassName
^if($_locals){
^@OPTIONS
locals
}
^@BASE
^if(def $aBaseName){$aBaseName}{pfTemplateParserPattern}
^@__create__[]

}[$.file[$aTemplate.file]]

  $lClass[^reflection:create[$aClassName;__create__]]
  ^applyImports[$aTemplate;$lClass]

# Компилируем тело шаблона в класс
  ^process[$lClass.CLASS]{^taint[as-is][$aTemplate.body]}[$.main[__main__] $.file[$aTemplate.path]]

@applyImports[aTemplate;lClass][lImports;lBase;lTemplateName;lImportName;lTempl]
## Ищем и компилируем импорты
  $result[]

  $lImports[^aTemplate.body.match[^^#@import\s+(.+)^$][gmi]]
  $lBase[^file:dirname[$aTemplate.path]]
  $lTemplateName[^file:basename[$aTemplate.path]]

  ^lImports.menu{
    $lImportName[^lImports.1.trim[both; ]]
    ^if($lImportName eq $lTemplateName){^throw[temlate.import.fail;Нельзя импортировать шаблон "$aTemplate.path" самого в себя.]}
    $lTempl[^TEMPLE.loadTemplate[$lImportName;$.base[$lBase]]]

    ^applyImports[$lTempl;$lClass]
  }

  ^process[$lClass.CLASS]{^taint[as-is][$aTemplate.body]}[$.main[__main__] $.file[$aTemplate.path]]

#---------------------------------------------------------------------------------------------------

@CLASS
pfTemplateParserPattern

@BASE
pfClass

@create[aOptions]
## aOptions.file
  ^if(!def $aOptions){$aOptions[^hash::create[]]}
  $__temple[$aOptions.temple]
  $__FILE[$aOptions.file]
  $__GLOBAL[]
  $__LOCAL[]

@GET_DEFAULT[aName]
  $result[^if(^__LOCAL.contains[$aName]){$__LOCAL.[$aName]}{$__GLOBAL.[$aName]}]

@GET___GLOBAL__[]
  $result[$__GLOBAL]

@GET___LOCAL__[]
  $result[$__LOCAL]

@GET_TEMPLET[]
  $result[$__temple]

@__process__[aOptions]
## aOptions.global
## aOptions.local
  ^if(!def $aOptions){$aOptions[^hash::create[]]}
  $__GLOBAL[^if(def $aOptions.global){$aOptions.global}{^hash::create[]}]
  $__LOCAL[^if(def $aOptions.local){$aOptions.local}{^hash::create[]}]
  $result[^__main__[]]
  $__GLOBAL[]
  $__LOCAL[]

@__main__[]
  ^throw[template.empty;Не задано тело шаблона.]

@compact[]
## Вызывает принудительную сборку мусора.
  $result[]
  ^pfRuntime:compact[]

@include[aTemplateName;aOptions]
  $result[^__temple.render[$aTemplateName;$aOptions]]

@import[aTemplateName][locals]
  $result[]
  $lTempl[^__temple.loadTemplate[$aTemplateName;^if(def $__FILE){$.base[^file:dirname[$__FILE]]}]]
  $lEngine[^__temple.findEngine[$aTemplateName]]
  ^if(def $lEngine){
    ^lEngine.applyImports[$lTempl;$CLASS]
  }
  ^process[$CLASS]{^taint[as-is][$lTempl.body]}[$.main[__main__] $.file[$lTempl.path]]
