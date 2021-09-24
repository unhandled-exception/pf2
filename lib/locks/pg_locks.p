@USE
pf2/lib/common.p

@CLASS
pfPGLocksManager

## Класс для работы с рекомендательными блокировками в Постгресе
## https://postgrespro.ru/docs/postgresql/13/functions-admin#FUNCTIONS-ADVISORY-LOCKS

@BASE
pfClass

@create[aCSQL]
  ^self.assert(!def $aCSQLs)[Не задан класс для соединения с БД]
  $self.CSQL[$aCSQL]

@keyToPGLiteral[aKey]
  $lKey[^math:md5[$aKey]]
  $result[x'^lKey.left(16)'::bigint]

@tryAdvisoryLock[aKey]
## Пытается взять сессионную блокировку и возвращает удалось взять лок или нет
## Не стоит использоватье если pg_bouncer в transaction-режиме
  $result(^self.CSQL.int{select pg_try_advisory_lock(^self.keyToPGLiteral[$aKey])::int}[;$.force(true)] != 0)

@tryAdvisoryXACTLock[aKey]
## Пытается взять блокировку до конца транзакции и возвращает удалось взять лок или нет
## Автоматически снимается в конце транзакции
  $result(^self.CSQL.int{select pg_try_advisory_xact_lock(^self.keyToPGLiteral[$aKey])::int}[;$.force(true)] != 0)

@advisoryUnlockAll[]
## Освобождает все закреплённые за текущим сеансом рекомендательные блокировки сеансового уровня
  $result[]
  ^CSQL.string{select pg_advisory_unlock_all()}

@exclusiveTransaction[aKey;aCode;aFailedCode]
## Пытается взять блокировку по aKey до конца транзакции и выполняет в транзакции aCode, иначе выполняет aFailedCode без транзакции
## Если при взятии лока произойдет исключение, то не выполняет никакой код, исключение не обрабатывает
  ^self.assert(!^reflection:is[aKey;code])[В первом параметре должен быть ключ блокировки]

  $result[]
  ^CSQL.transaction{
    $lLocked(^self.tryAdvisoryXACTLock[$aKey])
    ^if($lLocked){
      $result[$aCode]
    }
  }
  ^if(!$lLocked){
    $result[$aFailedCode]
  }
