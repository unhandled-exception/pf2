@USE
pf2/lib/web/controllers2.p


@CLASS
pfSessionMiddleware

## Добавляет в объект запроса объект сессии. Хранит данные в шифрованной куке.

@BASE
pfMiddleware

@OPTIONS
locals

@create[aOptions]
## aOptions.cryptoProvider — объект с методами encrypt и decrypt для шифрования сессий.
## aOptions.sessionVarName[session] — имя переменной в объеке request в который пишем данные сессии.
## aOptions.sessionCookieName[session] — имя куки для хранения сессий.
## aOptions.sessionCookieDomain — домен для куки сессии
## aOptions.sessionCookiePath — путь для куки сессии
## aOptions.expires[days(90)|date|session] — срок жизни куки. По-умолчанию ставим ограничение Парсера (90 дней).
## aOptions.secretKey[] — ключ для цифровой подписи сессии. Если не задан, то данные не подписываем.
  ^cleanMethodArgument[]
  ^BASE:create[$aOptions]
  ^pfAssert:isTrue(def $aOptions.cryptoProvider){A crypto provider not defined.}

  $self._cryptoProvider[$aOptions.cryptoProvider]
  $self._sessionVarName[^ifdef[$aOptions.sessionVarName]{session}]
  $self._sessionCookieName[^ifdef[$aOptions.sessionCookieName]{session}]
  $self._sessionCookieDomain[$aOptions.sessionCookieDomain]
  $self._sessionCookiePath[$aOptions.sessionCookiePath]
  $self._expires[$aOptions.expires]
  $self._secretKey[$aOptions.secretKey]

# Заполняется в processRequest
  $self._sessionData[]
  $self._isEmptySession(false)
  $self._hasSessionCookie(false)

@processRequest[aAction;aRequest;aController;aProcessOptions] -> []
  $result[]
  $lData[^self._getSessionFromRequest[$aRequest]]

  ^if(def $lData){
    $lData[^self._parseSession[$lData]]
  }{
     $lData[^hash::create[]]
   }
  ^if(!$lData){
    $self._isEmptySession(true)
  }
  $self._sessionData[$lData]
  ^aRequest.assign[$self._sessionVarName][$self._sessionData]

@processResponse[aAction;aRequest;aResponse;aController;aProcessOptions] -> [response]
  ^if($self._isEmptySession && !$self._sessionData){
#   Если в запросе пришла пустая сессия и в процессе обработки запроса сессия осталась пустая,
#   то даем команду на удаление куки.
    ^if($self._hasSessionCookie){
      $aResponse.cookie.[$self._sessionCookieName][]
    }
  }{
    $aResponse.cookie.[$self._sessionCookieName][
      $.value[^self._serializeSession[$self._sessionData]]
      $.httponly(true)
      ^if(def $self._expires){
        $.expires[$self._expires]
      }
      ^if(def $self._sessionCookieDomain){$.domain[$self._sessionCookieDomain]}
      ^if(def $self._sessionCookiePath){$.path[$self._sessionCookiePath]}
    ]
  }
  $result[$aResponse]

@_getSessionFromRequest[aRequest] -> [string]
  $result[]
  ^if(^aRequest.cookie.contains[$self._sessionCookieName]){
    $self._hasSessionCookie(true)
    $result[$aRequest.cookie.[$self._sessionCookieName]]
  }

@_parseSession[aData] -> [hash]
  $aData[^self._cryptoProvider.decrypt[$aData;$.log[-- Decrypt a session data.]]]
  $aData[^self._validateSessionAndReturnData[$aData]]
  ^if(def $aData){
    ^try{
      $result[^json:parse[^taint[as-is][$aData]]]
    }{
      ^if($exception.type eq "json.parse"){
        $result[^hash::create[]]
        $exception.handled(true)
      }
     }
  }{
     $result[^hash::create[]]
   }

@_serializeSession[aData] -> [string]
  $result[^json:string[$aData]]
  $result[^self._signSession[$result]]
  $result[^self._cryptoProvider.encrypt[$result;$.log[-- Encrypt a session data.]]]

@_signSession[aData]
## Подписывает сессию
  $result[]
  ^if(def $self._secretKey){
    $lSignature[^math:digest[sha256;$aData;$.hmac[$self._secretKey]]]
    $result[${lSignature}.$aData]
  }{
     $result[$aData]
   }

@_validateSessionAndReturnData[aData]
  $result[]
  ^if(def $self._secretKey){
    $lPos(^aData.pos[.])
    $lSignature[^aData.left($lPos)]
    $lData[^aData.mid($lPos + 1)]
    ^if($lSignature eq ^math:digest[sha256;$lData;$.hmac[$self._secretKey]]){
      $result[$lData]
    }
  }{
     $result[$aData]
   }
