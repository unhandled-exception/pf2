# PF2 Library

@USE
pf2/lib/common.p


@CLASS
pfTemplate

## Шаблонизатор

@OPTIONS
locals

@BASE
pfClass

@create[aOptions]
## aOptions.storage[pfTemplateStorage] — сторадж
## aOptions.searchPath[/../views] — путь к каталогу с шаблонами
  ^self.cleanMethodArgument[]
  ^BASE:create[$aOptions]

# Переменные шаблона
  $self.context[^hash::create[]]

# Хранилище шаблонов
  $self.storage[
    ^self.ifdef[$aOptions.storage]{
      ^pfTemplateStorage::create[$.searchPath[$aOptions.searchPath]]
    }
  ]

# Кеш откомпилированных шаблонов
  $self.templates[^hash::create[]]

@auto[]
  $self.PFTEMPLATE_TN_REGEX[^regex::create[^^(.*?)(?:@(.*))?^$]]
  $self.PFTEMPLATE_IMPORTS_REGEX[^regex::create[^^#@import\s+(.+)^$][gmi]]
  $self.PFTEMPLATE_BASE_REGEX[^regex::create[^^#@base\s+(.+)^$][gmi]]
  $self.PFTEMPLATE_FUNCTION_REGEX[^regex::create[^^@\S+;mn]]

@assign[aName;aValue] -> []
  $result[]
  $self.context.[$aName][$aValue]

@multiAssign[aVars] -> []
  $result[]
  ^aVars.foreach[k;v]{
    ^self.assign[$k;$v]
  }

@resetVars[]
  $result[]
  $self.vars[^hash::create[]]

@parseTemplateName[aTemplateName;aOptions] -> [$.path $.function]
## aOptions.defaultFunction — имя функции, если не указано в имени
  $result[^hash::create[]]
  ^aTemplateName.match[$self.PFTEMPLATE_TN_REGEX][]{
    $result.path[$match.1]
    $result.function[^self.ifdef[$match.2]{$aOptions.defaultFunction}]
  }

@getTemplate[aTemplateName;aOptions] -> [object]
## aTemplateName — имя шаблона
## aOptions.base — базовый путь, от которого ищем шаблон
## aOptions.force(false)
## aOptions.forceLoad(false)
  ^self.cleanMethodArgument[]
  $lForce(^aOptions.force.bool(false))
  $lTemplateName[^aOptions.base.trim[right;/]/$aTemplateName]
  ^if(!$lForce && ^self.templates.contains[$lTemplateName]){
    $result[$self.templates.[$lTemplateName].object]
    ^self.templates.[$lTemplateName].hits.inc[]
  }{
     $lTempFile[^self.storage.load[$aTemplateName;
       $.base[$aOptions.base]
       $.force(^aOptions.forceLoad.bool(false))
     ]]
     $lTemp[^self.compileTemplate[$lTempFile.text;$lTempFile.path]]
     ^if(!$lForce){
       $self.templates.[$lTemplateName][
         $.object[$lTemp.object]
         $.hits(0)
      ]
     }
     $result[$lTemp.object]
   }

@render[aTemplateName;aOptions]
## Рендерит шаблон
## aTemplateName[/path/to/template.pt@__main__] — имя шаблона и функция, которой передаем управление
## aOptions.context
## aOptions.force(false)
  ^self.cleanMethodArgument[]
  $lTemp[^self.parseTemplateName[$aTemplateName;$.defaultFunction[__main__]]]
  $lObj[^self.getTemplate[$lTemp.path;
    $.force(^aOptions.force.bool(false))
  ]]
  $result[^lObj.__render__[
    $.context[$aOptions.context]
    $.call[$lTemp.function]
  ]]

@GET_DEFAULT[aTemplateName] -> [object]
## Возвращает объект с шаблоном
## ^template.[/path/to/template.pt].function[arg1;arg2;...]
  $result[^self.getTemplate[$aTemplateName]]

@compileTemplate[aTemplateText;aTemplatePath] -> [$.object $.className]
## Компилирует объект и возвращает ссылку
  $result[$.className[^self.makeClassName[$aTemplatePath]]]

# Обрабатываем наследование
  $lParent[]
  $lBases[^aTemplateText.match[$self.PFTEMPLATE_BASE_REGEX]]
  ^if($lBases > 1){^throw[template.base.fail;У шаблона "$aTemplatePath" может быть только один предок.]}
  ^if($lBases){
     $lBaseName[^lBases.1.trim[both; ]]
     ^if($lBaseName eq ^file:basename[$aTemplatePath]){^throw[template.base.fail;Шаблон "$aTemplatePath" не может быть собственным предком.]}
     $lParent[^self.getTemplate[$lBaseName;$.base[^file:dirname[$aTemplatePath]]]]
  }

# Компилируем шаблон и создаем объект
  $result.object[^self.buildObject[$result.className;^if(def $lParent){$lParent.CLASS_NAME};$aTemplateText;$aTemplatePath]]

@makeClassName[aTemplatePath]
  $result[pfTemplateParserWrapper_^if(def $aTemplatePath){^math:md5[$aTemplatePath]_}^math:uid64[]]

@buildObject[aClassName;aBaseName;aTemplateText;aTemplatePath]
## Формирует пустой класс aClassName с предком aBaseName по тексту шаблока aTemplate
  $result[]

# Компилируем базовый клас с учетом наследования
^process{
^@CLASS
$aClassName

^@OPTIONS
locals

^@BASE
^self.ifdef[$aBaseName]{pfTemplateParserWrapper}

^@__create__[aOptions]
  ^^BASE:__create__[^$aOptions]
}[$.file[$aTemplatePath]]

  $result[^reflection:create[$aClassName;__create__;
    $.template[$self]
    $.file[$aTemplatePath]
  ]]
  ^self.applyImports[$result;$aTemplateText;$aTemplatePath;
    $.static(true)
  ]

@applyImports[aObject;aTemplateText;aTemplatePath;aOptions] -> []
## Ищем и компилируем импорты
## aOptions.static(false) — статический импорт
## aOptions.init[__init__] — инициализатор
  $result[]
  $lStatic(^aOptions.static.bool(false))
  $lInit[^if(def $aOptions.init){$aOptions.init}{__init__}]

  $lImports[^aTemplateText.match[$self.PFTEMPLATE_IMPORTS_REGEX]]
  $lBase[^file:dirname[$aTemplatePath]]
  $lTemplateName[^file:basename[$aTemplatePath]]

  ^lImports.menu{
    $lImportName[^lImports.1.trim[both; ]]
    ^if($lImportName eq $lTemplateName){^throw[template.import.recursive;Нельзя импортировать шаблон "$aTemplatePath" самого в себя.]}
    $lTempl[^self.storage.load[$lImportName;$.base[$lBase]]]

    ^if($lStatic && ^lTempl.text.match[^^@^taint[$lInit]\^[][nm]){
      ^throw[template.import.static.init;Нельзя импортировать шаблон "$lImportName" статически;Шаблон содержит метод-инициализатор "$lInit". Подключите шаблон в @main или @__init__ в главном шаблоне.]
    }

#   Рекурсивно обрабатываем импорты
    ^self.applyImports[$aObject;$lTempl.text;$lTempl.path;$aOptions]
  }

  ^process[$aObject]{^if(!^aTemplateText.match[$self.PFTEMPLATE_FUNCTION_REGEX]){@__main__[]^#0A}^taint[as-is][$aTemplateText]}[
    $.main[__main__]
    $.file[$aTemplatePath]
  ]

#---------------------------------------------------------------------------------------------------

@CLASS
pfTemplateStorage

## Хранилище шаблонов

@OPTIONS
locals

@BASE
pfClass

@create[aOptions]
## aOptions.searchPath[table<path>|string{/../views/}]
  ^self.cleanMethodArgument[]
  ^BASE:create[$aOptions]

  $self.searchPath[^table::create{path}]
  ^if(def $aOptions.searchPath){
    ^switch[$aOptions.searchPath.CLASS_NAME]{
      ^case[table]{^self.searchPath.join[$aOptions.searchPath]}
      ^case[string]{^self.searchPath.append{$aOptions.searchPath}}
    }
  }{
     ^self.searchPath.append{/../views/}
   }

  $self.templates[^hash::create[]]

@appendSearchPath[aPath]
## Добавдяет путь для поиска шаблонов
  $result[]
  ^self.searchPath.append{$aPath}

@load[aFileName;aOptions] -> [$.text $.path]
## Загружает шаблон
## aOptions.base — базовый путь от которого ищем шаблон
## aOptions.force(false) — отменяет кеширование
  ^self.cleanMethodArgument[]
  $lForce(^aOptions.force.bool(false))
  $result[^hash::create[]]

  $lFound[^self.find[$aFileName;$.base[$aOptions.base]]]
  $lFullPath[$lFound.fullPath]
  ^if(!def $lFullPath){
    ^if($lFound.searchedPath){
      $lComment[Пути:^#0A^lFound.searchedPath.foreach[_;v]{— $v}[^#0A]
      ]
    }
    ^throw[template.not.found;Не найден шаблон "${aFileName}".;$lComment]
  }

  ^if($lForce || !^self.templates.contains[$lFullPath]){
    $lFile[^file::load[text;$lFullPath]]
    $result.text[$lFile.text]
    $result.path[$lFullPath]
    ^if(!$lForce){
      $self.templates.[$lFullPath][$result]
    }
  }{
     $result[$self.templates.[$lFullPath]]
   }

@find[aFileName;aOptions] -> [$.fullPath $.searchedPath[hash<$.uid_key[full/path.to.pt] ...>]]
## aOptions.base — базовый путь от которого ищем шаблон
  ^self.cleanMethodArgument[]
  ^pfAssert:isTrue(def $aFileName){Не задано имя шаблона.}
  $result[$.fullPath[] $.searchedPath[^hash::create[]]]

  ^if(def $aOptions.base){
    $lFullPath[$aOptions.base/$aFileName]
    ^if(-f $lFullPath){
      $result.fullPath[$lFullPath]
    }{
       $result.searchedPath.[^math:uuid[]][$lFullPath]
    }
  }

  ^if(!def $result.fullPath){
    ^self.searchPath.foreach[_;v]{
      $lFullPath[$v.path/$aFileName]
      ^if(-f $lFullPath){
        $result.fullPath[$lFullPath]
        ^break[]
      }
      $result.searchedPath.[^math:uuid[]][$lFullPath]
    }
  }

@GET_DEFAULT[aFileName]
  $result[^self.load[$aTemplateName]]

@reset[aOptions]
  $self.templates[^hash::create[]]
  $result[]

#---------------------------------------------------------------------------------------------------

@CLASS
pfTemplateParserWrapper

## В класс «заворачиваем» тело шаблона

@BASE
pfClass

@OPTIONS
locals

@__create__[aOptions]
## aOptions.template
## aOptions.file
## aOptions.localContext
## aOptions.source — сделать клон объекта из source.
  ^self.cleanMethodArgument[]

  ^if(!^aOptions.contains[source]){
    ^BASE:create[$aOptions]
    $self.__TEMPLATE__[$aOptions.template]
    $self.__FILE__[$aOptions.file]
    $self.__LOCAL_CONTEXT__[$aOptions.localContext]
  }{
    ^reflection:copy[$aOptions.source;$self]
    ^reflection:mixin[$aOptions.source;$.overwrite(true)]
    ^if(^aOptions.contains[template]){$self.__TEMPLATE__[$aOptions.template]}
    ^if(^aOptions.contains[file]){$self.__FILE__[$aOptions.file]}
    ^if(^aOptions.contains[localContext]){$self.__LOCAL_CONTEXT__[$aOptions.localContext]}
  }

@GET_DEFAULT[aVarName]
# Достает переменную из контекста
  $result[^if(def $self.__LOCAL_CONTEXT__ && ^self.__LOCAL_CONTEXT__.contains[$aVarName]){$self.__LOCAL_CONTEXT__}{$self.__TEMPLATE__.context}]
  ^switch[$result.[$aVarName].CLASS_NAME]{
    ^case[int;double;bool]{$result($result.[$aVarName])}
    ^case[DEFAULT]{$result[$result.[$aVarName]]}
  }

@GET_TEMPLATE[]
  $result[$self.__TEMPLATE__]

@GET___CONTEXT__[]
# Контект с переменными шаблона из контролера
  $result[^hash::create[$self.__TEMPLATE__.context]]
  ^result.add[$self.__LOCAL_CONTEXT__]

@GET___GLOBAL__[]
## Глобальные переменные шаблона
  $result[$self.__TEMPLATE__.context]

@GET___LOCAL__[]
## Переменные из локальногоконтекста вызова render
  $result[$self.__LOCAL_CONTEXT__]

@__init__[]
## Инициализатор шаблона. Вызываем в __render__ перед __main__
  $result[]

@__main__[]
  ^throw[template.empty;Не нашли функцию main (__main__) в шаблоне. [$self.__FILE__]]

@__render__[aOptions]
## aOptions.context — переменные шаблона
## aOptions.call[__main__] — имя «главной» функции шаблона
## aOptions.init[__init__] — имя инициализатора шаблона
  ^self.cleanMethodArgument[]
  $result[]

# Создаем копию шаблона, чтобы ограничить контекст
  $lContext[^reflection:create[$self.CLASS_NAME;__create__;
    $.source[$self]
    $.localContext[^hash::create[$aOptions.context]]
  ]]

  $lConstructor[^self.ifdef[$aOptions.init]{__init__}]
  ^if(!($lContext.[$lConstructor] is junction)){
    ^throw[template.method.not.found;Инициализатор "${lConstructor}" не найден в шаблоне $lContext.__FILE__]
  }
  $lCResult[^lContext.[$lConstructor][]]

  $lMethod[^self.ifdef[$aOptions.call]{__main__}]
  ^if(!($lContext.[$lMethod] is junction)){
    ^throw[template.method.not.found;Метод "${lMethod}" не найден в шаблоне $lContext.__FILE__]
  }
  $result[^lContext.[$lMethod][]]

@include[aTemplateName;aOptions]
  $result[^self.__TEMPLATE__.render[$aTemplateName;$aOptions]]

@import[aTemplateName;aOptions]
## Динамически импортирует шаблон.
## aTemplateName[/path/to/template.pt@__init__] — имя шаблона и функция, которую вызываем после импорта. Результат в шаблон не попадет
## aOptions.forceLoad(false)
  $result[]
  $lTemplate[^self.__TEMPLATE__.parseTemplateName[$aTemplateName;$.defaultFunction[__init__]]]

  $lTemp[^self.__TEMPLATE__.storage.load[$lTemplate.path;
    $.base[^file:dirname[$self.__FILE__]]
    $.force(^aOptions.forceLoad.bool(false))
  ]]
  ^self.__TEMPLATE__.applyImports[$self;$lTemp.text;$lTemp.path]

# Пробуем вызвать инициализатор, если он есть в импортируемом шаблоне
  ^if(def $lTemplate.function){
    ^if(^lTemp.text.match[^^@^taint[$lTemplate.function]\^[][mn]){
      $lCResult[^self.[$lTemplate.function][]]
    }
  }

@compact[]
## Вызывает принудительную сборку мусора.
  $result[]
  ^pfRuntime:compact[]
