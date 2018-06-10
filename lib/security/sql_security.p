# PF2 Library

@USE
pf2/lib/common.p
pf2/lib/sql/connection.p


@CLASS
pfSQLSecurityCrypt

## Шифрование и работа с токенами.
## Вызывает функции шифрования через sql-серверы.
## Умеет шифровать через MySQL и Postgres.

## MySQL:
## Сериализация токенов в base64 доступна начиная с MySQL 5.6.10 и MariaDB 10.0.5.
## Для младших версий включите $.serializer[hex]

## Ключи лучше не вбивать с клавиатуры, а сгенерировать с помощью системного генератора случайных чисел:
## В unix/linux ключи можно сгенерировать через urandom:
## > python3 -c "import os, base64; print(base64.b64encode(os.urandom(24)))"

@BASE
pfClass

@OPTIONS
locals

@create[aOptions]
## aOptions.sql — объект для соединения с БД
## aOptions.secretKey — ключ для подписи и шифрования
## aOptions.cryptKey[aOptions.secretKey] — ключ шифрования. Если не задан, то используем secretKey
## aOptions.serializer[hex] — алгоритм сериализации зашифрованного текста (hex|base64)
## aOptions.hashAlgorythm[sha256] — алогритм хеширования по-умолчанию
  ^self.cleanMethodArgument[]
  ^BASE:create[]

  ^pfAssert:isTrue(def $aOptions.sql){На задан объект для доступа к sql-серверу}
  ^pfAssert:isTrue(def $aOptions.secretKey){Не задан секретный ключ}

  $self.CSQL[$aOptions.sql]
  $self._secretKey[$aOptions.secretKey]
  $self._cryptKey[^self.ifdef[$aOptions.cryptKey]{$self._secretKey}]

  $self._sqlFunctions[
    $.mysql[
      $.encrypt[
        $.hex[HEX(AES_ENCRYPT('{data}', '{key}'))]
        $.base64[TO_BASE64(AES_ENCRYPT('{data}', '{key}'))]
      ]
      $.decrypt[
        $.hex[AES_DECRYPT(UNHEX('{data}'), '{key}')]
        $.base64[AES_DECRYPT(FROM_BASE64('{data}'), '{key}')]
      ]
    ]
    $.pgsql[
      $.encrypt[
        $.hex[ENCODE(ENCRYPT(CONVERT_TO('{data}', 'utf8'), CONVERT_TO('{key}', 'utf8'), 'aes'), 'hex')]
        $.base64[ENCODE(ENCRYPT(CONVERT_TO('{data}', 'utf8'), CONVERT_TO('{key}', 'utf8'), 'aes'), 'base64')]
      ]
      $.decrypt[
        $.hex[CONVERT_FROM(DECRYPT(DECODE('{data}', 'base64'), CONVERT_TO('{key}', 'utf8'), 'aes'), 'utf8')]
        $.base64[CONVERT_FROM(DECRYPT(DECODE('{data}', 'base64'), CONVERT_TO('{key}', 'utf8'), 'aes'), 'utf8')]
      ]
    ]
  ]

  $self._serializer[^self.ifdef[$aOptions.serializer]{hex}]
  $self._hashAlgorythm[^self.ifdef[$aOptions.hashAlgorythm]{sha256}]

  ^pfAssert:isTrue(^self._sqlFunctions.contains[$self.CSQL.serverType]){Неизвестный тип sql-сервера — "${self.CSQL.serverType}". Класс $self.CLASS_NAME поддерживает шифрование через серверы ^self._sqlFunctions.foreach[k;]{"$k"}[, ]}

  $self._pattern[^regex::create[\{(.+?)\}][g]]

@GET_secretKey[]
  $result[$self._secretKey]

@GET_cryptKey[]
  $result[$self._cryptKey]

@encrypt[aString;aOptions]
## Шифрует и сериализует строку.
## aOptions.cryptKey[default crypt key]
## aOptions.serializer[default algorythm]
## aOptions.log — запись в sql-лог.
  ^self.cleanMethodArgument[]
  $lFuncs[$self._sqlFunctions.[$self.CSQL.serverType]]
  $lSeralizer[$lFuncs.encrypt.[^self.ifdef[$aOptions.serializer]{$self._serializer}]]
  ^pfAssert:isTrue(def $lSeralizer){Неизвестный метод сериализации "$aOptions.serializer".}
  $result[^self.CSQL.string{
    SELECT
      ^self._applyPattern[$lSeralizer;
        $.data[$aString]
        $.key[^self.ifdef[$aOptions.cryptKey]{$self._cryptKey}]
      ]
  }[][
    $.force(true)
    $.log{^self.ifdef[$aOptions.log]{-- Encrypt a string "$aString".}}
  ]]

@decrypt[aString;aOptions]
## Расшифровывает строку, закодированную методом encrypt
## aOptions.cryptKey[self._cryptKey]
## aOptions.log — запись в sql-лог
  ^self.cleanMethodArgument[]
  $lFuncs[$self._sqlFunctions.[$self.CSQL.serverType]]
  $lSeralizer[$lFuncs.decrypt.[^self.ifdef[$aOptions.serializer]{$self._serializer}]]
  ^pfAssert:isTrue(def $lSeralizer){Неизвестный метод сериализации "$aOptions.serializer".}
  $result[^self.CSQL.string{
    SELECT
      ^self._applyPattern[$lSeralizer;
        $.data[$aString]
        $.key[^self.ifdef[$aOptions.cryptKey]{$self._cryptKey}]
      ]
  }[][
    $.force(true)
    $.log{^self.ifdef[$aOptions.log]{-- Decrypt a string "$aString".}}
  ]]

@signString[aString] -> [signature.$aString]
## Добавляет в начало строки цифровую подпись hash/hmac/base64.
  $lSignature[^math:digest[$self._hashAlgorythm;$aString;$.hmac[$self._secretKey] $.format[base64]]]
  $result[${lSignature}.$aString]

@validateSignatureAndReturnString[aSignString] -> [string] <security.invalid.signature>
## Проверяет цифровую подпись и возвращает строку без подписи
## Если не удалось проверить подпись, выбрасывает исключение
  $result[]
  $lPos(^aSignString.pos[.])
  $lSignature[^aSignString.left($lPos)]
  $lString[^aSignString.mid($lPos + 1)]
  ^if(def $lSignature && $lSignature eq ^math:digest[sha256;$lString;$.hmac[$self._secretKey] $.format[base64]]){
    $result[$lString]
  }{
     ^throw[security.invalid.signature;;Цифровая подпись не соответствует данным в строке.]
   }

@makeToken[aData;aOptions]
## Формирует зашифрованный токен из данных и подписывает его с помощью sha256/hmac
## aData[hash] — данные сериализуются в json
## aOptions.skipSign(false) — не подписывать токен
## aOptions.serializer[default algorythm]
## aOptions.log — запись в sql-лог
  ^self.cleanMethodArgument[]
  $result[^json:string[$aData]]
  ^if(!^aOptions.skipSign.bool(false)){
    $result[^self.signString[$result]]
  }
  $result[^self.encrypt[$result;$.serializer[$aOptions.serializer] $.log[$aOptions.log]]]

@parseAndValidateToken[aToken;aOptions] -> [hash] <security.invalid.token>
## Расшифровывает и валидирует токен, сформированный функцией makeToken
## Возвращает хеш с данными токена или выбрасывает исключение
## aOptions.skipSign(false) — не проверять подпись
## aOptions.serializer[default algorythm]
## aOptions.log — запись в sql-лог
  ^self.cleanMethodArgument[]
  ^try{
    ^if(!def $aToken){
      ^throw[security.invalid.token;;Пустой токен.]
    }
    $result[^self.decrypt[$aToken;$.serializer[$aOptions.serializer] $.log[$aOptions.log]]]
    ^if(!^aOptions.skipSign.bool(false)){
      $result[^self.validateSignatureAndReturnString[$result]]
    }
    $result[^json:parse[^taint[as-is][$result]]]
  }{
     ^if($exception.type ne "security.invalid.token"){
       ^throw[security.invalid.token;;Не удалось расшифровать и проверить токен "${aToken}".]
      }
   }

@digest[aString;aOptions]
## Возвращает криптографический хеш строки
## aOptions.format[self._serializer] — формат дайджеста (hex|base64).
## aOptions.algorythm[self._hashAlgorythm] — алгоритм хешировани (sha256|sha512|...)
## aOptions.hmac[self._secretKey] — hmac-строка
  $result[^math:digest[^self.ifdef[$aOptions.algorythm]{$self._hashAlgorythm};$aString;
    $.format[^self.ifdef[$aOptions.format]{$self._serializer}]
    $.hmac[^self.ifdef[$aOptions.hmac]{$self._secretKey}]
  ]]

#----- Private -----

@_applyPattern[aPattern;aData]
  $result[^aPattern.match[$self._pattern][]{^taint[$aData.[$match.1]]}]
