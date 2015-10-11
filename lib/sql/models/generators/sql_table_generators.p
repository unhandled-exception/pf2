# PF2 library

@USE
pf2/lib/common.p


@CLASS
pfTableModelGenerator

## Генерирует текст класса модели по DDL.
## Класс умеет получать описания таблиц только из MySQL.

@BASE
pfClass

@create[aTableName;aOptions]
## aOptions.sql
## aOptions.schema
  ^cleanMethodArgument[]
  ^pfAssert:isTrue(def $aOptions.sql)[Не задан объект для соединения к СУБД.]
  ^pfAssert:isTrue($aOptions.sql.serverType eq "mysql")[Класс умеет получать описания таблиц только из MySQL.]
  ^BASE:create[]

  $_sql[$aOptions.sql]
  ^defReadProperty[CSQL;_sql]

  $_schema[$aOptions.schema]
  $_tableName[$aTableName]
  ^if(!def $_tableName || !^CSQL.table{show tables ^if(def $_schema){from `$_schema`} like "$_tableName"}){
    ^throw[table.not.found]
  }

  $_fields[^_getFields[]]

@_getFields[][locals]
  $result[^hash::create[]]
  $lDDL[^CSQL.table{describe ^if(def $_schema){`$_schema`.}`$_tableName`}]
  $lHasPrimary(^lDDL.select($lDDL.Key eq "PRI") == 1)
  $self._primary[]

  ^lDDL.menu{
    $lName[^_makeName[$lDDL.Field]]
    $lData[^hash::create[]]

    ^if($lDDL.Field ne $lName){$lData.dbField[$lDDL.Field]}

    $lType[^_parseType[$lDDL.Type]]
    ^switch[^lType.type.lower[]]{
      ^case[int;integer;smallint;mediumint]{
        $lData.processor[^if($lType.unsigned){uint}{int}]
        ^unsafe{$lData.default(^lDDL.Default.int[])}
      }
      ^case[tinyint]{
        $lData.processor[^if($lType.unsigned){uint}{int}]
        ^unsafe{$lData.default(^lDDL.Default.int[])}
        ^if(^lType.format.int(0) == 1
            || ^lDDL.Field.pos[is_] == 0){
          $lData.processor[bool]
          $lData.default(^lDDL.Default.bool(true))
        }
      }
      ^case[float;double;decimal;numeric]{
        $lData.processor[double]
        ^if(def $lType.format){
          $lData.format[^lType.format.match[^^(\d+)\,(\d+)^$][]{%${match.1}.${match.2}f}]
        }
        ^unsafe{$lData.default(^lDDL.Default.double[])}
      }
      ^case[date]{$lData.processor[date]}
      ^case[datetime]{$lData.processor[datetime]}
      ^case[time]{$lData.processor[time]}
    }

    ^if($lDDL.Key eq "PRI" && $lHasPrimary){
      $lData.primary(true)
      $self._primary[$lName]
      ^if(!^lDDL.Extra.match[auto_increment][in]){
        $lData.sequence(false)
      }
      $lData.widget[none]
    }

    ^if($lName eq "createdAt"){
      $lData.processor[auto_now]
      $lData.skipOnUpdate(true)
      $lData.widget[none]
    }
    ^if($lName eq "updatedAt"){
      $lData.processor[auto_now]
      $lData.widget[none]
    }
    ^if($lName eq "isActive"){
      $lData.widget[none]
    }
    ^if(^lName.match[IP^$][n] || $lName eq "ip"){
      ^if(!def $lData.dbField){
        $lData.dbField[$lName]
      }
      $lData.processor[inet_ip]
      $lData.expression[inet_ntoa(^^_builder.quoteIdentifier[^$TABLE_ALIAS].^^_builder.quoteIdentifier[$lData.dbField])]
      $lData.fieldExpression[^^_builder.quoteIdentifier[^$TABLE_ALIAS].^^_builder.quoteIdentifier[$lData.dbField]]
    }

    ^if(!def $lData.widget){
      $lData.label[]
    }

    $result.[$lName][$lData]
  }

@_parseType[aTypeString]
  $aTypeString[^aTypeString.lower[]]
  $result[^hash::create[]]
  ^aTypeString.match[^^(\w+)(\(.+?\))?(.+)?][]{
    $result.type[$match.1]
    $result.format[^match.2.trim[both;()]]
    $result.options[$match.3]
    ^if(^result.options.match[unsigned][in]){
      $result.unsigned(true)
    }
  }

@_makeName[aName]
  $aName[^aName.lower[]]
  $result[^aName.match[_(\w)][g]{^match.1.upper[]}]
  $result[^result.match[Id^$][][ID]]
  $result[^result.match[Ip^$][][IP]]

@generate[aOptions]
  ^cleanMethodArgument[]
  $result[
  ^@CLASS
  ${_tableName}
  # Table ^if(def $_schema){`$_schema`.}`$_tableName`

  ^@USE
  pf2/sql/models/sql_table.p

  ^@BASE
  pfSQLTable

  ^@create^[aTableName^;aOptions^]
    ^^BASE:create^[^$aTableName^;^^hash::create^[^$aOptions^]
  #    ^$.tableAlias^[^]
  #    ^$.allAsTable(true)
    ^]

  ^_classBody[]
  ]
  $result[^result.match[^^[ \t]{2}][gmx][]]
  $result[^result.match[(^^\s*^$){3,}][gmx][^#0A]]

@_classBody[][locals]
$result[
    ^^addFields^[
      ^_fields.foreach[k;v]{^$.$k^[^v.foreach[n;m]{^$.$n^if($m is bool){(^if($m){true}{false})}{^if($m is double){^($m^)}{^[$m^]}}}[ ]^]}[^#0A      ]
    ^]

  ^if(def $_primary){
    ^$_defaultOrderBy^[^$.${_primary}[asc]]
  }

  ^if(^_fields.contains[isActive] && def $_primary){
  $lArgument[a^pfString:changeCase[$_primary;first-upper]]
  ^@delete^[$lArgument^]
    ^$result^[^^modify^[^$$lArgument^;^$.isActive(false)^]^]

  ^@restore^[$lArgument^]
    ^$result^[^^modify^[^$$lArgument^;^$.isActive(true)^]^]
  }
]


#--------------------------------------------------------------------------------------------------

@CLASS
pfTableFormGenerator

## Генерирует «заготовку» формы по модели
## Этот класс — пример написания генераторов кода и заточен под библиотеку Бутстрап 2
## и мой подход к работе с шаблонами, поэтому не надо ждать от него универсальности.

## Виджеты:
##   none — без виджета (пропускаем поле)
##   [input] — стандартный виджет, если не указано иное
##   password
##   hidden
##   textarea
## Виджеты-заготовки (для них  форме выводится шаблончик, который надо дописать программисту :)
##   checkbox
##   radio
##   select

@BASE
pfClass

@create[aOptions]
## aOptions.widgets[object]
  ^cleanMethodArgument[]
  ^BASE:create[]
  $_defaultArgName[aFormData]

  $_widgets[^if(def $aOptions.widgets){$aOptions.widgets}{^pfTableFormGeneratorBootstrap2Widgets::create[]}]

@generate[aModel;aOptions][locals]
## aOptions.argName
  ^pfAssert:isTrue($aModel is pfSQLTable)[Модель "$aModel.CLASS_NAME" должна быть наследником pfSQLTable.]
  $aOptions[^hash::create[$aOptions]]
  $aOptions.argName[^if(def $aOptions.agrName){$aOptions.argName}{$_defaultArgName}]
  $result[^hash::create[]]

  ^aModel.FIELDS.foreach[k;v]{
    ^if(^_hasWidget[$v;$aModel]){
      $result.[^result._count[]][^_makeWidgetLine[$v;$aOptions]]
    }
  }
  $result[@form^[$aOptions.argName^;aOptions^]^[locals^]
  ^^cleanMethodArgument^[^]
  ^^cleanMethodArgument^[$aOptions.argName^]
  ^_widgets.formWidget{
    ^result.foreach[k;v]{$v^#0A^#0A}
    ^_widgets.submitWidget[$aOptions]
  }
  ]
  $result[^result.match[(^^\s*^$)][gmx][^#0A]]
  $result[^result.match[\n{3,}][g][^#0A]]

@_hasWidget[aField;aModel]
  $result($aField.widget ne none)

@_makeWidgetLine[aField;aOptions]
  $result[^switch[$aField.widget]{
        ^case[;input;password]{^_widgets.inputWidget[$aField;$aField.widget;$aOptions]}
        ^case[hidden]{^_widgets.hiddenWidget[$aField;$aOptions]}
        ^case[textarea]{^_widgets.textareaWidget[$aField;$aOptions]}
        ^case[checkbox;radio]{^_widgets.checkboxWidget[$aField;$aField.widget;$aOptions]}
        ^case[select]{^_widgets.selectWidget[$aField;$aOptions]}
      }]

#--------------------------------------------------------------------------------------------------
# Виджеты для генератора форм
#--------------------------------------------------------------------------------------------------

@CLASS
pfTableFormGeneratorBootstrap2Widgets

## Bootstrap 2

@BASE
pfClass

@create[aOptions]
  ^BASE:create[]

@formWidget[aBlock]
  $result[<form action="" method="post" class="form-horizontal">
    $aBlock
  </form>]

@inputWidget[aField;aType;aOptions]
  $result[
    <div class="control-group">
      <label for="f-$aField.name" class="control-label">$aField.label</label>
      <div class="controls">
        <input type="^if(def $aType){$aType}{text}" name="$aField.name" id="f-$aField.name" value="^$${aOptions.argName}.$aField.name" class="input-xxlarge" placeholder="" />
      </div>
    </div>]

@textareaWidget[aField;aOptions]
  $result[
    <div class="control-group">
      <label for="f-$aField.name" class="control-label">$aField.label</label>
      <div class="controls">
        <textarea name="$aField.name" id="f-$aField.name" class="input-xxlarge" rows="7" placeholder="" />^$${aOptions.argName}.$aField.name</textarea>
      </div>
    </div>]

@checkboxWidget[aField;aType;aOptions][locals]
  $lVarName[^$${aOptions.argName}.$aField.name]
  $aType[^if(def $aType){$aType}{checkbox}]
  $result[
    <div class="control-group">
      <div class="controls">
        <label class="$aType"><input type="$aType" name="$aField.name" id="f-${aField.name}1" value="1" ^^if($lVarName){checked="true"} /> $aField.label</label>
      </div>
    </div>]

@selectWidget[aField;aOptions]
  $result[
    <div class="control-group">
      <label for="f-$aField.name" class="control-label">$aField.label</label>
      <div class="controls">
        <select name="$aField.name" id="f-$aField.name" class="input-xxlarge" placeholder="">
          <option value=""></option>
^#          <option value="" ^^if(^$${aOptions.argName}.$aField.name eq ""){selected="true"}></option>
        </select>
      </div>
    </div>]

@hiddenWidget[aField;aOptions]
  $result[    <input type="hidden" name="$aField.name" value="^$${aOptions.argName}.$aField.name" />]

@submitWidget[aOptions]
  ^cleanMethodArgument[]
  $result[^^antiFlood.field^[^]
    <div class="control-group">
      <div class="controls">
        <input type="submit" id="f-sub" value="Сохранить" class="btn btn-primary" />
        или <a href="^^linkTo^[/^]" class="action">Ничего не менять</a>
      </div>
    </div>
  ]

#--------------------------------------------------------------------------------------------------

@CLASS
pfTableFormGeneratorBootstrap3Widgets

## Bootstrap 3

@BASE
pfClass

@create[aOptions]
  ^BASE:create[]

@formWidget[aBlock]
  $result[<form action="" method="post" class="form-horizontal form-default">
    $aBlock
  </form>]

@inputWidget[aField;aType;aOptions]
  $result[
    <div class="form-group">
      <label for="f-$aField.name" class="control-label col-sm-3">$aField.label</label>
      <div class="col-sm-9">
        <input type="^if(def $aType){$aType}{text}" name="$aField.name" id="f-$aField.name" value="^$${aOptions.argName}.$aField.name" class="form-control" placeholder="" />
      </div>
    </div>]

@textareaWidget[aField;aOptions]
  $result[
    <div class="form-group">
      <label for="f-$aField.name" class="control-label col-sm-3">$aField.label</label>
      <div class="col-sm-9">
        <textarea name="$aField.name" id="f-$aField.name" class="form-control" rows="7" placeholder="" />^$${aOptions.argName}.$aField.name</textarea>
      </div>
    </div>]

@checkboxWidget[aField;aType;aOptions][locals]
  $lVarName[^$${aOptions.argName}.$aField.name]
  $aType[^if(def $aType){$aType}{checkbox}]
  $result[
    <div class="form-group">
      <div class="col-sm-offset-3 col-sm-9">
        <div class="$aType"><label><input type="$aType" name="$aField.name" id="f-${aField.name}1" value="1" ^^if($lVarName){checked="true"} /> $aField.label</label></div>
      </div>
    </div>]

@selectWidget[aField;aOptions]
  $result[
    <div class="form-group">
      <label for="f-$aField.name" class="control-label col-sm-3">$aField.label</label>
      <div class="col-sm-9">
        <select name="$aField.name" id="f-$aField.name" class="form-control" placeholder="">
          <option value=""></option>
^#          <option value="" ^^if(^$${aOptions.argName}.$aField.name eq ""){selected="true"}></option>
        </select>
      </div>
    </div>]

@hiddenWidget[aField;aOptions]
  $result[    <input type="hidden" name="$aField.name" value="^$${aOptions.argName}.$aField.name" />]

@submitWidget[aOptions]
  ^cleanMethodArgument[]
  $result[^^antiFlood.field^[^]
    <div class="form-group">
      <div class="col-sm-offset-3 col-sm-9">
        <input type="submit" id="f-sub" value="Сохранить" class="btn btn-primary" />
        или <a href="^^linkTo^[/^]" class="action">Ничего не менять</a>
      </div>
    </div>
  ]

#--------------------------------------------------------------------------------------------------

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


