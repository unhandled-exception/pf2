# PF2 library

@USE
pf2/lib/common.p

@CLASS
pfTableControllerGenerator

## Генерирует «заготовку» crud-контроллера для модели.
## Этот класс — пример написания генераторов кода и заточен под мой подход к работе
## с модулями pf'а, поэтому не надо ждать от него универсаьности.

@BASE
pfClass

@create[]
  ^BASE:create[]

@generate[aModel;aModelName;aOptions][locals]
## aOptions.name[Entity] — имя контроллера.
  ^cleanMethodArgument[]
  ^pfAssert:isTrue($aModel is pfSQLTable)[Модель должна быть наследником pfSQLTable.]
  ^pfAssert:isTrue(def $aModel._primaryKey)[Модель должна иметь первичный ключ.]
  ^pfAssert:isTrue(def $aModelName)[Не задано имя модели.]

  $lOptions[^hash::create[]]
  $lOptions.modelName[$aModelName]
  $lOptions.prefix[^aOptions.name.lower[]]
  $lOptions.pathPrefix[^if(def $lOptions.prefix){$lOptions.prefix/}]
  $lOptions.name[^if(def $lOptions.prefix){^pfString:changeCase[$aOptions.name;first-upper]}{Entity}]
  $lOptions.propName[^lOptions.name.lower[]]
  $lOptions.actionPrefix[^if(def $lOptions.prefix){$lOptions.name}]
  $lOptions.formAction[_${lOptions.propName}FromRequest]
  $lOptions.localVar[l$lOptions.name]
  $lOptions.index[^if(def $lOptions.prefix){$lOptions.name}{INDEX}]
  $lOptions.hasRestore($aModel.restore is junction)
  $lOptions.primaryKey[$aModel._primaryKey]

  $result[
  ^@create^[aOptions^]
    ^^BASE:create^[^$aOptions^]
    ...
    ^_routes[$lOptions]

  ^_classBody[$lOptions]
  ]
  $result[^result.match[^^[ \t]{2}][gmx][]]
  $result[^result.match[(^^\s*^$)][gmx][^#0A]]
  $result[^result.match[\n{3,}][g][^#0A]]

@_routes[aOptions]
  $result[
    ^$_routerRequirements[
      ^$.${aOptions.primaryKey}[\d+]
    ]
    ^^router.assign[${aOptions.pathPrefix}:${aOptions.primaryKey}^;^aOptions.pathPrefix.trim[both;/]^;^$.requirements[$_routerRequirements]]
    ^^router.assign[${aOptions.pathPrefix}new^;person/new]
    ^^router.assign[${aOptions.pathPrefix}:${aOptions.primaryKey}/edit^;${aOptions.pathPrefix}edit^;^$.requirements[^$_routerRequirements]]
    ^^router.assign[${aOptions.pathPrefix}:${aOptions.primaryKey}/delete^;${aOptions.pathPrefix}delete^;^$.requirements[^$_routerRequirements]]
    ^if($aOptions.hasRestore){^^router.assign[${aOptions.pathPrefix}:${aOptions.primaryKey}/restore^;${aOptions.pathPrefix}restore^;^$.requirements[^$_routerRequirements]]}
  ]

@_classBody[aOptions]
  $result[
  ^_indexAction[$aOptions]
  ^_formProcessor[$aOptions]
  ^_newAction[$aOptions]
  ^_editAction[$aOptions]
  ^_deleteAction[$aOptions]
  ^if($aOptions.hasRestore){^_restoreAction[$aOptions]}
  ]

@_indexAction[aOptions]
  $result[
  ^if(def $aOptions.prefix){
  ^@onINDEX[aRequest][locals]
    ^$self.title[...]
    ^^render[index.pt]
  }
  ^@on${aOptions.index}[^$aRequest][locals]
    ^$${aOptions.localVar}[^^${aOptions.modelName}.one[^$.${aOptions.primaryKey}[^$aRequest.${aOptions.primaryKey}]]]
    ^if(def $aOptions.prefix){^^if(!^$${aOptions.localVar}){^^redirectTo[/]}}
    ^$self.title[...]
    ^^assignVar[${aOptions.propName}^;^$${aOptions.localVar}]
    ^^render[${aOptions.pathPrefix}^if(def $aOptions.prefix){$aOptions.propName}{index}.pt]
  ]

@_formProcessor[aOptions]
  $result[
  ^@${aOptions.formAction}[aRequest][locals]
    ^$result[^^${aOptions.modelName}.cleanForm[^$aRequest]]
  ]

@_newAction[aOptions]
  $result[
  ^@on${aOptions.actionPrefix}New[aRequest][locals]
    ^$self.title[...]
    ^^if(^$aRequest.isPOST){
      ^^antiFlood.process[^$aRequest]){
        ^$lNewData[^^${aOptions.formAction}[$aRequest]]
        ^$lNewID[^^${aOptions.modelName}.new[^$lNewData]]
        ^^logOperation[
  #        ^$.log[...]
          ^$.comment[...]
          ^$.dataID[^$lNewID]
        ]
      }
      ^^redirectTo[^aOptions.pathPrefix.trim[both;/]^;^$.${aOptions.primaryKey}[^$lNewID]]
    }
    ^^render[${aOptions.pathPrefix}edit.pt]
  ]

@_editAction[aOptions]
  $result[
  ^@on${aOptions.actionPrefix}Edit[aRequest][locals]
    ^$${aOptions.localVar}[^^${aOptions.modelName}.one[^$.${aOptions.primaryKey}[^$aRequest.${aOptions.primaryKey}]]]
    ^^if(!^$${aOptions.localVar}){^^redirectTo[/]}
    ^$self.title[...]
    ^^if(^$aRequest.isPOST){
      ^^antiFlood.process[^$aRequest]{
        ^$lNewData[^^${aOptions.formAction}[$aRequest]]
        ^^${aOptions.modelName}.modify[^$${aOptions.localVar}.${aOptions.primaryKey}^;^$lNewData]
        ^^logOperation[
  #        ^$.log[...]
          ^$.comment[...]
          ^$.oldData[^$${aOptions.localVar}]
          ^$.newData[^$lNewData]
          ^$.dataID[^$${aOptions.localVar}.${aOptions.primaryKey}]
        ]
      }
      ^^redirectTo[^aOptions.pathPrefix.trim[both;/]^;^$.${aOptions.primaryKey}[^$${aOptions.localVar}.${aOptions.primaryKey}]]
    }
    ^^assignVar[${aOptions.propName}^;^$${aOptions.localVar}]
    ^^render[${aOptions.pathPrefix}edit.pt]
  ]

@_deleteAction[aOptions]
  $result[
  ^@on${aOptions.actionPrefix}Delete[aRequest][locals]
    ^$${aOptions.localVar}[^^${aOptions.modelName}.one[^$.${aOptions.primaryKey}[^$aRequest.${aOptions.primaryKey}]]]
    ^^if(^$${aOptions.localVar} && ^$${aOptions.localVar}.isActive){
      ^^${aOptions.modelName}.delete[^$${aOptions.localVar}.${aOptions.primaryKey}]
      ^^logOperation[
  #      ^$.log[...]
        ^$.comment[...]
        ^$.oldData[^$${aOptions.localVar}]
        ^$.dataID[^$${aOptions.localVar}.${aOptions.primaryKey}]
      ]
      ^^redirectTo[^aOptions.pathPrefix.trim[both;/]^;^$.${aOptions.primaryKey}[^$${aOptions.localVar}.${aOptions.primaryKey}]]
    }
    ^^redirectTo[/]
  ]

@_restoreAction[aOptions]
  $result[
  ^@on${aOptions.actionPrefix}Restore[aRequest][locals]
    ^$${aOptions.localVar}[^^${aOptions.modelName}.one[^$.${aOptions.primaryKey}[^$aRequest.${aOptions.primaryKey}]]]
    ^^if(^$${aOptions.localVar} && !^$${aOptions.localVar}.isActive){
      ^^${aOptions.modelName}.restore[^$${aOptions.localVar}.${aOptions.primaryKey}]
      ^^logOperation[
  #      ^$.log[...]
        ^$.comment[...]
        ^$.oldData[^$${aOptions.localVar}]
        ^$.dataID[^$${aOptions.localVar}.${aOptions.primaryKey}]
      ]
      ^^redirectTo[^aOptions.pathPrefix.trim[both;/]^;^$.${aOptions.primaryKey}[^$${aOptions.localVar}.${aOptions.primaryKey}]]
    }
    ^^redirectTo[/]
  ]
