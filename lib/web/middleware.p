@USE
pf2/lib/web/controllers.p


@CLASS
pfCommonMiddleware

## Стандартные действия: антикеширующие заголовки, редирект на страницу со слешем в конце и пр.

## Пример мидлваре, которое умеет прерывать запросы не вызывая обработчик и постобработку.
## Редиректы на канонический url лучше делать средставми веб-сервера, а не через Парсер. :)

@OPTIONS
locals

@BASE
pfMiddleware

@create[aOptions]
## aOptions.appendSlash(false) — сделать редирект на url со слешем в конце.
## aOptions.disableHTTPCache(false) — выдать «антикеширующие заголовки».
  ^self.cleanMethodArgument[]
  $self._appendSlash(^aOptions.appendSlash.bool(false))
  $self._disableHTTPCache(^aOptions.disableHTTPCache.bool(false))

@processRequest[aAction;aRequest;aController;aProcessOptions] -> []
  $result[]
  ^if(!def $result && $_appendSlash){
    ^if(^aRequest.PATH.right(1) ne "/"
        && ($aRequest.method eq "get" || $aRequest.method eq "head")
    ){
       $lPos(^aRequest.URI.pos[?])
       $lURL[$aRequest.PATH/^if($lPos >= 0){^aRequest.URI.mid($lPos)}]
       $result[^pfResponseRedirect::create[^aRequest.absoluteURL[$lURL];301]]
     }
  }

@processResponse[aAction;aRequest;aResponse;aController;aProcessOptions] -> [response]
  $result[$aResponse]
  ^if($self._disableHTTPCache){
    ^if(!^result.headers.contains[cache-control]){
      $result.headers.cache-control[no-store, no-cache, must-revalidate, proxy-revalidate]
    }
    ^if(!^result.headers.contains[pragma]){
      $result.headers.pragma[no-cache]
    }
  }

#--------------------------------------------------------------------------------------------------

@CLASS
pfSessionMiddleware

## Добавляет в объект запроса объект сессии. Хранит данные в шифрованной куке.

@OPTIONS
locals

@BASE
pfMiddleware

@create[aOptions]
## aOptions.cryptoProvider — объект с методами encrypt и decrypt для шифрования сессий.
## aOptions.sessionVarName[session] — имя переменной в объеке request в который пишем данные сессии.
## aOptions.sessionCookieName[session] — имя куки для хранения сессий.
## aOptions.sessionCookieDomain — домен для куки сессии
## aOptions.sessionCookiePath — путь для куки сессии
## aOptions.sessionCookieSecure(false) —  ставим куку только на https
## aOptions.sessionCookieSameSite[Strict]
## aOptions.expires[days(90)|date|session] — срок жизни куки. По-умолчанию ставим ограничение Парсера (90 дней).
  ^self.cleanMethodArgument[]
  ^BASE:create[$aOptions]
  ^self.assert(def $aOptions.cryptoProvider){Не задан объект для шифрования сессий (options.cryptoProvider).}

  $self._cryptoProvider[$aOptions.cryptoProvider]
  $self._sessionVarName[^ifdef[$aOptions.sessionVarName]{session}]
  $self._sessionCookieName[^ifdef[$aOptions.sessionCookieName]{session}]
  $self._sessionCookieDomain[$aOptions.sessionCookieDomain]
  $self._sessionCookiePath[$aOptions.sessionCookiePath]
  $self._sessionCookieSecure[^aOptions.sessionCookieSecure.bool(false)]
  $self._sessionCookieSameSite[^self.ifdef[$aOptions.sessionCookieSameSite]{Strict}]
  $self._expires[$aOptions.expires]

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
      $.secure($self._sessionCookieSecure)
      $.samesite[$self._sessionCookieSameSite]
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
  ^if(def $aData){
    ^try{
      $result[^self._cryptoProvider.parseAndValidateToken[$aData;$.log{-- Decrypt a session data.}]]
    }{
      ^if($exception.type eq "json.parse"
        || $exception.type eq "security.invalid.token"
      ){
        $result[^hash::create[]]
        $exception.handled(true)
      }
     }
  }{
     $result[^hash::create[]]
   }

@_serializeSession[aData] -> [string]
  $result[^self._cryptoProvider.makeToken[$aData;$.log{-- Encrypt a session data.}]]

#--------------------------------------------------------------------------------------------------

@CLASS
pfDebugInfoMiddleware

## Добавляет в конец страницы отладочную информацию и лог sql-запросов.
## Пример мидлваре, которе трогает только html-ответы.

@OPTIONS
locals

@BASE
pfMiddleware

@create[aOptions]
## aOptions.enable(true) — включить вывод отладочной информации в конце страницы.
## aOptions.sql — класс с sql-соединением
## aOptions.hideQueryLog(false) — не показывать лог соединений.
## aOptions.enableHighlightJS(false) — подключить библиотеку highlight.js и подсветить синтаксис SQL.
## aOptions.cssClass[] — классы для дива с отладочной информацией.
  ^self.cleanMethodArgument[]
  $self._enabled(^aOptions.enable.bool(true))
  $self._sql[$aOptions.sql]
  $self._enableHighlightJS(^aOptions.enableHighlightJS.bool(false))
  $self._hideQueryLog(^aOptions.hideQueryLog.bool(false))

  $self._highlightJSVersion[11.6.0]
  $self._cssClass[^self.ifdef[$aOptions.cssClass]{debug-info hidden-xs}]

@processResponse[aAction;aRequest;aResponse;aController;aProcessOptions] -> [response]
  $result[$aResponse]
  ^if($self._enabled && $aResponse.type eq "html"){
    $result.body[^result.body.match[(</body>)][i]{^self._template[]$match.1}]
    $result.body[^result.body.match[(</head>)][i]{^self._links[]$match.1}]
  }

@_links[]
  ^if($self._enableHighlightJS){
    <link rel="stylesheet" href="//cdnjs.cloudflare.com/ajax/libs/highlight.js/${self._highlightJSVersion}/styles/default.min.css">
    <script src="//cdnjs.cloudflare.com/ajax/libs/highlight.js/${self._highlightJSVersion}/highlight.min.js"></script>
    <script>
      document.addEventListener('DOMContentLoaded', () => {
        document.querySelectorAll('.sql-log-query').forEach((e) => {
          hljs.highlightElement(e)^;
        })^;
      })^;
    </script>
  }

@_template[]
  <div class="container"><div class="row"><div class="col-sm-12">
     ^self._debugInfo[]
  </div></div></div>

@_debugInfo[]
  $lRes[^pfRuntime:resources[]]
  <div class="$self._cssClass">
    <p>Time: ^eval(($lRes.utime + $lRes.stime + ^self._getSQLTime[]) * 1000)[%.3f] ms (utime: ^eval($lRes.utime * 1000)[%.3f] ms, stime: ^eval($lRes.stime * 1000)[%.3f] ms).<br />
    Memory: $lRes.used KB, free: $lRes.free KB (total: ^lRes.allocated.format[%.0f] KB, after gc: ^lRes.allocatedSinceCompact.format[%.0f] KB, $lRes.compacts compacts, limit $lRes.memoryLimit KB)
    </p>
    ^self._sqlInfo[]
  </div>

@_getSQLTime[]
  $result(0)
  ^if(def $self._sql){
    $result(^self._sql.stat.queriesTime.double(0))
  }

@_sqlInfo[]
  ^if(def $self._sql){
    <div class="sql-log block">
      ^self._queriesStat[$self._sql.stat;$self._sql.serverType]
    </div>
  }

@_queriesStat[aStat;aServerType]
  <p class="sql-stat">SQL queries^if(def $aServerType){ ($aServerType)}: ${aStat.queriesCount} (^eval($aStat.queriesTime * 1000)[%.3f] ms).
       Memory cache: ${aStat.memoryCache.size} results, ${aStat.memoryCache.usage} hits.
  </p>

  ^if(!$self._hideQueryLog){
    <ol class="sql-queries">
       ^aStat.queries.foreach[number;it]{
         <li value="^eval($number+1)" style="margin-bottom: 0.5em^; ^if(def $it.exception){color: #94333C}">
           (^eval($it.time * 1000)[%.3f] ms, $it.results rec, $it.memory KB, $it.type)
           ^if(def $it.exception){<span>[^taint[$it.exception.type — $it.exception.comment]]</span>}
           <pre class="sql-log-query"><code class="sql">^taint[html][^it.query.trim[both]]
           ^if(def $it.limit){limit $it.limit} ^if(def $it.offset){offset $it.offset}
           </code></pre>
         </li>
       }
    </ol>
  }

#--------------------------------------------------------------------------------------------------

@CLASS
pfSecurityMiddleware

## Добавляет заголовки, связанные с безопасностью в объект ответа.

## Включаем расширения при инициализации мидлваре:
## ^assignMiddleware[lib/web/middleware.p@pfSecurityMiddleware;
##    $.stsSeconds(31536000)
##    $.contentTypeNosniff(true)
##    $.xssFilter(true)
##    $.xframeOptions(true)
##
##    $.contentSecurityPolicy[*] # Можно задать заголовок Content-Security-Policy, но его надо тщательно настраивать и тестировать.
##
##    $.sslRedirect(true) # Принудительный редирект нв https
##    $.sslRedirectExempt[$.tests[^^/tests]] # Не делаем редирект, если урл начинается с /tests
##  ]
##
## Чтобы отключить xframeOptions из обработчика в контролере, надо установить
## в объекте запроса bool-переменную xframeOptionsExempt:
## @onAction[aRequest]
##  $result[
##    $.body[...]
##    $.fields[
##      $.xframeOptionsExempt(true)
##    ]
##  ]

@OPTIONS
locals

@BASE
pfMiddleware

@create[aOptions]
## aOptions.enable(true) — включить мидлваре.
## aOptions.contentSecurityPolicy[] — выдает содержимое параметра в заголовок Content-Security-Policy. https://wiki.mozilla.org/Security/Guidelines/Web_Security#Content_Security_Policy
## aOptions.stsSeconds(0) — время в секундах для заголовка Strict-Transport-Security (STS). 0 — не выводить заголовок, 3600 — час, 31536000 — год.
## aOptions.stsIncludeSubDomains(false) — добавить в STS-заголовк опцию includeSubdomains.
## aOptions.contentTypeNosniff(false) — добавить заголовок X-Content-Type-Options: nosniff.
## aOptions.xssFilter(false) — добавить заголовок X-XSS-Protection: 1; mode=block.
## aOptions.sslRedirect(false) — сделать принудительный редирект на https.
## aOptions.sslRedirectHost[request.HOST] — хост на который редиректим.
## aOptions.sslRedirectExempt[hash<$.name[regexp]>] — хеш с регулярными выражениями для путей в урлах, которые не надо редиректить. Решудяркой может быть строка или объект regex. По-умолчанию регулярки case-insensiteve, если надо иное, то явно создаем regex-объект.
## aOptions.xframeOptions(false) — включить заголовок X-Frame-Options  для защиты от кликджекинга. https://developer.mozilla.org/ru/docs/Web/HTTP/Headers/X-Frame-Options
## aOptions.xframeOptionsValue[SAMEORIGIN] — тип блокировки (значение заголовка:  SAMEORIGIN, DENY и т.д.)
  ^self.cleanMethodArgument[]
  $self.enabled(^aOptions.enable.bool(true))

  $self.contentSecurityPolicy[$aOptions.contentSecurityPolicy]
  $self.stsSeconds(^aOptions.stsSeconds.int(0))
  $self.stsIncludeSubDomains(^aOptions.stsIncludeSubDomains.bool(false))
  $self.contentTypeNosniff(^aOptions.contentTypeNosniff.bool(false))
  $self.xssFilter(^aOptions.xssFilter.bool(false))

  $self.sslRedirect(^aOptions.sslRedirect.bool(false))
  $self.sslRedirectHost[$aOptions.sslRedirectHost]
  $self.sslRedirectExempt[^hash::create[$aOptions.sslRedirectExempt]]

  $self.xframeOptions(^aOptions.xframeOptions.bool(false))
  $self.xframeOptionsValue[^self.ifdef[$aOptions.xframeOptionsValue]{SAMEORIGIN}]

@processRequest[aAction;aRequest;aController;aProcessOptions] -> [response|null]
  $result[]
  ^if($self.enabled){
    ^if($self.sslRedirect && !$aRequest.isSECURE){
      $lPath[$aRequest.PATH]
      $lPassRedirect(false)
      ^self.sslRedirectExempt.foreach[_;v]{
        ^if(^lPath.match[$v][^if($v is string){ni}]){
          $lPassRedirect(true)
          ^break[]
        }
      }
      ^if(!$lPassRedirect){
        $result[^pfResponseRedirect::create[https://^self.ifdef[$self.sslRedirectHost]{$aRequest.HOST}$lPath;301]]
      }
    }
  }

@processResponse[aAction;aRequest;aResponse;aController;aProcessOptions] -> [response]
  $result[$aResponse]
  ^if($self.enabled){
    ^if($self.stsSeconds && $aRequest.isSECURE && !^result.hasHeader[Strict-Transport-Security]){
#     STS-заголовки нужно выдавать только при соединении по https.
      $result.headers.[Strict-Transport-Security][max-age=$self.stsSeconds^if($self.stsIncludeSubDomains){^; includeSubDomains}]
    }

    ^if($self.contentTypeNosniff && !^result.hasHeader[X-Content-Type-Options]){
      $result.headers.[X-Content-Type-Options][nosniff]
    }

    ^if($self.xssFilter && !^result.hasHeader[X-XSS-Protection]){
      $result.headers.[X-XSS-Protection][1^; mode=block]
    }

    ^if(def $self.contentSecurityPolicy && !^result.hasHeader[Content-Security-Policy]){
      $result.headers.[Content-Security-Policy][$self.contentSecurityPolicy]
    }

    ^if($self.xframeOptions
        && !^result.xframeOptionsExempt.bool(false)
        && !^result.hasHeader[X-Frame-Options]
    ){
       $result.headers.[X-Frame-Options][$self.xframeOptionsValue]
     }
  }

#--------------------------------------------------------------------------------------------------

@CLASS
pfRequestIDMiddleware

## Добавляет в request поле requestID из заголовка запроса X-Request-ID
## https://www.nginx.com/blog/application-tracing-nginx-plus/

@BASE
pfMiddleware

@create[aOptions]
## aOptions.idHeaderName[X-Request-ID]
  ^BASE:create[$aOptions]
  $self.idHeaderName[^ifdef[$aOptions.idHeaderName]{X-Request-ID}]

@processRequest[aAction;aRequest;aController;aProcessOptions] -> []
  $result[]
  $aRequest.requestID[^aRequest.header[$self.idHeaderName]]
