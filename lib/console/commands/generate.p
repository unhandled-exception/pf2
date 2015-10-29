@USE
pf2/lib/console/console_app.p
pf2/lib/sql/models/structs.p
pf2/lib/sql/models/generators/sql_table_generators.p

@CLASS
pfConsoleGenerateCommand

## Команда для генерации моделей, форм и контроллеров.
## Иллюстрирует использование генераторов кода и написания консольной команды.

@BASE
pfConsoleCommandWithSubcommands

@create[aOptions]
## aOptions.sql — ссылка на класс соединение с БД.
## aOptions.core - ссылка на модель данных.
  ^BASE:create[$aOptions]
  ^pfModelChainMixin:mixin[$self;$aOptions]

  $help[Generate models, forms and controllers.]

  ^assignSubcommand[model [schema.]table_name;$model;$.help[Generate a model class by table DDL.]]
  ^assignSubcommand[form core.model_name;$form;$.help[Generate a html-form by a model object.]]
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
    }
    $lGenerator[^pfTableModelGenerator::create[$lTableName;$.sql[$CSQL] $.schema[$lSchema]]]
    ^print[^lGenerator.generate[]]
  }{
     ^if($exception.type eq "table.not.found"){
       $exception.handled(true)
       ^print[The table "$aTableName" is not found in database.]
     }
   }

@form[aArgs;aSwitches]
  $aModelName[$aArgs.1]
  ^if(!def $aModelName){^fail[Not specified a model name.]}
    $lGenerator[^pfTableFormGenerator::create[]]
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
