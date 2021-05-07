# PF2 Library

@USE
pf2/lib/common.p

@CLASS
pfSQLConnection

@OPTIONS
locals

## Базовый класс для работы с sql-серверами.

@BASE
pfClass

@create[aConnectString;aOptions]
## aOptions.dialect — «диалект» для СУБД. Если не задан, определяем по типу сервера.
## aOptions.enableMemoryCache(false) — добавлять результаты выборок из БД в кеш в памяти.
## aOptions.enableQueriesLog(false) — включить логирование sql-запросов.
## aOptions.nestedAsSavepoints(false) — объединить вложенные транзакции в сейвпоинты.
  ^self.cleanMethodArgument[]
  ^self.assert(def $aConnectString)[Не задана строка соединения. не задано регулярное выражение для поиска дублирования ключей]

  ^BASE:create[]
  $self.serverType[^aConnectString.left(^aConnectString.pos[:])]

  $self._connectString[$aConnectString]
  $self._connectionsCount(0)
  $self._transactionsCount(0)

  $self.dialect[$aOptions.dialect]
  ^if(!def $self.dialect){
    $self.dialect[^switch[$self.serverType]{
      ^case[mysql]{^pfSQLMySQLDialect::create[]}
      ^case[pgsql]{^pfSQLPostgresDialect::create[]}
      ^case[postgresql]{^pfSQLPostgresDialect::create[]}
      ^case[sqlite]{^pfSQLSQLiteDialect::create[]}
      ^case[DEFAULT]{^pfSQLAnsiDialect::create[]}
    }]
  }

  $self._enableMemoryCache[^aOptions.enableMemoryCache.bool(false)]
  $self._memoryCache[]

  $self._enableQueriesLog(^aOptions.enableQueriesLog.bool(false))
  $self._stat[
    $.queriesCount(0)
    $.memoryCache[
      $.size(0)
      $.usage(0)
    ]
    $.queries[^hash::create[]]
    $.queriesTime(0)
  ]

  $self._nestedAsSavepoints(^aOptions.nestedAsSavepoints.bool(false))

@GET_connectString[]
  $result[$self._connectString]

@GET_isConnected[]
  $result($self._connectionsCount)

@GET_isTransaction[]
  $result($self._transactionsCount)

@GET_memoryCache[]
  ^if(!def $self._memoryCache){
    ^self.clearMemoryCache[]
  }
  $result[$self._memoryCache]

@GET_stat[]
## Возвращает статистику по запросам
  $result[$self._stat]

@connect[aCode]
## Выполняет соединение с сервером и выполняет код, если оно еще не установлено.
## Выполняется автоматически при попытке отправить запрос или открыть транзакцию.
  ^if($self._connectionsCount){
    $result[$aCode]
  }{
     ^connect[$self._connectString]{
       ^self._connectionsCount.inc[]
       ^try{
         $result[$aCode]
       }{}{
         ^self._connectionsCount.dec[]
       }
     }
   }

@transaction[aArg1;aArg2;aArg3]
## Организует транзакцию, обеспечивая возможность отката.
## ^transaction{aCode}
## ^transaction{aCode}[aOptions]
## ^transaction[aModes]{aCode}[aOptions]
## aOptions.disableQueriesLog(false) — отключить лог на время транзакции
## aOptions.disableMemoryCache(false) — отелючить кеш в памяти на время транзакции
## aOptions.nestedAsSavepoints(false) — заменить вложенные транзакции на сейвпоинты
  $result[]

  ^if(^reflection:is[aArg1;code]){
    $aCode{$aArg1}
    $aOptions[^hash::create[$aArg2]]
  }{
    $aModes[$aArg1]
    $aCode{$aArg2}
    $aOptions[^hash::create[$aArg3]]
  }

  ^self.connect{
    $lEnableQueriesLog($self._enableQueriesLog)
    ^if(^aOptions.disableQueriesLog.bool(false)){$self._enableQueriesLog(false)}

    $lEnableMemoryCache($self._enableMemoryCache)
    ^if(^aOptions.disableMemoryCache.bool(false)){$self._enableMemoryCache(false)}
    ^self._transactionsCount.inc(1)

    $lOldNestedAsSavepoints($self._nestedAsSavepoints)
    $self._nestedAsSavepoints(^aOptions.nestedAsSavepoints.bool($self._nestedAsSavepoints))

    ^try{
      ^if($self._transactionsCount > 1){
##      Объединяем вложенные транзакции
        ^if($self._nestedAsSavepoints){
          ^self.savepoint{
            $result[$aCode]
          }
        }{
          $result[$aCode]
        }
      }{
        ^self.begin[$aModes]
        ^try{
          $result[$aCode]
          ^self.commit[]
        }{
           ^self.rollback[]
        }
      }
    }{}{
      ^self._transactionsCount.dec(1)
      $self._enableQueriesLog($lEnableQueriesLog)
      $self._enableMemoryCache($lEnableMemoryCache)
      $self._nestedAsSavepoints($lOldNestedAsSavepoints)
    }
  }

@savepoint[aNameOrCode;aCode]
## Делает сейвпоинт
## ^savepoint[name] — выдает команду savepoint name
## ^savepoint{code} — выполняет код внутри savepoint. Имя для сейвпоинта формируется автоматически.
## ^savepoint[name]{code} — выполняет код внутри сейвпоинта name
  $result[]
  ^if(^reflection:is[aNameOrCode;code]){
    $lSavepointName[AUTO_SAVEPOINT_^math:uid64[]]
    $lSavepointCode{$aNameOrCode}
    $lHasCode(true)
  }($aNameOrCode is string){
    $lSavepointName[$aNameOrCode]
    ^if(^reflection:is[aCode;code]){
      $lSavepointCode{$aCode}
      $lHasCode(true)
    }
  }{
    ^throw[pf.sql.connetction;Методу pfSQLConnection.savepoint надо передать один или два параметра.]
  }

  ^self.connect{
    ^if($lHasCode){
      ^self.void{^self.dialect.savepoint[$lSavepointName]}
      ^try{
        $result[$lSavepointCode]
        ^self.release[$lSavepointName]
      }{
         ^self.rollback[$lSavepointName]
       }
    }{
       ^self.void{^self.dialect.savepoint[$lSavepointName]}
     }
  }

@begin[aModes]
## Открывает транзакцию.
  $result[]
  ^self.void{^self.dialect.begin[$aModes]}

@commit[]
## Комитит транзакцию.
  $result[]
  ^self.void{^self.dialect.commit[]}

@rollback[aSavePoint]
## Откатывает текущую транзакцию или сейвпоинт.
  $result[]
  ^self.void{^self.dialect.rollback[$aSavePoint]}

@release[aSavePoint]
## Освобождает сейвпоинт.
  $result[]
  ^self.void{^self.dialect.release[$aSavePoint]}

@table[aQuery;aSQLOptions;aOptions]
## aOptions.force — отключить кеширование в памяти
## aOptions.cacheKey — ключ для кеширования. Если не задан, то вычисляется автоматически.
## aOptions.log[] — запись, которую надо сделать в логе вместо текста запроса.
  $lQuery[$aQuery]
  $lOptions[^self._getOptions[$lQuery;table;$aSQLOptions;$aOptions]]
  $result[^self._processMemoryCache{^self._sql[table]{^table::sql{$lQuery}[$aSQLOptions]}[$lOptions]}[$lOptions]]

@hash[aQuery;aSQLOptions;aOptions]
## aOptions.force — отключить кеширование в памяти
## aOptions.cacheKey — ключ для кеширования. Если не задан, то вычисляется автоматически.
## aOptions.log[] — запись, которую надо сделать в логе вместо текста запроса.
  $lQuery[$aQuery]
  $lOptions[^self._getOptions[$lQuery;hash;$aSQLOptions;$aOptions]]
  $result[^self._processMemoryCache{^self._sql[hash]{^hash::sql{$lQuery}[$aSQLOptions]}[$lOptions]}[$lOptions]]

@file[aQuery;aSQLOptions;aOptions]
## aOptions.force — отключить кеширование в памяти
## aOptions.cacheKey — ключ для кеширования. Если не задан, то вычисляется автоматически.
## aOptions.log[] — запись, которую надо сделать в логе вместо текста запроса.
  $lQuery[$aQuery]
  $lOptions[^self._getOptions[$lQuery;file;$aSQLOptions;$aOptions]]
  $result[^self._processMemoryCache{^self._sql[file]{^file::sql{$lQuery}[$aSQLOptions]}[$lOptions]}[$lOptions]]

@string[aQuery;aSQLOptions;aOptions]
## aOptions.force — отключить кеширование в памяти
## aOptions.cacheKey — ключ для кеширования. Если не задан, то вычисляется автоматически.
## aOptions.log[] — запись, которую надо сделать в логе вместо текста запроса.
  $lQuery[$aQuery]
  $lOptions[^self._getOptions[$lQuery;string;$aSQLOptions;$aOptions]]
  $result[^self._processMemoryCache{^self._sql[string]{^string:sql{$lQuery}[$aSQLOptions]}[$lOptions]}[$lOptions]]

@double[aQuery;aSQLOptions;aOptions]
## aOptions.force — отключить кеширование в памяти
## aOptions.cacheKey — ключ для кеширования. Если не задан, то вычисляется автоматически.
## aOptions.log[] — запись, которую надо сделать в логе вместо текста запроса.
  $lQuery[$aQuery]
  $lOptions[^self._getOptions[$lQuery;double;$aSQLOptions;$aOptions]]
  $result(^self._processMemoryCache{^self._sql[double]{^double:sql{$lQuery}[$aSQLOptions]}[$lOptions]}[$lOptions])

@int[aQuery;aSQLOptions;aOptions]
## aOptions.force — отключить кеширование в памяти
## aOptions.cacheKey — ключ для кеширования. Если не задан, то вычисляется автоматически.
## aOptions.log[] — запись, которую надо сделать в логе вместо текста запроса.
  $lQuery[$aQuery]
  $lOptions[^self._getOptions[$lQuery;int;$aSQLOptions;$aOptions]]
  $result(^self._processMemoryCache{^self._sql[int]{^int:sql{$lQuery}[$aSQLOptions]}[$lOptions]}[$lOptions])

@void[aQuery;aSQLOptions;aOptions]
## aOptions.log[] — запись, которую надо сделать в логе вместо текста запроса.
  $lQuery[$aQuery]
  $lOptions[^self._getOptions[$lQuery;int;$aSQLOptions;$aOptions]]
  $result[^self._sql[void]{^void:sql{$lQuery}[$aSQLOptions]}[^hash::create[$lOptions]]]

@clearMemoryCache[]
  $self._memoryCache[^hash::create[]]
  $self._stat.memoryCache.size($self._memoryCache)

@safeInsert[aInsertCode;aExistsCode]
## Выполняет aInsertCode, если в нем произошел exception on duplicate, то выполняет aExistsCode.
## Реализует абстракцию insert ... on duplicate key update, которая нативно реализована не во всех СУБД.
  ^self.assert(def $self.dialect.duplicateKeyExceptionRegex)[В диалекте не задано регулярное выражение для поиска дублирования ключей]
  $result[^try{^self.transaction{^self.savepoint{$aInsertCode}}}{^if($exception.type eq "sql.execute" && ^exception.comment.match[$self.dialect.duplicateKeyExceptionRegex][]){$exception.handled(true)$aExistsCode}}]

@lastInsertID[aOptions]
## Возвращает идентификатор последней вставленной записи.
## Способ получения зависит от типа сервера.
  $result[]
  $lQuery[^self.dialect.lastInsertID[$aOptions]]
  ^if(def $lQuery){
    $result[^self.string{$lQuery}[$.limit(1)][$.force(true)]]
  }

@_processMemoryCache[aCode;aOptions]
## Возвращает результат запроса из коллекции объектов.
## Если объект не найден, то выполняет запрос и добавляет его результат в коллекцию.
  $result[]
  $lIsIM($self._enableMemoryCache && !^aOptions.force.bool(false))
  $lKey[^if(def $aOptions.cacheKey){$aOptions.cacheKey}{$aOptions.queryKey}]

  ^if($lIsIM && ^self.memoryCache.contains[$lKey]){
    $result[$self.memoryCache.[$lKey]]
    ^_stat.memoryCache.usage.inc[]
  }{
     $result[$aCode]
     ^if($lIsIM){
       $self.memoryCache.[$lKey][$result]
     }
   }
   $self._stat.memoryCache.size($self._memoryCache)

@_makeQueryKey[aQuery;aType;aSQLOptions]
## Формирует ключ для запроса
   $result[auto-${aType}-^math:sha1[^taint[as-is][$aQuery]]]
   ^if(def $aSQLOptions.limit){$result[${result}-l$aSQLOptions.limit]}
   ^if(def $aSQLOptions.offset){$result[${result}-o$aSQLOptions.offset]}

@_getOptions[aQuery;aType;aSQLOptions;aOptions]
## Объединяет опции запроса в один хеш, и, при необходимости,
## вычисляет ключ запроса.
  ^self.cleanMethodArgument[]
  ^self.cleanMethodArgument[aSQLOptions]
  $result[^hash::create[$aOptions]]
  ^result.add[$aSQLOptions]
  $result.type[$aType]
  ^if(!$aOptions.force && $self._enableMemoryCache){
    $result.queryKey[^self._makeQueryKey[$aQuery;$aType;$aSQLOptions]]
  }
  ^if($self._enableQueriesLog){
    $result.query[$aQuery]
  }

@_sql[aType;aCode;aOptions]
## Выполняет запрос и сохраняет статистику
  ^self.cleanMethodArgument[]
  $lMemStart($status:memory.used)
  $lStart($status:rusage.tv_sec + $status:rusage.tv_usec/1000000.0)

  ^try{
    $result[^self.connect{$aCode}]
  }{
    $lException[$exception]
  }{
    $lEnd($status:rusage.tv_sec + $status:rusage.tv_usec/1000000.0)
    $lMemEnd($status:memory.used)

    $self._stat.queriesTime($self._stat.queriesTime + ($lEnd-$lStart))
    ^_stat.queriesCount.inc[]
    ^if($self._enableQueriesLog){
      $self._stat.queries.[^_stat.queries._count[]][
        $.type[$aType]
        $.query[^taint[^ifdef[$aOptions.log]{^self.connect{^apply-taint[sql][$aOptions.query]}}]]
        $.time($lEnd-$lStart)
        $.limit[$aOptions.limit]
        $.offset[$aOptions.offset]
        $.memory($lMemEnd - $lMemStart)
        $.results(^switch[$aType]{
          ^case[DEFAULT;void]{0}
          ^case[int;double;string;file]{1}
          ^case[table;hash]{^eval($result)}
        })
        $.exception[$lException]
      ]
    }
  }

#----------------------------------------------------------------------------------------------------------------------

@CLASS
pfSQLAnsiDialect

## Базовый класс с диалектом ANSI SQL
## В «диалекты» выносим команды и переменные специфичные для СУБД.

@OPTIONS
locals

@BASE
pfClass

@create[aOptions]
  ^BASE:create[]

  $self.name[ANSI]
  $self.identifierQuoteMark["]

# Регулярное вражение для проверки исключения в pfSQLConnection.safeInsert.
  $self.duplicateKeyExceptionRegex[]

@quoteIdentifier[aIdentifier]
  $result[${self.identifierQuoteMark}${aIdentifier}${self.identifierQuoteMark}]

@begin[aModes]
  $result[START TRANSACTION^if(def $aModes){ ^taint[$aModes]}]

@commit[]
  $result[COMMIT]

@rollback[aName]
  $result[ROLLBACK^if(def $aName){ TO SAVEPOINT ^taint[$aName]}]

@savepoint[aName]
  $result[SAVEPOINT ^taint[$aName]]

@release[aName]
  $result[RELEASE SAVEPOINT ^taint[$aName]]

@lastInsertID[aOptions]
  ^pfAssert:fail[Method not implemented.]

@insertStatement[aRelName;aColumnsExp;aValuesExp;aOptions]
  $result[INSERT INTO $aRelName ($aColumnsExp) VALUES ($aValuesExp)]

#----------------------------------------------------------------------------------------------------------------------

@CLASS
pfSQLPostgresDialect

## Диалект Postgres

@OPTIONS
locals

@BASE
pfSQLAnsiDialect

@create[aOptions]
  ^BASE:create[$aOptions]

  $self.name[Postgres]
  $self.duplicateKeyExceptionRegex[^regex::create[(?:duplicate key value|повторяющееся значение ключа)][i]]

@lastInsertID[aOptions]
  $result[SELECT LASTVAL()]

@insertStatement[aRelName;aColumnsExp;aValuesExp;aOptions]
## aOptions.ignore(false) — не вставлять при дублировании строк
  ^if(^aOptions.ignore.bool(false)){
    $lTail[ON CONFLICT DO NOTHING]
  }
  $result[INSERT INTO $aRelName ($aColumnsExp) VALUES ($aValuesExp)^if(def $lTail){ $lTail}]

#----------------------------------------------------------------------------------------------------------------------

@CLASS
pfSQLMySQLDialect

## Диалект MySQL

@OPTIONS
locals

@BASE
pfSQLAnsiDialect

@create[aOptions]
## aOptions.ansiQuotes(false) — использовать даойные кавычки для идентификаторов.
  ^BASE:create[$aOptions]

  $self.name[MySQL]
  $self.identifierQuoteMark[^if(^aOptions.ansiQuotes.bool(false)){"}{`}]
  $self.duplicateKeyExceptionRegex[^regex::create[duplicate entry][i]]

@lastInsertID[aOptions]
  $result[SELECT LAST_INSERT_ID()]

@insertStatement[aRelName;aColumnsExp;aValuesExp;aOptions]
## aOptions.ignore(false) — не вставлять при дублировании строк
  ^if(^aOptions.ignore.bool(false)){
    $lOption[IGNORE]
  }
  $result[INSERT ^if(def $lOption){ $lOption}INTO $aRelName ($aColumnsExp) VALUES ($aValuesExp)]

#----------------------------------------------------------------------------------------------------------------------

@CLASS
pfSQLSQLiteDialect

## Диалект SQLite

@OPTIONS
locals

@BASE
pfSQLAnsiDialect

@create[aOptions]
  ^BASE:create[$aOptions]

  $self.name[SQLite]
  $self.duplicateKeyExceptionRegex[^regex::create[SQL logic error][i]]

@lastInsertID[aOptions]
  $result[SELECT LAST_INSERT_ROWID()]

@begin[aModes]
  $result[BEGIN^if(def $aModes){ ^taint[$aModes]} TRANSACTION]

@insertStatement[aRelName;aColumnsExp;aValuesExp;aOptions]
## aOptions.ignore(false) — не вставлять при дублировании строк
  ^if(^aOptions.ignore.bool(false)){
    $lOption[OR IGNORE]
  }
  $result[INSERT ^if(def $lOption){ $lOption}INTO $aRelName ($aColumnsExp) VALUES ($aValuesExp)]
