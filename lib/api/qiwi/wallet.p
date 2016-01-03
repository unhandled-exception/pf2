# PF2 Library

@CLASS
pfQiwiWallet

## Работа с xml-интерфейсом Киви.Кошелька.
## Алгоритм шифрования не реализован.

@USE
pf2/lib/common.p

@BASE
pfClass

@create[aOptions]
## aOptions.shopID
## aOptions.password
## aOptions.url[https://ishop.qiwi.ru/xml]
## aOptions.timeout(10)
## aOptions.prefix[QIWI_PF_] - Глобальный префикс для счетов. Счета, которые создаются, отменяются,
##                             проверяются через этот модуль будут иметь ID, начинающийся с этого
##                             префикса. Можно оставить пустым.
## aOptions.charset[utf-8]
## aOptions.lifetime(0) - Время жизни счёта по умолчанию. Задается в часах.
##                        Если 0, то "неограничен" (45 суток).
## aOptions.createClient(true) - при выставлении счёта создается пользователь в системе QIWI.
##                               При этом оплатить счёт можно в терминале наличными без ввода ПИН-кода.
## aOptions.alarmSMS(false) - sms оповещение пользователя о выставлении счета.
## aOptions.alarmCall(false) - звонок-оповещение пользователя о выставлении счета.
  ^cleanMethodArgument[]
  ^BASE:create[$aOptions]
  ^pfAssert:isTrue(def $aOptions.shopID)[Не задан shopID (login) магазина.]

  $_shopID[$aOptions.shopID]
  $_password[$aOptions.password]
  $_url[^if(def $aOptions.url){$aOptions.url}{https://ishop.qiwi.ru/xml}]
  $_charset[^if(def $aOptions.charset){$aOptions.charset}{utf-8}]
  $_timeout(^aOptions.timeout.int(10))

  $_options[
    $.prefix[^if(def $aOptions.prefix){$aOptions.prefix}{QIWI_PF_}]
    $.lifetime(^aOptions.lifetime.double(0))
    $.createClient(^aOptions.createClient.bool(true))
    $.alarmSMS(^aOptions.alarmSMS.bool(false))
    $.alarmCall(^aOptions.alarmCall.bool(false))
  ]

  $_statuses[
    $.50[Счёт не оплачен.]
    $.52[Счет проводится.]
    $.60[Счёт оплачен.]
    $.150[Счёт отменен (ошибка на терминале).]
    $.151[Счет отменен (ошибка авторизации: недостаточно средств на балансе, отклонен абонентом при оплате с лицевого счета оператора сотовой связи и т.п.).]
    $.160[Отменен]
    $.161[Отменен (истекло время)]
  ]

  $_successStatuses[
    $.60(true)
    $._default(false)
  ]

  $_cancelStatuses[
    $.150(true)
    $.151(true)
    $.160(true)
    $.161(true)
    $._default(false)
  ]

  $_errors[
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

@createBill[aBill;aOptions][lOptions;lResponse;lDoc]
## Создание счёта.
## aBill.phone - номер телефона того, кому выставляется счёт. 10 цифр, без +7 или 8 вначале.
## aBill.amount - сумма выставляемого счёта.
## aBill.comment - комментарий.
## aBill.txnID - номер счёта ("уникальный" номер, например, номер заказа в интернет-магазине).
## aOptions - если не указывать, будут использоваться соответствующие параметры из конструктора.
## aOptions.ignorePrefix(false) - не вставлять префикс перед номером счета.
  ^cleanMethodArgument[aBill]
  ^cleanMethodArgument[]
  ^pfAssert:isTrue(def $aBill.phone)[Не задан номер телефона.]
  ^pfAssert:isTrue(def $aBill.txnID)[Не задан номер транзакции (счета).]
  ^pfAssert:isTrue($aBill.amount > 0)[Сумма счета должна быть положительной.]

  $result[]
  $lOptions[^hash::create[$_options]]
  ^lOptions.add[$aOptions]

  $lResponse[^pfCFile:load[text;$_url;
    $.charset[$_charset]
    $.method[POST]
    $.content-type[text/xml]
    $.timeout($_timeout)
    $.body[<?xml version="1.0" encoding="$_charset"?>
      <request>
        <protocol-version>4.00</protocol-version>
        <request-type>30</request-type>
        <terminal-id>^taint[xml][$_shopID]</terminal-id>
        <extra name="password">^taint[xml][$_password]</extra>
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
  $lDoc[^xdoc::create{<?xml version="1.0" encoding="$_charset"?>^taint[as-is][$lResponse.text]}]
  ^_checkResponse[$lDoc]

@cancelBill[aTxnID;aOptions][lResponse;lDoc;lOptions]
## Отмена счета.
## aTxnID - номер счета
## aOptions.ignorePrefix(false) - не вставлять префикс перед номером счета.
  ^cleanMethodArgument[]
  ^pfAssert:isTrue(def $aTxnID)[Не задан номер транзакции (счета).]

  $result[]
  $lOptions[^hash::create[$_options]]
  ^lOptions.add[$aOptions]

  $lResponse[^pfCFile:load[text;$_url;
    $.charset[$_charset]
    $.method[POST]
    $.content-type[text/xml]
    $.timeout($_timeout)
    $.body[<?xml version="1.0" encoding="$_charset"?>
      <request>
        <protocol-version>4.00</protocol-version>
        <request-type>29</request-type>
        <terminal-id>^taint[xml][$_shopID]</terminal-id>
        <extra name="password">^taint[xml][$_password]</extra>
        <extra name="txn-id">^taint[xml][^if(!^lOptions.ignorePrefix.bool(false)){$lOptions.prefix}$aTxnID]</extra>
        <extra name="status">reject</extra>
      </request>
    ]
  ]]
  $lDoc[^xdoc::create{<?xml version="1.0" encoding="$_charset"?>^taint[as-is][$lResponse.text]}]
  ^_checkResponse[$lDoc]

@billStatus[aIDS;aOptions][lOptions;lResponse;lDoc;k;v;i;lNodes;lID]
## Проверка статуса счетов.
## aIDS<string|hash|table> - номера счетов, которые необходимо проверить.
## aOptions.ignorePrefix(false) - не вставлять префикс перед номером счета.
## aOptions.column[id] - имя колонки с номерами счетов (если в aIDS пришла таблица)
## result<hash>[$.[txnID][$.status $.amount $.isPaid $.isCanceled $.rawID]]
##      - ключ - номер счета без префикса (если не задан ignorePrefix)
  ^cleanMethodArgument[]
  ^pfAssert:isTrue(def $aIDS)[Не заданы номера транзакций (счетов).]

  $result[^hash::create[]]
  $lOptions[^hash::create[$_options]]
  ^lOptions.add[$aOptions]
  ^if(!def $lOptions.column){$lOptions.column[id]}

  $lResponse[^pfCFile:load[text;$_url;
    $.charset[$_charset]
    $.method[POST]
    $.content-type[text/xml]
    $.timeout($_timeout)
    $.body[<?xml version="1.0" encoding="$_charset"?>
      <request>
        <protocol-version>4.00</protocol-version>
        <request-type>33</request-type>
        <terminal-id>^taint[xml][$_shopID]</terminal-id>
        <extra name="password">^taint[xml][$_password]</extra>
        <bills-list>
          ^switch(true){
            ^case($aIDS is string || $aIDS is int){
              <bill txn-id="^taint[xml][^if(!^lOptions.ignorePrefix.bool(false)){$_options.prefix}$aIDS]" />
            }
            ^case($aIDS is hash){
              ^aIDS.foreach[k;v]{
                <bill txn-id="^taint[xml][^if(!^lOptions.ignorePrefix.bool(false)){$_options.prefix}$k]" />
              }
            }
            ^case($aIDS is table){
              ^aIDS.menu{
                <bill txn-id="^taint[xml][^if(!^lOptions.ignorePrefix.bool(false)){$_options.prefix}$aIDS.[$lOptions.column]]" />
              }
            }
          }
        </bills-list>
      </request>
    ]
  ]]
  $lDoc[^xdoc::create{<?xml version="1.0" encoding="$_charset"?>^taint[as-is][$lResponse.text]}]
  ^_checkResponse[$lDoc]

  $lNodes[^lDoc.select[/response/bills-list/bill]]
  ^if($lNodes){
    ^for[i](0;$lNodes - 1){
      $lID[^lNodes.[$i].getAttribute[id]]
      $result.[^if(!^lOptions.ignorePrefix.bool(false)){^lID.match[^^$_options.prefix][][]}{$lID}][
        $.status[^lNodes.[$i].getAttribute[status]]
        $.isPaid($_successStatuses.[^lNodes.[$i].getAttribute[status]])
        $.isCanceled($_cancelStatuses.[^lNodes.[$i].getAttribute[status]])
        $.amount[^lNodes.[$i].getAttribute[sum]]
        $.rawID[$lID]
      ]
    }
  }

@_checkResponse[aDoc][lRes]
  $result[]
  $lRes[
    $.status(^aDoc.selectString[string(/response/result-code)])
    $.fatality(^if(^aDoc.selectString[string(/response/result-code/@fatal)] eq "true"){1}{0})
  ]
  ^if($lRes.status > 0 && $lRes.fatality){
    ^throw[pfQiwiWallet.fail;$_errors.[$lRes.status] ($lRes.status);^aDoc.string[$.method[html]]]
  }

