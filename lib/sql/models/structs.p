# PF2 Library

## Классы для организации иерархических структур моделей.

@USE
pf2/lib/common.p
pf2/lib/sql/connection.p
pf2/lib/sql/models/sql_table.p


@CLASS
pfModelModule

## Базовый класс модели. Наследует pfClass и реализует интерфейс цепочек модулей.
## Может быть как вложеным модулем, так и корнем иерархии моделей (core).
## При вызове ^core.module.subModule.subModule.method[] на лету подключает пакеты,
## создает объекты и вызывает метод.

@OPTIONS
locals

@BASE
pfClass

@create[aOptions]
## aOptions.core
## aOptions.sql
## aOptions.schema
## aOptions.exportFields
## aOptions.ignoreChainMixin(false)
  ^BASE:create[]
  ^if(!^aOptions.ignoreChainMixin.bool(false)){
    ^pfModelChainMixin:mixin[$self;$aOptions]
  }

#--------------------------------------------------------------------------------------------------

@CLASS
pfModelTable

## Модель sql-таблица. Наследует pfSQLTable и реализует интерфейс цепочек модулей.

@OPTIONS
locals

@BASE
pfSQLTable

@create[aOptions]
## aOptions.tableName
## aOptions.ignoreChainMixin(false)
  ^BASE:create[$aOptions.tableName;$aOptions]
  $self.__options[^hash::create[$aOptions]]
  ^if(!^aOptions.ignoreChainMixin.bool(false)){
    ^pfModelChainMixin:mixin[$self;^hash::create[$aOptions]
      $.ignoreSQLFields(true)
    ]
  }

#--------------------------------------------------------------------------------------------------

@CLASS
pfModelChainMixin

## Миксин расширяет модели интерфейсом цепочек и записывает в поля базовый набор
## параметров из аргументов конструктора модели (core, sql, schema и т.п.).

@OPTIONS
locals

@BASE
pfChainMixin

@__init__[aThis;aOptions]
## aOptions.core
## aOptions.sql
## aOptions.schema
## aOptions.exportFields
## aOptions.ignoreSQLFields(false)
  $aOptions[^hash::create[$aOptions]]
  ^if(!def $aOptions.core){
    $aOptions.core[$aThis]
  }

  $lDefaultModelExportFields[
    $.sql[_csql]
    $.schema[_schema]
    $.core[_core]
  ]

  $aOptions.exportFields[^hash::create[$lDefaultModelExportFields]]
  ^if(def $aOptions.exportFields){
    ^aOptions.exportFields.add[$aOptions.exportFields]
  }

  ^BASE:__init__[$aThis;$aOptions]

  $aThis._core[$aOptions.core]
  $aThis.core[$aThis._core]

  ^if(!^aOptions.ignoreSQLFields.bool(false)){
    ^pfAssert:isTrue(def $aOptions.sql)[Не передан объект для соединения с БД в конструкторе объекта "$aThis.CLASS_NAME".]

    $aThis._csql[$aOptions.sql]
    $aThis.CSQL[$aThis._csql]

    $aThis._schema[$aOptions.schema]
    $aThis.SCHEMA[$aThis._schema]
  }
