@USE
pf2/lib/web/controllers.p

# https://docs.djangoproject.com/en/1.10/ref/csrf/

# — Ставим сессионную куку csrftoken с постоянным секретом и переменной солью.
#   Обновлять куку безопано — секрет берем из куки и обновляем только соль.
# — Куку можност авить http-only, если нет Аякс запросов.
# — В форму добавляем скрытое поле csrftoken с токеном.
# — Если нам пришел запрос с небезопасным методом, то сравниваем секреты в куке и токене. Безопасным методами считаем GET, HEAD, OPTIONS или TRACE.
# — Если запрос пришел Аяксом и в форме нет инпута, то проверям заголовко X-CSRFToken.

# — При логине обновляем секрет в токене.
#   if not getattr(request, 'csrf_cookie_needs_reset', False):

# — Сделать исключения для урлов.
#   Пример: aOptions.sslRedirectExempt[hash<$.name[regexp]>] — хеш с регулярными выражениями для путей в урлах, которые не надо редиректить. Решудяркой может быть строка или объект regex. По-умолчанию регулярки case-insensiteve, если надо иное, то явно создаем regex-объект.


# На будущее:
# — Проверять реферер.
# — Соль в токене можно использовать для антифлуда. При посте формы, пишем соль в хранилище на 60 минут. Антифлуд проверям в обработчиках.

@CLASS
pfCSRFMiddleware

@OPTIONS
locals

@BASE
pfMiddleware

@create[aOptions]
## aOptions.cookieAge[365] — время жизни csrf-куки в днях
## aOptions.cookieDomain[] — домен csrf-куки
## aOptions.cookieHTTPOnly(false) — ставим куку только для http. Перестанет работать ajax-post
## aOptions.cookieName[csrftoken] — имя csrf-куки
## aOptions.cookiePath[/] — путь csrf-куки
## aOptions.cookieSecure(false) —  ставим куку только на https
## aOptions.formName[csrf_form_token] — имя поля формы с токеном
## aOptions.headerName[X-CSRFToken] — http-заголовок с токеном
## aOptions.pathExempt[hash<$.name[regexp]>] — хеш с регулярными выражениями для путей в урлах, которые не надо обрабатывать в мидлваре.
  ^self.cleanMethodArgument[]

  $self._cookieAge[^self.ifdef[$aOptions.cookieAge]{365}]
  $self._cookieDomain[^self.ifdef[$aOptions.cookieDomain]]
  $self._cookieHTTPOnly[^aOptions.cookieHTTPOnly.bool(false)]
  $self._cookieName[^self.ifdef[$aOptions.cookieName]{csrftoken}]
  $self._cookiePath[^self.ifdef[$aOptions.cookiePath]{/}]
  $self._cookieSecure[^aOptions.cookieSecure.bool(false)]

  $self._formName[^self.ifdef[$aOptions.formName]{csrf_form_token}]
  $self._headerName[^self.ifdef[$aOptions.headerName]{X-CSRFToken}]

  $self._pathExempt[^hash::create[$aOptions.pathExempt]]

@processRequest[aAction;aRequest;aController;aProcessOptions] -> []
  $result[]

@processResponse[aAction;aRequest;aResponse;aController;aProcessOptions] -> [response]
  $result[$aResponse]
