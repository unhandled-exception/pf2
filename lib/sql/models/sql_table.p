# PF2 Library

@USE
pf2/lib/sql/connection.p

@CLASS
pfSQLTable

## Шлюз таблицы данных (Table Data Gateway).

@OPTIONS
locals

@BASE
pfClass

@create[aTableName;aOptions]
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
  ^self.cleanMethodArgument[]
  ^BASE:create[$aOptions]
  $self.__options[^hash::create[$aOptions]]

  $self._csql[^if(def $aOptions.sql){$aOptions.sql}{$self._PFSQLTABLE_CSQL}]
  ^pfAssert:isTrue(def $self._csql){Не задан объект для работы с SQL-сервером.}
  $self.CSQL[$self._csql]

  $self._builder[^if(def $aOptions.builder){$aOptions.builder}{$self._PFSQLTABLE_BUILDER}]
  ^if(!def $self._builder){
    $self._builder[^pfSQLBuilder::create[$.quoteStyle[$self._csql.serverType]]]
  }

  $self._schema[^aOptions.schema.trim[]]

  $self._tableName[$aTableName]
  $self._tableAlias[^if(def $aOptions.tableAlias){$aOptions.tableAlias}(def $self._schema){${self._schema}_$self._tableName}]
  $self._primaryKey[^if(def $aOptions.primaryKey){$aOptions.primaryKey}]

  $self._fields[^hash::create[]]
  $self._plurals[^hash::create[]]
  ^if(^aOptions.contains[fields]){
    ^self.addFields[$aOptions.fields]
  }

  $self._skipOnInsert[^hash::create[^if(def $aOptions.skipOnInsert){$aOptions.skipOnInsert}]]
  $self._skipOnUpdate[^hash::create[^if(def $aOptions.skipOnUpdate){$aOptions.skipOnUpdate}]]

  $self._defaultResultType[^if(^aOptions.allAsTable.bool(false)){table}{hash}]

  $self._defaultOrderBy[]
  $self._defaultGroupBy[]

  $self._scopes[^hash::create[]]
  $self._defaultScope[^hash::create[]]

  $self.__context[]

#----- Статические методы и конструктор -----

@auto[]
  $self._PFSQLTABLE_CSQL[]
  $self._PFSQLTABLE_BUILDER[]
  $self._PFSQLTABLE_COMPARSION_REGEX[^regex::create[^^\s*(\S+)(?:\s+(\S+))?][]]
  $self._PFSQLTABLE_AGR_REGEX[^regex::create[^^\s*(([^^\s(]+)(.*?))\s*(?:as\s+([^^\s\)]+))?\s*^$][i]]
  $self._PFSQLTABLE_LOGICAL[
    $.OR[or]
    $.AND[and]
    $.NOT[and]
    $._default[and]
  ]

@static:assignServer[aSQLConnection]
# Чтобы можно было задать коннектор для всех объектов сразу.
  $self._PFSQLTABLE_CSQL[$aSQLConnection]

@static:assignBuilder[aSQLBuilder]
  $self._PFSQLTABLE_BUILDER[$aSQLBuilder]

#----- Метаданные -----

@addField[aFieldName;aOptions]
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
  ^self.cleanMethodArgument[]
  ^pfAssert:isTrue(def $aFieldName){Не задано имя поля таблицы.}
  ^pfAssert:isTrue(!^self._fields.contains[$aFieldName]){Поле «${aFieldName}» в таблице уже существует.}

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
    ^if(^aOptions.skipOnUpdate.bool(false) || !def $lField.dbField){
      $self._skipOnUpdate.[$aFieldName](true)
    }
    ^if(^aOptions.skipOnInsert.bool(false) || !def $lField.dbField){
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
     ^if(def $lField.primary && !def $self._primaryKey){
       $self._primaryKey[$aFieldName]
     }
   }
  $self._fields.[$aFieldName][$lField]
  ^if(def $lField.plural){
    $self._plurals.[$lField.plural][$lField]
  }

@addFields[aFields]
## Добавляет сразу несколько полей
## aFields[hash]
  ^self.cleanMethodArgument[aFields]
  $result[]
  ^aFields.foreach[k;v]{
    ^self.addField[$k;$v]
  }

@hasField[aFieldName]
## Проверяет наличие поля в таблице
  $result(def $aFieldName && ^self._fields.contains[$aFieldName])

@replaceField[aFieldName;aOptions]
  ^if(^self.hasField[$aFieldName]){
    ^self._fields.delete[$aFieldName]
  }
  $result[^self.addField[$aFieldName;$aOptions]]

@cleanFormData[aFormData]
## Возвращает хеш с полями, для которых разрешены html-виджеты.
  ^self.cleanMethodArgument[aFormData]
  $result[^hash::create[]]
  ^aFormData.foreach[k;v]{
    ^if(^self._fields.contains[$k]
        && $self._fields.[$k].widget ne "none"
    ){
       $result.[$k][$v]
    }
  }

@addScope[aName;aConditions]
  $result[]
  $self._scopes.[$aName][^hash::create[$aConditions]]


#----- Свойства -----

@GET_SCHEMA[]
  $result[$self._schema]

@GET_TABLE_NAME[]
  ^pfAssert:isTrue(def $self._tableName){Не задано имя таблицы в классе $self.CLASS_NAME}
  $result[$self._tableName]

@GET_TABLE_ALIAS[]
  ^if(!def $self._tableAlias){
    $self._tableAlias[$self.TABLE_NAME]
  }
  $result[$self._tableAlias]

@GET_TABLE_EXPRESSION[]
  $result[^if(def $self.SCHEMA){^self._builder.quoteIdentifier[$self.SCHEMA].}^self._builder.quoteIdentifier[$self.TABLE_NAME] as ^self._builder.quoteIdentifier[$self.TABLE_ALIAS]]

@GET_FIELDS[]
  $result[$self._fields]

@GET_DEFAULT[aField]
# Если нам пришло имя скоупа, то возвращаем таблицу со скоупом
# Если нам пришло имя поля, то возвращаем имя поля в БД
# Для сложных случаев поддерживаем альтернативный синтаксис f_fieldName.
  $result[]
  ^if(^self._scopes.contains[$aField]){
    $lScope[^hash::create[$self._defaultScope]]
    ^lScope.add[$self._scopes.[$aField]]
    $result[^pfSQLTableScope::create[$self;$lScope]]
  }{
    $lField[^if(^aField.pos[f_] == 0){^aField.mid(2)}{$aField}]
    ^if($lField eq "PRIMARYKEY"){
      $lField[$self._primaryKey]
    }
    ^if(^self._fields.contains[$lField]){
      $result[^self.sqlFieldName[$lField]]
    }
  }

@TABLE_AS[aAlias]
  $result[^if(def $self.SCHEMA){^self._builder.quoteIdentifier[$self.SCHEMA].}^self._builder.quoteIdentifier[$self.TABLE_NAME]^if(def $aAlias){ as ^self._builder.quoteIdentifier[$aAlias]}]

#----- Выборки -----

@get[aPrimaryKeyValue;aOptions]
  ^pfAssert:isTrue(def $aPrimaryKeyValue){Не задано значение первичного ключа}
  $result[^self.one[$.[$self._primaryKey][$aPrimaryKeyValue]]]

@one[aOptions;aSQLOptions]
  $result[^self.all[$aOptions;$aSQLOptions]]
  ^if($result){
    ^if($result is table){
      $result[$result.fields]
    }{
       $result[^result._at[first]]
     }
  }{
     $result[^hash::create[]]
   }

@all[aOptions;aSQLOptions]
## aOptions.asTable(false) — возвращаем таблицу
## aOptions.asHash(false) — возвращаем хеш (ключ хеша — первичный ключ таблицы)
## aOptions.asHashOn[fieldName] — возвращаем хеш таблиц, ключем которого будет fieldName
## Выражения для контроля выборки (код в фигурных скобках):
##   aOptions.selectFields{exression} — выражение для списка полей (вместо автогенерации)
##   aOptions.where{expression} — выражение для where
##   aOptions.having{expression} — выражение для having
##   aOptions.orderBy[hash[$.field[asc]]|{expression}] — хеш с полями или выражение для orderBy
##   aOptions.groupBy[hash[$.field[asc]]|{expression}] — хеш с полями или выражение для groupBy
##   aOptions.join[] — выражение для join. Заменяет результат вызова ^self._allJoin[].
## aOptions.limit
## aOptions.offset
## Для поддержки специфики СУБД:
##   aSQLOptions.tail — концовка запроса
##   aSQLOptions.selectОptions — модификатор после select (distinct, sql_no_cache и т.п.)
##   aSQLOptions.skipFields — пропустить поля
##   aSQLOptions.force — отменить кеширование результата запроса
##   + Все опции pfSQL.
  ^self.cleanMethodArgument[aOptions;aSQLOptions]
  $lResultType[^if(def $aOptions.asHashOn){table}{^self.__getResultType[$aOptions]}]
  $result[^self.CSQL.[$lResultType]{^self.__normalizeWhitespaces{^self.__allSQLExpression[$lResultType;$aOptions;$aSQLOptions]}}[][$aSQLOptions]]

  ^if($result is table && def $aOptions.asHashOn){
    $result[^result.hash[$aOptions.asHashOn;$.type[table] $.distinct(true)]]
  }

@allSQL[aOptions;aSQLOptions]
## Возвращает текст запроса из метода all.
  ^self.cleanMethodArgument[aOptions;aSQLOptions]
  $lResultType[^self.__getResultType[$aOptions]]
  $result[^self.__normalizeWhitespaces{^self.__allSQLExpression[$lResultType;$aOptions;$aSQLOptions]]}[$.apply(true)]]

@union[*aConds]
## Выполняет несколько запросов и объединяет их в один результат.
## Параметр aSQLOptions не поддерживается!
## Тип результата берем из самого первого условия.
  ^pfAssert:isTrue($aConds){Надо задать как-минимум одно условие выборки.}
  $result[]
  $lResultType[^self.__getResultType[^hash::create[$aConds.0]]]

  ^aConds.foreach[k;v]{
    $v[^hash::create[$v]]
    $lExpression[^self._selectExpression[
      ^self.__allSelectFieldsExpression[$lResultType;$v]
    ][$lResultType;$v]]
    $lRes[^self.CSQL.[$lResultType]{$lExpression}]
    ^if($k eq "0"){
      $result[$lRes]
    }($lResultType eq "table"){
      ^result.join[$lRes]
    }($lResultType eq "hash"){
      ^result.add[$lRes]
    }
  }

#----- Агрегации -----

@count[aConds;aSQLOptions]
## Возвращает количество записей в таблице
  ^self.cleanMethodArgument[aConds;aSQLOptions]
# Убираем из запроса параметры orderBy и having, потому что они ссылаются
# на поля выборки, которых нет при вызове select count(*).
# Если нужны сложные варианты используйте aggregate.
  $aConds[^hash::create[$aConds] $.orderBy[] $.having[]]
  $lExpression[^self._selectExpression[count(*)][;$aConds;$aSQLOptions]]
  $result[^self.CSQL.int{^self.__normalizeWhitespaces{$lExpression}}[][$aSQLOptions]]

@aggregate[*aConds]
## Выборки с группировкой
## ^aggregate[func(expr) as alias;_fields(field1, field2 as alias2);_fields(*);conditions hash;sqlOptions]
## aConds.asHashOn[fieldName] — возвращаем хеш таблиц, ключем которого будет fieldName
  $lConds[^self.__getAgrConds[$aConds]]
  $lResultType[^if(def $lConds.options.asHashOn){table}{^self.__getResultType[$lConds.options]}]
  $lExpression[^self.__aggregateSQLExpression[$lResultType;$lConds]]
  $result[^self.CSQL.[$lResultType]{^self.__normalizeWhitespaces{$lExpression}}[][$lConds.sqlOptions]]

  ^if($result is table && def $lConds.options.asHashOn){
    $result[^result.hash[$lConds.options.asHashOn;$.type[table] $.distinct(true)]]
  }

@aggregateSQL[*aConds]
## Возвращает текст запроса из метода aggregate.
  $lConds[^self.__getAgrConds[$aConds]]
  $lResultType[^self.__getResultType[$lConds.options]]
  $lExpression[^self.__aggregateSQLExpression[$lResultType;$lConds]]
  $result[^self.CSQL.connect{^self.__normalizeWhitespaces{$lExpression}[$.apply(true)]}]

#----- Манипуляции с данными -----

@new[aData;aSQLOptions]
## Вставляем значение в базу
## aSQLOptions.ignore(false)
## Возврашает автосгенерированное значение первичного ключа (last_insert_id) для sequence-полей.
  ^self.cleanMethodArgument[aData;aSQLOptions]
  ^self.asContext[update]{
    $result[^self.CSQL.void{^self.__normalizeWhitespaces{^self._builder.insertStatement[$self.TABLE_NAME;$self._fields;$aData;
      ^hash::create[$aSQLOptions]
      $.skipFields[$self._skipOnInsert]
      $.schema[$self.SCHEMA]
      $.fieldValueFunction[$self.fieldValue]
    ]}}]
  }
  ^if(def $self._primaryKey && $self._fields.[$self._primaryKey].sequence){
    $result[^self.CSQL.lastInsertID[]]
  }

@modify[aPrimaryKeyValue;aData]
## Изменяем запись с первичныйм ключем aPrimaryKeyValue в таблице
  ^pfAssert:isTrue(def $self._primaryKey){Не определен первичный ключ для таблицы ${TABLE_NAME}.}
  ^pfAssert:isTrue(def $aPrimaryKeyValue){Не задано значение первичного ключа}
  ^self.cleanMethodArgument[aData]
  $result[^self.CSQL.void{
    ^self.asContext[update]{^self.__normalizeWhitespaces{
      ^self._builder.updateStatement[$self.TABLE_NAME;$self._fields;$aData][$self.PRIMARYKEY = ^self.fieldValue[$self._fields.[$self._primaryKey];$aPrimaryKeyValue]][
        $.skipAbsent(true)
        $.skipFields[$self._skipOnUpdate]
        $.emptySetExpression[$self.PRIMARYKEY = $self.PRIMARYKEY]
        $.schema[$self.SCHEMA]
        $.fieldValueFunction[$self.fieldValue]
      ]
    }}
  }]

@newOrModify[aData;aSQLOptions]
## Аналог мускулевского "insert on duplicate key update"
## Пытаемся создать новую запись, а если она существует, то обновляем данные.
## Работает только для таблиц с первичным ключем.
  $result[]
  ^self.cleanMethodArgument[aSQLOptions]
  ^pfAssert:isTrue(def $self._primaryKey){Не определен первичный ключ для таблицы ${TABLE_NAME}.}
  ^self.CSQL.safeInsert{
     $result[^self.new[$aData;$aSQLOptions]]
  }{
      ^self.modify[$aData.[$self._primaryKey];$aData]
      $result[$aData.[$self._primaryKey]]
   }

@delete[aPrimaryKeyValue]
## Удаляем запись из таблицы с первичныйм ключем aPrimaryKeyValue
  ^pfAssert:isTrue(def $self._primaryKey){Не определен первичный ключ для таблицы ${TABLE_NAME}.}
  ^pfAssert:isTrue(def $aPrimaryKeyValue){Не задано значение первичного ключа}
  $result[^self.CSQL.void{
    ^self.asContext[update]{^self.__normalizeWhitespaces{
      delete from ^if(def $self.SCHEMA){^self._builder.quoteIdentifier[$self.SCHEMA].}^self._builder.quoteIdentifier[$self.TABLE_NAME] where $self.PRIMARYKEY = ^self.fieldValue[$self._fields.[$self._primaryKey];$aPrimaryKeyValue]
    }}
  }]

@shift[aPrimaryKeyValue;aFieldName;aValue]
## Увеличивает или уменьшает значение счетчика в поле aFieldName на aValue
## aValue(1) — положитетельное или отрицательное число
## По-умолчанию увеличивает значение поля на единицу
  ^pfAssert:isTrue(def $self._primaryKey){Не определен первичный ключ для таблицы ${TABLE_NAME}.}
  ^pfAssert:isTrue(def $aPrimaryKeyValue){Не задано значение первичного ключа.}
  ^pfAssert:isTrue(^self.hasField[$aFieldName]){Не найдено поле "$aFieldName" в таблице.}
  $aValue(^if(def $aValue){$aValue}{1})
  $lFieldName[^self._builder.sqlFieldName[$self._fields.[$aFieldName]]]]
  $result[^self.CSQL.void{
    ^self.asContext[update]{^self.__normalizeWhitespaces{
      update ^if(def $self.SCHEMA){^self._builder.quoteIdentifier[$self.SCHEMA].}^self._builder.quoteIdentifier[$self.TABLE_NAME]
         set $lFieldName = $lFieldName ^if($aValue < 0){-}{+} ^self.fieldValue[$self._fields.[$aFieldName]](^math:abs($aValue))
       where $self.PRIMARYKEY = ^self.fieldValue[$self._fields.[$self._primaryKey];$aPrimaryKeyValue]
    }}
  }]

#----- Групповые операции с данными -----

@modifyAll[aOptions;aData]
## Изменяем все записи
## Условие обновления берем из _allWhere
  ^self.cleanMethodArgument[aOptions;aData]
  $result[^self.CSQL.void{
    ^self.asContext[update]{^self.__normalizeWhitespaces{
      ^self._builder.updateStatement[$self.TABLE_NAME;$self._fields;$aData][
        ^self._allWhere[$aOptions]
      ][
        $.schema[$self.SCHEMA]
        $.skipAbsent(true)
        $.skipFields[$self._skipOnUpdate]
        $.emptySetExpression[]
        $.fieldValueFunction[$self.fieldValue]
      ]
    }}
  }]

@deleteAll[aOptions]
## Удаляем все записи из таблицы
## Условие для удаления берем из self._allWhere
  ^self.cleanMethodArgument[]
  $result[^self.CSQL.void{
    ^self.asContext[update]{^self.__normalizeWhitespaces{
      delete from ^if(def $self.SCHEMA){^self._builder.quoteIdentifier[$self.SCHEMA].}^self._builder.quoteIdentifier[$self.TABLE_NAME]
       where ^self._allWhere[$aOptions]
    }}
  }]

#----- Private -----
## Методы с префиксом _all используются для построения частей выражений выборки.
## Их можно перекрывать в наследниках смело, но не рекомендуется их использовать
## напрямую во внешнем коде.

@_allFields[aOptions;aSQLOptions]
  ^self.cleanMethodArgument[aOptions;aSQLOptions]
  $result[^self._builder.selectFields[$self._fields;
    $.tableAlias[$self.TABLE_ALIAS]
    ^if(^aSQLOptions.contains[skipFields]){
      $.skipFields[$aSQLOptions.skipFields]
    }
  ]]

@_allJoinFields[aOptions]
  $result[]

@_allJoin[aOptions]
  $result[]

@_allWhere[aOptions]
## Дополнительное выражение для where
## (выражение для полей формируется в _fieldsWhere)
  $lConds[^self._buildConditions[$aOptions]]
  $result[^if(^aOptions.contains[where]){$aOptions.where}{1=1}^if(def $lConds){ and $lConds}]

@_allHaving[aOptions]
  $result[]

@_allGroup[aOptions]
## aOptions.groupBy
  ^if(^aOptions.contains[groupBy]){
    $lGroup[$aOptions.groupBy]
  }{
    $lGroup[$self._defaultGroupBy]
  }
  ^self.asContext[group]{
    ^switch(true){
      ^case($lGroup is hash){$result[^lGroup.foreach[k;v]{^if(^self._fields.contains[$k]){^self.sqlFieldName[$k]^if(^v.lower[] eq "desc"){ desc}(^v.lower[] eq "asc"){ asc}}}[, ]]}
      ^case[DEFAULT]{$result[^lGroup.trim[]]}
    }
  }

@_allOrder[aOptions]
## aOptions.orderBy
  ^if(^aOptions.contains[orderBy]){
    $lOrder[$aOptions.orderBy]
  }(def $self._defaultOrderBy){
    $lOrder[$self._defaultOrderBy]
  }
  ^self.asContext[group]{
    ^switch(true){
      ^case($lOrder is hash){$result[^lOrder.foreach[k;v]{^if(^self._fields.contains[$k]){^self.sqlFieldName[$k] ^if(^v.lower[] eq "desc"){desc}{asc}}}[, ]]}
      ^case[DEFAULT]{$result[^lOrder.trim[]]}
    }
  }

# ----- Методы для построения запросов ----

@fieldValue[aField;aValue]
## aField — имя или хеш с полем
  ^if($aField is string){
    $aField[$self._fields.[$aField]]
  }
  $result[^self._builder.fieldValue[$aField;$aValue]]

@valuesArray[aField;aValues;aOptions]
## aField — имя или хеш с полем
  ^self.cleanMethodArgument[]
  ^if($aField is string){
    $aField[$self._fields.[$aField]]
  }
  $result[^self._builder.array[$aField;$aValues;$aOptions $.valueFunction[$fieldValue]]]

@sqlFieldName[aFieldName]
  ^pfAssert:isTrue(^self._fields.contains[$aFieldName]){Неизвестное поле «${aFieldName}».}
  $lField[$self._fields.[$aFieldName]]
  ^if($self.__context eq "where"
      && ^lField.contains[fieldExpression]
      && def $lField.fieldExpression){
    $result[$lField.fieldExpression]
  }(^lField.contains[expression]
    && def $lField.expression
   ){
     ^if($self.__context eq "group"){
       $result[^self._builder.quoteIdentifier[$lField.name]]
     }{
        $result[$lField.expression]
      }
  }{
     ^if(!^lField.contains[dbField]){
       ^throw[pfSQLTable.field.fail;Для поля «${aFieldName}» не задано выражение или имя в базе данных.]
     }
     $result[^self._builder.sqlFieldName[$lField;^if($self.__context ne "update"){$self.TABLE_ALIAS}]]
   }

@asContext[aContext;aCode]
  $lOldContext[$self.__context]
  $self.__context[$aContext]
  ^try{
    $result[$aCode]
  }{}{
#   Возвращаем старый контекст, даже если был exception
    $self.__context[$lOldContext]
  }

@_buildConditions[aConds;aOP]
## Строим выражение для сравнения
## aOp[AND|OR|NOT]
  ^self.cleanMethodArgument[aConds]
  $result[]

  $lConds[^hash::create[]]
  $lRes[^hash::create[]]

  ^aConds.foreach[k;v]{
    ^k.match[$self._PFSQLTABLE_COMPARSION_REGEX][]{
      $lField[$self._fields.[$match.1]]
      ^if($match.2 eq "range" || $match.2 eq "!range"){
#       $.[field range][$.from $.to]
#       $.[field !range][$.from $.to]
        $lRes.[^lRes._count[]][^if(^match.2.left(1) eq "!"){not }^(^self.sqlFieldName[$match.1] between ^self.fieldValue[$lField;$v.from] and ^self.fieldValue[$lField;$v.to])]
      }(^self._fields.contains[$match.1] && $match.2 eq "is"){
        $lRes.[^lRes._count[]][^self.sqlFieldName[$match.1] is ^if(!def $v || $v eq "null"){null}{not null}]
      }(^self._plurals.contains[$match.1]
        || (^self._fields.contains[$match.1] && ($match.2 eq "in" || $match.2 eq "!in"))
       ){
#       $.[field [!]in][hash|table|values string]
#       $.[plural [not]][hash|table|values string]
        $lRes.[^lRes._count[]][^self._condArrayField[$aConds;$match.1;^match.2.lower[];$v]]
      }($match.1 eq "OR" || $match.1 eq "AND" || $match.1 eq "NOT"){
#       Рекурсивный вызов логического блока
        $lRes.[^lRes._count[]][^self._buildConditions[$v;$match.1]]
      }(^self._fields.contains[$match.1]){
#       Операторы
#       $.[field operator][value]
        $lRes.[^lRes._count[]][^self.sqlFieldName[$match.1] ^taint[^ifdef[$match.2]{=}] ^self.fieldValue[$lField;$v]]
      }
    }
  }
  $result[^if($lRes){^if($aOP eq "NOT"){not} (^lRes.foreach[_;v]{$v}[ $self._PFSQLTABLE_LOGICAL.[$aOP] ])}]

@_condArrayField[aConds;aFieldName;aOperator;aValue]
  $lField[^if(^self._plurals.contains[$aFieldName]){$self._plurals.[$aFieldName]}{$self._fields.[$aFieldName]}]
  $lColumn[^if(^aConds.contains[${aFieldName}Column]){$aConds.[${aFieldName}Column]}{$lField.name}]
  $result[^self.sqlFieldName[$lField.name] ^if($aOperator eq "not" || $aOperator eq "!in"){not in}{in} (^self.valuesArray[$lField.name;$aValue;$.column[$lColumn]])]

@_selectExpression[aFields;aResultType;aOptions;aSQLOptions]
  $aOptions[^hash::create[$aOptions]]
  $aOptions[^aOptions.union[$self._defaultScope]]

  ^self.asContext[where]{
    $lGroup[^self._allGroup[$aOptions]]
    $lOrder[^self._allOrder[$aOptions]]
    $lHaving[^if(^aOptions.contains[having]){$aOptions.having}{^self._allHaving[$aOptions]}]
  }
  $result[
       select $aFields
         from ^if(def $self.SCHEMA){^self._builder.quoteIdentifier[$self.SCHEMA].}^self._builder.quoteIdentifier[$self.TABLE_NAME] as ^self._builder.quoteIdentifier[$self.TABLE_ALIAS]
              ^self.asContext[where]{^if(^aOptions.contains[join]){$aOptions.join}{^self._allJoin[$aOptions]}}
        where ^self.asContext[where]{^self._allWhere[$aOptions]}
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
## Методы, начинаююшиеся с двух подчеркиваний, сугубо внутренние,
## желательно их не перекрывать и ни при каких условиях не использовать
## во внешнем коде.

@__getResultType[aOptions]
  $result[^switch(true){
    ^case(^aOptions.asTable.bool(false)){table}
    ^case(^aOptions.asHash.bool(false)){hash}
    ^case[DEFAULT]{$self._defaultResultType}
  }]

@__allSQLExpression[aResultType;aOptions;aSQLOptions]
  $result[^self._selectExpression[
    ^self.__allSelectFieldsExpression[$aResultType;$aOptions;$aSQLOptions]
  ][$aResultType;$aOptions;$aSQLOptions]]

@__aggregateSQLExpression[aResultType;aConds]
  $result[^self._selectExpression[
    ^self.asContext[select]{^self.__getAgrFields[$aConds.fields]}
  ][$aResultType;$aConds.options;$aConds.sqlOptions]]

@__allSelectFieldsExpression[aResultType;aOptions;aSQLOptions]
  $result[
    ^self.asContext[select]{
     ^if(def $aSQLOptions.selectОptions){$aSQLOptions.selectОptions}
     ^if(^aOptions.contains[selectFields]){
       $aOptions.selectFields
     }{
       ^if($aResultType eq "hash"){
         ^pfAssert:isTrue(def $self._primaryKey){Не определен первичный ключ для таблицы ${TABLE_NAME}. Выборку можно делать только в таблицу.}
#         Для хеша добавляем еще одно поле с первичным ключем
          $self.PRIMARYKEY as ^self._builder.quoteIdentifier[_ORM_HASH_KEY_],
       }
       $lJoinFields[^self._allJoinFields[$aOptions]]
       ^self._allFields[$aOptions;$aSQLOptions]^if(def $lJoinFields){, $lJoinFields}
      }
    }
  ]

@__getAgrConds[aConds]
  $aConds[^hash::create[$aConds]]
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

@__getAgrFields[aFields]
  $result[^hash::create[]]
  ^if(!$aFields){
#   Если нам не передали поля, то подставляем все поля модели.
    $aFields[^hash::create[$.0[_fields(*)]]]
  }
  ^aFields.foreach[_;v]{
    ^v.match[$self._PFSQLTABLE_AGR_REGEX][]{
      $lField[
        $.expr[$match.1]
        $.function[$match.2]
        $.args[^match.3.trim[both;() ]]
        $.alias[$match.4]
      ]
      ^if(^lField.function.lower[] eq "_fields"){
        ^if(^lField.args.trim[] eq "*"){
          $lField.expr[^self._allFields[]]
        }{
           $lSplit[^lField.args.split[,;lv]]
           $lField.expr[^lSplit.menu{^lSplit.piece.match[$self._PFSQLTABLE_AGR_REGEX][]{^if(def $match.1){^self.sqlFieldName[$match.1] as ^self._builder.quoteIdentifier[^if(def $match.4){$match.4}{$match.1}]}}}[, ]]
           $lField.alias[]
         }
      }
      $result.[^result._count[]][$lField]
    }
  }
  $result[^result.foreach[_;v]{$v.expr^if(def $v.alias){ as ^self._builder.quoteIdentifier[$v.alias]}}[, ]]

@__normalizeWhitespaces[aQuery;aOptions]
  $result[^untaint[optimized-as-is]{^untaint[sql]{$aQuery}}]

  ^if(^aOptions.apply.bool(false)){
    $result[^apply-taint[$result]]
  }

#----------------------------------------------------------------------------------------------------------------------

@CLASS
pfSQLTableScope

@OPTIONS
locals

@create[aModel;aScope;aOptions]
  $self.__model__[$aModel]
  $self.__scope__[$aScope]
  ^reflection:copy[$aModel;$self]
  ^reflection:mixin[$aModel]
  $self._defaultScope[$aScope]

#----------------------------------------------------------------------------------------------------------------------

@CLASS
pfSQLBuilder

@OPTIONS
locals

@BASE
pfClass

@create[aOptions]
## aOptions.quoteStyle[mysql|ansi] — стиль «кавычек» для идентификаторов (default: mysql)
  ^self.cleanMethodArgument[]
  ^BASE:create[$aOptions]

  $self._quote[]
  ^self.setQuoteStyle[^if(def $aOptions.quoteStyle){^aOptions.quoteStyle.lower[]}]

  $self._now[^date::now[]]
  $self._today[^date::today[]]

@auto[]
  $self._PFSQLBUILDER_CSV_REGEX_[^regex::create[((?:\s*"(?:[^^"]*|"{2})*"\s*(?:,|^$))|\s*"[^^"]*"\s*(?:,|^$)|[^^,]+(?:,|^$)|(?:,))][g]]
  $self._PFSQLBUILDER_CSV_QTRIM_REGEX_[^regex::create["(.*)"][]]
  $self._PFSQLBUILDER_PROCESSOR_FIRST_UPPER[^regex::create[^^\s*(\pL)(.*?)^$][]]

@setQuoteStyle[aStyle]
  $result[]
  ^switch[$aStyle]{
    ^case[mysql]{$self._quote[`]}
    ^case[DEFAULT;ansi]{$self._quote["]}
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
##   auto_default — если не задано значение, то возвращает field.default (поведение по-умолчанию)
##   uint, auto_uint — целое число без знака, если не задан default, то приведение делаем без значения по-умолчанию
##   int, auto_int — целое число, если не задан default, то приведение делаем без значения по-умолчанию
##   double, auto_double — целое число, если не задан default, то приведение делаем без значения по-умолчанию
##   bool, auto_bool — 1/0
##   datetime — дата и время (если нам передали дату, то делаем sql-string)
##   date — дата (если нам передали дату, то делаем sql-string[date])
##   time — время (если нам передали дату, то делаем sql-string[time])
##   now, auto_now — текущие дата время (если не задано значение поля)
##   curtime, auto_curtime — текущее время (если не задано значение поля)
##   curdate, auto_curdate — текущая дата (если не задано значение поля)
##   json — сереиализует значение в json
##   null — если не задано значение, то возвращает null
##   uint_null — преобразуем зачение в целое без знака, если не задано значение, то возвращаем null
##   uid, auto_uid — уникальный идентификатор (math:uuid)
##   inet_ip — преобразует строку в числовое представление IP
##   first_upper — удаляет ведущие пробелы и капитализирует первую букву
##   hash_md5 — берет md5 от значения

@_processFieldsOptions[aOptions]
  $result[^hash::create[$aOptions]]
  $result.skipNames(^aOptions.skipNames.bool(false))
  $result.skipAbsent(^aOptions.skipAbsent.bool(false))
  $result.skipFields[^hash::create[$aOptions.skipFields]]

@quoteIdentifier[aIdent]
  $result[${self._quote}^taint[${aIdent}]${self._quote}]

@sqlFieldName[aField;aTableAlias]
  $result[^if(def $aTableAlias){${self._quote}${aTableAlias}${self._quote}.}${self._quote}^taint[$aField.dbField]${self._quote}]

@selectFields[aFields;aOptions]
## Возвращает список полей для выражения select
## aOptions.tableAlias
## aOptions.skipFields[$.field[] ...] — хеш с полями, которые надо исключить из выражения
  ^pfAssert:isTrue(def $aFields){Не задан список полей.}
  $aOptions[^self._processFieldsOptions[$aOptions]]
  $lTableAlias[^if(def $aOptions.tableAlias){$aOptions.tableAlias}]

  $result[^hash::create[]]
  $lFields[^hash::create[$aFields]]
  ^aFields.foreach[k;v]{
    ^if(^aOptions.skipFields.contains[$k]){^continue[]}
    ^if(^v.contains[expression]){
      $result.[^result._count[]][$v.expression as ${self._quote}${k}${self._quote}]]
    }{
       $result.[^result._count[]][^self.sqlFieldName[$v;$lTableAlias] as ${self._quote}${k}${self._quote}]]
     }
  }
  $result[^result.foreach[_;v]{$v}[, ]]

@fieldsList[aFields;aOptions]
## Возвращает список полей
## aOptions.tableAlias
## aOptions.skipFields[$.field[] ...] — хеш с полями, которые надо исключить из выражения
## aOptions.skipAbsent(false) — пропустить поля, данных для которых нет (нaдо обязательно задать поле aOptions.data)
## aOptions.data — хеш с данными
  ^pfAssert:isTrue(def $aFields){Не задан список полей.}
  $aOptions[^self._processFieldsOptions[$aOptions]]
  $lData[^if(def $aOptions.data){$aOptions.data}{^hash::create[]}]
  $lTableAlias[^if(def $aOptions.tableAlias){$aOptions.tableAlias}]
  $result[^hash::create[]]
  ^aFields.foreach[k;v]{
    ^if(^v.contains[expression] && !^v.contains[dbField]){^continue[]}
    ^if($aOptions.skipAbsent && !^lData.contains[$k] && !(def $v.processor && ^v.processor.pos[auto_] >= 0)){^continue[]}
    ^if(^aOptions.skipFields.contains[$k]){^continue[]}
    $result.[${self._quote}^result._count[]][^self.sqlFieldName[$v;$lTableAlias]]
  }
  $result[^result.foreach[_;v]{$v}[, ]]

@setExpression[aFields;aData;aOptions]
## Возвращает выражение для присвоения значения (field = vale, ...)
## aOptions.tableAlias
## aOptions.skipAbsent(false) — пропустить поля, данных для которых нет
## aOptions.skipFields[$.field[] ...] — хеш с полями, которые надо исключить из выражения
## aOptions.skipNames(false) — не выводить имена полей, только значения (для insert values)
## aOptions.fieldValueFunction[self.fieldValue] — функция для преобразования полей
  ^pfAssert:isTrue(def $aFields){Не задан список полей.}
  ^self.cleanMethodArgument[aData;aOptions]
  $aOptions[^self._processFieldsOptions[$aOptions]]
  $lAlias[^if(def $aOptions.alias){${aOptions.alias}}]
  $lFieldValue[^if($aOptions.fieldValueFunction is junction){$aOptions.fieldValueFunction}{$self.fieldValue}]

  $result[^hash::create[]]
  ^aFields.foreach[k;v]{
    ^if(^aOptions.skipFields.contains[$k] || (^v.contains[expression] && !^v.contains[dbField])){^continue[]}
    ^if($aOptions.skipAbsent && !^aData.contains[$k] && !(def $v.processor && ^v.processor.pos[auto_] >= 0)){^continue[]}
    $result.[^result._count[]][^if(!$aOptions.skipNames){^self.sqlFieldName[$v;$lAlias] = }^lFieldValue[$v;^if(^aData.contains[$k]){$aData.[$k]}]]
  }
  $result[^result.foreach[_;v]{$v}[, ]]

@fieldValue[aField;aValue]
## Возвращает значение поля в sql-формате.
  ^pfAssert:isTrue(def $aField){Не задано описание поля.}
  ^try{
    $result[^switch[^if(def $aField.processor){^aField.processor.lower[]}]{
      ^case[uint;auto_uint]{^try{$lVal($aValue)}{^if(^aField.contains[default]){$exception.handled(true) $lVal($aField.default)}}^lVal.format[^if(def $aField.format){$aField.format}{%u}]}
      ^case[int;auto_int]{^try{$lVal($aValue)}{^if(^aField.contains[default]){$exception.handled(true) $lVal($aField.default)}}^lVal.format[^if(def $aField.format){$aField.format}{%d}]}
      ^case[double;auto_double]{^if(^aField.contains[default]){$lValue(^aValue.double($aField.default))}{$lValue(^aValue.double[])}^lValue.format[^if(def $aField.format){$aField.format}{%.16g}]}
      ^case[bool;auto_bool]{^if(^aValue.bool(^if(^aField.contains[default]){$aField.default}{false})){1}{0}}
      ^case[now;auto_now]{^if(def $aValue){'^if($aValue is date){^aValue.sql-string[]}{^taint[$aValue]}'}{$lNow[^date::now[]]'^lNow.sql-string[]'}}
      ^case[curtime;auto_curtime]{'^if(def $aValue){^if($aValue is date){^aValue.sql-string[time]}{^taint[$aValue]}}{$lNow[^date::now[]]^lNow.sql-string[time]}'}
      ^case[curdate;auto_curdate]{'^if(def $aValue){^if($aValue is date){^aValue.sql-string[date]}{^taint[$aValue]}}{$lNow[^date::now[]]^lNow.sql-string[date]}'}
      ^case[datetime]{^if(def $aValue){'^if($aValue is date){^aValue.sql-string[]}{^taint[$aValue]}'}{null}}
      ^case[date]{^if(def $aValue){'^if($aValue is date){^aValue.sql-string[date]}{^taint[$aValue]}'}{null}}
      ^case[time]{^if(def $aValue){'^if($aValue is date){^aValue.sql-string[time]}{^taint[$aValue]}'}{null}}
      ^case[json]{^if(def $aValue){'^taint[^json:string[$aValue]]'}{null}}
      ^case[null]{^if(def $aValue){'^taint[$aValue]'}{null}}
      ^case[int_null]{^if(def $aValue){$lVal($aValue)^lVal.format[%d]}{null}}
      ^case[uint_null]{^if(def $aValue){$lVal($aValue)^lVal.format[%u]}{null}}
      ^case[uid;auto_uid;uuid;uuid_auto]{'^taint[^if(def $aValue){$aValue}{$lUUID[^math:uuid[]]^lUUID.lower[]}]'}
      ^case[inet_ip]{^self.unsafe{^inet:aton[$aValue]}{null}}
      ^case[first_upper]{'^taint[^if(def $aValue){^aValue.match[$self._PFSQLBUILDER_PROCESSOR_FIRST_UPPER][]{^match.1.upper[]$match.2}}(def $aField.default){$aField.default}]'}
      ^case[hash_md5]{'^taint[^if(def $aValue){^math:md5[$aValue]}]'}
      ^case[lower_trim]{$lVal[^aValue.lower[]]'^taint[^lVal.trim[both]]'}
      ^case[upper_trim]{$lVal[^aValue.lower[]]'^taint[^lVal.trim[both]]'}
      ^case[DEFAULT;auto_default]{'^taint[^if(def $aValue){$aValue}(def $aField.default){$aField.default}]'}
    }]
  }{
     ^throw[pfSQLBuilder.bad.value;Ошибка при преобразовании поля ${aField.name} (processor: ^if(def $aField.processor){$aField.processor}{default}^; value type: $aValue.CLASS_NAME);[${exception.type}] ${exception.source}, ${exception.comment}.]
   }

@array[aField;aValue;aOptions]
## Строит массив значений
## aValue[table|hash|csv-string]
## aOptions.column[$aField.name] — имя колонки в таблице
## aOptions.emptyValue[null] — значение массива, если в aValue нет данных
## aOptions.valueFunction[fieldValue] — функция форматирования значения поля
  ^self.cleanMethodArgument[]
  $result[]
  $lValueFunction[^if(^aOptions.contains[valueFunction]){$aOptions.valueFunction}{$self.fieldValue}]
  $lEmptyValue[^if(^aOptions.contains[emptyValue]){$aOptions.emptyValue}{null}]
  $lColumn[^if(def $aOptions.column){$aOptions.column}{$aField.name}]
  ^switch(true){
    ^case($aValue is hash){$result[^aValue.foreach[k;_]{^lValueFunction[$aField;$k]}[, ]]}
    ^case($aValue is table){$result[^aValue.menu{^lValueFunction[$aField;$aValue.[$lColumn]]}[, ]]}
    ^case($aValue is string){
      $lItems[^self._parseCSVString[$aValue]]
      $result[^lItems.foreach[_;v]{^lValueFunction[$aField;$v]}[, ]]
    }
    ^case[DEFAULT]{
      ^throw[pfSQLBuilder.bad.array.values;Значениями массива может быть хеш, таблица или csv-строка. (Поле: $aField.name, тип значения: $aValue.CLASS_NAME)]
    }
  }]
  ^if(!def $result && def $lEmptyValue){
    $result[$lEmptyValue]
  }

@_parseCSVString[aString]
# $result[$.0[] $.1[] ...]
  $result[^hash::create[]]
  ^aString.match[$self._PFSQLBUILDER_CSV_REGEX_][]{
    $lValue[^match.1.trim[right;,]]
    $lValue[^lValue.match[$self._PFSQLBUILDER_CSV_QTRIM_REGEX_][]{^match.1.replace[""]["]}]
    $result.[^result._count[]][$lValue]
  }

#----- Построение sql-выражений -----

@insertStatement[aTableName;aFields;aData;aOptions]
## Строит выражение insert into values
## aTableName — имя таблицы
## aFields — поля
## aData — данные
## aOptions.schema
## aOptions.skipFields[$.field[] ...] — хеш с полями, которые надо исключить из выражения
## aOptions.ignore(false)
  ^pfAssert:isTrue(def $aTableName){Не задано имя таблицы.}
  ^pfAssert:isTrue(def $aFields){Не задан список полей.}
  ^self.cleanMethodArgument[aData;aOptions]
  $lOpts[^if(^aOptions.ignore.bool(false)){ignore}]
  $result[insert $lOpts into ^if(def $aOptions.schema){${self._quote}${aOptions.schema}${self._quote}.}${self._quote}${aTableName}${self._quote} (^self.fieldsList[$aFields;^hash::create[$aOptions] $.data[$aData]]) values (^self.setExpression[$aFields;$aData;^hash::create[$aOptions] $.skipNames(true)])]


@updateStatement[aTableName;aFields;aData;aWhere;aOptions]
## Строит выражение для update
## aTableName — имя таблицы
## aFields — поля
## aData — данные
## aWhere — выражение для where
##          (для безопасности блок where задается принудительно,
##           если нужно иное поведение укажите aWhere[1=1])
## aOptions.schema
## aOptions.skipAbsent(false) — пропустить поля, данных для которых нет
## aOptions.skipFields[$.field[] ...] — хеш с полями, которые надо исключить из выражения
## aOptions.emptySetExpression[выражение, которое надо подставить, если нет данных для обновления]
  ^pfAssert:isTrue(def $aTableName){Не задано имя таблицы.}
  ^pfAssert:isTrue(def $aFields){Не задан список полей.}
  ^pfAssert:isTrue(def $aWhere){Не задано выражение для where.}
  ^self.cleanMethodArgument[aData;aOptions]

  $lSetExpression[^self.setExpression[$aFields;$aData;$aOptions]]
  ^pfAssert:isTrue(def $lSetExpression || (!def $lSetExpression && def $aOptions.emptySetExpression)){Необходимо задать выражение для пустого update set.}
  $result[update ^if(def $aOptions.schema){${self._quote}${aOptions.schema}${self._quote}.}${self._quote}${aTableName}${self._quote} set ^if(def $lSetExpression){$lSetExpression}{$aOptions.emptySetExpression} where $aWhere]
