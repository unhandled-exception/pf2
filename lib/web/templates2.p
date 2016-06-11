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

@assign[aName;aValue]
  $result[]
  $self.context.[$aName][$aValue]

@multiAssign[aVars]
  $result[]
  ^aVars.foreach[k;v]{
    ^self.assign[$k;$v]
  }

@resetVars[]
  $result[]
  $self.vars[^hash::create[]]

@parseTemplateName[aTemplateName]
  $result[^hash::create[]]
  ^aTemplateName.match[$PFTEMPLATE_TN_REGEX][]{
    $result.path[$match.1]
    $result.mainFunction[^self.ifdef[$match.2]{__main__}]
  }

@getTemplate[aTemplateName;aOptions]
## aOptions.base — базовый путь от которого ищем шаблон
## aOptions.force(false)
  ^self.cleanMethodArgument[]
  $lForce(^aOptions.force.bool(false))
  $lTemplate[^self.parseTemplateName[$aTemplateName]]
  ^if(!$lForce && ^self.templates.contains[$lTemplate.name]){
    $result[$self.templates.[$lTemplate.name]]
  }{
     $lTemplate.file[^self.storage.load[$lTemplate.path;
       $.base[$aOptions.base]
       $.force($lForce)
     ]]
     $result[^self._compileTemplate[$lTemplate.file.text]]
     ^if(!$lForce){
       $self.templates.[$lTemplate.name][$result]
     }
   }

@render[aTemplateName;aOptions]
## Рендерит шаблон
## aTemplateName[/path/to/template.pt[@__main__]] — имя шаблона и функция, которой передаем управление.
  $result[]

@GET_DEFAULT[aTemplateName]
## Возвращает объект с шаблоном
## ^template.[/path/to/template.pt].function[arg1;arg2;...]
  $result[^self.getTemplate[$aTemplateName]]

@_compileTemplate[aTemplateText;aOptions]
  $result[$.text[$aTemplateText]]

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

@load[aFileName;aOptions]
## Загружает шаблон
## aOptions.base — базовый путь от которого ищем шаблон
## aOptions.force(false) — отменяет кеширование
## result[$.text $.path]
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

@find[aFileName;aOptions]
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
  $result[^if(def $self.__LOCAL_CONTEXT__ && ^self.__LOCAL_CONTEXT__.contains[$aVarName]){$self.__LOCAL_CONTEXT__.[$aVarName]}{$self.__TEMPLATE__.context.[$aVarName]}]

@GET_TEMPLATE[]
  $result[$self.__TEMPLATE__]

@GET___GLOBAL__[]
  $result[$self.__TEMPLATE__.context]

@GET___LOCAL__[]
  $result[$self.__LOCAL_CONTEXT__]

@__main__[]
  ^throw[template.empty;Не задано тело шаблона.]

@__render__[aOptions]
## aOptions.context
## aOptions.call[__main__]
  $result[]

@include[aTemplateName;aOptions]
  $result[^self.__TEMPLATE__.render[$aTemplateName;$aOptions]]

@import[aTemplateName]
  $result[]

@compact[]
## Вызывает принудительную сборку мусора.
  $result[]
  ^pfRuntime::compact[]
