# PF2 library

@USE
pf2/lib/common.p

@CLASS
pfTableControllerGenerator

## Генерирует «заготовку» crud-контроллера для модели.
## Этот класс — пример написания генераторов кода и заточен под мой подход к работе
## с модулями pf'а, поэтому не надо ждать от него универсаьности.

@OPTIONS
locals

@BASE
pfClass

@create[]
  ^BASE:create[]

@generate[aModel;aModelName;aOptions]
## aOptions.name[Entity] — имя контроллера.
  ^self.cleanMethodArgument[]
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
    ^self._routes[$lOptions]

  ^self._classBody[$lOptions]
  ]
  $result[^result.match[^^[ \t]{2}][gmx][]]
  $result[^result.match[(^^\s*^$)][gmx][^#0A]]
  $result[^result.match[\n{3,}][g][^#0A]]

@_routes[aOptions]
  $result[
    ^$self._routerRequirements[
      ^$.${aOptions.primaryKey}[\d+]
    ]
    ^^self.router.assign[${aOptions.pathPrefix}:${aOptions.primaryKey}^;^aOptions.pathPrefix.trim[both;/]^;^$.requirements[$_self.routerRequirements]]
    ^^self.router.assign[${aOptions.pathPrefix}new^;person/new]
    ^^self.router.assign[${aOptions.pathPrefix}:${aOptions.primaryKey}/edit^;${aOptions.pathPrefix}edit^;^$.requirements[^$_self.routerRequirements]]
    ^^self.router.assign[${aOptions.pathPrefix}:${aOptions.primaryKey}/delete^;${aOptions.pathPrefix}delete^;^$.requirements[^$_self.routerRequirements]]
    ^if($aOptions.hasRestore){^^self.router.assign[${aOptions.pathPrefix}:${aOptions.primaryKey}/restore^;${aOptions.pathPrefix}restore^;^$.requirements[^$self._routerRequirements]]}
  ]

@_classBody[aOptions]
  $result[
  ^self._indexAction[$aOptions]
  ^self._formProcessor[$aOptions]
  ^self._newAction[$aOptions]
  ^self._editAction[$aOptions]
  ^self._deleteAction[$aOptions]
  ^if($aOptions.hasRestore){^self._restoreAction[$aOptions]}
  ]

@_indexAction[aOptions]
  $result[
  ^if(def $aOptions.prefix){
  ^@onINDEX[aRequest]
    ^$self.title[...]
    ^^self.render[index.pt]
  }
  ^@on${aOptions.index}[^$aRequest]
    ^$${aOptions.localVar}[^^${aOptions.modelName}.one[^$.${aOptions.primaryKey}[^$aRequest.${aOptions.primaryKey}]]]
    ^if(def $aOptions.prefix){^^if(!^$${aOptions.localVar}){^^self.redirectTo[/]}}
    ^$self.title[...]
    ^^self.assignVar[${aOptions.propName}^;^$${aOptions.localVar}]
    ^^self.render[${aOptions.pathPrefix}^if(def $aOptions.prefix){$aOptions.propName}{index}.pt]
  ]

@_formProcessor[aOptions]
  $result[
  ^@${aOptions.formAction}[aRequest]
    ^$result[^^${aOptions.modelName}.cleanForm[^$aRequest]]
  ]

@_newAction[aOptions]
  $result[
  ^@on${aOptions.actionPrefix}New[aRequest]
    ^$self.title[...]
    ^^if(^$aRequest.method eq post){
      ^^antiFlood.process[^$aRequest]){
        ^$lNewData[^^${aOptions.formAction}[$aRequest]]
        ^$lNewID[^^${aOptions.modelName}.new[^$lNewData]]
        ^^self.logOperation[
  #        ^$.log[...]
          ^$.comment[...]
          ^$.dataID[^$lNewID]
        ]
      }
      ^^self.redirectTo[^aOptions.pathPrefix.trim[both;/]^;^$.${aOptions.primaryKey}[^$lNewID]]
    }
    ^^self.render[${aOptions.pathPrefix}edit.pt]
  ]

@_editAction[aOptions]
  $result[
  ^@on${aOptions.actionPrefix}Edit[aRequest]
    ^$${aOptions.localVar}[^^${aOptions.modelName}.one[^$.${aOptions.primaryKey}[^$aRequest.${aOptions.primaryKey}]]]
    ^^if(!^$${aOptions.localVar}){^^self.redirectTo[/]}
    ^$self.title[...]
    ^^if(^$aRequest.method eq post){
      ^^antiFlood.process[^$aRequest]{
        ^$lNewData[^^${aOptions.formAction}[$aRequest]]
        ^^${aOptions.modelName}.modify[^$${aOptions.localVar}.${aOptions.primaryKey}^;^$lNewData]
        ^^self.logOperation[
  #        ^$.log[...]
          ^$.comment[...]
          ^$.oldData[^$${aOptions.localVar}]
          ^$.newData[^$lNewData]
          ^$.dataID[^$${aOptions.localVar}.${aOptions.primaryKey}]
        ]
      }
      ^^self.redirectTo[^aOptions.pathPrefix.trim[both;/]^;^$.${aOptions.primaryKey}[^$${aOptions.localVar}.${aOptions.primaryKey}]]
    }
    ^^self.assignVar[${aOptions.propName}^;^$${aOptions.localVar}]
    ^^self.render[${aOptions.pathPrefix}edit.pt]
  ]

@_deleteAction[aOptions]
  $result[
  ^@on${aOptions.actionPrefix}Delete[aRequest]
    ^$${aOptions.localVar}[^^${aOptions.modelName}.one[^$.${aOptions.primaryKey}[^$aRequest.${aOptions.primaryKey}]]]
    ^^if(^$${aOptions.localVar} && ^$${aOptions.localVar}.isActive){
      ^^${aOptions.modelName}.delete[^$${aOptions.localVar}.${aOptions.primaryKey}]
      ^^self.logOperation[
  #      ^$.log[...]
        ^$.comment[...]
        ^$.oldData[^$${aOptions.localVar}]
        ^$.dataID[^$${aOptions.localVar}.${aOptions.primaryKey}]
      ]
      ^^self.redirectTo[^aOptions.pathPrefix.trim[both;/]^;^$.${aOptions.primaryKey}[^$${aOptions.localVar}.${aOptions.primaryKey}]]
    }
    ^^self.redirectTo[/]
  ]

@_restoreAction[aOptions]
  $result[
  ^@on${aOptions.actionPrefix}Restore[aRequest]
    ^$${aOptions.localVar}[^^${aOptions.modelName}.one[^$.${aOptions.primaryKey}[^$aRequest.${aOptions.primaryKey}]]]
    ^^if(^$${aOptions.localVar} && !^$${aOptions.localVar}.isActive){
      ^^${aOptions.modelName}.restore[^$${aOptions.localVar}.${aOptions.primaryKey}]
      ^^self.logOperation[
  #      ^$.log[...]
        ^$.comment[...]
        ^$.oldData[^$${aOptions.localVar}]
        ^$.dataID[^$${aOptions.localVar}.${aOptions.primaryKey}]
      ]
      ^^self.redirectTo[^aOptions.pathPrefix.trim[both;/]^;^$.${aOptions.primaryKey}[^$${aOptions.localVar}.${aOptions.primaryKey}]]
    }
    ^^self.redirectTo[/]
  ]
