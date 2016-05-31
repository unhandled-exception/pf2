# PF2 library

@CLASS
pfTemplate

## Шаблонный движок.

@OPTIONS
locals

@USE
pf2/lib/common.p

@BASE
pfClass

@create[aOptions]
## aOptions.templateFolder — путь к базовому каталогу с шаблонами
## aOptions.force(false) — принудительно отменяет кеширование в стораджах и пр. местах
## aOptions.defaultEnginePattern[(?:pt|htm|html)^$] — шаблон для дефолтного энжина
## aOptions.defaultEngineOptions[] — опции, которые надо передать дефолтному энжину
## Дефолтный энжин — parser
  ^self.cleanMethodArgument[]
  ^BASE:create[$aOptions]

# Массив путей для поиска шаблонов (hash[$.0 $.1 ...])
  $self._templatePath[^hash::create[]]
  ^self.appendPath[^if(def $aOptions.templateFolder){$aOptions.templateFolder}{/../views}]

  $self._force($aOptions.force)

  $self._storages[^hash::create[]]
  ^self.registerStorage[file;pfTemplateStorage;$.force($self._force)]
  $self._defaultStorage[file]

  $self._engines[^hash::create[]]
  $self._defaultEnginePattern[^if(def $aOptions.defaultEnginePattern){$aOptions.defaultEnginePattern}{(?:pt|htm|html)^$}]
  ^self.registerEngine[parser;;pfTemplateParserEngine;$.options[$aOptions.defaultEngineOptions]]
  $self._defaultEngine[parser]

  $self._globalVars[^hash::create[]]
  $self._profiles[^hash::create[]]

@GET_templatePath[]
  $result[$self._templatePath]

@GET_defaultStorage[]
  $result[$self._defaultStorage]

@SET_defaultStorage[aName]
  $self._defaultStorage[$aName]

@GET_defaultEngine[]
  $result[$self._defaultEngine]

@SET_defaultEngine[aName]
  $self._defaultEngine[$aName]

@GET_defaultEnginePattern[]
  $result[$self._defaultEnginePattern]

@SET_defaultEnginePattern[aName]
  $self._defaultEnginePattern[$aName]

@GET_vars[]
  $result[$self._globalVars]

@appendPath[aPath]
## Добавляет путь для поиска шаблонов
  ^if(def $aPath){
    $self._templatePath.[^self._templatePath._count[]][$aPath]
  }
  $result[]

@registerStorage[aStorageName;aClassName;aOptions]
## aOptions.file — имя файла с классом
## aOptions.options — переменные, которые надо передать конструктору стораджа
  ^self.cleanMethodArgument[]
  ^pfAssert:isTrue(def $aStorageName)[Не задано имя стораджа.]
  ^pfAssert:isTrue(def $aClassName)[Не задано имя класса стораджа.]
  $self._storages.[$aStorageName][
    $.className[$aClassName]
    $.file[$aOptions.file]
    $.options[$aOptions.options]
    $.object[]
  ]
  $result[]

@registerEngine[aEngineName;aPattern;aClassName;aOptions]
## aPattern[] — регулярное выражение для определения типа движка по имени шаблона, если не задано, то опеределяем движок
## aOptions.file — имя файла с классом
## aOptions.options — переменные, которые надо передать конструктору энжина
  ^self.cleanMethodArgument[]
  ^pfAssert:isTrue(def $aEngineName)[Не задано имя энжина.]
  ^pfAssert:isTrue(def $aClassName)[Не задано имя класса энжина.]
  $self._engines.[$aEngineName][
    $.pattern[^if(def $aPattern){$aPattern}]
    $.className[$aClassName]
    $.file[$aOptions.file]
    $.options[$aOptions.options]
    $.object[]
  ]
  $result[]

@loadTemplate[aTemplateName;aOptions]
## Загружает шаблон
## result: $.body $.path
  ^self.cleanMethodArgument[]
  $result[^hash::create[]]
  $lParsed[^self._parseTemplateName[$aTemplateName]]
  $lStorage[^self._getStorage[$lParsed.protocol]]
  $result[^lStorage.load[$aTemplateName;$aOptions]]

@assign[aVarName;aValue]
## Добавляет переменную в шаблон.
  $self._globalVars.[$aVarName][$aValue]
  $result[]

@multiAssign[aVars]
## Добавляет сразу несколько переменных в шаблон.
  ^aVars.foreach[k;v]{
    ^self.assign[$k;$v]
  }
  $result[]

@clearAllAssigned[]
  $self._globalVars[^hash::create[]]
  $result[]

@render[aTemplateName;aOptions]
## Рендрит шаблон
## $aTemplateName может быть задан в форме protocol:path/to/template/
## Если протокол не указан, то используем дефолтный — file
## aOptions.vars — переменные, которые необходимо передать шаблону (замещают VARS)
## aOptions.force(false) — принудительно перекомпилировать шаблон и отменить кеширование
## aOptions.engine[] — принудительно рендрит щаблон с помощью конкретного энжина
  ^self.cleanMethodArgument[]
  $lEngine[^self.findEngine[$aTemplateName;$aOptions.engine]]
  $lTemplate[^self.loadTemplate[$aTemplateName;$.force($self._force || $aOptions.force)]]
  $result[^lEngine.render[$lTemplate;$.vars[$aOptions.vars] $.force($self._force || $aOptions.force)]]

@_getStorage[aStorageName]
## Возвращает объект стораджа
  ^if(^self._storages.contains[$aStorageName]){
    $lStorage[$self._storages.[$aStorageName]]
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

@_getEngine[aEngineName]
  ^if(^self._engines.contains[$aEngineName]){
    $lEngine[$self._engines.[$aEngineName]]
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

@findEngine[aTemplateName;aEngineName]
## Ищет энжин для шаблона по имени или по типу энжина.
  ^self._engines.foreach[k;v]{
    ^if($k eq $aEngineName || ^aTemplateName.match[^if(def $v.pattern){$v.pattern}{$self._defaultEnginePattern}][n]){
      $lEngineName[$k]
      ^break[]
    }
  }
  ^if(def $aEngineName){$lEngineName[$aEngineName]}
  ^if(!def $lEngineName){$lEngineName[$self._defaultEngine]}
  ^if(def $lEngineName){
    $result[^self._getEngine[$lEngineName]]
  }{
     ^throw[template.engine.not.found;Не найден энжин для шаблона "$aTemplateName".]
   }

@_parseTemplateName[aTemplateName]
## Разбирает строку с именем шаблона и возвращает
## хэш: $.protocol $.path
  $lTemp[^aTemplateName.match[(?:(.*?):(?://)?)?(.*)]]
  $lProtocol[$lTemp.1]
  $lPath[$lTemp.2]
  ^if(!def $lProtocol || !def $self._storages.$lProtocol){
    $lProtocol[$self.defaultStorage]
  }
  ^if(!def $lProtocol){
    ^throw[template.runtime;Storage "$lProtocol" not found.]
  }
  $result[$.protocol[$lProtocol] $.path[$lPath]]

#---------------------------------------------------------------------------------------------------

@CLASS
pfTemplateStorage

@OPTIONS
locals

@BASE
pfClass

@create[aTemplate;aOptions]
## aTemplate — ссылка на объект темпла, которому принадлежит сторадж
## aOptions.force(false)
  ^self.cleanMethodArgument[]
  ^pfAssert:isTrue(def $aTemplate)[Не задан объект Темпла.]

  $self._template[$aTemplate]
  $self._isForce($aOptions.force)
  $self._cache[^hash::create[]]

@load[aTemplateName;aOptions]
## Возвращает шаблон
## aOptions.base[] — базовый путь в котором начинается поиск шаблона
## aOptions.force(false)
## result: $.body $.path
## throw: tepmlate.not.found — возбуждается, если шаблон не найден
  ^self.cleanMethodArgument[]
  $result[^hash::create[]]

# Ищем файл
  $lPath[^if(def $aOptions.base && -f "$aOptions.base/$aTemplateName"){$aOptions.base/$aTemplateName}]
  ^if(!def $lPath){
    $c($self._template.templatePath)
    ^for[i](1;$c){
      $v[$self._template.templatePath.[^eval($c - $i)]]
      ^if(-f "$v/$aTemplateName"){
        $lPath[$v/$aTemplateName]
        ^break[]
      }
    }
  }

# Загружаем файл или достаем его из кеша
  ^if(def $lPath){
    $result.path[$lPath]
    ^if((!$self._isForce || !$aOptions.force) && ^self._cache.contains[$lPath]){
      $result.body[$self._cache.[$lPath]]
    }{
       $lFile[^file::load[text;$lPath]]
       $result.body[$lFile.text]
       ^if(!$self._isForce){
         $self._cache.[$lPath][$result.body]
       }
     }
  }{
     ^throw[template.not.found;Шаблон "$aTemplateName" не найден.]
   }

@flushCache[]
## Очищает кеш
  $self._cache[^hash::create[]]

#---------------------------------------------------------------------------------------------------

@CLASS
pfTemplateEngine

@OPTIONS
locals

@BASE
pfClass

@create[aTemplate;aOptions]
## aTemplate — ссылка на объект темпла, которому принадлежит энжин
  ^pfAssert:isTrue($aTemplate is pfTemplate)[Не передан объект pfTemplate.]
  $self._template[$aTemplate]

@GET_template[]
  $result[$self._template]

@render[aTemplate;aOptions]
## aTemplate[$.body $.path]
## aOptions.vars[]
  ^throw[pf.runtime;A render method is not implemented.]

@applyImports[aTemplate;lClass]
  $result[]

#---------------------------------------------------------------------------------------------------

@CLASS
pfTemplateParserEngine

@OPTIONS
locals

@BASE
pfTemplateEngine

@create[aTemplate;aOptions]
## aTemplate — ссылка на объект темпла, которому принадлежит энжин
## aOptions.locals(false) — включить options locals в классе-обертке шаблона
  ^self.cleanMethodArgument[]
  ^BASE:create[$aTemplate;$aOptions]
  $self._locals(^aOptions.locals.bool(true))

@render[aTemplate;aOptions]
## aTemplate[$.body $.path]
## aOptions.vars[]
  ^self.cleanMethodArgument[]
  $lClassName[^self._compileToPattern[$aTemplate]]

  $lPattern[^reflection:create[$lClassName;create;$.template[$template] $.file[$aTemplate.path]]]
  $result[^lPattern.__process__[$.global[$template.vars] $.local[$aOptions.vars]]]

@_compileToPattern[aTemplate;aBaseName]
  $result[^self._buildClassName[$aTemplate.path]]

# Обрабатываем наследование
  $lBases[^aTemplate.body.match[^^#@base\s+(.+)^$][gmi]]
  ^if($lBases > 1){^throw[template.base.fail;У шаблона "$aTemplate.path" может быть только один предок.]}
  ^if($lBases){
    $lTemplateName[^lBases.1.trim[both; ]]
    ^if($lTemplateName eq ^file:basename[$aTemplate.path]){^throw[template.base.fail;Шаблон "$aTemplate.path" не может быть собственным предком.]}
    $lParent[^self._compileToPattern[^self.template.loadTemplate[$lTemplateName;$.base[^file:dirname[$aTemplate.path]]];$lParent]]
  }

# Компилируем текущий шаблон
  ^self._buildClass[$result;$lParent;$aTemplate]

@_buildClassName[aFileName]
  $result[^math:uid64[]]

@_buildClass[aClassName;aBaseName;aTemplate]
## Формирует пустой класс aClassName с предком aBaseName
$result[]

# Компилируем базовый клас с учетом наследования
^process{
^@CLASS
$aClassName
^if($self._locals){
^@OPTIONS
locals
}
^@BASE
^if(def $aBaseName){$aBaseName}{pfTemplateParserPattern}
^@__create__[]

}[$.file[$aTemplate.file]]

  $lClass[^reflection:create[$aClassName;__create__]]
  ^self.applyImports[$aTemplate;$lClass]

# Компилируем тело шаблона в класс
  ^process[$lClass.CLASS]{^taint[as-is][$aTemplate.body]}[$.main[__main__] $.file[$aTemplate.path]]

@applyImports[aTemplate;lClass]
## Ищем и компилируем импорты
  $result[]

  $lImports[^aTemplate.body.match[^^#@import\s+(.+)^$][gmi]]
  $lBase[^file:dirname[$aTemplate.path]]
  $lTemplateName[^file:basename[$aTemplate.path]]

  ^lImports.menu{
    $lImportName[^lImports.1.trim[both; ]]
    ^if($lImportName eq $lTemplateName){^throw[temlate.import.fail;Нельзя импортировать шаблон "$aTemplate.path" самого в себя.]}
    $lTempl[^self.template.loadTemplate[$lImportName;$.base[$lBase]]]

    ^self.applyImports[$lTempl;$lClass]
  }

  ^process[$lClass.CLASS]{^taint[as-is][$aTemplate.body]}[$.main[__main__] $.file[$aTemplate.path]]

#---------------------------------------------------------------------------------------------------

@CLASS
pfTemplateParserPattern

@OPTIONS
locals

@BASE
pfClass

@create[aOptions]
## aOptions.template
## aOptions.file
  ^if(!def $aOptions){$aOptions[^hash::create[]]}
  $self.__TEMPLATE[$aOptions.template]
  $self.__FILE[$aOptions.file]
  $self.__GLOBAL[]
  $self.__LOCAL[]

@GET_DEFAULT[aName]
  $result[^if(^self.__LOCAL.contains[$aName]){$self.__LOCAL.[$aName]}{$self.__GLOBAL.[$aName]}]

@GET___GLOBAL__[]
  $result[$self.__GLOBAL]

@GET___LOCAL__[]
  $result[$self.__LOCAL]

@GET_TEMPLATE[]
  $result[$self.__template]

@__process__[aOptions]
## aOptions.global
## aOptions.local
  ^if(!def $aOptions){$aOptions[^hash::create[]]}
  $self.__GLOBAL[^if(def $aOptions.global){$aOptions.global}{^hash::create[]}]
  $self.__LOCAL[^if(def $aOptions.local){$aOptions.local}{^hash::create[]}]
  $result[^self.__main__[]]
  $self.__GLOBAL[]
  $self.__LOCAL[]

@__main__[]
  ^throw[template.empty;Не задано тело шаблона.]

@compact[]
## Вызывает принудительную сборку мусора.
  $result[]
  ^pfRuntime:compact[]

@include[aTemplateName;aOptions]
  $result[^self.__TEMPLATE.render[$aTemplateName;$aOptions]]

@import[aTemplateName]
  $result[]
  $lTemplate[^self.__TEMPLATE.loadTemplate[$aTemplateName;^if(def $self.__FILE){$.base[^file:dirname[$self.__FILE]]}]]
  $lEngine[^self.__TEMPLATE.findEngine[$aTemplateName]]
  ^if(def $lEngine){
    ^lEngine.applyImports[$lTemplate;$self.CLASS]
  }
  ^process[$self.CLASS]{^taint[as-is][$lTemplate.body]}[$.main[__main__] $.file[$lTemplate.path]]
