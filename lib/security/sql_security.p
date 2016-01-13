# PF2 Library

@CLASS
pfSQLSecurityCrypt

## Шифрование и работа с токенами.
## Вызывает функции шифрования MySQL-совместимых серверов.

## Сериализация токенов в base64 доступна начиная с MySQL 5.6.10 и MariaDB 10.0.5.

## Ключи лучше не вбивать с клавиатуры, а сгенерировать с помощью надежного генератора случайных чисел:
## В unix/linux это можно сделать командой:
## > python3 -c "import os, base64; print(base64.b64encode(os.urandom(24)))"

@USE
pf2/lib/common.p
pf2/lib/sql/connection.p

@BASE
pfClass

@create[aOptions]
## aOptions.sql — объект для соединениея с БД.
## aOptions.secretKey — ключ для подписи, если не задан, то используем secretKey.
## aOptions.cryptKey[aOptions.secretKey] — ключ шифрования
## aOptions.serializationAlgorythm[hex] — алгоритм сериализации (hex|base64)
  ^cleanMethodArgument[]
  ^BASE:create[]

  ^pfAssert:isTrue(def $aOptions.sql)[На задан объект для доступа к sql-серверу.]
  ^pfAssert:isTrue($aOptions.sql.serverType eq "mysql")[Класс $CLASS_NAME работает только с MySQL-совместимыми серверами.]
  ^pfAssert:isTrue(def $aOptions.secretKey)[Не задан секретный ключ.]

  $self._sql[$aOptions.sql]
  $self._secretKey[$aOptions.secretKey]
  $self._cryptKey[^ifdef[$aOptions.cryptKey]{$self._secretKey}]

  $self._funcs[^_getFunctionsNames[$aOptions.serializationAlgorythm]]

@GET_CSQL[]
  $result[$_sql]

@encrypt[aString;aOptions]
## Шифрует строку и сериализует её.
  $result[^CSQL.string{
    select sql_no_cache ${_funcs.serialize}(${_funcs.encrypt}("^taint[$aString]", "^taint[$_cryptKey]"))
  }[][$.log[^ifdef[$aOptions.log]{-- Encrypt string: "$aString".}]]]

@decrypt[aString;aOptions]
## Расшифровывает строку, закодированную методом encrypt.
  $result[^CSQL.string{
    select sql_no_cache ${_funcs.decrypt}(${_funcs.unserialize}("^taint[$aString]"), "^taint[$_cryptKey]")
  }[][$.log[^ifdef[$aOptions.log]{-- Decrypt string: "$aString".}]]]

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

