# PF2 Library

@USE
pf2/lib/common.p

@CLASS
pfSQLConnection

## Базовый класс для работы с sql-серверами.

@BASE
pfClass

@create[aConnectString;aOptions]
## aOptions.enableMemoryCache(false) - добавлять результаты выборок из БД в кеш в памяти.
## aOptions.enableQueriesLog(false) - включить логирование sql-запросов.
  ^cleanMethodArgument[]
  ^pfAssert:isTrue(def $aConnectString)[Не задана строка соединения.]

  ^BASE:create[]

  $_connectString[$aConnectString]
  $_connectionsCount(0)
  $_transactionsCount(0)

  $_serverType[^aConnectString.left(^aConnectString.pos[:])]

  $_enableMemoryCache[^aOptions.enableMemoryCache.bool(false)]
  $_memoryCache[]

  $_enableQueriesLog(^aOptions.enableQueriesLog.bool(false))
  $_stat[
    $.queriesCount(0)
    $.memoryCache[
      $.size(0)
      $.usage(0)
    ]
    $.queries[^hash::create[]]
    $.queriesTime(0)
  ]

# Регулярное вражение, которое проверят эксепшн при дублировании записей в safeInsert.
  $_duplicateKeyExceptionRegex[^regex::create[duplicate entry][i]]

@GET_connectString[]
  $result[$_connectString]

@GET_isConnected[]
  $result($_connectionsCount)

@GET_isTransaction[]
  $result($_transactionsCount)

@GET_memoryCache[]
  ^if(!def $_memoryCache){
    ^clearMemoryCache[]
  }
  $result[$_memoryCache]

@GET_serverType[]
  $result[$_serverType]

@GET_stat[]
## Возвращает статистику по запросам
  $result[$_stat]

@connect[aCode]
## Выполняет соединение с сервером и выполняет код, если оно еще не установлено.
## Выполняется автоматически при попытке отправить запрос или открыть транзакцию.
  ^if($_connectionsCount){
    $result[$aCode]
  }{
     ^MAIN:connect[$_connectString]{
       ^_connectionsCount.inc[]
       ^try{
         $result[$aCode]
       }{}{
         ^_connectionsCount.dec[]
       }
     }
   }

@transaction[aCode;aOptions][locals]
## Организует транзакцию, обеспечивая возможность отката.
## aOptions.disableQueriesLog(false) - отключить лог на время работы транзакции
  ^cleanMethodArgument[]
  $result[]
  ^self.connect{
    $lIsEnabledQueryLog($_enableQueriesLog)
    ^if(^aOptions.disableQueriesLog.bool(false)){$self._enableQueriesLog(false)}
    ^self._transactionsCount.inc(1)

    ^startTransaction[]
    ^try{
      $result[$aCode]
      ^commit[]
    }{
       ^rollback[]
    }{
       ^self._transactionsCount.dec(1)
       $self._enableQueriesLog($lIsEnabledQueryLog)
     }
  }

@startTransaction[]
## Открывает транзакцию.
  $result[]
  ^void{begin}

@commit[]
## Комитит транзакцию.
  $result[]
  ^void{commit}

@rollback[]
## Откатывает текущую транзакцию.
  $result[]
  ^void{rollback}


@table[aQuery;aSQLOptions;aOptions][locals]
## aOptions.force — отключить кеширование в памяти
## aOptions.cacheKey — ключ для кешироапния. Если не задан, то вычисляется автоматически.
  $lQuery[$aQuery]
  $lOptions[^_getOptions[$lQuery;table;$aSQLOptions;$aOptions]]
  $result[^_processMemoryCache{^_sql[table]{^table::sql{$lQuery}[$aSQLOptions]}[$lOptions]}[$lOptions]]

@hash[aQuery;aSQLOptions;aOptions][locals]
## aOptions.force — отключить кеширование в памяти
## aOptions.cacheKey — ключ для кешироапния. Если не задан, то вычисляется автоматически.
  $lQuery[$aQuery]
  $lOptions[^_getOptions[$lQuery;hash;$aSQLOptions;$aOptions]]
  $result[^_processMemoryCache{^_sql[hash]{^hash::sql{$lQuery}[$aSQLOptions]}[$lOptions]}[$lOptions]]

@file[aQuery;aSQLOptions;aOptions][locals]
## aOptions.force — отключить кеширование в памяти
## aOptions.cacheKey — ключ для кешироапния. Если не задан, то вычисляется автоматически.
  $lQuery[$aQuery]
  $lOptions[^_getOptions[$lQuery;file;$aSQLOptions;$aOptions]]
  $result[^_processMemoryCache{^_sql[file]{^file::sql{$lQuery}[$aSQLOptions]}[$lOptions]}[$lOptions]]

@string[aQuery;aSQLOptions;aOptions][locals]
## aOptions.force — отключить кеширование в памяти
## aOptions.cacheKey — ключ для кешироапния. Если не задан, то вычисляется автоматически.
  $lQuery[$aQuery]
  $lOptions[^_getOptions[$lQuery;string;$aSQLOptions;$aOptions]]
  $result[^_processMemoryCache{^_sql[string]{^string:sql{$lQuery}[$aSQLOptions]}[$lOptions]}[$lOptions]]

@double[aQuery;aSQLOptions;aOptions][locals]
## aOptions.force — отключить кеширование в памяти
## aOptions.cacheKey — ключ для кешироапния. Если не задан, то вычисляется автоматически.
  $lQuery[$aQuery]
  $lOptions[^_getOptions[$lQuery;double;$aSQLOptions;$aOptions]]
  $result(^_processMemoryCache{^_sql[double]{^double:sql{$lQuery}[$aSQLOptions]}[$lOptions]}[$lOptions])

@int[aQuery;aSQLOptions;aOptions][locals]
## aOptions.force — отключить кеширование в памяти
## aOptions.cacheKey — ключ для кешироапния. Если не задан, то вычисляется автоматически.
  $lQuery[$aQuery]
  $lOptions[^_getOptions[$lQuery;int;$aSQLOptions;$aOptions]]
  $result(^_processMemoryCache{^_sql[int]{^int:sql{$lQuery}[$aSQLOptions]}[$lOptions]}[$lOptions])

@void[aQuery;aSQLOptions;aOptions][locals]
  $lQuery[$aQuery]
  $lOptions[^_getOptions[$lQuery;int;$aSQLOptions;$aOptions]]
  $result[^_sql[void]{^void:sql{$lQuery}[$aSQLOptions]}[^hash::create[$lOptions]]]

@clearMemoryCache[]
  $_memoryCache[^hash::create[]]
  $_stat.memoryCache.size($_memoryCache)

@safeInsert[aInsertCode;aExistsCode]
## Выполняет aInsertCode, если в нем произошел exception on duplicate, то выполняет aExistsCode.
## Реализует абстракцию insert ... on duplicate key update, которая нативно реализована не во всех СУБД.
  $result[^try{$aInsertCode}{^if($exception.type eq "sql.execute" && ^exception.comment.match[$_duplicateKeyExceptionRegex][]){$exception.handled(true)$aExistsCode}}]

@_processMemoryCache[aCode;aOptions][lKey;lResult;lIsIM]
## Возвращает результат запроса из коллекции объектов.
## Если объект не найден, то выполняет запрос и добавляет его результат в коллекцию.
  $result[]
  $lIsIM($_enableMemoryCache && !^aOptions.force.bool(false))
  $lKey[^if(def $aOptions.cacheKey){$aOptions.cacheKey}{$aOptions.queryKey}]

  ^if($lIsIM && ^memoryCache.contains[$lKey]){
    $result[$memoryCache.[$lKey]]
    ^_stat.memoryCache.usage.inc[]
  }{
     $result[$aCode]
     ^if($lIsIM){
       $memoryCache.[$lKey][$result]
     }
   }
   $_stat.memoryCache.size($_memoryCache)

@_makeQueryKey[aQuery;aType;aSQLOptions]
## Формирует ключ для запроса
   $result[auto-${aType}-^math:sha1[$aQuery]]
   ^if(def $aSQLOptions.limit){$result[${result}-l$aSQLOptions.limit]}
   ^if(def $aSQLOptions.offset){$result[${result}-o$aSQLOptions.offset]}

@_getOptions[aQuery;aType;aSQLOptions;aOptions]
## Объединяет опции запроса в один хеш, и, при необходимости,
## вычисляет ключ запроса.
  ^cleanMethodArgument[]
  ^cleanMethodArgument[aSQLOptions]
  $result[^hash::create[$aOptions]]
  ^result.add[$aSQLOptions]
  $result.type[$aType]
  ^if(!$aOptions.force && $_enableMemoryCache){
    $result.queryKey[^_makeQueryKey[$aQuery;$aType;$aSQLOptions]]
  }
  ^if($_enableQueriesLog){
    $result.query[$aQuery]
  }

@_sql[aType;aCode;aOptions][locals]
## Выполняет запрос и сохраняет статистику
  ^cleanMethodArgument[]
  $lMemStart($status:memory.used)
  $lStart($status:rusage.tv_sec + $status:rusage.tv_usec/1000000.0)

  $result[^self.connect{$aCode}]

  $lEnd($status:rusage.tv_sec + $status:rusage.tv_usec/1000000.0)
  $lMemEnd($status:memory.used)

  $_stat.queriesTime($_stat.queriesTime + ($lEnd-$lStart))
  ^_stat.queriesCount.inc[]
  ^if($_enableQueriesLog){
    $_stat.queries.[^_stat.queries._count[]][
      $.type[$aType]
      $.query[^taint[$aOptions.query]]
      $.time($lEnd-$lStart)
      $.limit[$aOptions.limit]
      $.offset[$aOptions.offset]
      $.memory($lMemEnd - $lMemStart)
      $.results(^switch[$aType]{
        ^case[DEFAULT;void]{0}
        ^case[int;double;string;file]{1}
        ^case[table;hash]{^eval($result)}
      })
    ]
  }
