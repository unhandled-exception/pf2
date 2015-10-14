# PF2 Library

@CLASS
pfSQLSecurityCrypt

## Шифрование и работа с токенами.
## Вызывает функции шифрования MySQL-совместимых серверов.

## Сериализация токенов в base64 доступна начиная с MySQL 5.6.10 и MariaDB 10.0.5.

@USE
pf2/lib/common.p
pf2/lib/sql/connection.p

@BASE
pfClass

@create[aOptions]
## aOptions.sql — объект для соединениея с БД.
## aOptions.cryptKey — ключ шифрования
## aOptions.secretKey — ключ для подписи
## aOptions.serializationAlgorythm[hex] — алгоритм сериализации (hex|base64)
  ^cleanMethodArgument[]
  ^BASE:create[]

  ^pfAssert:isTrue(def $aOptions.sql)[На задан объект для доступа к sql-серверу.]
  ^pfAssert:isTrue($aOptions.sql.serverType eq "mysql")[Класс $CLASS_NAME работает только с MySQL-совместимыми серверами.]
  ^pfAssert:isTrue(def $aOptions.cryptKey)[Не задан ключ шифрования.]
  ^pfAssert:isTrue(def $aOptions.secretKey)[Не задан ключ для подписи.]

  $_sql[$aOptions.sql]
  $_secretKey[$aOptions.secretKey]
  $_cryptKey[$aOptions.cryptKey]

  $_funcs[^_getFunctionsNames[$aOptions.serializationAlgorythm]]

@GET_CSQL[]
  $result[$_sql]

@encrypt[aString]
## Шифрует строку и сериализует её.
  $result[^CSQL.string{
    select sql_no_cache ${_funcs.serialize}(${_funcs.encrypt}("^taint[$aString]", "^taint[$_cryptKey]"))
  }]

@decrypt[aString]
## Расшифровывает строку, закодированную методом encrypt.
  $result[^CSQL.string{
    select sql_no_cache ${_funcs.decrypt}(${_funcs.unserialize}("^taint[$aString]"), "^taint[$_cryptKey]")
  }]

@makeToken[aTokenData;aOptions][locals]
## Формирует токен из данных и подписывает его.
## Разделитель данных — вертикальная черта.
  $result[^aTokenData.foreach[k;v]{$v}[|]]
  $result[^encrypt[${result}|^math:crypt[$result|$_secretKey;^$apr1^$]]]

@parseAndValidateToken[aToken;aOptions][locals]
## Расшифровывает и валидирует токен, сформированный функцией makeToken.
## Возвращает хеш с данными токена или выбрасывает исключение.
  $result[^hash::create[]]
  $aToken[^decrypt[^aToken.trim[both]]]
  $lParts[^aToken.split[|;lv]]
  ^if($lParts < 2){^throw[invalid.token]}
  ^lParts.foreach[k;v]{
    ^if($k == ($lParts - 1)){
      $lSignature[$v.piece]
      ^break[]
    }
    $result.[$k][$v.piece]
  }
  $lData[^aToken.left(^aToken.length[] - ^lSignature.length[] - 1)]
  ^if(!def $lSignature || $lSignature ne ^math:crypt[${lData}|$_secretKey;$lSignature]){
    ^throw[invalid.token]
  }

@_getFunctionsNames[aSerAlgorythm]
  $result[^hash::create[]]

  $result.encrypt[aes_encrypt]
  $result.decrypt[aes_decrypt]

  ^switch[^aSerAlgorythm.lower[]]{
    ^case[;hex]{
      $result.serialize[hex]
      $result.unserialize[unhex]
    }
    ^case[base64]{
      $result.serialize[to_base64]
      $result.unserialize[from_base64]
    }
    ^case[DEFAULT]{
      ^throw[unknown.serialization.algorythm;"$aAlgorythm" is an unknown serialization algorythm.]
    }
  }

