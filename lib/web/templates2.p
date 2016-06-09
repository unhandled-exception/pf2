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
  ^self.vars[^hash::create[]]

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
  $self.vars.[$aName][$aValue]

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
  ^self.PFTEMPLATE_TN_REGEX.match[]{
    $result.path[$match.1]
    $result.mainFunction[^self.ifdef[$match.2]{__main__}]
  }

@getTemplate[aTemplateName;aOptions]
  $lTemplate[^self.parseTemplateName[$aTemplateName]]
  ^if(^self.templates.contains[$lTemplate.name]){
    $result[$self.templates.[$lTemplate.name]]
  }{
     $lTemplate.text[^storage.load[$aTemplate.name]]
     $result[^self._compileTemplate[$lTemplate].text]
   }

@render[aTemplateName;aOptions]
## Рендерит шаблон
## aTemplateName[/path/to/template.pt[@__main__]] — имя шаблона и функция, которой передаем управление.
  $result[]

@GET_DEFAULT[aTemplateName]
## Возвращает объект с шаблоном
## ^template.[/path/to/template.pt].function[arg1;arg2;...]
  $result[^self.getTemplate[$aTemplateName]]

@_compileTemplate[aTemplateText;aOptions]
  $result[]

#---------------------------------------------------------------------------------------------------

@CLASS
pfTemplateStorage

## Хранилище шаблонов

@OPTIONS
locals

@BASE
pfClass

@create[aOptions]
  ^self.cleanMethodArgument[]
  ^BASE:create[$aOptions]

  $self.templates[^hash::create[]]

@load[aFileName;aOptions]
## Загружает шаблон
  $result[]

@GET_DEFAULT[aFileName]
  $result[^self.load[$aTemplateName]]

@reset[aOptions]
  $self.templates[^hash::create[]]
  $result[]
