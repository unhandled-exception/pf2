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


# На будущее:
# — Добавить timestamp в токен. ts : hex_timestamp. Проверять можно при валидации и сравнивать с cookieAge. Или сделать в токене valid_till: timestamp, чтобы токены устаревали сами.
# — Проверять реферер.
# — Соль в токене можно использовать для антифлуда. При посте формы, пишем соль в хранилище на 60 минут. Антифлуд проверям в обработчиках.

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
## aOptions.requestVarName[CSRF] — имя переменной в запросе со ссылкой на мидлваре.
  ^self.cleanMethodArgument[]
  ^BASE:create[$aOptions]

  ^pfAssert:isTrue(def $aOptions.cryptoProvider){Не задан объект для шифрования csrf-токенов (options.cryptoProvider).}
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

  $self._requestVarName[^self.ifdef[$aOtpions.requestVarName]{CSRF}]

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

@GET_tokenSecret[]
  $result[$self.tokenSecret]

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
  $lURI[]
  ^self._pathExempt.foreach[_;v]{
    ^if(^aRequest.PATH.match[$v][]){
      $result(true)
      ^break[]
    }
  }

@makeToken[aOptions] -> [a token string]
## aOptions.log
  $result[^self._cryptoProvider.makeToken[
    $.secret[^self.ifdef[$self._tokenSecret]{^self._makeNewSecret[]}]
    $.salt[^math:uid64[]]
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
          ^throw[security.invalid.token]
        }
        $self._formToken[$lFormTokenData]
      }{
        ^if($exception.type eq "security.invalid.token"){
          $exception.handled(true)
          $self.isValidRequest(false)
          $result[^pfResponse::create[$self.REASON_BAD_TOKEN;$.status[403]]]
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

@tokenField[]
  $result[<input type="hidden" name="$self._formFieldName" value="^taint[html][^self.makeToken[$.log[-- Make a form csrf token.]]]" />]
