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
## aOptions.schema — название схемы в БД (можно не указывать)
## aOptions.builder
## aOptions.allAsTable(false) — по-умолчанию возвращать результат в виде таблицы
## aOptions.allAsTable(false) — по-умолчанию возвращать результат в виде массива хешей
## aOptions.readOnlyTable(false) — модель только для чтения (методы, менящие данне, вызовут исключение)

## Следующие поля необязательны, но полезны
## при создании объекта на основании другой таблицы:
##   aOptions.fields[$.field[...]]
##   aOptions.primaryKey
##   aOptions.skipOnInsert[$.field(bool)]
##   aOptions.skipOnUpdate[$.field(bool)]
##   aOptions.skipOnSelect[$.field(bool)]
##   aOptions.fieldsGroups[$.group[$.field(bool)]]
  ^self.cleanMethodArgument[]
  ^BASE:create[$aOptions]
  $self.__options[^hash::create[$aOptions]]

  $self._readOnlyTable(^aOptions.readOnlyTable.bool(false))

  $self._csql[^if(def $aOptions.sql){$aOptions.sql}{$self._PFSQLTABLE_CSQL}]
  ^self.assert(def $self._csql){Не задан объект для работы с SQL-сервером.}
  $self.CSQL[$self._csql]

  $self._builder[^if(def $aOptions.builder){$aOptions.builder}{$self._PFSQLTABLE_BUILDER}]
  ^if(!def $self._builder){
    $self._builder[^pfSQLBuilder::create[$self._csql.dialect]]
  }

  $self._schema[^taint[^aOptions.schema.trim[]]]

  $self._tableName[^taint[$aTableName]]
  $self._tableAlias[^if(def $aOptions.tableAlias){^taint[$aOptions.tableAlias]}(def $self._schema){^taint[${self._schema}_$self._tableName]}]
  $self._primaryKey[^if(def $aOptions.primaryKey){$aOptions.primaryKey}]

  $self._fields[^hash::create[]]
  $self._plurals[^hash::create[]]
  ^if(^aOptions.contains[fields]){
    ^self.addFields[$aOptions.fields]
  }

  $self._fieldsGroups[^hash::create[^if(def $aOptions.fieldsGroups){$aOptions.fieldsGroups}]]

  $self._skipOnInsert[^hash::create[^if(def $aOptions.skipOnInsert){$aOptions.skipOnInsert}]]
  $self._skipOnUpdate[^hash::create[^if(def $aOptions.skipOnUpdate){$aOptions.skipOnUpdate}]]
  $self._skipOnSelect[^hash::create[^if(def $aOptions.skipOnSelect){$aOptions.skipOnSelect}]]

  $self._defaultResultType[^if(^aOptions.allAsTable.bool(false)){table}(^aOptions.allAsArray.bool(false)){array}{hash}]

  $self._defaultOrderBy[]
  $self._defaultGroupBy[]

# Скоупы. Наборы параметров, которые ограничивают Выборку
# ^addScope[visible;$.isActive(true)]
# ^model.visible.all[] аналогично ^model.all[$.isActive(true)]
  $self._scopes[^hash::create[]]
  $self._defaultScope[^hash::create[]]

  $self.__context[]

# Делаем алиас на aggregate, чтобы писать кастомные запросы через ^model.select[...]
  ^self.alias[select;$self.aggregate]

#----- Статические методы и конструктор -----

@auto[]
  $self._PFSQLTABLE_CSQL[]
  $self._PFSQLTABLE_BUILDER[]
  $self._PFSQLTABLE_COMPARSION_REGEX[^regex::create[^^\s*(\S+)(?:\s+(\S+))?][]]
  $self._PFSQLTABLE_AGR_REGEX[^regex::create[^^\s*(\(*([^^\s(]+)(.*?))\s*(?:as\s+([^^\s\)]+))?\s*^$][i]]
  $self._PFSQLTABLE_LOGICAL[
    $.OR[OR]
    $.AND[AND]
    $.NOT[AND]
    $._default[AND]
  ]

@static:assignServer[aSQLConnection]
# Чтобы можно было задать коннектор для всех объектов сразу.
  $self._PFSQLTABLE_CSQL[$aSQLConnection]

@static:assignBuilder[aSQLBuilder]
  $self._PFSQLTABLE_BUILDER[$aSQLBuilder]

#----- Метаданные -----

@addFields[aFields]
## Добавляем сразу много полей в модель
## Вместо множественного вызова addField делаем один addFields для оптимизации добавления ольшого числа полей в модель,
## что приводило к слишком большому числу вызовов функций
## aFields[$.fieldName[fieldOptions ...]]
## fieldOptions.dbField[aFieldName] — название поля
## fieldOptions.fieldExpression{} — выражение для названия поля
## fieldOptions.expression{} — sql-выражение для значения поля (если не определено, то используем fieldExpression)
## fieldOptions.plural[] — название поля для групповой выборки
## fieldOptions.processor — процессор
## fieldOptions.default — значение «по-умолчанию»
## fieldOptions.format — формат числового значения
## fieldOptions.primary(false) — первичный ключ
## fieldOptions.sequence(true) — последовательность формирует БД (автоинкремент; только для первичного ключа)
## fieldOptions.groups[group1, group2] — список групп для поля
## fieldOptions.skipOnInsert(false) — пропустить при вставке
## fieldOptions.skipOnUpdate(false) — пропустить при обновлении
## fieldOptions.skipOnSelect(false) — пропустить при селекте
## fieldOptions.label[aFieldName] — текстовое название поля (например, для форм)
## fieldOptions.comment — описание поля
## fieldOptions.widget — название html-виджета для редактирования поля.
  $result[]
  $aFields[^hash::create[$aFields]]

  ^aFields.foreach[lFieldName;lOptions]{
    ^if(!def $lFieldName){^throw[assert.fail;Не задано имя поля таблицы.]}
    ^if(^self._fields.contains[$lFieldName]){^throw[assert.fail;Поле «${lFieldName}» в таблице уже существует.]}

    $lField[
      $.name[$lFieldName]
      $.plural[$lOptions.plural]
      $.processor[$lOptions.processor]
      $.default[$lOptions.default]
      $.format[$lOptions.format]
      $.primary(false)

      $.label[^if(def $lOptions.label){$lOptions.label}{$lFieldName}]
      $.comment[$lOptions.comment]
      $.widget[$lOptions.widget]
    ]

    ^if(^lOptions.contains[fieldExpression] || ^lOptions.contains[expression]){
      ^if(def $lOptions.dbField){
        $lField.dbField[$lOptions.dbField]
      }
      $lField.fieldExpression[$lOptions.fieldExpression]
      $lField.expression[$lOptions.expression]
      ^if(!def $lField.expression){
        $lField.expression[$lField.fieldExpression]
      }
      ^if(^lOptions.skipOnUpdate.bool(false) || !def $lField.dbField){
        $self._skipOnUpdate.[$lFieldName](true)
      }
      ^if(^lOptions.skipOnInsert.bool(false) || !def $lField.dbField){
        $self._skipOnInsert.[$lFieldName](true)
      }
    }{
      $lField.dbField[^if(def $lOptions.dbField){$lOptions.dbField}{$lFieldName}]
      $lField.primary(^lOptions.primary.bool(false))
      $lField.sequence($lField.primary && ^lOptions.sequence.bool(true))
      ^if(^lOptions.skipOnUpdate.bool(false) || $lField.primary){
        $self._skipOnUpdate.[$lFieldName](true)
      }
      ^if(^lOptions.skipOnInsert.bool(false) || $lField.sequence){
        $self._skipOnInsert.[$lFieldName](true)
      }
      ^if($lField.primary && !def $self._primaryKey){
        $self._primaryKey[$lFieldName]
      }
    }

    ^if(^lOptions.skipOnSelect.bool(false)){
      $self._skipOnSelect.[$lFieldName](true)
    }

    $self._fields.[$lFieldName][$lField]
    ^if(def $lField.plural){
      $self._plurals.[$lField.plural][$lField]
    }

    ^if(def $lOptions.groups){
      $lGroups[^lOptions.groups.split[,;lv]]
      ^lGroups.foreach[;group]{
        $group[^group.piece.trim[]]
        ^if(!def $group){
          ^continue[]
        }

        ^if(!^self._fieldsGroups.contains[$group]){
          $self._fieldsGroups.[$group][^hash::create[]]
        }

        $self._fieldsGroups.[$group].[$lFieldName](true)
      }
    }
  }

@addField[aFieldName;aOptions]
## Добавляем одно поле в модель
## Лучше сразу вызвать addFields
  $result[]
  ^self.addFields[$.[$aFieldName][$aOptions]]

@hasField[aFieldName]
## Проверяет наличие поля в таблице
  $result(def $aFieldName && ^self._fields.contains[$aFieldName])

@replaceField[aFieldName;aOptions]
## Заменяет поле в таблице
  ^if(^self.hasField[$aFieldName]){
    ^self._fields.delete[$aFieldName]
  }
  $result[^self.addFields[$.[$aFieldName][$aOptions]]]

@removeField[aFieldName]
## Удаляет поле в таблице
  $result[]
  ^if(^self.hasField[$aFieldName]){
    ^self._fields.delete[$aFieldName]
  }

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
## Добавлет новый скоуп в модель
  $result[]
  ^self.assert(def ^aName.trim[]){На задано имя скоупа.}
  $self._scopes.[$aName][^hash::create[$aConditions]]

#----- Свойства -----

@GET_SCHEMA[]
  $result[$self._schema]

@GET_TABLE_NAME[]
  ^self.assert(def $self._tableName){Не задано имя таблицы в классе $self.CLASS_NAME}
  $result[$self._tableName]

@GET_TABLE_ALIAS[]
  ^if(!def $self._tableAlias){
    $self._tableAlias[$self.TABLE_NAME]
  }
  $result[$self._tableAlias]

@GET_TABLE_EXPRESSION[]
  $result[^if(def $self.SCHEMA){^self._builder.quoteIdentifier[$self.SCHEMA].}^self._builder.quoteIdentifier[$self.TABLE_NAME] AS ^self._builder.quoteIdentifier[$self.TABLE_ALIAS]]

@GET_TE[]
  $result[^self.GET_TABLE_EXPRESSION[]]

@GET_FIELDS[]
  $result[$self._fields]

@GET_FIELDS_GROUPS[]
  $result[$self._fieldsGroups]

@GET_DEFAULT[aField]
# Если нам пришло имя скоупа, то возвращаем таблицу со скоупом
# Если нам пришло имя поля, то возвращаем имя поля в БД
# Для сложных случаев поддерживаем альтернативный синтаксис f_fieldName.
  $result[]
  ^if(^self._scopes.contains[$aField]){
    $lScope[^hash::create[$self._defaultScope]]
    ^lScope.add[$self._scopes.[$aField]]
    $result[^pfSQLTableScope::create[$self;$lScope;$.name[$aField]]]
  }{
    $lField[^if(^aField.pos[f_] == 0){^aField.mid(2)}{$aField}]
    ^if($lField eq "PRIMARYKEY"){
      $lField[$self._primaryKey]
    }
    ^if(^self._fields.contains[$lField]){
      $result[^self.sqlFieldName[$lField]]
    }
  }

@TABLE_AS[*aArgs]
## ^TABLE_AS[name] -> schema.table_name as name
## ^TABLE_AS[name]{$t.TE ... $t.field} — временно переименовывает таблицы и выполняет код
  ^if($aArgs == 2){
    $lOldTableAlias[$self._tableAlias]
    $self._tableAlias[$aArgs.0]
    $result[$aArgs.1]
    $self._tableAlias[$lOldTableAlias]
  }{
    $lAlias[$aArgs.0]
    $result[^if(def $self.SCHEMA){^self._builder.quoteIdentifier[$self.SCHEMA].}^self._builder.quoteIdentifier[$self.TABLE_NAME]^if(def $lAlias){ AS ^self._builder.quoteIdentifier[$lAlias]}]
   }

#----- Выборки -----

@get[aPrimaryKeyValue;aOptions]
  ^self.assert(def $aPrimaryKeyValue){Не задано значение первичного ключа}
  $result[^self.one[$.[$self._primaryKey][$aPrimaryKeyValue]]]

@one[aOptions;aSQLOptions]
## Достаёт из базы одну запись
## Игнорируем _defaultOrderBy модели.
  $result[^self.all[
    ^hash::create[$aOptions]
#   Хак. Чтобы отсортировать результат надо явно передать aOptions.orderBy
    $.orderBy[$aOptions.orderBy]
  ][
    $aSQLOptions
  ]]
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
## aOptions.asArray(false) — возвращаем массив
## Выражения для контроля выборки (код в фигурных скобках):
##   aOptions.selectFieldsGroups[group1, group2] — выбрать толкьо поля с группами
##   aOptions.selectFields{exression} — выражение для списка полей (вместо автогенерации)
##   aOptions.where{expression} — выражение для where
##   aOptions.having{expression} — выражение для having
##   aOptions.window{expression} — выражение для window
##   aOptions.orderBy[hash[$.field[asc]]|{expression}] — хеш с полями или выражение для orderBy
##   aOptions.groupBy[hash[$.field[asc]]|{expression}] — хеш с полями или выражение для groupBy
##   aOptions.join[] — выражение для join. Заменяет результат вызова ^self._allJoin[].
## aOptions.limit
## aOptions.offset
## Для поддержки специфики СУБД:
##   aSQLOptions.tail — концовка запроса
##   aSQLOptions.selectOptions — модификатор после select (distinct, sql_no_cache и т.п.)
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
  ^CSQL.connect{
    $lResultType[^self.__getResultType[$aOptions]]
    $result[^self.__normalizeWhitespaces{^self.__allSQLExpression[$lResultType;$aOptions;$aSQLOptions]}[$.apply(true)]]
  }

@union[*aConds]
## Выполняет несколько запросов и объединяет их в один результат.
## Параметр aSQLOptions не поддерживается!
## Тип результата берем из самого первого условия.
  ^self.assert($aConds){Надо задать как-минимум одно условие выборки.}
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
  $lExpression[^self._selectExpression[COUNT(*)][;$aConds;$aSQLOptions]]
  $result[^self.CSQL.int{^self.__normalizeWhitespaces{$lExpression}}[][$aSQLOptions]]

@aggregate[*aConds]
## Выборки с группировкой
## ^aggregate[func(expr) as alias;_fields(field1, field2 as alias2);_fields(*);_groups(group1, group2);table[<field>];conditions hash;sqlOptions]
## aOptions.asTable(false) — возвращаем таблицу
## aOptions.asHash(false) — возвращаем хеш (ключ хеша — первичный ключ таблицы)
## aOptions.asHashOn[fieldName] — возвращаем хеш таблиц, ключем которого будет fieldName
## aOptions.asArray(false) — возвращаем массив
  $lConds[^self.__getAgrConds[$aConds]]
  $lResultType[^if(def $lConds.options.asHashOn){table}{^self.__getResultType[$lConds.options]}]
  $lExpression[^self.__aggregateSQLExpression[$lResultType;$lConds]]
  $result[^self.CSQL.[$lResultType]{^self.__normalizeWhitespaces{$lExpression}}[][$lConds.sqlOptions]]

  ^if($result is table && def $lConds.options.asHashOn){
    $result[^result.hash[$lConds.options.asHashOn;$.type[table] $.distinct(true)]]
  }

@aggregateSQL[*aConds]
## Возвращает текст запроса из метода aggregate.
  ^CSQL.connect{
    $lConds[^self.__getAgrConds[$aConds]]
    $lResultType[^self.__getResultType[$lConds.options]]
    $lExpression[^self.__aggregateSQLExpression[$lResultType;$lConds]]
    $result[^self.CSQL.connect{^self.__normalizeWhitespaces{$lExpression}[$.apply(true)]}]
  }

#----- Манипуляции с данными -----

@new[aData;aSQLOptions]
## Вставляем значение в базу
## aSQLOptions.ignore(false)
## Возврашает автосгенерированное значение первичного ключа (last_insert_id) для sequence-полей.
## aSQLOptions.log
  ^CSQL.transaction{
    ^self.assert(!$self._readOnlyTable){Модель $self.CLASS_NAME в режиме read only (только чтение данных)}
    ^self.cleanMethodArgument[aData;aSQLOptions]
    ^self.asContext[update]{
      $result[^self.CSQL.void{^self.__normalizeWhitespaces{^self._builder.insertStatement[$self.TABLE_NAME;$self._fields;^if($aData is table){$aData.fields}{$aData};
        ^hash::create[$aSQLOptions]
        $.skipFields[$self._skipOnInsert]
        $.schema[$self.SCHEMA]
        $.fieldValueFunction[$self.fieldValue]
      ]}}[][$aSQLOptions]]
    }
    ^if(def $self._primaryKey && $self._fields.[$self._primaryKey].sequence){
      $result[^self.CSQL.lastInsertID[]]
    }
  }

@modify[aPrimaryKeyValue;aData]
## Изменяем запись с первичныйм ключем aPrimaryKeyValue в таблице
  ^self.assert(!$self._readOnlyTable){Модель $self.CLASS_NAME в режиме read only (только чтение данных)}
  ^self.assert(def $self._primaryKey){Не определен первичный ключ для таблицы ${TABLE_NAME}.}
  ^self.assert(def $aPrimaryKeyValue){Не задано значение первичного ключа}
  ^self.cleanMethodArgument[aData]
  $result[^self.CSQL.void{
    ^self.asContext[update]{^self.__normalizeWhitespaces{
      ^self._builder.updateStatement[$self.TABLE_NAME;$self._fields;^if($aData is table){$aData.fields}{$aData}][$self.PRIMARYKEY = ^self.fieldValue[$self._fields.[$self._primaryKey];$aPrimaryKeyValue]][
        $.skipAbsent(true)
        $.skipFields[$self._skipOnUpdate]
        $.emptySetExpression[$self.PRIMARYKEY = $self.PRIMARYKEY]
        $.schema[$self.SCHEMA]
        $.fieldValueFunction[$self.fieldValue]
      ]
    }}
  }[][$aSQLOptions]]

@newOrModify[aData;aSQLOptions]
## Аналог мускулевского "insert on duplicate key update"
## Пытаемся создать новую запись, а если она существует, то обновляем данные.
## Работает только для таблиц с первичным ключем.
  ^self.assert(!$self._readOnlyTable){Модель $self.CLASS_NAME в режиме read only (только чтение данных)}
  $result[]
  ^self.cleanMethodArgument[aSQLOptions]
  ^self.assert(def $self._primaryKey){Не определен первичный ключ для таблицы ${TABLE_NAME}.}
  ^CSQL.transaction{
    ^self.CSQL.safeInsert{
       $result[^self.new[$aData;$aSQLOptions]]
    }{
        ^self.modify[$aData.[$self._primaryKey];$aData]
        $result[$aData.[$self._primaryKey]]
     }
  }

@delete[aPrimaryKeyValue]
## Удаляем запись из таблицы с первичныйм ключем aPrimaryKeyValue
  ^self.assert(!$self._readOnlyTable){Модель $self.CLASS_NAME в режиме read only (только чтение данных)}
  ^self.assert(def $self._primaryKey){Не определен первичный ключ для таблицы ${TABLE_NAME}.}
  ^self.assert(def $aPrimaryKeyValue){Не задано значение первичного ключа}
  $result[^self.CSQL.void{
    ^self.asContext[update]{^self.__normalizeWhitespaces{
      DELETE FROM ^if(def $self.SCHEMA){^self._builder.quoteIdentifier[$self.SCHEMA].}^self._builder.quoteIdentifier[$self.TABLE_NAME] WHERE $self.PRIMARYKEY = ^self.fieldValue[$self._fields.[$self._primaryKey];$aPrimaryKeyValue]
    }}
  }[][$aSQLOptions]]

@shift[aPrimaryKeyValue;aFieldName;aValue]
## Увеличивает или уменьшает значение счетчика в поле aFieldName на aValue
## aValue(1) — положитетельное или отрицательное число
## По-умолчанию увеличивает значение поля на единицу
  ^self.assert(!$self._readOnlyTable){Модель $self.CLASS_NAME в режиме read only (только чтение данных)}
  ^self.assert(def $self._primaryKey){Не определен первичный ключ для таблицы ${TABLE_NAME}.}
  ^self.assert(def $aPrimaryKeyValue){Не задано значение первичного ключа.}
  ^self.assert(^self.hasField[$aFieldName]){Не найдено поле "$aFieldName" в таблице.}
  $aValue(^if(def $aValue){$aValue}{1})
  $lFieldName[^self._builder.sqlFieldName[$self._fields.[$aFieldName]]]]
  $result[^self.CSQL.void{
    ^self.asContext[update]{^self.__normalizeWhitespaces{
      UPDATE ^if(def $self.SCHEMA){^self._builder.quoteIdentifier[$self.SCHEMA].}^self._builder.quoteIdentifier[$self.TABLE_NAME]
         SET $lFieldName = $lFieldName ^if($aValue < 0){-}{+} ^self.fieldValue[$self._fields.[$aFieldName]](^math:abs($aValue))
       WHERE $self.PRIMARYKEY = ^self.fieldValue[$self._fields.[$self._primaryKey];$aPrimaryKeyValue]
    }}
  }[][$aSQLOptions]]

#----- Групповые операции с данными -----

@modifyAll[aOptions;aData]
## Изменяем все записи
## Условие обновления берем из _allWhere
  ^self.assert(!$self._readOnlyTable){Модель $self.CLASS_NAME в режиме read only (только чтение данных)}
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
  }[][$aSQLOptions]]

@modifyAllSQL[aOptions;aData]
## Возвращает текст запроса метода modifyAll
  ^self.assert(!$self._readOnlyTable){Модель $self.CLASS_NAME в режиме read only (только чтение данных)}
  ^self.cleanMethodArgument[aOptions;aData]
  ^CSQL.connect{
    $result[
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
    ]
  }

@deleteAll[aOptions]
## Удаляем все записи из таблицы
## Условие для удаления берем из self._allWhere
  ^self.assert(!$self._readOnlyTable){Модель $self.CLASS_NAME в режиме read only (только чтение данных)}
  ^self.cleanMethodArgument[]
  $result[^self.CSQL.void{
    ^self.asContext[update]{^self.__normalizeWhitespaces{
      DELETE FROM ^if(def $self.SCHEMA){^self._builder.quoteIdentifier[$self.SCHEMA].}^self._builder.quoteIdentifier[$self.TABLE_NAME]
       WHERE ^self._allWhere[$aOptions]
    }}
  }[][$aSQLOptions]]

#----- Private -----
## Методы с префиксом _all используются для построения частей выражений выборки.
## Их можно перекрывать в наследниках смело, но не рекомендуется их использовать
## напрямую во внешнем коде.

@_allFields[aOptions;aSQLOptions]
  ^self.cleanMethodArgument[aOptions;aSQLOptions]
  $lSkipFields[^hash::create[$self._skipOnSelect]]
  ^if(^aSQLOptions.contains[skipFields]){
    ^lSkipFields.add[$aSQLOptions.skipFields]
  }

  $lFields[$self._fields]
  ^if(def $aOptions.selectFieldsGroups){
    $lFields[^self._filterFieldsByGroups[$aOptions.selectFieldsGroups]]
  }

  $result[^self._builder.selectFields[$lFields;
    $.tableAlias[$self.TABLE_ALIAS]
    $.skipFields[$lSkipFields]
  ]]

@_filterFieldsByGroups[aGroups]
  $result[^hash::create[]]

  $lGroups[^aGroups.split[,;lv]]
  ^lGroups.foreach[;group]{
    $group[^group.piece.trim[]]
    ^if(!def $group){
      ^continue[]
    }

    ^if(!$self._fieldsGroups.[$group]){
      ^throw[pfSQLTable.unknown.group;В таблице нет группы полей "$group". Доступные группы: "^self._fieldsGroups.foreach[k;]{$k}[, ]" ($self.CLASS_NAME)]
    }

    ^result.add[$self._fieldsGroups.[$group]]
  }

  $result[^self._fields.intersection[$result]]

@_allWith[aOptions]
  $result[]

@_allJoinFields[aOptions]
  $result[]

@_allJoin[aOptions]
  $result[]

@_allWhere[aOptions]
## Дополнительное выражение для where
## (выражение для полей формируется в _fieldsWhere)
  $lConds[^self._buildConditions[$aOptions]]
  $result[^if(^aOptions.contains[where] && def ^aOptions.where.trim[]){$aOptions.where}{1=1}^if(def $lConds){ AND $lConds}]

@_allHaving[aOptions]
  $result[]

@_allWindow[aOptions]
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
      ^case($lGroup is hash){$result[^lGroup.foreach[k;v]{^if(^self._fields.contains[$k]){^self.sqlFieldName[$k]^if(^v.lower[] eq "desc"){ DESC}(^v.lower[] eq "asc"){ ASC}}}[, ]]}
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
      ^case($lOrder is hash){
        $result[^lOrder.foreach[k;v]{^if(^self._fields.contains[$k]){^self.sqlFieldName[$k] ^switch[^v.lower[]]{^case[desc;-]{DESC} ^case[asc;+]{ASC}}}}[, ]]}
      ^case[DEFAULT]{$result[^lOrder.trim[]]}
    }
  }

@_allLimitOffset[aOptions]
  $result[]
  $lLimit(^aOptions.limit.int(-1))
  $lOffset(^aOptions.offset.int(-1))
  ^if($lLimit >= 0 || $lOffset >= 0){
    $result[LIMIT ^if($lLimit >=0){$lLimit}{18446744073709551615}]
    ^if($lOffset >= 0){
      $result[$result OFFSET $lOffset]
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
  $result[^self._builder.array[$aField;$aValues;^hash::create[$aOptions] $.valueFunction[$self.fieldValue]]]

@sqlFieldName[aFieldName]
  ^self.assert(^self._fields.contains[$aFieldName]){Неизвестное поле «${aFieldName}».}
  $lField[$self._fields.[$aFieldName]]

  ^if(^lField.contains[fieldExpression]
      && def $lField.fieldExpression
      && ($self.__context eq "where" || $self.__context eq "update")
  ){
    ^return[$lField.fieldExpression]
  }

  ^if(^lField.contains[expression]
    && def $lField.expression
    && !($self.__context eq "update" && ^lField.contains[dbField])
   ){
     ^if($self.__context eq "group"){
       ^return[^self._builder.quoteIdentifier[$lField.name]]
     }

     ^return[$lField.expression]
  }

  ^if(!^lField.contains[dbField]){
    ^throw[pfSQLTable.field.fail;Для поля «${aFieldName}» не задано выражение или имя в базе данных.]
  }

  ^return[^self._builder.sqlFieldName[$lField;^if($self.__context ne "update"){$self.TABLE_ALIAS}]]

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
        $lRes.[^lRes._count[]][^if(^match.2.left(1) eq "!"){NOT }^(^self.sqlFieldName[$match.1] BETWEEN ^self.fieldValue[$lField;$v.from] AND ^self.fieldValue[$lField;$v.to])]
      }(^self._fields.contains[$match.1] && $match.2 eq "is"){
        $lRes.[^lRes._count[]][^self.sqlFieldName[$match.1] IS ^if(!def $v || $v eq "null"){NULL}{NOT NULL}]
      }(^self._plurals.contains[$match.1]
        || (^self._fields.contains[$match.1] && ($match.2 eq "in" || $match.2 eq "!in"))
       ){
#       $.[field [!]in][hash|table|array[hash or string value]|values string]
#       $.[plural [not]][hash|table|array[hash or string value]|values string]
        $lRes.[^lRes._count[]][^self._condArrayField[$aConds;$match.1;^match.2.lower[];$v]]
      }($match.1 eq "OR" || $match.1 eq "AND" || $match.1 eq "NOT"){
#       Рекурсивный вызов логического блока
        $lRes.[^lRes._count[]][^self._buildConditions[$v;$match.1]]
      }(^self._fields.contains[$match.1]){
#       Операторы
#       $.[field operator][value]
        $lRes.[^lRes._count[]][^self.sqlFieldName[$match.1] ^taint[^self.ifdef[$match.2]{=}] ^self.fieldValue[$lField;$v]]
      }
    }
  }
  $result[^if($lRes){^if($aOP eq "NOT"){NOT} (^lRes.foreach[_;v]{$v}[ $self._PFSQLTABLE_LOGICAL.[$aOP] ])}]

@_condArrayField[aConds;aFieldName;aOperator;aValue]
  $lField[^if(^self._plurals.contains[$aFieldName]){$self._plurals.[$aFieldName]}{$self._fields.[$aFieldName]}]
  $lColumn[^if(^aConds.contains[${aFieldName}Column]){$aConds.[${aFieldName}Column]}{$lField.name}]
  $result[^self.sqlFieldName[$lField.name] ^if($aOperator eq "not" || $aOperator eq "!in"){NOT IN}{IN} (^self.valuesArray[$lField.name;$aValue;$.column[$lColumn]])]

@_selectExpression[aFields;aResultType;aOptions;aSQLOptions]
  $aOptions[^hash::create[$aOptions]]
  $aOptions[^aOptions.union[$self._defaultScope]]

  ^self.asContext[where]{
    $lGroup[^self._allGroup[$aOptions]]
    $lOrder[^self._allOrder[$aOptions]]
    $lHaving[^if(^aOptions.contains[having]){$aOptions.having}{^self._allHaving[$aOptions]}]
    $lWindow[^if(^aOptions.contains[window]){$aOptions.window}{^self._allWindow[$aOptions]}]
  }
  $lWith[^self._allWith[$aOptions]]
  $result[
       ^if(def ^lWith.trim[]){WITH $lWith}
       SELECT $aFields
         FROM ^if(def $self.SCHEMA){^self._builder.quoteIdentifier[$self.SCHEMA].}^self._builder.quoteIdentifier[$self.TABLE_NAME] AS ^self._builder.quoteIdentifier[$self.TABLE_ALIAS]
              ^self.asContext[where]{^if(^aOptions.contains[join]){$aOptions.join}{^self._allJoin[$aOptions]}}
        WHERE ^self.asContext[where]{^self._allWhere[$aOptions]}
      ^if(def ^lGroup.trim[]){
        GROUP BY $lGroup
      }
      ^if(def ^lHaving.trim[]){
        HAVING $lHaving
      }
      ^if(def ^lWindow.trim[]){
        WINDOW $lWindow
      }
      ^if(def ^lOrder.trim[]){
        ORDER BY $lOrder
      }
      ^self._allLimitOffset[$aOptions]
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
    ^case(^aOptions.asArray.bool(false)){array}
    ^case[DEFAULT]{$self._defaultResultType}
  }]

@__allSQLExpression[aResultType;aOptions;aSQLOptions]
  $result[^self._selectExpression[
    ^self.__allSelectFieldsExpression[$aResultType;$aOptions;$aSQLOptions]
  ][$aResultType;$aOptions;$aSQLOptions]]

@__aggregateSQLExpression[aResultType;aConds]
  $result[^self._selectExpression[
    ^self.asContext[select]{^self.__getAgrFields[$aConds.fields;$aConds.sqlOptions]}
  ][$aResultType;$aConds.options;$aConds.sqlOptions]]

@__allSelectFieldsExpression[aResultType;aOptions;aSQLOptions]
  $result[
    ^self.asContext[select]{
     ^if(def $aSQLOptions.selectOptions){$aSQLOptions.selectOptions}
     ^if(^aOptions.contains[selectFields]){
       $aOptions.selectFields
     }{
       ^if($aResultType eq "hash"){
         ^self.assert(def $self._primaryKey){Не определен первичный ключ для таблицы ${TABLE_NAME}. Выборку можно делать только в таблицу.}
#         Для хеша добавляем еще одно поле с первичным ключем
          $self.PRIMARYKEY AS ^self._builder.quoteIdentifier[_ORM_HASH_KEY_],
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
    ^switch(true){
      ^case($v is table){
        ^v.foreach[;f]{
          $result.fields.[^eval($result.fields)][$f.field]
        }
      }
      ^case($v is string){
        $result.fields.[^eval($result.fields)][$v]
      }
      ^case($v is hash){
        ^if(!def $result.options){
          $result.options[^hash::create[$v]]
        }(def $result.options && !def $result.sqlOptions){
          $result.sqlOptions[^hash::create[$v]]
        }
      }
    }
  }
  ^if(!def $result.options){$result.options[^hash::create[]]}
  ^if(!def $result.sqlOptions){$result.sqlOptions[^hash::create[]]}

@__getAgrFields[aFields;aSQLOptions]
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
        $lSplit[^lField.args.split[,;lv]]
        $lField.expr[^lSplit.menu{^lSplit.piece.match[$self._PFSQLTABLE_AGR_REGEX][]{^if($match.1 eq "*"){^self._allFields[][$aSQLOptions]}(def $match.1){^self.sqlFieldName[$match.1] AS ^self._builder.quoteIdentifier[^if(def $match.4){$match.4}{$match.1}]}}}[, ]]
        $lField.alias[]
      }

      ^if(^lField.function.lower[] eq "_groups"){
        ^if(!def ^lField.args.trim[]){
          ^continue[]
        }

        $lField.expr[^self._allFields[$.selectFieldsGroups[$lField.args]][$aSQLOptions]]
        $lField.alias[]
      }

      $result.[^result._count[]][$lField]
    }
  }

  $result[^result.foreach[_;v]{$v.expr^if(def $v.alias){ AS ^self._builder.quoteIdentifier[$v.alias]}}[, ]]

@__normalizeWhitespaces[aQuery;aOptions]
  $result[^untaint[optimized-as-is]{^untaint[sql]{$aQuery}}]

  ^if(^aOptions.apply.bool(false)){
    $result[^apply-taint[$result]]
  }

#----------------------------------------------------------------------------------------------------------------------

@CLASS
pfSQLTableScope

## Класс-копия модели с новым _defaultScope.
## Используем для вызова скоупов в pfSQLTable.

## Притворяется оригинальной моделью. Содержит в себе все поля и методы модели.
## Механизм похож на наследование. Можно переопределить методы как в наследнике,
## но для вызова «базового» класса надо писать ^__model__.method[]

@OPTIONS
locals

@create[aModel;aScope;aOptions]
## aOptions.name - имя скоупа, которое использовали в модели
  $self.__model__[$aModel]
  $self.__scope__[$aScope]
  $self.__name__[$aOptions.name]
  ^reflection:copy[$aModel;$self]
  ^reflection:mixin[$aModel]
  $self._defaultScope[$aScope]

# Делаем копии небезопасных полей и алиасов из модели
# В наследниках обязательно делайте копии хешиков и алиасов в конструкторе,
# чтобы не повредить оригинальный объект.
  $self._fields[^reflection:fields_reference[$self._fields]]
  $self._plurals[^reflection:fields_reference[$self._plurals]]
  $self._skipOnInsert[^reflection:fields_reference[$self._skipOnInsert]]
  $self._skipOnUpdate[^reflection:fields_reference[$self._skipOnUpdate]]
  $self._scopes[^reflection:fields_reference[$self._scopes]]
  ^self.alias[select;$self.aggregate]

#----------------------------------------------------------------------------------------------------------------------

@CLASS
pfSQLBuilder

@OPTIONS
locals

@BASE
pfClass

@create[aDialect;aOptions]
  ^self.cleanMethodArgument[]
  ^BASE:create[$aOptions]

  ^self.assert(def $aDialect){Не задан объект с sql-диалектом.}
  $self.dialect[$aDialect]

  $self._quote[$self.dialect.identifierQuoteMark]

  $self._now[^date::now[]]
  $self._today[^date::today[]]

@auto[]
  $self._PFSQLBUILDER_CSV_REGEX_[^regex::create[((?:\s*"(?:[^^"]*|"{2})*"\s*(?:,|^$))|\s*"[^^"]*"\s*(?:,|^$)|[^^,]+(?:,|^$)|(?:,))][g]]
  $self._PFSQLBUILDER_CSV_QTRIM_REGEX_[^regex::create["(.*)"][]]
  $self._PFSQLBUILDER_PROCESSOR_FIRST_UPPER[^regex::create[^^\s*(\pL)(.*?)^$][]]

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
  $result[${self._quote}^taint[^aIdent.trim[both;$self._quote]]${self._quote}]

@sqlFieldName[aField;aTableAlias]
  $result[^if(def $aTableAlias){${self._quote}${aTableAlias}${self._quote}.}${self._quote}^taint[$aField.dbField]${self._quote}]

@selectFields[aFields;aOptions]
## Возвращает список полей для выражения select
## aOptions.tableAlias
## aOptions.skipFields[$.field[] ...] — хеш с полями, которые надо исключить из выражения
  ^self.assert(def $aFields){Не задан список полей.}
  $aOptions[^self._processFieldsOptions[$aOptions]]
  $lTableAlias[^if(def $aOptions.tableAlias){$aOptions.tableAlias}]

  $result[^hash::create[]]
  $lFields[^hash::create[$aFields]]
  ^aFields.foreach[k;v]{
    ^if(^aOptions.skipFields.contains[$k]){^continue[]}
    ^if(^v.contains[expression]){
      $result.[^result._count[]][$v.expression AS ${self._quote}${k}${self._quote}]]
    }{
       $result.[^result._count[]][^self.sqlFieldName[$v;$lTableAlias] AS ${self._quote}${k}${self._quote}]]
     }
  }
  $result[^result.foreach[_;v]{$v}[, ]]

@fieldsList[aFields;aOptions]
## Возвращает список полей
## aOptions.tableAlias
## aOptions.skipFields[$.field[] ...] — хеш с полями, которые надо исключить из выражения
## aOptions.skipAbsent(false) — пропустить поля, данных для которых нет (нaдо обязательно задать поле aOptions.data)
## aOptions.data — хеш с данными
  ^self.assert(def $aFields){Не задан список полей.}
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
  ^self.assert(def $aFields){Не задан список полей.}
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
  ^self.assert(def $aField){Не задано описание поля.}
  $result[]
  ^try{
    ^switch[^if(def $aField.processor){^aField.processor.lower[]}]{
      ^case[null]{
        $result[^if(def $aValue){'^taint[$aValue]'}{NULL}]
      }

      ^case[int_null]{
        $result[^if(def $aValue){$lVal($aValue)^lVal.format[%d]}{NULL}]
      }

      ^case[uint_null]{
        $result[^if(def $aValue){$lVal($aValue)^lVal.format[%u]}{NULL}]
      }

      ^case[uint;auto_uint]{
        ^if(^aField.contains[default]){
          $result(^aValue.double($aField.default))
        }{
          $result(^aValue.double[])
        }
        $result[^result.format[^if(def $aField.format){$aField.format}{%u}]]
      }

      ^case[int;auto_int]{
        ^if(^aField.contains[default]){
          $result(^aValue.int($aField.default))
        }{
          $result(^aValue.int[])
        }
        $result[^result.format[^if(def $aField.format){$aField.format}{%d}]]
      }

      ^case[double_null]{
        $result[NULL]
        ^if(def $aValue){
          $result(^aValue.double[])
          $result[^result.format[^if(def $aField.format){$aField.format}{%.16g}]]
        }
      }

      ^case[double;auto_double]{
        ^if(^aField.contains[default]){
          $result(^aValue.double($aField.default))
        }{
          $result(^aValue.double[])
        }
        $result[^result.format[^if(def $aField.format){$aField.format}{%.16g}]]
      }

      ^case[bool;auto_bool]{
        $result[^if(^aValue.bool(^if(^aField.contains[default]){$aField.default}{false})){'1'}{'0'}]
      }

      ^case[now;auto_now]{
        $result[^if(def $aValue){'^if($aValue is date){^aValue.sql-string[]}{^taint[$aValue]}'}{$lNow[^date::now[]]'^lNow.sql-string[]'}]
      }

      ^case[curtime;auto_curtime]{
        $result['^if(def $aValue){^if($aValue is date){^aValue.sql-string[time]}{^taint[$aValue]}}{$lNow[^date::now[]]^lNow.sql-string[time]}']
      }

      ^case[curdate;auto_curdate]{
        $result['^if(def $aValue){^if($aValue is date){^aValue.sql-string[date]}{^taint[$aValue]}}{$lNow[^date::now[]]^lNow.sql-string[date]}']
      }

      ^case[datetime]{
        $result[^if(def $aValue){'^if($aValue is date){^aValue.sql-string[]}{^taint[$aValue]}'}{NULL}]
      }

      ^case[date]{
        $result[^if(def $aValue){'^if($aValue is date){^aValue.sql-string[date]}{^taint[$aValue]}'}{NULL}]
      }

      ^case[time]{
        $result[^if(def $aValue){'^if($aValue is date){^aValue.sql-string[time]}{^taint[$aValue]}'}{NULL}]
      }

      ^case[json]{
        $result[^if(def $aValue || $aValue is hash){'^taint[^json:string[$aValue]]'}{NULL}]
      }

      ^case[uid;auto_uid;uuid;uuid_auto]{
        $result['^taint[^if(def $aValue){$aValue}{^unsafe{^math:uuid7[$.lower(true)]}{^math:uuid[$.lower(true)]}}]']
      }

      ^case[inet_ip]{
        $result[^self.unsafe{^inet:aton[$aValue]}{NULL}]
      }

      ^case[first_upper]{
        $result['^taint[^if(def $aValue){^aValue.match[$self._PFSQLBUILDER_PROCESSOR_FIRST_UPPER][]{^match.1.upper[]$match.2}}(def $aField.default){$aField.default}]']
      }

      ^case[hash_md5]{
        $result['^taint[^if(def $aValue){^math:md5[$aValue]}]']
      }

      ^case[lower_trim]{
        $result[^aValue.lower[]]
        $result['^taint[^result.trim[both]]']
      }

      ^case[upper_trim]{
        $result[^aValue.lower[]]
        $result['^taint[^result.trim[both]]']
      }

      ^case[DEFAULT;auto_default]{
        $result['^taint[^if(def $aValue){$aValue}(def $aField.default){$aField.default}]']
      }
    }
  }{
     ^throw[pfSQLBuilder.bad.value;Ошибка при преобразовании поля ${aField.name} (processor: ^if(def $aField.processor){$aField.processor}{default}^; value type: $aValue.CLASS_NAME);[${exception.type}] ${exception.source}, ${exception.comment}.]
   }

@array[aField;aValue;aOptions]
## Строит массив значений
## aValue[table|hash|array|csv-string]
## aOptions.column[$aField.name] — имя колонки в таблице или массиве
## aOptions.emptyValue[null] — значение массива, если в aValue нет данных
## aOptions.valueFunction[fieldValue] — функция форматирования значения поля
  ^self.cleanMethodArgument[]
  $result[]
  $lValueFunction[^if(^aOptions.contains[valueFunction]){$aOptions.valueFunction}{$self.fieldValue}]
  $lEmptyValue[^if(^aOptions.contains[emptyValue]){$aOptions.emptyValue}{null}]
  $lColumn[^if(def $aOptions.column){$aOptions.column}{$aField.name}]
  ^switch(true){
    ^case($aValue is hash){
      $result[^aValue.foreach[k;]{^lValueFunction[$aField;$k]}[, ]]
    }
    ^case($aValue is table){
      $result[^aValue.menu{^lValueFunction[$aField;$aValue.[$lColumn]]}[, ]]
    }
    ^case($aValue is array){
      $result[^aValue.foreach[;v]{^if($v is hash){^lValueFunction[$aField;$v.[$lColumn]]}{^lValueFunction[$aField;$v]}}[, ]]
    }
    ^case($aValue is string){
      $lItems[^self._parseCSVString[$aValue]]
      $result[^lItems.foreach[_;v]{^lValueFunction[$aField;$v]}[, ]]
    }
    ^case[DEFAULT]{
      ^throw[pfSQLBuilder.bad.array.values;Значениями массива может быть хеш, таблица, массив или csv-строка. (Поле: $aField.name, тип значения: $aValue.CLASS_NAME)]
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
  ^self.assert(def $aTableName){Не задано имя таблицы.}
  ^self.assert(def $aFields){Не задан список полей.}
  ^self.cleanMethodArgument[aData;aOptions]
  $lOptions[^hash::create[]]
  $lOptions.ignore(^aOptions.ignore.bool(false))
  $result[^self.dialect.insertStatement[^if(def $aOptions.schema){${self._quote}${aOptions.schema}${self._quote}.}${self._quote}${aTableName}${self._quote};^self.fieldsList[$aFields;^hash::create[$aOptions] $.data[$aData]];^self.setExpression[$aFields;$aData;^hash::create[$aOptions] $.skipNames(true)];$lOptions]]

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
  ^self.assert(def $aTableName){Не задано имя таблицы.}
  ^self.assert(def $aFields){Не задан список полей.}
  ^self.assert(def $aWhere){Не задано выражение для where.}
  ^self.cleanMethodArgument[aData;aOptions]

  $lSetExpression[^self.setExpression[$aFields;$aData;$aOptions]]
  ^self.assert(def $lSetExpression || (!def $lSetExpression && def $aOptions.emptySetExpression)){Необходимо задать выражение для пустого update set.}
  $result[UPDATE ^if(def $aOptions.schema){${self._quote}${aOptions.schema}${self._quote}.}${self._quote}${aTableName}${self._quote} SET ^if(def $lSetExpression){$lSetExpression}{$aOptions.emptySetExpression} WHERE $aWhere]
