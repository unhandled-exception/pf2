# PF2 Library

@CLASS
pfSQLSettings

@USE
pf2/lib/common.p
pf2/lib/sql/connection.p

@BASE
pfClass

@create[aOptions]
## aOptions.sql - ссылка на sql-класс.
## aOptions.ignoreKeyCase(false) - игнорировать регистр символов для ключей.
## aOptions.tableName[settings] - имя таблицы в БД.
## aOptions.keyColumn[key] - имя столбца для ключей в таблице.
## aOptions.valueColumn[value] - имя столбца для ЗНАЧЕНИЙ в таблице.
## aOptions.schema - имя базы данных (если не задано, то используется имя из строки соединения)
  ^cleanMethodArgument[]
  ^BASE:create[$aOptions]

  ^pfAssert:isTrue(def $aOptions.sql)[Не задан класс для соединения с СУБД.]
  $_CSQL[$aOptions.sql]

  $_schema[$aOptions.schema]
  $_tableName[^if(def $_schema){`$_schema`.}`^taint[^if(def $aOptions.tableName){$aOptions.tableName}{settings}]`]

  $_ignoreKeyCase(^aOptions.ignoreKeyCase.bool(false))

  $_keyColumn[^taint[^if(def $aOptions.keyColumn){$aOptions.keyColumn}{key}]]
  $_valueColumn[^taint[^if(def $aOptions.valueColumn){$aOptions.valueColumn}{value}]]

  $_vars[^_CSQL.hash{
    select distinct ^if($_ignoreKeyCase){upper(`$_keyColumn`)}{`$_keyColumn`} as `key`,
                    `$_valueColumn` as value
               from $_tableName
        }[$.type[string]]]

@GET_DEFAULT[aKey]
  $result[^get[$aKey]]

@SET_DEFAULT[aKey;aValue]
  ^set[$aKey;$aValue]

@GET_ALL[]
  $result[$_vars]

@contains[aKey][locals]
  $lKey[^if($_ignoreKeyCase){^aKey.upper[]}{$aKey}]
  $result(^_vars.contains[$aKey])

@get[aKey;aDefault][locals]
  $lKey[^if($_ignoreKeyCase){^aKey.upper[]}{$aKey}]
  $result[^if(^_vars.contains[$lKey]){$_vars.[$lKey]}{$aDefault}]

@set[aKey;aValue][locals]
  $result[]
  $lKey[^if($_ignoreKeyCase){^aKey.upper[]}{$aKey}]
  ^_CSQL.safeInsert{
    ^_CSQL.void{insert into $_tableName (`$_keyColumn`, `$_valueColumn`) values ("$lKey", "$aValue")}
  }{
    ^_CSQL.void{update $_tableName set `$_valueColumn` = "$aValue" where `$_keyColumn` = "$lKey"}
   }
  $_vars.[$lKey][$aValue]

@foreach[aNameVar;aValueVar;aCode;aSeparator][locals]
  $result[^_vars.foreach[k;v]{$caller.[$aNameVar][$k]$caller.[$aValueVar][$v]$aCode}{$aSeparator}]
