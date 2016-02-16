# PF2 Library

@CLASS
pfSQLSecurityCrypt

## Шифрование и работа с токенами.
## Вызывает функции шифрования через sql-серверы.
## Сервер должен пожжерживать функции шифрования и сераилизации в текстовый формат.

## MySQL:
## Шифрование — aes_encrypt/aes_decrypt. Сериализация — hex/base64.
## Сериализация токенов в base64 доступна начиная с MySQL 5.6.10 и MariaDB 10.0.5.

## Ключи лучше не вбивать с клавиатуры, а сгенерировать с помощью системного генератора случайных чисел:
## В unix/linux ключи можно сгенерировать через urandom:
## > python3 -c "import os, base64; print(base64.b64encode(os.urandom(24)))"

@USE
pf2/lib/common.p
pf2/lib/sql/connection.p

@BASE
pfClass

@OPTIONS
locals

@create[aOptions]
## aOptions.sql — объект для соединениея с БД.
## aOptions.secretKey — ключ для подписи и шифрования.
## aOptions.cryptKey[aOptions.secretKey] — ключ шифрования. Если не задан, то используем secretKey.
## aOptions.serializer[hex] — алгоритм сериализации зашифрованного текста (hex|base64)
  ^cleanMethodArgument[]
  ^BASE:create[]

  ^pfAssert:isTrue(def $aOptions.sql){На задан объект для доступа к sql-серверу.}
  ^pfAssert:isTrue(def $aOptions.secretKey){Не задан секретный ключ.}

  $self.CSQL[$aOptions.sql]
  $self._secretKey[$aOptions.secretKey]
  $self._cryptKey[^ifdef[$aOptions.cryptKey]{$self._secretKey}]

  $self._sqlFunctions[
    $.mysql[
      $.encrypt[
        $.func[aes_encrypt]
        $.options[]
      ]
      $.decrypt[
        $.func[aes_decrypt]
        $.options[]
      ]
      $.serializers[
        $.hex[
          $.to[hex]
          $.from[unhex]
        ]
        $.base64[
          $.to[to_base64]
          $.from[from_base64]
        ]
      ]
    ]
  ]
  $self._serializer[^ifdef[$aOptions.serializer]{hex}]
  $self._hashAlgorythm[sha256]

  ^pfAssert:isTrue(^self._sqlFunctions.contains[$self.CSQL.serverType]){Неизвестный тип sql-сервера — "${self.CSQL.serverType}". Класс $CLASS_NAME поддерживает шифрование через серверы ^self._sqlFunctions.foreach[k;v]{"$k"}[, ]}

@encrypt[aString;aOptions]
## Шифрует и сериализует строку.
## aOptions.serializer[default algorythm]
## aOptions.log — запись в sql-лог.
  ^cleanMethodArgument[]
  $lFuncs[$self._sqlFunctions.[$CSQL.serverType]]
  $lSeralizer[$lFuncs.serializers.[^ifdef[$aOptions.serializer]{$self._serializer}]]
  ^pfAssert:isTrue($lSeralizer){Неизвестный метод сериализации "$aOptions.serializer".}
  $result[^CSQL.string{
    select ${lSeralizer.to}(${lFuncs.encrypt.func}('^taint[$aString]', '^taint[$_cryptKey]'${lFuncs.encrypt.options}))
  }[][$.force(true) $.log{^ifdef[$aOptions.log]{-- Encrypt a string "$aString".}}]]

@decrypt[aString;aOptions]
## Расшифровывает строку, закодированную методом encrypt.
## aOptions.serializer[default algorythm]
## aOptions.log — запись в sql-лог.
  ^cleanMethodArgument[]
  $lFuncs[$self._sqlFunctions.[$CSQL.serverType]]
  $lSeralizer[$lFuncs.serializers.[^ifdef[$aOptions.serializer]{$self._serializer}]]
  ^pfAssert:isTrue($lSeralizer){Неизвестный метод сериализации "$aOptions.serializer".}
  $result[^CSQL.string{
    select ${lFuncs.decrypt.func}(${lSeralizer.from}('^taint[$aString]'), '^taint[$_cryptKey]'${lFuncs.decrypt.options})
  }[][$.force(true) $.log{^ifdef[$aOptions.log]{-- Decrypt a string "$aString".}}]]

@signString[aString] -> [signature.$aString]
## Добавляет в начало строки цифровую подпись подпись hash/hmac/base64.
  $lSignature[^math:digest[$self._hashAlgorythm;$aString;$.hmac[$self._secretKey] $.format[base64]]]
  $result[${lSignature}.$aString]

@validateSignatureAndReturnString[aSignString] -> [string] <security.invalid.signature>
## Проверяет цифровую подпись и возвращает строку без подписи.
## Если проверка подписи не прошла, выбрасывает исключение security.invalid.signature.
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
## Формирует зашифрованный токен из данных и подписывает его с помощью sha256/hmac.
## aData[hash] — данные сериализуются в json.
## aOptions.skipSign(false) — не подписывать токен
## aOptions.serializer[default algorythm]
## aOptions.log — запись в sql-лог.
  ^cleanMethodArgument[]
  $result[^json:string[$aData]]
  ^if(!^aOptions.skipSign.bool(false)){
    $result[^self.signString[$result]]
  }
  $result[^self.encrypt[$result;$.serializer[$aOptions.serializer] $.log[$aOptions.log]]]

@parseAndValidateToken[aToken;aOptions] -> [hash] <invalid.token>
## Расшифровывает и валидирует токен, сформированный функцией makeToken.
## Возвращает хеш с данными токена или выбрасывает исключение.
## aOptions.skipSign(false) — не провирять подпись
## aOptions.serializer[default algorythm]
## aOptions.log — запись в sql-лог.
  ^cleanMethodArgument[]
  ^try{
    $result[^self.decrypt[$aToken;$.serializer[$aOptions.serializer] $.log[$aOptions.log]]]
    ^if(!^aOptions.skipSign.bool(false)){
      $result[^self.validateSignatureAndReturnString[$result]]
    }
    $result[^json:parse[^taint[as-is][$result]]]
  }{
     ^throw[security.invalid.token;;Не удалось расшифровать и проверить токен "${aToken}".]
   }

@digest[aString;aOptions]
## Возвращает hmac-хеш строки.
## aOptions.format[base64|hex] — формат дайджеста. По-умолчанию base64.
  $result[^math:digest[$self._hashAlgorythm;$aString;$.format[^ifdef[$aOptions.format]{base64}]]]
