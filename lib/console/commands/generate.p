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

@BASE
pfConsoleCommandWithSubcommands

@create[aOptions][k]
## aOptions.sql — ссылка на класс соединение с БД.
## aOptions.core - ссылка на модель данных.
## aOptions.formWidgets[bootstrap3] — виджеты для генерации форм.
  ^cleanMethodArgument[]
  ^BASE:create[$aOptions]
  ^pfModelChainMixin:mixin[$self;$aOptions]

  $help[Generate models, forms and controllers.]

  $_formWidgets[
    $.bootstrap2[pfTableFormGeneratorBootstrap2Widgets]
    $.bootstrap3[pfTableFormGeneratorBootstrap3Widgets]
    $.semantic[pfTableFormGeneratorSemanticUIWidgets]
  ]
  $_defaultFormWidget[^if(def $aOptions.formWidgets){$aOptions.formWidgets}{bootstrap3}]
  ^pfAssert:isTrue(^_formWidgets.contains[$_defaultFormWidget]){"$_defaultFormWidget" is an unknown form widgets type.}

  ^assignSubcommand[model [schema.]table_name;$model;$.help[Generate a model class by table DDL.]]
  ^assignSubcommand[form core.model_name [widgets];$form;$.help[Generate a html-form by a model object. Available widgets: ^_formWidgets.foreach[k;_]{$k}[, ] (default: ${_defaultFormWidget}).]]
  ^assignSubcommand[controller model.name [entity_name];$controller;$.help[Generate a controller class by a model object.]]

@model[aArgs;aSwitches][locals]
## aArgs.1 — table_name
  $aTableName[$aArgs.1]
  ^if(!def $aTableName){^fail[Not specified a table name in the database.]}
  ^try{
    $lParts[^aTableName.split[.;lh]]
    ^if(def $lParts.1){
      $lSchema[$lParts.0]
      $lTableName[$lParts.1]
    }{
       $lTableName[$lParts.0]
     }
    ^switch[$CSQL.serverType]{
      ^case[mysql]{
        $lGenerator[
          ^pfMySQLTableModelGenerator::create[$lTableName;
            $.sql[$CSQL]
            $.schema[$lSchema]
        ]]
      }
      ^case[pgsql]{
        $lGenerator[
          ^pfPostgresTableModelGenerator::create[$lTableName;
            $.sql[$CSQL]
            $.schema[$lSchema]
        ]]
      }
      ^case[DEFAULT]{
        ^fail["$CSQL.serverType" is an unknown sql-server type.]
      }
    }
    ^print[^lGenerator.generate[]]
  }{
     ^if($exception.type eq "table.not.found"){
       $exception.handled(true)
       ^print[The table "$aTableName" is not found in database.]
     }
   }

@form[aArgs;aSwitches][locals]
  $aModelName[$aArgs.1]
  $aWidgets[$aArgs.2]
  ^if(!def $aModelName){^fail[Not specified a model name.]}
    $aWidgets[^if(def $aWidgets){$aWidgets}{$_defaultFormWidget}]
    ^if(!^_formWidgets.contains[$aWidgets]){
      ^fail["$aWidgets" is an unknow widgets type.]
    }
    $lGenerator[^pfTableFormGenerator::create[
      $.widgets[^reflection:create[$_formWidgets.[$aWidgets];create]]
    ]]
    ^try{
      ^print[^lGenerator.generate[^_getModel[$aModelName]]]
    }{
       ^if($exception.type eq "model.fail"){
         $exception.handled(true)
         ^print[$exception.source]
       }
     }
  }

@controller[aArgs;aSwitches][locals]
  $aModelName[$aArgs.1]
  $aEntityName[$aArgs.2]
  ^if(!def $aModelName){^fail[Not specified a model name.]}
  $lGenerator[^pfTableControllerGenerator::create[]]
  ^print[^lGenerator.generate[^_getModel[$aModelName];$aModelName;$.name[$aEntityName]]]

@_getModel[aModelName]
  $result[]
  ^if(^aModelName.match[^^[a-z0-9_\-\.]+^$][in]){
    ^unsafe{$result[^process{^$$aModelName}]}
    ^if(!def $result){
      ^throw[model.fail;The object "$aModelName" not found.]
    }
  }{
    ^throw[model.fail;Don't use a code in a model name. :)]
  }
