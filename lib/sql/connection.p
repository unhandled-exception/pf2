# PF2 Library

@USE
pf2/lib/common.p

@CLASS
pfSQLConnection

## Базовый класс для работы с sql-серверами.

@BASE
pfClass

@create[aConnectString;aOptions]
## aOptions.cache - объект класса pfCache (если не найден, то используем базовый класс)
## aOptions.isCaching(false) - принудительно включить кеширование для всех запросов
## aOptions.cacheLifetime(60) - время кеширования в секундах
## aOptions.cacheDir[] - путь к папке с кешем (если не передали объект cache)
## aOptions.cacheKeyPrefix[sql/] - префикс для ключа кеширования
## aOptions.isNatural(false) - выполнять транзакции средствами SQL-сервера (режим "натуральной транзакции").
## aOptions.isNaturalTransactions(false) - deprecated (алиас для isNatural).
## aOptions.enableIdentityMap(false) - включить добавление результатов запросов в коллекцию объектов.
## aOptions.enableQueriesLog(false) - включить логирование sql-запросов.

  ^cleanMethodArgument[]
  ^pfAssert:isTrue(def $aConnectString)[Не задана строка соединения.]

  ^BASE:create[]

  $_connectString[$aConnectString]
  $_transactionsCount(0)

  $_serverType[^aConnectString.left(^aConnectString.pos[:])]

  $isCaching(^if(def $aOptions.isCaching){$aOptions.isCaching}{0})
  ^if(def $aOptions.cache){
    ^if($aOptions.cache is pfCache){
      $_CACHE[$aOptions.cache]
    }{
       ^throw[pfSQL.create;Cache must be child of pfCache.]
     }
  }

  $_cacheDir[$aOptions.cacheDir]
  $_cacheLifetime(^aOptions.cacheLifetime.int(60))
  $_cacheKeyPrefix[^if(def $aOptions.cacheKeyPrefix){$aOptions.cacheKeyPrefix}{sql/}]

  $_isNaturalTransactions[^if(^aOptions.contains[isNatural]){^aOptions.isNatural.bool(false)}{^aOptions.isNaturalTransactions.bool(false)}]

  $_enableIdentityMap[^aOptions.enableIdentityMap.bool(false)]
  $_identityMap[]

  $_enableQueriesLog(^aOptions.enableQueriesLog.bool(false))
  $_stat[
    $.queriesCount(0)
    $.identityMap[
      $.size(0)
      $.usage(0)
    ]
    $.queries[^hash::create[]]
    $.queriesTime(0)
  ]

# Регулярное вражение, которое проверят эксепшн при дублировании записейв safeInsert.
  $_duplicateKeyExceptionRegex[^regex::create[duplicate entry][i]]

#----- Properties -----
@GET_connectString[]
  $result[$_connectString]

@GET_identityMap[]
  ^if(!def $_identityMap){
    ^clearIdentityMap[]
  }
  $result[$_identityMap]

@GET_CACHE[]
  ^if(!def $_CACHE){
     ^use[pf/cache/pfCache.p]
     $_CACHE[^pfCache::create[
       $.cacheDir[$_cacheDir]
     ]]
  }
  $result[$_CACHE]

@GET_transactionsCount[]
  $result($_transactionsCount)

@GET_isTransaction[]
## Возвращает true, если идет  транзакция.
  $result($_transactionsCount > 0)

@GET_serverType[]
  $result[$_serverType]

@GET_isNaturalTransactions[]
## Возвращает true, если включен резим "натуральной транзакции".
  $result($_isNaturalTransactions)

@GET_stat[]
## Возвращает статистику по запросам
  $result[$_stat]

@transaction[aCode;aOptions][lQL]
## Организует транзакцию, обеспечивая возможность отката.
## aOptions.isNatural - принудительно устанавливает режим "натуральной транзакции".
## aOptions.disableQueriesLog(false) - отключить лог на время работы транзакции
  ^cleanMethodArgument[]
  $result[]
  ^connect[$connectString]{
    ^try{
      $lQL($_enableQueriesLog)
      ^if(^aOptions.disableQueriesLog.bool(false)){$_enableQueriesLog(false)}
      ^_transactionsCount.inc(1)
      ^setServerEnvironment[]
      ^if($_transactionsCount == 1 && ($isNaturalTransactions || $aOptions.isNatural)){
        ^startTransaction[$.isNatural(true)]
        $result[$aCode]
        ^commit[$.isNatural(true)]
      }{
         $result[$aCode]
       }
    }{
       ^rollback[]
    }{
       ^_transactionsCount.dec(1)
       $_enableQueriesLog($lQL)
     }
  }

@naturalTransaction[aCode;aOptions]
## Принудительно вызывает "натуральную транзацию". Алиас на transaction.
  $result[^transaction{$aCode}[^hash::create[$aOptions] $.isNatural(true)]]

@rollback[]
## Откатывает текущую транзакцию.
  $result[]
  ^if($isTransaction && $isNaturalTransactions){
    ^void{rollback}
  }

@startTransaction[aOptions]
## Открывает транзакцию.
## aOptions.isNatural
  $result[]
  ^void{start transaction}

@commit[aOptions]
## Комитит транзакцию.
## aOptions.isNatural
  $result[]
  ^void{commit}

@setServerEnvironment[]
## Устанавливает переменные окружения сервера.
## Вызывается перед транзакцией

@table[aQuery;aSQLOptions;aOptions][lQuery;lOptions]
  $lQuery[$aQuery]
  $lOptions[^_getOptions[$lQuery;table;$aSQLOptions;$aOptions]]
  $result[^_processIdentityMap{^_sql[table]{^table::sql{$lQuery}[$aSQLOptions]}[$lOptions]}[$lOptions]]

@hash[aQuery;aSQLOptions;aOptions][lQuery;lOptions]
  $lQuery[$aQuery]
  $lOptions[^_getOptions[$lQuery;hash;$aSQLOptions;$aOptions]]
  $result[^_processIdentityMap{^_sql[hash]{^hash::sql{$lQuery}[$aSQLOptions]}[$lOptions]}[$lOptions]]

@file[aQuery;aSQLOptions;aOptions][lQuery;lOptions]
  $lQuery[$aQuery]
  $lOptions[^_getOptions[$lQuery;file;$aSQLOptions;$aOptions]]
  $result[^_processIdentityMap{^_sql[file]{^file::sql{$lQuery}[$aSQLOptions]}[$lOptions]}[$lOptions]]

@string[aQuery;aSQLOptions;aOptions][lQuery;lOptions]
  $lQuery[$aQuery]
  $lOptions[^_getOptions[$lQuery;string;$aSQLOptions;$aOptions]]
  $result[^_processIdentityMap{^_sql[string]{^string:sql{$lQuery}[$aSQLOptions]}[$lOptions]}[$lOptions]]

@double[aQuery;aSQLOptions;aOptions][lQuery;lOptions]
  $lQuery[$aQuery]
  $lOptions[^_getOptions[$lQuery;double;$aSQLOptions;$aOptions]]
  $result(^_processIdentityMap{^_sql[double]{^double:sql{$lQuery}[$aSQLOptions]}[$lOptions]}[$lOptions])

@int[aQuery;aSQLOptions;aOptions][lQuery;lOptions]
  $lQuery[$aQuery]
  $lOptions[^_getOptions[$lQuery;int;$aSQLOptions;$aOptions]]
  $result(^_processIdentityMap{^_sql[int]{^int:sql{$lQuery}[$aSQLOptions]}[$lOptions]}[$lOptions])

@void[aQuery;aSQLOptions;aOptions][lQuery;lOptions]
  $lQuery[$aQuery]
  $lOptions[^_getOptions[$lQuery;int;$aSQLOptions;$aOptions]]
  $result[^_sql[void]{^void:sql{$lQuery}[$aSQLOptions]}[^hash::create[$lOptions] $.isForce(true)]]

@clearIdentityMap[]
  $_identityMap[^hash::create[]]
  $_stat.identityMap.size($_identityMap)

@safeInsert[aInsertCode;aExistsCode]
## Выполняет aInsertCode, если в нем произошел exception on duplicate, то выполняет aExistsCode.
## Реализует абстракцию insert ... on duplicate key update, которая нативно реализована не во всех СУБД.
  $result[^try{$aInsertCode}{^if($exception.type eq "sql.execute" && ^exception.comment.match[$_duplicateKeyExceptionRegex][]){$exception.handled(true)$aExistsCode}}]

@_processIdentityMap[aCode;aOptions][lKey;lResult;lIsIM]
## Возвращает результат запроса из коллекции объектов.
## Если объект не найден, то запускает запрос и добавляет его результат в коллекцию.
## aOptions.isForce(false) - принудительно отменяет кеширование
## aOptions.identityMapKey[] - ключ для коллекции (по-умолчанию MD5 на aQuery).
  $result[]
  $lIsIM($_enableIdentityMap && !^aOptions.isForce.bool(false))
  $lKey[^if(def $aOptions.identityMapKey){$aOptions.identityMapKey}{$aOptions.queryKey}]

  ^if($lIsIM && ^identityMap.contains[$lKey]){
    $result[$identityMap.[$lKey]]
    ^_stat.identityMap.usage.inc[]
  }{
     $result[$aCode]
     ^if($lIsIM){
       $identityMap.[$lKey][$result]
     }
   }
   $_stat.identityMap.size($_identityMap)

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
  ^if(!$aOptions.isForce && ($_enableIdentityMap || $isCaching)){
    $result.queryKey[^_makeQueryKey[$aQuery;$aType;$aSQLOptions]]
  }
  ^if($_enableQueriesLog){
    $result.query[$aQuery]
  }

@_sql[aType;aCode;aOptions][lResult;lCacheKey]
## Возвращает результат запроса. Если нужно оранизует транзакцию.
## aOptions.isCaching(false) - принудительно включает кеширование
## aOptions.isForce(false) - принудительно отменяет кеширование (если оно включено глобально)
## aOptions.cacheKey[] - ключ кеширования
## aOptions.cacheTime[секунды|дата окончания]
## aOptions.queryKey
  ^cleanMethodArgument[]
  ^if(($isCaching || $aOptions.isCaching)
      && (def $aOptions.cacheKey || def $aOptions.queryKey)
      && !^aOptions.isForce.bool(false)){
    ^if(!def $aOptions.cacheTime){$aOptions.cacheTime[$_cacheLifetime]}
    $lCacheKey[^if(def $aOptions.cacheKey){$aOptions.cacheKey}{$aOptions.queryKey}]
    $result[^CACHE.data[${_cacheKeyPrefix}$lCacheKey][$aOptions.cacheTime][$aType]{^if($isTransaction){^_exec[$aType]{$aCode}[$aOptions]}{^transaction{^_exec[$aType]{$aCode}[$aOptions]}}}]
  }{
     $result[^if($isTransaction){^_exec[$aType]{$aCode}[$aOptions]}{^transaction{^_exec[$aType]{$aCode}[$aOptions]}}]
   }

@_exec[aType;aCode;aOptions][lStart;lEnd;lMemStart;lMemEnd]
## Выполняет sql-запрос.
  $lMemStart($status:memory.used)
  $lStart($status:rusage.tv_sec + $status:rusage.tv_usec/1000000.0)
  $result[$aCode]
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
