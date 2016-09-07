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

@parseTemplateName[aTemplateName] -> [$.path $.mainFunction]
  $result[^hash::create[]]
  ^aTemplateName.match[$self.PFTEMPLATE_TN_REGEX][]{
    $result.path[$match.1]
    $result.mainFunction[^self.ifdef[$match.2]{__main__}]
  }

@getTemplate[aTemplateName;aOptions] -> [object]
## aTemplateName — имя шаблона.
## aOptions.base — базовый путь от которого ищем шаблон
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
## aTemplateName[/path/to/template.pt@__main__] — имя шаблона и функция, которой передаем управление.
## aOptions.context
## aOptions.force(false)
  ^self.cleanMethodArgument[]
  $lTemp[^self.parseTemplateName[$aTemplateName]]
  $lObj[^self.getTemplate[$lTemp.path;
    $.force(^aOptions.force.bool(false))
  ]]
  $result[^lObj.__render__[
    $.context[$aOptions.context]
    $.call[$lTemp.mainFunction]
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
  ^self.applyImports[$result;$aTemplateText;$aTemplatePath]

@applyImports[aObject;aTemplateText;aTemplatePath] -> []
## Ищем и компилируем импорты
  $result[]

  $lImports[^aTemplateText.match[$self.PFTEMPLATE_IMPORTS_REGEX]]
  $lBase[^file:dirname[$aTemplatePath]]
  $lTemplateName[^file:basename[$aTemplatePath]]

  ^lImports.menu{
    $lImportName[^lImports.1.trim[both; ]]
    ^if($lImportName eq $lTemplateName){^throw[temlate.import.recursive;Нельзя импортировать шаблон "$aTemplatePath" самого в себя.]}
    $lTempl[^self.storage.load[$lImportName;$.base[$lBase]]]

#   Рекурсивно обрабатываем импорты
    ^self.applyImports[$aObject;$lTempl.text;$lTempl.path]
  }

  ^process[$aObject]{^taint[as-is][$aTemplateText]}[
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
      ^case[table]{^self.searchPath.append[$aOptions.searchPath]}
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
  $lFullName[^self.find[$aFileName;$.base[$aOptions.base]]]
  ^if(!def $lFullName){
    ^throw[template.not.found;Не найден шаблон "$aFileName".]
  }
  ^if($lForce || !^self.templates.contains[$lFullName]){
    $lFile[^file::load[text;$lFullName]]
    $result.text[$lFile.text]
    $result.path[$lFullName]
    ^if(!$lForce){
      $self.templates.[$lFullName][$result]
    }
  }{
     $result[$self.templates.[$lFullName]]
   }

@find[aFileName;aOptions] -> [path]
## aOptions.base — базовый путь от которого ищем шаблон
  ^self.cleanMethodArgument[]
  ^pfAssert:isTrue(def $aFileName){Не задано имя шаблона "$aFileName".}
  $result[^if(def $aOptions.base && -f "$aOptions.base/$aFileName"){$aOptions.base/$aFileName}]
  ^if(!def $result){
    ^self.searchPath.foreach[_;v]{
      $lFullName[$v.path/$aFileName]
      ^if(-f $lFullName){
        $result[$lFullName]
        ^break[]
      }
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
  ^self.cleanMethodArgument[]
  ^BASE:create[$aOptions]

  $self.__TEMPLATE__[$aOptions.template]
  $self.__FILE__[$aOptions.file]
  $self.__LOCAL_CONTEXT__[]

@GET_DEFAULT[aVarName]
# Получает переменную из глобального контекста или из контекста шаблона.
  $result[^if(def $self.__LOCAL_CONTEXT__ && ^self.__LOCAL_CONTEXT__.contains[$aVarName]){$self.__LOCAL_CONTEXT__.[$aVarName]}{$self.__TEMPLATE__.context.[$aVarName]}]

@SET_DEFAULT[aVarName;aValue]
# Предотвращаем запись локальных переменных шаблона в объект.
# Если есть контекст, то записываем переменную в контекст.
# Если контекста нет, то игнорируем переменную.
  ^if($self.__LOCAL_CONTEXT__ is hash){
    $self.__LOCAL_CONTEXT__.[$aVarName][$aValue]
  }

@GET_TEMPLATE[]
  $result[$self.__TEMPLATE__]

@GET___GLOBAL__[]
  $result[$self.__TEMPLATE__.context]

@GET___LOCAL__[]
  $result[$self.__LOCAL_CONTEXT__]

@__main__[]
  ^throw[template.empty;Не задано тело шаблона. [$self.__FILE__]]

@__render__[aOptions]
## aOptions.context — переменные шаблона
## aOptions.call[__main__] — имя «главной» функции шаблона
  ^self.cleanMethodArgument[]
  $lOldLocalContext[$self.__LOCAL_CONTEXT__]
  $self.__LOCAL_CONTEXT__[^hash::create[$aOptions.context]]

  $lMethod[^self.ifdef[$aOptions.call]{__main__}]
  ^if(!($self.[$lMethod] is junction)){
    ^throw[template.method.not.found;Метод json не найден в шаблоне $self.__FILE__]
  }
  $result[^self.[$lMethod][]]

  $self.__LOCAL_CONTEXT__[$lOldLocalContext]

@include[aTemplateName;aOptions]
  $result[^self.__TEMPLATE__.render[$aTemplateName;$aOptions]]

@import[aTemplateName;aOptions]
## Динамически импортирует шаблон.
## aOptions.forceLoad(false)
  $result[]
  $lTemp[^self.__TEMPLATE__.storage.load[$aTemplateName;
    $.base[^file:dirname[$self.__FILE__]]
    $.force(^aOptions.forceLoad.bool(false))
  ]]
  ^self.__TEMPLATE__.applyImports[$self;$lTemp.text;$lTemp.path]

@compact[]
## Вызывает принудительную сборку мусора.
  $result[]
  ^pfRuntime:compact[]
