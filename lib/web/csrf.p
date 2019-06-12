@USE
pf2/lib/web/controllers.p

# https://docs.djangoproject.com/en/1.10/ref/csrf/

# — Ставим сессионную куку csrftoken с постоянным секретом и переменной солью.
#   Обновлять куку безопано — секрет берем из куки и обновляем только соль.
# — Куку можно ставить http-only, если нет Аякс запросов.
# — В форму добавляем скрытое поле csrftoken с токеном.
# — Если нам пришел запрос с небезопасным методом, то сравниваем секреты в куке и токене. Безопасным методами считаем GET, HEAD, OPTIONS или TRACE.
# — Если запрос пришел Аяксом и в форме нет инпута, то проверям заголовко X-CSRFToken.
# — При логине обновляем секрет в токене.
#   if not getattr(request, 'csrf_cookie_needs_reset', False):
# — Сделать исключения для урлов.
#   Пример: aOptions.sslRedirectExempt[hash<$.name[regexp]>] — хеш с регулярными выражениями для путей в урлах, которые не надо редиректить. Решудяркой может быть строка или объект regex. По-умолчанию регулярки case-insensiteve, если надо иное, то явно создаем regex-объект.
# — Проверяем реферер для https.

# На будущее:
# — Соль в токене можно использовать для антифлуда. При посте формы, пишем соль в хранилище на 60 минут. Антифлуд проверям в обработчиках.
# — Добавить обработчик для csrf-fail'ов ($.csrfFailureView[$self.csrfError[request;reason] -> [response[403]]]). Сейчас выдается 403 ошибка напрямую из мидлваре.

@CLASS
pfCSRFMiddleware

@OPTIONS
locals

@BASE
pfMiddleware

@create[aOptions]
## aOptions.cryptoProvider — объект с методами makeToken и parseAndValidateToken для работы с токенами.
## aOptions.cookieAge[365] — время жизни csrf-куки в днях
## aOptions.cookieDomain[] — домен csrf-куки
## aOptions.cookieHTTPOnly(false) — ставим куку только для http. Перестанет работать ajax-post
## aOptions.cookieName[csrftoken] — имя csrf-куки
## aOptions.cookiePath[/] — путь csrf-куки
## aOptions.cookieSecure(false) —  ставим куку только на https
## aOptions.formFieldName[csrf_form_token] — имя поля формы с токеном
## aOptions.headerName[X-CSRFToken] — http-заголовок с токеном
## aOptions.pathExempt[hash<$.name[regexp]>] — хеш с регулярными выражениями для путей в урлах, которые не надо обрабатывать в мидлваре.
## aOptions.trustedOrigins[hash<$.name[host.name]>] — хеш с именами доменов с которых могут идти небезопасные запросы. Используются при проверке рефереров.
## aOptions.requestVarName[CSRF] — имя переменной в запросе со ссылкой на мидлваре.
## aOptions.exceptionHandler[function[request;exception]->response] — ссылка на функцию-обработчик исключения. Если не задана, то возвращаем ошибку сами
  ^self.cleanMethodArgument[]
  ^BASE:create[$aOptions]

  ^self.assert(def $aOptions.cryptoProvider){Не задан объект для шифрования csrf-токенов (options.cryptoProvider).}
  $self._cryptoProvider[$aOptions.cryptoProvider]

  $self._cookieAge[^self.ifdef[$aOptions.cookieAge]{365}]
  $self._cookieDomain[^self.ifdef[$aOptions.cookieDomain]]
  $self._cookieHTTPOnly[^aOptions.cookieHTTPOnly.bool(false)]
  $self._cookieName[^self.ifdef[$aOptions.cookieName]{csrftoken}]
  $self._cookiePath[^self.ifdef[$aOptions.cookiePath]{/}]
  $self._cookieSecure[^aOptions.cookieSecure.bool(false)]

  $self._formFieldName[^self.ifdef[$aOptions.formFieldName]{csrf_form_token}]
  $self._headerName[^self.ifdef[$aOptions.headerName]{X-CSRFToken}]

  $self._pathExempt[^hash::create[$aOptions.pathExempt]]
  $self._trustedOrigins[^hash::create[$aOptions.trustedOrigins]]

  $self._requestVarName[^self.ifdef[$aOtpions.requestVarName]{CSRF}]

  ^if(^aOptions.contains[exceptionHandler]){
    ^self.assert($aOptions.exceptionHandler is junction)[Обработчик исключения для CSRF-мидлваре должен быть функцией.]
    $self._exceptionHandler[$aOptions.exceptionHandler]
  }

  $self._tokenSecret[]
  $self._tokenSerializer[base64]

  $self._requestToken[]
  $self._formToken[]
  $self.isValidRequest(true)

  $self._safeHTTPMethods[
    $._default(false)
    $.get(true)
    $.head(true)
    $.options(true)
    $.trace(true)
  ]
  $self.REASON_NO_CSRF_COOKIE[CSRF cookie not set.]
  $self.REASON_BAD_TOKEN[CSRF token missing or incorrect.]

  $self.REASON_NO_REFERER[Referer checking failed - no Referer.]
  $self.REASON_BAD_REFERER[Referer checking failed - Referer does not match any trusted origins.]
  $self.REASON_MALFORMED_REFERER[Referer checking failed - Referer is malformed.]
  $self.REASON_INSECURE_REFERER[Referer checking failed - Referer is insecure while host is secure.]

@GET_tokenSecret[]
  $result[$self.tokenSecret]

@GET_formFieldName[]
  $result[$self._formFieldName]

@makeToken[aOptions] -> [a token string]
## aOptions.log
  $result[^self._cryptoProvider.makeToken[
    $.secret[^self.ifdef[$self._tokenSecret]{^self._makeNewSecret[]}]
    $.salt[^math:uid64[]]
    $.ts[^_now.iso-string[]]
  ][
    $.serializer[$self._tokenSerializer]
    $.log[^self.ifdef[$aOptions.log]{-- Make a csrf token.}]
  ]]

@processRequest[aAction;aRequest;aController;aProcessOptions] -> []
  $result[]
  $lSecret[^self._getSecretFromRequest[$aRequest]]
  ^aRequest.assign[$.[$self._requestVarName][$self]]

  ^if(!$self._safeHTTPMethods.[^aRequest.method.lower[]]
    && !^self._hasExempt[$aRequest]
  ){
#   Проверяем токен
    ^if(!def $result && !def $self._requestToken){
      $self.isValidRequest(false)
      $result[^pfResponse::create[$self.REASON_NO_CSRF_COOKIE;$.status[403]]]
    }
    ^if(!def $result){
      ^try{
        $lFormToken[$aRequest.form.[$self._formFieldName]]
        ^if(!def $lFormToken){
#         Если нам не прислали токен в форме, то смотрим http-заголовок
          $lFormToken[$aRequest.headers.[$self._headerName]]
        }
        $lFormTokenData[^self._cryptoProvider.parseAndValidateToken[$lFormToken;
          $.serializer[$self._tokenSerializer]
          $.log[-- Parse a request csrf token.]
        ]]
        ^if(!def $self._requestToken.secret
            || $lFormTokenData.secret ne $self._requestToken.secret
        ){
          ^throw[csrf.invalid.token;$self.REASON_BAD_TOKEN]
        }
        $self._formToken[$lFormTokenData]

#       Проверяем реферер, если нам прислали запрос по https.
#       Для нешифрованного соединеня проверять реферер не имеет смысла —
#       «мужик посередине» может подделать любые поля запроса.
        ^if($aRequest.isSECURE){
          $lReferer[^aRequest.header[referer]]
          ^if(!def $lReferer){
            ^throw[csrf.invalid.referer;$self.REASON_NO_REFERER]
          }

#         При парсинге реферера считаем, что нам никогда не приходит реферер
#         с логином и паролем. Потому что в гет-параметрах могут запросто передать @,
#         что сразу ломает проверку реферера.
          $lReferer[^pfString:parseURL[^lReferer.lower[];$.skipAuth(true)]]
          ^if(!$lReferer){
            ^throw[csrf.invalid.referer;$self.REASON_MALFORMED_REFERER]
          }
          ^if($lReferer.protocol ne "https"){
            ^throw[csrf.invalid.referer;$self.REASON_INSECURE_REFERER]
          }

          $lGoodReferer[$self._cookieDomain]
          ^if(def $lGoodReferer){
            ^if($aRequest.PORT ne "80" && $aRequest.PORT ne "443"){
              $lGoodReferer[${lGoodReferer}:$aRequest.PORT]
            }
          }{
             $lGoodReferer[$aRequest.HOST]
          }
          $lGoodHosts[^hash::create[$self._trustedOrigins]]
          $lGoodHosts.[^math:uid64[]][$lGoodReferer]

          $lValidReferer(false)
          ^lGoodHosts.foreach[_;lHost]{
            ^if(^self._isSameDomain[$lReferer.netloc;$lHost]){
              $lValidReferer(true)
              ^break[]
            }
          }
          ^if(!$lValidReferer){
            ^throw[csrf.invalid.referer;$self.REASON_BAD_REFERER]
          }
        }

#       Удаляем поле с токеном из request.form
        ^aRequest.form.delete[$self._formFieldName]
      }{
        ^if($self._exceptionHandler is junction){
          $exception.handled(true)
          $self.isValidRequest(false)
          $result[^self._exceptionHandler[$aRequest;$exception]]
        }($exception.type eq "csrf.invalid.referer"
          || $exception.type eq "csrf.invalid.token"
          || $exception.type eq "security.invalid.token"
        ){
          $exception.handled(true)
          $self.isValidRequest(false)
          $result[^pfResponse::create[^if($exception.type eq "security.invalid.token"){$self.REASON_BAD_TOKEN}{$exception.source};$.status[403]]]
        }
      }
    }
  }

@processResponse[aAction;aRequest;aResponse;aController;aProcessOptions] -> [response]
## aResponse.csrfCookieNeedsReset(false) — обновить серкрет в куке
  $result[$aResponse]
  ^if(^aRequest.csrfCookieNeedsReset.bool(false)){
#   Если нам дали команду обновить куку, то обновляем секрет
    ^_makeNewSecret[]
  }
  ^if(!^self._hasExempt[$aRequest]){
    $aResponse.cookie.[$self._cookieName][
      $.value[^self.makeToken[$.log[-- Make a cookie csrf token.]]]
      $.expires($self._cookieAge)
      ^if(def $self._cookieDomain){
        $.domain[$self._cookieDomain]
      }
      $.path[$self._cookiePath]
      $.httponly($self._cookieHTTPOnly)
      $.secure($self._cookieSecure)
    ]
  }

@tokenField[]
  $result[<input type="hidden" name="$self._formFieldName" value="^taint[html][^self.makeToken[$.log[-- Make a form csrf token.]]]" />]

@tokenMetaTag[]
  $result[
    <meta name="csrf-token" content="^taint[^self.makeToken[$.log[-- Make a meta csrf token.]]]" />
    <meta name="csrf-name" content="$self._formFieldName" />
  ]

#----- Private -----

@_makeNewSecret[] -> [a secret string]
  $self._tokenSecret[^math:uuid[]]
  $result[$self._tokenSecret]

@_getSecretFromRequest[aRequest] -> [a secret string]
  ^if(!def $self._tokenSecret){
    ^try{
      $lToken[$aRequest.cookie.[$self._cookieName]]
      $lData[^self._cryptoProvider.parseAndValidateToken[$lToken;
        $.serializer[$self._tokenSerializer]
        $.log[-- Parse a cookie csrf token.]
      ]]
      $self._requestToken[$lData]
      $self._tokenSecret[$lData.secret]
    }{
      ^if($exception.type eq "security.invalid.token"){
        $exception.handled(true)
      }
    }
  }
  ^if(!def $self._tokenSecret){
    $self._tokenSecret[^self._makeNewSecret[]]
  }
  $result[$self._tokenSecret]

@_hasExempt[aRequest]
  $result(false)
  ^self._pathExempt.foreach[_;v]{
    ^if(^aRequest.PATH.match[$v][]){
      $result(true)
      ^break[]
    }
  }

@_isSameDomain[aHost;aPattern] -> [bool]
## Проверяет соответсвует ли домен aHost домену aPattern.
## Если aPattern  начинается с точки, то проверяем является ли aHost поддоменом aPattern.
## Паттерн ".example.com" совпадет с хостами "example.com" и "foo.example.com".
  $result(false)
  ^if(^aPattern.left(1) eq "."){
    $result(^aHost.right(^aPattern.length[]) eq $aPattern
      || $aHost eq ^aPattern.mid(1)
    )
  }{
     $result($aHost eq $aPattern)
   }
