# PF2 Library

@CLASS
pfSQLSettings

@OPTIONS
locals

@USE
pf2/lib/common.p
pf2/lib/sql/connection.p

@BASE
pfClass

@create[aOptions]
## aOptions.sql — ссылка на sql-класс.
## aOptions.ignoreKeyCase(false) — игнорировать регистр символов для ключей.
## aOptions.tableName[settings] — имя таблицы в БД.
## aOptions.keyColumn[key] — имя столбца для ключей в таблице.
## aOptions.valueColumn[value] — имя столбца для ЗНАЧЕНИЙ в таблице.
## aOptions.schema — имя базы данных (если не задано, то используется имя из строки соединения)
  ^self.cleanMethodArgument[]
  ^BASE:create[$aOptions]

  ^pfAssert:isTrue(def $aOptions.sql)[Не задан класс для соединения с СУБД.]
  $self._CSQL[$aOptions.sql]

  $self._schema[$aOptions.schema]
  $self._tableName[^if(def $self._schema){`$self._schema`.}`^taint[^if(def $aOptions.tableName){$aOptions.tableName}{settings}]`]

  $self._ignoreKeyCase(^aOptions.ignoreKeyCase.bool(false))

  $self._keyColumn[^taint[^if(def $aOptions.keyColumn){$aOptions.keyColumn}{key}]]
  $self._valueColumn[^taint[^if(def $aOptions.valueColumn){$aOptions.valueColumn}{value}]]

  $self._vars[^self._CSQL.hash{
    select distinct ^if($self._ignoreKeyCase){upper(`$self._keyColumn`)}{`$self._keyColumn`} as `key`,
                    `$self._valueColumn` as value
               from $self._tableName
        }[$.type[string]]]

@GET_DEFAULT[aKey]
  $result[^self.get[$aKey]]

@SET_DEFAULT[aKey;aValue]
  ^self.set[$aKey;$aValue]

@GET_ALL[]
  $result[$self._vars]

@contains[aKey]
  $lKey[^if($self._ignoreKeyCase){^aKey.upper[]}{$aKey}]
  $result(^_vars.contains[$aKey])

@get[aKey;aDefault]
  $lKey[^if($self._ignoreKeyCase){^aKey.upper[]}{$aKey}]
  $result[^if(^_vars.contains[$lKey]){$self._vars.[$lKey]}{$aDefault}]

@set[aKey;aValue]
  $result[]
  $lKey[^if($self._ignoreKeyCase){^aKey.upper[]}{$aKey}]
  ^self._CSQL.safeInsert{
    ^self._CSQL.void{insert into $self._tableName (`$self._keyColumn`, `$self._valueColumn`) values ("$lKey", "$aValue")}
  }{
    ^self._CSQL.void{update $self._tableName set `$self._valueColumn` = "$aValue" where `$self._keyColumn` = "$lKey"}
   }
  $self._vars.[$lKey][$aValue]

@foreach[aNameVar;aValueVar;aCode;aSeparator]
  $result[^_vars.foreach[k;v]{$caller.[$aNameVar][$k]$caller.[$aValueVar][$v]$aCode}{$aSeparator}]
