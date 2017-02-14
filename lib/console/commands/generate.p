@USE
pf2/lib/console/console_app.p
pf2/lib/sql/models/structs.p

pf2/lib/sql/models/generators/sql_table_generators.p
pf2/lib/sql/models/generators/model_form_generators.p
pf2/lib/sql/models/generators/model_controller_generators.p

@CLASS
pfConsoleGenerateCommand

## Команда для генерации моделей, форм и контроллеров.
## Иллюстрирует использование генераторов кода и написания консольной команды.

@OPTIONS
locals

@BASE
pfConsoleCommandWithSubcommands

@create[aOptions]
## aOptions.sql — ссылка на класс соединение с БД.
## aOptions.core - ссылка на модель данных.
## aOptions.formWidgets[bootstrap3] — виджеты для генерации форм.
## aOptions.modelClassPrefix[] — префикс класса модели.
  ^self.cleanMethodArgument[]
  ^BASE:create[$aOptions]
  ^pfModelChainMixin:mixin[$self;$aOptions]

  $self.help[Generate models, forms and controllers.]

  $self._formWidgets[
    $.bootstrap2[pfTableFormGeneratorBootstrap2Widgets]
    $.bootstrap3[pfTableFormGeneratorBootstrap3Widgets]
    $.bs4v[pfTableFormGeneratorBootstrap4VerticalWidgets]
    $.bs4h[pfTableFormGeneratorBootstrap4HorizontalWidgets]
    $.semantic[pfTableFormGeneratorSemanticUIWidgets]
  ]
  $self._defaultFormWidget[^if(def $aOptions.formWidgets){$aOptions.formWidgets}{bootstrap3}]
  ^pfAssert:isTrue(^_formWidgets.contains[$self._defaultFormWidget]){"$self._defaultFormWidget" is an unknown form widgets type.}

  $self._modelClassPrefix[$aOptions.modelClassPrefix]

  ^self.assignSubcommand[model [schema.]table_name;$model;
    $.help[Generate a model class by table DDL.]
  ]
  ^self.assignSubcommand[form core.model_name [widgets];$form;
    $.help[Generate a html-form by a model object. Available widgets: ^_formWidgets.foreach[k;_]{$k}[, ] (default: ${self._defaultFormWidget}).]
  ]
  ^self.assignSubcommand[controller model.name [entity_name];$controller;
    $.help[Generate a controller class by a model object.]
  ]

@_getModelGenerator[aServerType;aTableName;aSchema]
  $lOptions[
    $.sql[$CSQL]
    $.schema[$aSchema]
    $.classPrefix[$self._modelClassPrefix]
  ]
  $result[
    ^switch[$aServerType]{
      ^case[mysql]{^pfMySQLTableModelGenerator::create[$aTableName;$lOptions]}
      ^case[pgsql]{^pfPostgresTableModelGenerator::create[$aTableName;$lOptions]}
      ^case[DEFAULT]{
        ^self.fail["$CSQL.serverType" is an unknown sql-server type.]
      }
    }
  ]

@model[aArgs;aSwitches]
## aArgs.1 — table_name
  $aTableName[$aArgs.1]
  ^if(!def $aTableName){^self.fail[Not specified a table name in the database.]}
  ^try{
    $lParts[^aTableName.split[.;lh]]
    ^if(def $lParts.1){
      $lSchema[$lParts.0]
      $lTableName[$lParts.1]
    }{
       $lTableName[$lParts.0]
     }
    $lGenerator[^self._getModelGenerator[$CSQL.serverType;$lTableName;$lSchema]]
    ^self.print[^lGenerator.generate[]]
  }{
     ^if($exception.type eq "table.not.found"){
       $exception.handled(true)
       ^self.print[The table "$aTableName" is not found in database.]
     }
   }

@form[aArgs;aSwitches]
  $aModelName[$aArgs.1]
  $aWidgets[$aArgs.2]
  ^if(!def $aModelName){^self.fail[Not specified a model name.]}

  $aWidgets[^if(def $aWidgets){$aWidgets}{$self._defaultFormWidget}]
  ^if(!^_formWidgets.contains[$aWidgets]){
    ^self.fail["$aWidgets" is an unknow widgets type.]
  }
  $lGenerator[^pfTableFormGenerator::create[
    $.widgets[^reflection:create[$self._formWidgets.[$aWidgets];create]]
  ]]
  ^try{
    ^self.print[^lGenerator.generate[^self._getModel[$aModelName]]]
  }{
     ^if($exception.type eq "model.fail"){
       $exception.handled(true)
       ^self.print[$exception.source]
     }
   }

@controller[aArgs;aSwitches]
  $aModelName[$aArgs.1]
  $aEntityName[$aArgs.2]
  ^if(!def $aModelName){^self.fail[Not specified a model name.]}
  $lGenerator[^pfTableControllerGenerator::create[]]
  ^self.print[^lGenerator.generate[^self._getModel[$aModelName];$aModelName;$.name[$aEntityName]]]

@_getModel[aModelName]
  $result[]
  ^if(^aModelName.match[^^[a-z0-9_\-\.]+^$][in]){
    ^self.unsafe{$result[^process{^$$aModelName}]}
    ^if(!def $result){
      ^throw[model.fail;The object "$aModelName" not found.]
    }
  }{
    ^throw[model.fail;Don't use a code in a model name. :)]
  }
