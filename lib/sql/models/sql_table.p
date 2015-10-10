# PF2 Library

@USE
pf2/lib/sql/connection.p

@CLASS
pfSQLTable

## Шлюз таблицы данных (Table Data Gateway).

@BASE
pfClass

@create[aTableName;aOptions][k;v]
## aOptions.sql
## aOptions.tableAlias
## aOptions.schema — название базы данных (можно не указывать).
## aOptions.builder
## aOptions.allAsTable(false) — по умолчанию возвращать результат в виде таблицы.

## Следующие поля необязательны, но полезны
## при создании объекта на основании другой таблицы:
##   aOptions.fields[$.field[...]]
##   aOptions.primaryKey
##   aOptions.skipOnInsert[$.field(bool)]
##   aOptions.skipOnUpdate[$.field(bool)]
  ^cleanMethodArgument[]
  ^BASE:create[$aOptions]

  $_csql[^if(def $aOptions.sql){$aOptions.sql}{$_PFSQLTABLE_CSQL}]
  ^pfAssert:isTrue(def $_csql){Не задан объект для работы с SQL-сервером.}

  $_builder[^if(def $aOptions.builder){$aOptions.builder}{$_PFSQLTABLE_BUILDER}]
  ^if(!def $_builder){
    $_builder[^pfSQLBuilder::create[$.quoteStyle[$_csql.serverType]]]
  }

  $_schema[^aOptions.schema.trim[]]

  $_tableName[$aTableName]
  $_tableAlias[^if(def $aOptions.tableAlias){$aOptions.tableAlias}(def $_schema){${_schema}_$_tableName}]
  $_primaryKey[^if(def $aOptions.primaryKey){$aOptions.primaryKey}]

  $_fields[^hash::create[]]
  $_plurals[^hash::create[]]
  ^if(^aOptions.contains[fields]){
    ^addFields[$aOptions.fields]
  }

  $_skipOnInsert[^hash::create[^if(def $aOptions.skipOnInsert){$aOptions.skipOnInsert}]]
  $_skipOnUpdate[^hash::create[^if(def $aOptions.skipOnUpdate){$aOptions.skipOnUpdate}]]

  $_defaultResultType[^if(^aOptions.allAsTable.bool(false)){table}{hash}]

  $_defaultOrderBy[]
  $_defaultGroupBy[]

  $_now[^date::now[]]
  $_today[^date::today[]]

  $__context[]

# Алиасы методов для совоместимости со старым кодом.
  ^alias[_fieldValue;$fieldValue]
  ^alias[_valuesArray;$valuesArray]
  ^alias[_sqlFieldName;$sqlFieldName]
  ^alias[_asContext;$asContext]

#----- Статические методы и конструктор -----

@auto[]
  $_PFSQLTABLE_CSQL[]
  $_PFSQLTABLE_BUILDER[]
  $_PFSQLTABLE_COMPARSION_REGEX[^regex::create[^^\s*(\S+)(?:\s+(\S+))?][]]
  $_PFSQLTABLE_AGR_REGEX[^regex::create[^^\s*(([^^\s(]+)(.*?))\s*(?:as\s+([^^\s\)]+))?\s*^$][i]]
  $_PFSQLTABLE_OPS[
    $.[<][<]
    $.[>][>]
    $.[<=][<=]
    $.[>=][>=]
    $.[!=][<>]
    $.[!][<>]
    $.[<>][<>]
    $.like[like]
    $.[=][=]
    $.[==][=]
    $._default[=]
  ]
  $_PFSQLTABLE_LOGICAL[
    $.OR[or]
    $.AND[and]
    $.NOT[and]
    $._default[and]
  ]

@static:assignServer[aSQLConnection]
# Чтобы можно было задать коннектор для всех объектов сразу.
  $_PFSQLTABLE_CSQL[$aSQLConnection]

@static:assignBuilder[aSQLBuilder]
  $_PFSQLTABLE_BUILDER[$aSQLBuilder]

#----- Метаданные -----

@addField[aFieldName;aOptions][locals]
## aOptions.dbField[aFieldName] — название поля
## aOptions.fieldExpression{} — выражение для названия поля
## aOptions.expression{} — sql-выражение для значения поля (если не определено, то используем fieldExpression)
## aOptions.plural[] — название поля для групповой выборки
## aOptions.processor — процессор
## aOptions.default — значение «по-умолчанию»
## aOptions.format — формат числового значения
## aOptions.primary(false) — первичный ключ
## aOptions.sequence(true) — последовательность формирует БД (автоинкремент; только для первичного ключа)
## aOptions.skipOnInsert(false) — пропустить при вставке
## aOptions.skipOnUpdate(false) — пропустить при обновлении
## aOptions.label[aFieldName] — текстовое название поля (например, для форм)
## aOptions.comment — описание поля
## aOptions.widget — название html-виджета для редактирования поля.
  $result[]
  ^cleanMethodArgument[]
  ^pfAssert:isTrue(def $aFieldName){Не задано имя поля таблицы.}
  ^pfAssert:isTrue(!^_fields.contains[$aFieldName]){Поле «${aFieldName}» в таблице уже существует.}

  $lField[^hash::create[]]

  $lField.name[$aFieldName]
  $lField.plural[$aOptions.plural]
  $lField.processor[^if(def $aOptions.processor){$aOptions.processor}]
  $lField.default[^if(def $aOptions.default){$aOptions.default}]
  $lField.format[^if(def $aOptions.format){$aOptions.format}]

  $lField.label[^if(def $aOptions.label){$aOptions.label}{$lField.name}]
  $lField.comment[$aOptions.comment]
  $lField.widget[$aOptions.widget]

  ^if(^aOptions.contains[fieldExpression] || ^aOptions.contains[expression]){
     ^if(def $aOptions.dbField){$lField.dbField[$aOptions.dbField]}
     $lField.fieldExpression[$aOptions.fieldExpression]
     $lField.expression[$aOptions.expression]
     ^if(!def $lField.expression){
       $lField.expression[$lField.fieldExpression]
     }
     ^if(!def $lField.dbField){
       $self._skipOnUpdate.[$aFieldName](true)
       $self._skipOnInsert.[$aFieldName](true)
     }
  }{
     $lField.dbField[^if(def $aOptions.dbField){$aOptions.dbField}{$aFieldName}]
     $lField.primary(^aOptions.primary.bool(false))
     $lField.sequence($lField.primary && ^aOptions.sequence.bool(true))
     ^if(^aOptions.skipOnUpdate.bool(false) || $lField.primary){
       $self._skipOnUpdate.[$aFieldName](true)
     }
     ^if(^aOptions.skipOnInsert.bool(false) || $lField.sequence){
       $self._skipOnInsert.[$aFieldName](true)
     }
     ^if(def $lField.primary && !def $_primaryKey){
       $self._primaryKey[$aFieldName]
     }
   }
  $_fields.[$aFieldName][$lField]
  ^if(def $lField.plural){
    $_plurals.[$lField.plural][$lField]
  }

@addFields[aFields][locals]
## Добавляет сразу несколько полей
## aFields[hash]
  ^cleanMethodArgument[aFields]
  $result[]
  ^aFields.foreach[k;v]{
    ^addField[$k;$v]
  }

@hasField[aFieldName]
## Проверяет наличие поля в таблице
  $result(def $aFieldName && ^_fields.contains[$aFieldName])

@replaceField[aFieldName;aOptions]
  ^if(^hasField[$aFieldName]){
    ^_fields.delete[$aFieldName]
  }
  $result[^addField[$aFieldName;$aOptions]]

@cleanFormData[aFormData]
## Возвращает хеш с полями, для которых разрешены html-виджеты.
  ^cleanMethodArgument[aFormData]
  $result[^hash::create[]]
  ^aFormData.foreach[k;v]{
    ^if(^_fields.contains[$k]
        && $_fields.[$k].widget ne "none"
    ){
      $result.[$k][$v]
    }
  }

#----- Свойства -----

@GET_SCHEMA[]
  $result[$_schema]

@GET_TABLE_NAME[]
  ^pfAssert:isTrue(def $_tableName){Не задано имя таблицы в классе $self.CLASS_NAME}
  $result[$_tableName]

@GET_TABLE_ALIAS[]
  ^if(!def $_tableAlias){
    $_tableAlias[$TABLE_NAME]
  }
  $result[$_tableAlias]

@GET_TABLE_EXPRESSION[]
  $result[^if(def $SCHEMA){^_builder.quoteIdentifier[$SCHEMA].}^_builder.quoteIdentifier[$TABLE_NAME] as ^_builder.quoteIdentifier[$TABLE_ALIAS]]

@GET_FIELDS[]
  $result[$_fields]

@GET_CSQL[]
  $result[$_csql]

@GET_DEFAULT[aField][locals]
# Если нам пришло имя поля, то возвращаем имя поля в БД
# Для сложных случаев поддерживаем альтернативный синтаксис f_fieldName.
  $result[]
  $lField[^if(^aField.pos[f_] == 0){^aField.mid(2)}{$aField}]
  ^if($lField eq "PRIMARYKEY"){
    $lField[$_primaryKey]
  }
  ^if(^_fields.contains[$lField]){
    $result[^sqlFieldName[$lField]]
  }

@TABLE_AS[aAlias]
  $result[^if(def $SCHEMA){^_builder.quoteIdentifier[$SCHEMA].}^_builder.quoteIdentifier[$TABLE_NAME]^if(def $aAlias){ as ^_builder.quoteIdentifier[$aAlias]}]

#----- Выборки -----

@get[aPrimaryKeyValue;aOptions]
  ^pfAssert:isTrue(def $aPrimaryKeyValue){Не задано значение первичного ключа}
  $result[^one[$.[$_primaryKey][$aPrimaryKeyValue]]]

@one[aOptions;aSQLOptions]
  $result[^all[$aOptions;$aSQLOptions]]
  ^if($result){
    ^if($result is table){
      $result[$result.fields]
    }{
       $result[^result._at[first]]
     }
  }{
     $result[^hash::create[]]
   }

@all[aOptions;aSQLOptions][locals]
## aOptions.asTable(false) — возвращаем таблицу
## aOptions.asHash(false) — возвращаем хеш (ключ хеша — первичный ключ таблицы)
## aOptions.asHashOn[fieldName] — возвращаем хеш таблиц, ключем которого будет fieldName
## Выражения для контроля выборки (код в фигурных скобках):
##   aOptions.selectFields{exression} — выражение для списка полей (вместо автогенерации)
##   aOptions.where{expression} — выражение для where
##   aOptions.having{expression} — выражение для having
##   aOptions.orderBy[hash[$.field[asc]]|{expression}] — хеш с полями или выражение для orderBy
##   aOptions.groupBy[hash[$.field[asc]]|{expression}] — хеш с полями или выражение для groupBy
##   aOptions.join[] — выражение для join. Заменяет результат вызова ^_allJoin[].
## aOptions.limit
## aOptions.offset
## aOptions.primaryKeyColumn[:primaryKey] — имя колонки для первичного ключа
## Для поддержки специфики СУБД:
##   aSQLOptions.tail — концовка запроса
##   aSQLOptions.selectОptions — модификатор после select (distinct, sql_no_cache и т.п.)
##   aSQLOptions.skipFields — пропустить поля
##   + Все опции pfSQL.
 ^cleanMethodArgument[aOptions;aSQLOptions]
 $lResultType[^__getResultType[$aOptions]]
 $lExpression[^_selectExpression[
   ^__allSelectFieldsExpression[$lResultType;$aOptions;$aSQLOptions]
 ][$lResultType;$aOptions;$aSQLOptions]]
 $result[^CSQL.[$lResultType]{$lExpression}[][$aSQLOptions]]]

 ^if($result is table && def $aOptions.asHashOn){
   $result[^result.hash[$aOptions.asHashOn;$.type[table] $.distinct(true)]]
 }

@__getResultType[aOptions]
  $result[^switch(true){
    ^case(^aOptions.asTable.bool(false)){table}
    ^case(^aOptions.asHash.bool(false)){hash}
    ^case[DEFAULT]{$_defaultResultType}
  }]

@union[*aConds][locals]
## Выполняет несколько запросов и объединяет их в один результат.
## Параметр aSQLOptions не поддерживается!
## Тип результата берем из самого первого условия.
  ^pfAssert:isTrue($aConds){Надо задать как-минимум одно условие выборки.}
  $result[]
  $lResultType[^__getResultType[^hash::create[$aConds.0]]]

  ^aConds.foreach[k;v]{
    $v[^hash::create[$v]]
    $lExpression[^_selectExpression[
      ^__allSelectFieldsExpression[$lResultType;$v]
    ][$lResultType;$v]]
    $lRes[^CSQL.[$lResultType]{$lExpression}]
    ^if($k eq "0"){
      $result[$lRes]
    }($lResultType eq "table"){
      ^result.join[$lRes]
    }($lResultType eq "hash"){
      ^result.add[$lRes]
    }
  }

#----- Агрегации -----

@count[aConds;aSQLOptions][locals]
## Возвращает количество записей в таблице
  ^cleanMethodArgument[aConds;aSQLOptions]
# Убираем из запроса параметры orderBy и having, потому что они ссылаются
# на поля выборки, которых нет при вызове select count(*).
# Если нужны сложные варианты используйте aggregate.
  $aConds[^hash::create[$aConds] $.orderBy[] $.having[]]
  $lExpression[^_selectExpression[count(*)][;$aConds;$aSQLOptions]]
  $result[^CSQL.int{$lExpression}[][$aSQLOptions]]

@aggregate[*aConds][locals]
## Выборки с группировкой
## ^aggregate[func(expr) as alias;_fields(field1, field2 as alias2);_fields(*);conditions hash;sqlOptions]
## aConds.asHashOn[fieldName] — возвращаем хеш таблиц, ключем которого будет fieldName
  $lConds[^__getAgrConds[$aConds]]
  $lResultType[^__getResultType[$lConds.options]]
  $lExpression[^_selectExpression[
    ^asContext[select]{^__getAgrFields[$lConds.fields]}
  ][$lResultType;$lConds.options;$lConds.sqlOptions]]
  $result[^CSQL.[$lResultType]{$lExpression}[][$lConds.sqlOptions]]

  ^if($result is table && def $lConds.options.asHashOn){
    $result[^result.hash[$lConds.options.asHashOn;$.type[table] $.distinct(true)]]
  }

#----- Манипуляции с данными -----

@new[aData;aSQLOptions]
## Вставляем значение в базу
## aSQLOptions.ignore(false)
## Возврашает автосгенерированное значение первичного ключа (last_insert_id) для sequence-полей.
  ^cleanMethodArgument[aData;aSQLOptions]
  ^asContext[update]{
    $result[^CSQL.void{^_builder.insertStatement[$TABLE_NAME;$_fields;$aData;^hash::create[$aSQLOptions] $.skipFields[$_skipOnInsert] $.schema[$SCHEMA]]}]
  }
  ^if(def $_primaryKey && $_fields.[$_primaryKey].sequence){
    $result[^CSQL.lastInsertID[]]
  }

@modify[aPrimaryKeyValue;aData]
## Изменяем запись с первичныйм ключем aPrimaryKeyValue в таблице
  ^pfAssert:isTrue(def $_primaryKey){Не определен первичный ключ для таблицы ${TABLE_NAME}.}
  ^pfAssert:isTrue(def $aPrimaryKeyValue){Не задано значение первичного ключа}
  ^cleanMethodArgument[aData]
  $result[^CSQL.void{
    ^asContext[update]{
      ^_builder.updateStatement[$TABLE_NAME;$_fields;$aData][$PRIMARYKEY = ^fieldValue[$_fields.[$_primaryKey];$aPrimaryKeyValue]][
        $.skipAbsent(true)
        $.skipFields[$_skipOnUpdate]
        $.emptySetExpression[$PRIMARYKEY = $PRIMARYKEY]
        $.schema[$SCHEMA]
      ]
    }
  }]

@newOrModify[aData;aSQLOptions]
## Аналог мускулевского "insert on duplicate key update"
## Пытаемся создать новую запись, а если она существует, то обновляем данные.
## Работает только для таблиц с первичным ключем.
  $result[]
  ^cleanMethodArgument[aSQLOptions]
  ^pfAssert:isTrue(def $_primaryKey){Не определен первичный ключ для таблицы ${TABLE_NAME}.}
  ^CSQL.safeInsert{
     $result[^new[$aData;$aSQLOptions]]
  }{
      ^modify[$aData.[$_primaryKey];$aData]
      $result[$aData.[$_primaryKey]]
   }

@delete[aPrimaryKeyValue]
## Удаляем запись из таблицы с первичныйм ключем aPrimaryKeyValue
  ^pfAssert:isTrue(def $_primaryKey){Не определен первичный ключ для таблицы ${TABLE_NAME}.}
  ^pfAssert:isTrue(def $aPrimaryKeyValue){Не задано значение первичного ключа}
  $result[^CSQL.void{
    ^asContext[update]{
      delete from ^if(def $SCHEMA){^_builder.quoteIdentifier[$SCHEMA].}^_builder.quoteIdentifier[$TABLE_NAME] where $PRIMARYKEY = ^fieldValue[$_fields.[$_primaryKey];$aPrimaryKeyValue]
    }
  }]

@shift[aPrimaryKeyValue;aFieldName;aValue][locals]
## Увеличивает или уменьшает значение счетчика в поле aFieldName на aValue
## aValue(1) — положитетельное или отрицательное число
## По-умолчанию увеличивает значение поля на единицу
  ^pfAssert:isTrue(def $_primaryKey){Не определен первичный ключ для таблицы ${TABLE_NAME}.}
  ^pfAssert:isTrue(def $aPrimaryKeyValue){Не задано значение первичного ключа.}
  ^pfAssert:isTrue(^hasField[$aFieldName]){Не найдено поле "$aFieldName" в таблице.}
  $aValue(^if(def $aValue){$aValue}{1})
  $lFieldName[^_builder.sqlFieldName[$_fields.[$aFieldName]]]]
  $result[^CSQL.void{
    ^asContext[update]{
      update ^if(def $SCHEMA){^_builder.quoteIdentifier[$SCHEMA].}^_builder.quoteIdentifier[$TABLE_NAME]
         set $lFieldName = $lFieldName ^if($aValue < 0){-}{+} ^fieldValue[$_fields.[$aFieldName]](^math:abs($aValue))
       where $PRIMARYKEY = ^fieldValue[$_fields.[$_primaryKey];$aPrimaryKeyValue]
    }
  }]

#----- Групповые операции с данными -----

@modifyAll[aOptions;aData]
## Изменяем все записи
## Условие обновления берем из _allWhere
  ^cleanMethodArgument[aOptions;aData]
  $result[^CSQL.void{
    ^asContext[update]{
      ^_builder.updateStatement[$TABLE_NAME;$_fields;$aData][
        ^_allWhere[$aOptions]
      ][
        $.schema[$SCHEMA]
        $.skipAbsent(true)
        $.skipFields[$_skipOnUpdate]
        $.emptySetExpression[]
      ]
    }
  }]

@deleteAll[aOptions]
## Удаляем все записи из таблицы
## Условие для удаления берем из _allWhere
  ^cleanMethodArgument[]
  $result[^CSQL.void{
    ^asContext[update]{
      delete from ^if(def $SCHEMA){^_builder.quoteIdentifier[$SCHEMA].}^_builder.quoteIdentifier[$TABLE_NAME]
       where ^_allWhere[$aOptions]
    }
  }]

#----- Private -----
## Методы с префиксом _all используются для построения частей выражений выборки.
## Их можно перекрывать в наследниках смело, но не рекомендуется их использовать
## напрямую во внешнем коде.

@_allFields[aOptions;aSQLOptions]
  ^cleanMethodArgument[aOptions;aSQLOptions]
  $result[^_builder.selectFields[$_fields;
    $.tableAlias[$TABLE_ALIAS]
    ^if(^aSQLOptions.contains[skipFields]){
      $.skipFields[$aSQLOptions.skipFields]
    }
  ]]

@_allJoinFields[aOptions]
  $result[]

@_allJoin[aOptions]
  $result[]

@_allWhere[aOptions][locals]
## Дополнительное выражение для where
## (выражение для полей формируется в _fieldsWhere)
  $lConds[^_buildConditions[$aOptions]]
  $result[^if(^aOptions.contains[where]){$aOptions.where}{1=1}^if(def $lConds){ and $lConds}]

@_allHaving[aOptions]
  $result[]

@_allGroup[aOptions][locals]
## aOptions.groupBy
  ^if(^aOptions.contains[groupBy]){
    $lGroup[$aOptions.groupBy]
  }{
    $lGroup[$_defaultGroupBy]
  }
  ^asContext[group]{
    ^switch(true){
      ^case($lGroup is hash){$result[^lGroup.foreach[k;v]{^if(^_fields.contains[$k]){^sqlFieldName[$k]^if(^v.lower[] eq "desc"){ desc}(^v.lower[] eq "asc"){ asc}}}[, ]]}
      ^case[DEFAULT]{$result[^lGroup.trim[]]}
    }
  }

@_allOrder[aOptions][locals]
## aOptions.orderBy
  ^if(^aOptions.contains[orderBy]){
    $lOrder[$aOptions.orderBy]
  }(def $_defaultOrderBy){
    $lOrder[$_defaultOrderBy]
  }{
     $lOrder[^if(def $_primaryKey){$PRIMARYKEY asc}]
   }
  ^asContext[group]{
    ^switch(true){
      ^case($lOrder is hash){$result[^lOrder.foreach[k;v]{^if(^_fields.contains[$k]){^sqlFieldName[$k] ^if(^v.lower[] eq "desc"){desc}{asc}}}[, ]]}
      ^case[DEFAULT]{$result[^lOrder.trim[]]}
    }
  }

# ----- Методы для построения запросов ----

@fieldValue[aField;aValue]
## aField — имя или хеш с полем
  ^if($aField is string){
    $aField[$_fields.[$aField]]
  }
  $result[^_builder.fieldValue[$aField;$aValue]]

@valuesArray[aField;aValues;aOptions]
## aField — имя или хеш с полем
  ^cleanMethodArgument[]
  ^if($aField is string){
    $aField[$_fields.[$aField]]
  }
  $result[^_builder.array[$aField;$aValues;$aOptions $.valueFunction[$fieldValue]]]

@sqlFieldName[aFieldName][locals]
  ^pfAssert:isTrue(^_fields.contains[$aFieldName]){Неизвестное поле «${aFieldName}».}
  $lField[$_fields.[$aFieldName]]
  ^if($__context eq "where"
      && ^lField.contains[fieldExpression]
      && def $lField.fieldExpression){
    $result[$lField.fieldExpression]
  }(^lField.contains[expression]
    && def $lField.expression
   ){
     ^if($__context eq "group"){
       $result[$lField.name]
     }{
        $result[$lField.expression]
      }
  }{
     ^if(!^lField.contains[dbField]){
       ^throw[pfSQLTable.field.fail;Для поля «${aFieldName}» не задано выражение или имя в базе данных.]
     }
     $result[^_builder.sqlFieldName[$lField;^if($__context ne "update"){$TABLE_ALIAS}]]
   }

@asContext[aContext;aCode][locals]
  $lOldContext[$self.__context]
  $self.__context[$aContext]
  ^try{
    $result[$aCode]
  }{}{
#   Возвращаем старый контекст, даже если был exception
    $self.__context[$lOldContext]
  }

@_buildConditions[aConds;aOP][locals]
## Строим выражение для сравнения
## aOp[AND|OR|NOT]
  ^cleanMethodArgument[aConds]
  $result[]

  $lConds[^hash::create[]]
  $_res[^hash::create[]]

  ^aConds.foreach[k;v]{
    ^k.match[$_PFSQLTABLE_COMPARSION_REGEX][]{
      $lField[$_fields.[$match.1]]
      ^if(^_fields.contains[$match.1] && !def $match.2 || ^_PFSQLTABLE_OPS.contains[$match.2]){
#       $.[field operator][value]
        $_res.[^_res._count[]][^sqlFieldName[$match.1] $_PFSQLTABLE_OPS.[$match.2] ^fieldValue[$lField;$v]]
      }($match.2 eq "range" || $match.2 eq "!range"){
#       $.[field range][$.from $.to]
#       $.[field !range][$.from $.to]
        $_res.[^_res._count[]][^if(^match.2.left(1) eq "!"){not }^(^sqlFieldName[$match.1] between ^fieldValue[$lField;$v.from] and ^fieldValue[$lField;$v.to])]
      }(^_fields.contains[$match.1] && $match.2 eq "is"){
        $_res.[^_res._count[]][^sqlFieldName[$match.1] is ^if(!def $v || $v eq "null"){null}{not null}]
      }(^_plurals.contains[$match.1]
        || (^_fields.contains[$match.1] && ($match.2 eq "in" || $match.2 eq "!in"))
       ){
#       $.[field [!]in][hash|table|values string]
#       $.[plural [not]][hash|table|values string]
        $_res.[^_res._count[]][^_condArrayField[$aConds;$match.1;^match.2.lower[];$v]]
      }($match.1 eq "OR" || $match.1 eq "AND" || $match.1 eq "NOT"){
#       Рекурсивный вызов логического блока
        $_res.[^_res._count[]][^_buildConditions[$v;$match.1]]
      }
    }
  }
  $result[^if($_res){^if($aOP eq "NOT"){not} (^_res.foreach[k;v]{$v}[ $_PFSQLTABLE_LOGICAL.[$aOP] ])}]

@_condArrayField[aConds;aFieldName;aOperator;aValue][locals]
  $lField[^if(^_plurals.contains[$aFieldName]){$_plurals.[$aFieldName]}{$_fields.[$aFieldName]}]
  $lColumn[^if(^aConds.contains[${aFieldName}Column]){$aConds.[${aFieldName}Column]}{$lField.name}]
  $result[^sqlFieldName[$lField.name] ^if($aOperator eq "not" || $aOperator eq "!in"){not in}{in} (^valuesArray[$lField.name;$aValue;$.column[$lColumn]])]

@_selectExpression[aFields;aResultType;aOptions;aSQLOptions][locals]
  ^asContext[where]{
    $lGroup[^_allGroup[$aOptions]]
    $lOrder[^_allOrder[$aOptions]]
    $lHaving[^if(^aOptions.contains[having]){$aOptions.having}{^_allHaving[$aOptions]}]
  }

  $result[
       select $aFields
         from ^if(def $SCHEMA){^_builder.quoteIdentifier[$SCHEMA].}^_builder.quoteIdentifier[$TABLE_NAME] as ^_builder.quoteIdentifier[$TABLE_ALIAS]
              ^asContext[where]{^if(^aOptions.contains[join]){$aOptions.join}{^_allJoin[$aOptions]}}
        where ^asContext[where]{^_allWhere[$aOptions]}
      ^if(def $lGroup){
        group by $lGroup
      }
      ^if(def $lHaving){
       having $lHaving
      }
      ^if(def $lOrder){
        order by $lOrder
      }
#     Строим выражение для limit и offset.
      $lLimit(^aOptions.limit.int(-1))
      $lOffset(^aOptions.offset.int(-1))
      ^if($lLimit >= 0 || $lOffset >= 0){
        limit ^if($lLimit >=0){$lLimit}{18446744073709551615}
        ^if($lOffset >= 0){
          offset $lOffset
        }
      }
      ^if(def $aSQLOptions.tail){$aSQLOptions.tail}
  ]

#----- Вспомогательные методы (deep private :) -----
## Методы, начинаююшиеся с двух подчеркиваний сугубо внутренние,
## желательно их не перекрывать и ни при каких условиях не использовать
## во внешнем коде.

@__allSelectFieldsExpression[aResultType;aOptions;aSQLOptions]
  $result[
    ^asContext[select]{
     ^if(def $aSQLOptions.selectОptions){$aSQLOptions.selectОptions}
     ^if(^aOptions.contains[selectFields]){
       $aOptions.selectFields
     }{
       ^if($aResultType eq "hash"){
         ^pfAssert:isTrue(def $_primaryKey){Не определен первичный ключ для таблицы ${TABLE_NAME}. Выборку можно делать только в таблицу.}
#         Для хеша добавляем еще одно поле с первичным ключем
          $PRIMARYKEY as ^_builder.quoteIdentifier[_ORM_HASH_KEY_],
       }
       $lJoinFields[^_allJoinFields[$aOptions]]
       ^_allFields[$aOptions;$aSQLOptions]^if(def $lJoinFields){, $lJoinFields}
      }
    }
  ]

@__getAgrConds[aConds][locals]
  $result[$.fields[^hash::create[]] $.options[] $.sqlOptions[]]
  ^aConds.foreach[k;v]{
    ^switch[$v.CLASS_NAME]{
      ^case[string]{
        $result.fields.[^eval($result.fields)][$v]
      }
      ^case[hash]{
        ^if(!def $result.options){
          $result.options[$v]
        }(def $result.options && !def $result.sqlOptions){
          $result.sqlOptions[$v]
        }
      }
    }
  }
  ^if(!def $result.options){$result.options[^hash::create[]]}
  ^if(!def $result.sqlOptions){$result.sqlOptions[^hash::create[]]}

@__getAgrFields[aFields][locals]
  $result[^hash::create[]]
  ^aFields.foreach[k;v]{
    ^v.match[$_PFSQLTABLE_AGR_REGEX][]{
      $lField[
        $.expr[$match.1]
        $.function[$match.2]
        $.args[^match.3.trim[both;() ]]
        $.alias[$match.4]
      ]
      ^if(^lField.function.lower[] eq "_fields"){
        ^if(^lField.args.trim[] eq "*"){
          $lField.expr[^_allFields[]]
        }{
           $lSplit[^lField.args.split[,;lv]]
           $lField.expr[^lSplit.menu{^lSplit.piece.match[$_PFSQLTABLE_AGR_REGEX][]{^if(def $match.1){^sqlFieldName[$match.1] as ^_builder.quoteIdentifier[^if(def $match.4){$match.4}{$match.1}]}}}[, ]]
           $lField.alias[]
         }
      }
      $result.[^result._count[]][$lField]
    }
  }
  $result[^result.foreach[k;v]{$v.expr^if(def $v.alias){ as ^_builder.quoteIdentifier[$v.alias]}}[, ]]

#----------------------------------------------------------------------------------------------------------------------

@CLASS
pfSQLBuilder

@BASE
pfClass

@create[aOptions]
## aOptions.quoteStyle[mysql|ansi] — стиль «кавычек» для идентификаторов (default: mysql)
  ^cleanMethodArgument[]
  ^BASE:create[$aOptions]

  $_quote[]
  ^setQuoteStyle[^if(def $aOptions.quoteStyle){^aOptions.quoteStyle.lower[]}]

  $_now[^date::now[]]
  $_today[^date::today[]]

@auto[][lSeparator;lEncloser]
  $_PFSQLBUILDER_CSV_REGEX_[^regex::create[((?:\s*"(?:[^^"]*|"{2})*"\s*(?:,|^$))|\s*"[^^"]*"\s*(?:,|^$)|[^^,]+(?:,|^$)|(?:,))][g]]
  $_PFSQLBUILDER_CSV_QTRIM_REGEX_[^regex::create["(.*)"][]]
  $_PFSQLBUILDER_PROCESSOR_FIRST_UPPER[^regex::create[^^\s*(\pL)(.*?)^$][]]

@setQuoteStyle[aStyle]
  $result[]
  ^switch[$aStyle]{
    ^case[mysql]{$_quote[`]}
    ^case[DEFAULT;ansi]{$_quote["]}
  }

#----- Работа с полями -----

## Формат описания полей
## aFields[
##   $.fieldName[ <- Имя поля в прорамме
##     $.dbField[field_name] <- Имя поля в базе
##     $.processor[int|bool|curdate|curtime|...] <- Как обрабатывать поле при присвоении (по-умолчанию "^taint[value]")
##     $.format[] — форматная строка для процессоров (числа)
##     $.default[] <- Значение по-умолчанию (if !def).
##     $.expression{}
##   ]
## ]
##
## Процессоры:
##   auto_default - если не задано значение, то возвращает field.default (поведение по-умолчанию)
##   uint, auto_uint - целое число без знака, если не задан default, то приведение делаем без значения по-умолчанию
##   int, auto_int - целое число, если не задан default, то приведение делаем без значения по-умолчанию
##   double, auto_double - целое число, если не задан default, то приведение делаем без значения по-умолчанию
##   bool, auto_bool - 1/0
##   datetime - дата и время (если нам передали дату, то делаем sql-string)
##   date - дата (если нам передали дату, то делаем sql-string[date])
##   time - время (если нам передали дату, то делаем sql-string[time])
##   now, auto_now - текущие дата время (если не задано значение поля)
##   curtime, auto_curtime - текущее время (если не задано значение поля)
##   curdate, auto_curdate - текущая дата (если не задано значение поля)
##   json - сереиализует значение в json
##   null - если не задано значение, то возвращает null
##   uint_null - преобразуем зачение в целое без знака, если не задано значение, то возвращаем null
##   uid, auto_uid - уникальный идентификатор (math:uuid)
##   inet_ip — преобразует строку в числовое представление IP
##   first_upper - удаляет ведущие пробелы и капитализирует первую букву
##   hash_md5 — берет md5 от значения

@_processFieldsOptions[aOptions]
  $result[^hash::create[$aOptions]]
  $result.skipNames(^aOptions.skipNames.bool(false))
  $result.skipAbsent(^aOptions.skipAbsent.bool(false))
  $result.skipFields[^hash::create[$aOptions.skipFields]]

@quoteIdentifier[aIdent]
  $result[${_quote}${aIdent}${_quote}]

@sqlFieldName[aField;aTableAlias][locals]
  $result[^if(def $aTableAlias){${_quote}${aTableAlias}${_quote}.}${_quote}^taint[$aField.dbField]${_quote}]

@selectFields[aFields;aOptions][locals]
## Возвращает список полей для выражения select
## aOptions.tableAlias
## aOptions.skipFields[$.field[] ...] — хеш с полями, которые надо исключить из выражения
  ^pfAssert:isTrue(def $aFields){Не задан список полей.}
  $aOptions[^_processFieldsOptions[$aOptions]]
  $lTableAlias[^if(def $aOptions.tableAlias){$aOptions.tableAlias}]

  $result[^hash::create[]]
  $lFields[^hash::create[$aFields]]
  ^aFields.foreach[k;v]{
    ^if(^aOptions.skipFields.contains[$k]){^continue[]}
    ^if(^v.contains[expression]){
      $result.[^result._count[]][$v.expression as ${_quote}${k}${_quote}]]
    }{
       $result.[^result._count[]][^sqlFieldName[$v;$lTableAlias] as ${_quote}${k}${_quote}]]
     }
  }
  $result[^result.foreach[k;v]{$v}[, ]]

@fieldsList[aFields;aOptions][locals]
## Возвращает список полей
## aOptions.tableAlias
## aOptions.skipFields[$.field[] ...] — хеш с полями, которые надо исключить из выражения
## aOptions.skipAbsent(false) - пропустить поля, данных для которых нет (нaдо обязательно задать поле aOptions.data)
## aOptions.data - хеш с данными
  ^pfAssert:isTrue(def $aFields){Не задан список полей.}
  $aOptions[^_processFieldsOptions[$aOptions]]
  $lData[^if(def $aOptions.data){$aOptions.data}{^hash::create[]}]
  $lTableAlias[^if(def $aOptions.tableAlias){$aOptions.tableAlias}]
  $result[^hash::create[]]
  ^aFields.foreach[k;v]{
    ^if(^v.contains[expression] && !^v.contains[dbField]){^continue[]}
    ^if($aOptions.skipAbsent && !^lData.contains[$k] && !(def $v.processor && ^v.processor.pos[auto_] >= 0)){^continue[]}
    ^if(^aOptions.skipFields.contains[$k]){^continue[]}
    $result.[${_quote}^result._count[]][^sqlFieldName[$v;$lTableAlias]]
  }
  $result[^result.foreach[k;v]{$v}[, ]]

@setExpression[aFields;aData;aOptions][locals]
## Возвращает выражение для присвоения значения (field = vale, ...)
## aOptions.tableAlias
## aOptions.skipAbsent(false) - пропустить поля, данных для которых нет
## aOptions.skipFields[$.field[] ...] — хеш с полями, которые надо исключить из выражения
## aOptions.skipNames(false) - не выводить имена полей, только значения (для insert values)
  ^pfAssert:isTrue(def $aFields){Не задан список полей.}
  ^cleanMethodArgument[aData;aOptions]
  $aOptions[^_processFieldsOptions[$aOptions]]
  $lAlias[^if(def $aOptions.alias){${aOptions.alias}}]

  $result[^hash::create[]]
  ^aFields.foreach[k;v]{
    ^if(^aOptions.skipFields.contains[$k] || (^v.contains[expression] && !^v.contains[dbField])){^continue[]}
    ^if($aOptions.skipAbsent && !^aData.contains[$k] && !(def $v.processor && ^v.processor.pos[auto_] >= 0)){^continue[]}
    $result.[^result._count[]][^if(!$aOptions.skipNames){^sqlFieldName[$v;$lAlias] = }^fieldValue[$v;^if(^aData.contains[$k]){$aData.[$k]}]]
  }
  $result[^result.foreach[k;v]{$v}[, ]]

@fieldValue[aField;aValue][locals]
## Возвращает значение поля в sql-формате.
  ^pfAssert:isTrue(def $aField){Не задано описание поля.}
  ^try{
    $result[^switch[^if(def $aField.processor){^aField.processor.lower[]}]{
      ^case[uint;auto_uint]{^try{$lVal($aValue)}{^if(^aField.contains[default]){$exception.handled(true) $lVal($aField.default)}}^lVal.format[^if(def $aField.format){$aField.format}{%u}]}
      ^case[int;auto_int]{^try{$lVal($aValue)}{^if(^aField.contains[default]){$exception.handled(true) $lVal($aField.default)}}^lVal.format[^if(def $aField.format){$aField.format}{%d}]}
      ^case[double;auto_double]{^if(^aField.contains[default]){$lValue(^aValue.double($aField.default))}{$lValue(^aValue.double[])}^lValue.format[^if(def $aField.format){$aField.format}{%.16g}]}
      ^case[bool;auto_bool]{^if(^aValue.bool(^if(^aField.contains[default]){$aField.default}{false})){1}{0}}
      ^case[now;auto_now]{^if(def $aValue){'^if($aValue is date){^aValue.sql-string[]}{^taint[$aValue]}'}{'^_now.sql-string[]'}}
      ^case[curtime;auto_curtime]{'^if(def $aValue){^if($aValue is date){^aValue.sql-string[time]}{^taint[$aValue]}}{^_now.sql-string[time]}'}
      ^case[curdate;auto_curdate]{'^if(def $aValue){^if($aValue is date){^aValue.sql-string[date]}{^taint[$aValue]}}{^_now.sql-string[date]}'}
      ^case[datetime]{^if(def $aValue){'^if($aValue is date){^aValue.sql-string[]}{^taint[$aValue]}'}{null}}
      ^case[date]{^if(def $aValue){'^if($aValue is date){^aValue.sql-string[date]}{^taint[$aValue]}'}{null}}
      ^case[time]{^if(def $aValue){'^if($aValue is date){^aValue.sql-string[time]}{^taint[$aValue]}'}{null}}
      ^case[json]{^if(def $aValue){'^taint[^json:string[$aValue]]'}{null}}
      ^case[null]{^if(def $aValue){'^taint[$aValue]'}{null}}
      ^case[uint_null]{^if(def $aValue){$lVal($aValue)^lVal.format[%u]}{null}}
      ^case[uid;auto_uid]{'^taint[^if(def $aValue){$aValue}{^math:uuid[]}']}
      ^case[inet_ip]{^unsafe{^inet:aton[$aValue]}{null}}
      ^case[first_upper]{'^taint[^if(def $aValue){^aValue.match[$_PFSQLBUILDER_PROCESSOR_FIRST_UPPER][]{^match.1.upper[]$match.2}}(def $aField.default){$aField.default}]'}
      ^case[hash_md5]{'^taint[^if(def $aValue){^math:md5[$aValue]}]'}
      ^case[DEFAULT;auto_default]{'^taint[^if(def $aValue){$aValue}(def $aField.default){$aField.default}]'}
    }]
  }{
     ^throw[pfSQLBuilder.bad.value;Ошибка при преобразовании поля ${aField.name} (processor: ^if(def $aField.processor){$aField.processor}{default}^; value type: $aValue.CLASS_NAME);[${exception.type}] ${exception.source}, ${exception.comment}.]
   }

@array[aField;aValue;aOptions][locals]
## Строит массив значений
## aValue[table|hash|csv-string]
## aOptions.column[$aField.name] — имя колонки в таблице
## aOptions.emptyValue[null] — значение массива, если в aValue нет данных
## aOptions.valueFunction[fieldValue] — функция форматирования значения поля
  ^cleanMethodArgument[]
  $result[]
  $lValueFunction[^if(^aOptions.contains[valueFunction]){$aOptions.valueFunction}{$fieldValue}]
  $lEmptyValue[^if(^aOptions.contains[emptyValue]){$aOptions.emptyValue}{null}]
  $lColumn[^if(def $aOptions.column){$aOptions.column}{$aField.name}]
  ^switch(true){
    ^case($aValue is hash){$result[^aValue.foreach[k;v]{^lValueFunction[$aField;$k]}[, ]]}
    ^case($aValue is table){$result[^aValue.menu{^lValueFunction[$aField;$aValue.[$lColumn]]}[, ]]}
    ^case($aValue is string){
      $lItems[^_parseCSVString[$aValue]]
      $result[^lItems.foreach[k;v]{^lValueFunction[$aField;$v]}[, ]]
    }
    ^case[DEFAULT]{
      ^throw[pfSQLBuilder.bad.array.values;Значениями массива может быть хеш, таблица или csv-строка. (Поле: $aField.name, тип значения: $aValue.CLASS_NAME)]
    }
  }]
  ^if(!def $result && def $lEmptyValue){
    $result[$lEmptyValue]
  }

@_parseCSVString[aString][loacals]
# $result[$.0[] $.1[] ...]
  $result[^hash::create[]]
  ^aString.match[$_PFSQLBUILDER_CSV_REGEX_][]{
    $lValue[^match.1.trim[right;,]]
    $lValue[^lValue.match[$_PFSQLBUILDER_CSV_QTRIM_REGEX_][]{^match.1.replace[""]["]}]
    $result.[^result._count[]][$lValue]
  }

#----- Построение sql-выражений -----

@insertStatement[aTableName;aFields;aData;aOptions][locals]
## Строит выражение insert into values
## aTableName - имя таблицы
## aFields - поля
## aData - данные
## aOptions.schema
## aOptions.skipFields[$.field[] ...] — хеш с полями, которые надо исключить из выражения
## aOptions.ignore(false)
  ^pfAssert:isTrue(def $aTableName){Не задано имя таблицы.}
  ^pfAssert:isTrue(def $aFields){Не задан список полей.}
  ^cleanMethodArgument[aData;aOptions]
  $lOpts[^if(^aOptions.ignore.bool(false)){ignore}]
  $result[insert $lOpts into ^if(def $aOptions.schema){${_quote}${aOptions.schema}${_quote}.}${_quote}${aTableName}${_quote} (^fieldsList[$aFields;^hash::create[$aOptions] $.data[$aData]]) values (^setExpression[$aFields;$aData;^hash::create[$aOptions] $.skipNames(true)])]

@updateStatement[aTableName;aFields;aData;aWhere;aOptions][locals]
## Строит выражение для update
## aTableName - имя таблицы
## aFields - поля
## aData - данные
## aWhere - выражение для where
##          (для безопасности блок where задается принудительно,
##           если нужно иное поведение укажите aWhere[1=1])
## aOptions.schema
## aOptions.skipAbsent(false) - пропустить поля, данных для которых нет
## aOptions.skipFields[$.field[] ...] — хеш с полями, которые надо исключить из выражения
## aOptions.emptySetExpression[выражение, которое надо подставить, если нет данных для обновления]
  ^pfAssert:isTrue(def $aTableName){Не задано имя таблицы.}
  ^pfAssert:isTrue(def $aFields){Не задан список полей.}
  ^pfAssert:isTrue(def $aWhere){Не задано выражение для where.}
  ^cleanMethodArgument[aData;aOptions]

  $lSetExpression[^setExpression[$aFields;$aData;$aOptions]]
  ^pfAssert:isTrue(def $lSetExpression || (!def $lSetExpression && def $aOptions.emptySetExpression)){Необходимо задать выражение для пустого update set.}
  $result[update ^if(def $aOptions.schema){${_quote}${aOptions.schema}${_quote}.}${_quote}${aTableName}${_quote} set ^if(def $lSetExpression){$lSetExpression}{$aOptions.emptySetExpression} where $aWhere]
