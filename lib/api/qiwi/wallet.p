# PF2 Library

@CLASS
pfQiwiWallet

## Работа с xml-интерфейсом Киви.Кошелька.
## Алгоритм шифрования не реализован.

@OPTIONS
locals

@USE
pf2/lib/common.p

@BASE
pfClass

@create[aOptions]
## aOptions.shopID
## aOptions.password
## aOptions.url[https://ishop.qiwi.ru/xml]
## aOptions.timeout(10)
## aOptions.prefix[QIWI_PF_] — Глобальный префикс для счетов. Счета, которые создаются, отменяются,
##                             проверяются через этот модуль будут иметь ID, начинающийся с этого
##                             префикса. Можно оставить пустым.
## aOptions.charset[utf-8]
## aOptions.lifetime(0) — Время жизни счёта по умолчанию. Задается в часах.
##                        Если 0, то "неограничен" (45 суток).
## aOptions.createClient(true) — при выставлении счёта создается пользователь в системе QIWI.
##                               При этом оплатить счёт можно в терминале наличными без ввода ПИН-кода.
## aOptions.alarmSMS(false) — sms оповещение пользователя о выставлении счета.
## aOptions.alarmCall(false) — звонок-оповещение пользователя о выставлении счета.
  ^self.cleanMethodArgument[]
  ^BASE:create[$aOptions]
  ^self.assert(def $aOptions.shopID)[Не задан shopID (login) магазина.]

  $self._shopID[$aOptions.shopID]
  $self._password[$aOptions.password]
  $self._url[^if(def $aOptions.url){$aOptions.url}{https://ishop.qiwi.ru/xml}]
  $self._charset[^if(def $aOptions.charset){$aOptions.charset}{utf-8}]
  $self._timeout(^aOptions.timeout.int(10))

  $self._options[
    $.prefix[^if(def $aOptions.prefix){$aOptions.prefix}{QIWI_PF_}]
    $.lifetime(^aOptions.lifetime.double(0))
    $.createClient(^aOptions.createClient.bool(true))
    $.alarmSMS(^aOptions.alarmSMS.bool(false))
    $.alarmCall(^aOptions.alarmCall.bool(false))
  ]

  $self._statuses[
    $.50[Счёт не оплачен.]
    $.52[Счет проводится.]
    $.60[Счёт оплачен.]
    $.150[Счёт отменен (ошибка на терминале).]
    $.151[Счет отменен (ошибка авторизации: недостаточно средств на балансе, отклонен абонентом при оплате с лицевого счета оператора сотовой связи и т.п.).]
    $.160[Отменен]
    $.161[Отменен (истекло время)]
  ]

  $self._successStatuses[
    $.60(true)
    $._default(false)
  ]

  $self._cancelStatuses[
    $.150(true)
    $.151(true)
    $.160(true)
    $.161(true)
    $._default(false)
  ]

  $self._errors[
    $._default[Неизвестная ошибка.]
    $.300[Неизвестная ошибка.]
    $.13[Сервер занят. Повторите запрос позже.]
    $.150[Неверный логин или пароль.]
    $.215[Счёт с таким номером уже существует.]
    $.278[Превышение максимального интервала получения списка счетов.]
    $.298[Агент не существует в системе.]
    $.330[Ошибка шифрования.]
    $.370[Превышено максимальное количество одновременно выполняемых запросов.]
    $.0[OK]
  ]

@createBill[aBill;aOptions]
## Создание счёта.
## aBill.phone — номер телефона того, кому выставляется счёт. 10 цифр, без +7 или 8 вначале.
## aBill.amount — сумма выставляемого счёта.
## aBill.comment — комментарий.
## aBill.txnID — номер счёта ("уникальный" номер, например, номер заказа в интернет-магазине).
## aOptions — если не указывать, будут использоваться соответствующие параметры из конструктора.
## aOptions.ignorePrefix(false) — не вставлять префикс перед номером счета.
  ^self.cleanMethodArgument[aBill]
  ^self.cleanMethodArgument[]
  ^self.assert(def $aBill.phone)[Не задан номер телефона.]
  ^self.assert(def $aBill.txnID)[Не задан номер транзакции (счета).]
  ^self.assert($aBill.amount > 0)[Сумма счета должна быть положительной.]

  $result[]
  $lOptions[^hash::create[$self._options]]
  ^lOptions.add[$aOptions]

  $lResponse[^pfCFile:load[text;$self._url;
    $.charset[$self._charset]
    $.method[POST]
    $.content-type[text/xml]
    $.timeout($self._timeout)
    $.body[<?xml version="1.0" encoding="$self._charset"?>
      <request>
        <protocol-version>4.00</protocol-version>
        <request-type>30</request-type>
        <terminal-id>^taint[xml][$self._shopID]</terminal-id>
        <extra name="password">^taint[xml][$self._password]</extra>
        <extra name="txn-id">^taint[xml][^if(!^lOptions.ignorePrefix.bool(false)){$lOptions.prefix}$aBill.txnID]</extra>
        <extra name="to-account">^taint[xml][$aBill.phone]</extra>
        <extra name="amount">^taint[xml][$aBill.amount]</extra>
        <extra name="comment">^taint[xml][$aBill.comment]</extra>
        <extra name="create-agt">^lOptions.createClient.int(0)</extra>
        <extra name="ltime">^lOptions.lifetime.double(0)</extra>
        <extra name="ALARM_SMS">^lOptions.alarmSMS.int(0)</extra>
        <extra name="ACCEPT_CALL">^lOptions.alarmCall.int(0)</extra>
      </request>
    ]
  ]]
  $lDoc[^xdoc::create{<?xml version="1.0" encoding="$self._charset"?>^taint[as-is][$lResponse.text]}]
  ^self._checkResponse[$lDoc]

@cancelBill[aTxnID;aOptions]
## Отмена счета.
## aTxnID — номер счета
## aOptions.ignorePrefix(false) — не вставлять префикс перед номером счета.
  ^self.cleanMethodArgument[]
  ^self.assert(def $aTxnID)[Не задан номер транзакции (счета).]

  $result[]
  $lOptions[^hash::create[$self._options]]
  ^lOptions.add[$aOptions]

  $lResponse[^pfCFile:load[text;$self._url;
    $.charset[$self._charset]
    $.method[POST]
    $.content-type[text/xml]
    $.timeout($self._timeout)
    $.body[<?xml version="1.0" encoding="$self._charset"?>
      <request>
        <protocol-version>4.00</protocol-version>
        <request-type>29</request-type>
        <terminal-id>^taint[xml][$self._shopID]</terminal-id>
        <extra name="password">^taint[xml][$self._password]</extra>
        <extra name="txn-id">^taint[xml][^if(!^lOptions.ignorePrefix.bool(false)){$lOptions.prefix}$aTxnID]</extra>
        <extra name="status">reject</extra>
      </request>
    ]
  ]]
  $lDoc[^xdoc::create{<?xml version="1.0" encoding="$self._charset"?>^taint[as-is][$lResponse.text]}]
  ^self._checkResponse[$lDoc]

@billStatus[aIDS;aOptions]
## Проверка статуса счетов.
## aIDS<string|hash|table> — номера счетов, которые необходимо проверить.
## aOptions.ignorePrefix(false) — не вставлять префикс перед номером счета.
## aOptions.column[id] — имя колонки с номерами счетов (если в aIDS пришла таблица)
## result<hash>[$.[txnID][$.status $.amount $.isPaid $.isCanceled $.rawID]]
##      — ключ — номер счета без префикса (если не задан ignorePrefix)
  ^self.cleanMethodArgument[]
  ^self.assert(def $aIDS)[Не заданы номера транзакций (счетов).]

  $result[^hash::create[]]
  $lOptions[^hash::create[$self._options]]
  ^lOptions.add[$aOptions]
  ^if(!def $lOptions.column){$lOptions.column[id]}

  $lResponse[^pfCFile:load[text;$self._url;
    $.charset[$self._charset]
    $.method[POST]
    $.content-type[text/xml]
    $.timeout($self._timeout)
    $.body[<?xml version="1.0" encoding="$self._charset"?>
      <request>
        <protocol-version>4.00</protocol-version>
        <request-type>33</request-type>
        <terminal-id>^taint[xml][$self._shopID]</terminal-id>
        <extra name="password">^taint[xml][$self._password]</extra>
        <bills-list>
          ^switch(true){
            ^case($aIDS is string || $aIDS is int){
              <bill txn-id="^taint[xml][^if(!^lOptions.ignorePrefix.bool(false)){$self._options.prefix}$aIDS]" />
            }
            ^case($aIDS is hash){
              ^aIDS.foreach[k;]{
                <bill txn-id="^taint[xml][^if(!^lOptions.ignorePrefix.bool(false)){$self._options.prefix}$k]" />
              }
            }
            ^case($aIDS is table){
              ^aIDS.menu{
                <bill txn-id="^taint[xml][^if(!^lOptions.ignorePrefix.bool(false)){$self._options.prefix}$aIDS.[$lOptions.column]]" />
              }
            }
          }
        </bills-list>
      </request>
    ]
  ]]
  $lDoc[^xdoc::create{<?xml version="1.0" encoding="$self._charset"?>^taint[as-is][$lResponse.text]}]
  ^self._checkResponse[$lDoc]

  $lNodes[^lDoc.select[/response/bills-list/bill]]
  ^if($lNodes){
    ^for[i](0;$lNodes - 1){
      $lID[^lNodes.[$i].getAttribute[id]]
      $result.[^if(!^lOptions.ignorePrefix.bool(false)){^lID.match[^^$self._options.prefix][][]}{$lID}][
        $.status[^lNodes.[$i].getAttribute[status]]
        $.isPaid($self._successStatuses.[^lNodes.[$i].getAttribute[status]])
        $.isCanceled($self._cancelStatuses.[^lNodes.[$i].getAttribute[status]])
        $.amount[^lNodes.[$i].getAttribute[sum]]
        $.rawID[$lID]
      ]
    }
  }

@_checkResponse[aDoc]
  $result[]
  $lRes[
    $.status(^aDoc.selectString[string(/response/result-code)])
    $.fatality(^if(^aDoc.selectString[string(/response/result-code/@fatal)] eq "true"){1}{0})
  ]
  ^if($lRes.status > 0 && $lRes.fatality){
    ^throw[pfQiwiWallet.fail;$self._errors.[$lRes.status] ($lRes.status);^aDoc.string[$.method[html]]]
  }
