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
## aOptions.enableMemoryCache(false) — добавлять результаты выборок из БД в кеш в памяти.
## aOptions.enableQueriesLog(false) — включить логирование sql-запросов.
## aOptions.nestedAsSavepoints(false) — объединить вложенные транзакции в сейвпоинты.
  ^self.cleanMethodArgument[]
  ^pfAssert:isTrue(def $aConnectString)[Не задана строка соединения.]

  ^BASE:create[]

  $self._connectString[$aConnectString]
  $self._connectionsCount(0)
  $self._transactionsCount(0)

  $self._serverType[^aConnectString.left(^aConnectString.pos[:])]

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

# Регулярное вражение, которое проверят эксепшн при дублировании записей в safeInsert.
  $self._duplicateKeyExceptionRegex[^switch[$self._serverType]{
    ^case[sqlite]{^regex::create[SQL logic error][i]}
    ^case[pgsql]{^regex::create[duplicate key value][i]}
    ^case[DEFAULT]{^regex::create[duplicate entry][i]}
  }]

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

@GET_serverType[]
  $result[$self._serverType]

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

@transaction[aCode;aOptions]
## Организует транзакцию, обеспечивая возможность отката.
## aOptions.disableQueriesLog(false) — отключить лог на время работы транзакции
## aOptions.nestedAsSavepoints(false) — заменить вложенные транзакции на сейвпоинты
  ^self.cleanMethodArgument[]
  $result[]
  ^self.connect{
    $lIsEnabledQueryLog($self._enableQueriesLog)
    ^if(^aOptions.disableQueriesLog.bool(false)){$self._enableQueriesLog(false)}
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
        ^self.begin[]
        ^try{
          $result[$aCode]
          ^self.commit[]
        }{
           ^self.rollback[]
        }
      }
    }{}{
      ^self._transactionsCount.dec(1)
      $self._enableQueriesLog($lIsEnabledQueryLog)
      $self._nestedAsSavepoints($lOldNestedAsSavepoints)
    }
  }

@savepoint[aNameOrCode;aCode]
## Делает сейвпоинт
## ^savepoint[name] — выдает команду savepoint name
## ^savepoint{code} — выполняет код внутри savepoint. Имя для сейвпоинта формируется автоматически.
## ^savepoint[name]{code} — выполняет код внутри сейвпоинта name
  $result[]
  ^if(^reflection:is[aNameOrCode;junction]){
    $lSavepointName[AUTO_SAVEPOINT_^math:uid64[]]
    $lSavepointCode{$aNameOrCode}
    $lHasCode(true)
  }($aNameOrCode is string){
    $lSavepointName[$aNameOrCode]
    ^if(^reflection:is[aCode;junction]){
      $lSavepointCode{$aCode}
      $lHasCode(true)
    }
  }{
    ^throw[pf.sql.connetction;Методу pfSQLConnection.savepoint надо передать один или два параметра.]
  }

  ^self.connect{
    ^if($lHasCode){
      ^self.void{savepoint ^taint[$lSavepointName]}
      ^try{
        $result[$lSavepointCode]
        ^self.release[$lSavepointName]
      }{
         ^self.rollback[$lSavepointName]
       }
    }{
       ^self.void{savepoint ^taint[$lSavepointName]}
     }
  }

@begin[]
## Открывает транзакцию.
  $result[]
  ^self.void{begin}

@commit[]
## Комитит транзакцию.
  $result[]
  ^self.void{commit}

@rollback[aSavePoint]
## Откатывает текущую транзакцию или сейвпоинт.
  $result[]
  ^self.void{rollback^if(def $aSavePoint){ to ^taint[$aSavePoint]}}

@release[aSavePoint]
## Освобождает сейвпоинт.
  $result[]
  ^self.void{release savepoint ^taint[$aSavePoint]}

@table[aQuery;aSQLOptions;aOptions]
## aOptions.force — отключить кеширование в памяти
## aOptions.cacheKey — ключ для кешироапния. Если не задан, то вычисляется автоматически.
## aOptions.log[] — запись, которую надо сделать в логе вместо текста запроса.
  $lQuery[$aQuery]
  $lOptions[^self._getOptions[$lQuery;table;$aSQLOptions;$aOptions]]
  $result[^self._processMemoryCache{^self._sql[table]{^table::sql{$lQuery}[$aSQLOptions]}[$lOptions]}[$lOptions]]

@hash[aQuery;aSQLOptions;aOptions]
## aOptions.force — отключить кеширование в памяти
## aOptions.cacheKey — ключ для кешироапния. Если не задан, то вычисляется автоматически.
## aOptions.log[] — запись, которую надо сделать в логе вместо текста запроса.
  $lQuery[$aQuery]
  $lOptions[^self._getOptions[$lQuery;hash;$aSQLOptions;$aOptions]]
  $result[^self._processMemoryCache{^self._sql[hash]{^hash::sql{$lQuery}[$aSQLOptions]}[$lOptions]}[$lOptions]]

@file[aQuery;aSQLOptions;aOptions]
## aOptions.force — отключить кеширование в памяти
## aOptions.cacheKey — ключ для кешироапния. Если не задан, то вычисляется автоматически.
## aOptions.log[] — запись, которую надо сделать в логе вместо текста запроса.
  $lQuery[$aQuery]
  $lOptions[^self._getOptions[$lQuery;file;$aSQLOptions;$aOptions]]
  $result[^self._processMemoryCache{^self._sql[file]{^file::sql{$lQuery}[$aSQLOptions]}[$lOptions]}[$lOptions]]

@string[aQuery;aSQLOptions;aOptions]
## aOptions.force — отключить кеширование в памяти
## aOptions.cacheKey — ключ для кешироапния. Если не задан, то вычисляется автоматически.
## aOptions.log[] — запись, которую надо сделать в логе вместо текста запроса.
  $lQuery[$aQuery]
  $lOptions[^self._getOptions[$lQuery;string;$aSQLOptions;$aOptions]]
  $result[^self._processMemoryCache{^self._sql[string]{^string:sql{$lQuery}[$aSQLOptions]}[$lOptions]}[$lOptions]]

@double[aQuery;aSQLOptions;aOptions]
## aOptions.force — отключить кеширование в памяти
## aOptions.cacheKey — ключ для кешироапния. Если не задан, то вычисляется автоматически.
## aOptions.log[] — запись, которую надо сделать в логе вместо текста запроса.
  $lQuery[$aQuery]
  $lOptions[^self._getOptions[$lQuery;double;$aSQLOptions;$aOptions]]
  $result(^self._processMemoryCache{^self._sql[double]{^double:sql{$lQuery}[$aSQLOptions]}[$lOptions]}[$lOptions])

@int[aQuery;aSQLOptions;aOptions]
## aOptions.force — отключить кеширование в памяти
## aOptions.cacheKey — ключ для кешироапния. Если не задан, то вычисляется автоматически.
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
  $result[^try{$aInsertCode}{^if($exception.type eq "sql.execute" && ^exception.comment.match[$self._duplicateKeyExceptionRegex][]){$exception.handled(true)$aExistsCode}}]

@lastInsertID[]
## Возвращает идентификатор последней вставленной записи.
## Способ получения зависит от типа сервера.
  $result[]
  $lQuery[^switch[$self._serverType]{
    ^case[sqlite]{select last_insert_rowid()}
    ^case[mysql]{select last_insert_id()}
    ^case[pgsql]{select lastval()}
  }]
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
   $result[auto-${aType}-^math:sha1[$aQuery]]
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
