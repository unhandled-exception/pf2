@USE
pf2/lib/web/controllers2.p


@CLASS
pfCommonMiddleware

## Стандартные дейтсвия: антикеширующие заголовки, редирект на страницу со слешем в конце и пр.

## Пример мидлваре, которое умеет прерывать запросы не вызывая обработчик и постобработку.
## Редиректы на канонический url лучше делать средставми веб-сервера, а не через Парсер. :)

@BASE
pfMiddleware

@OPTIONS
locals

@create[aOptions]
## aOptions.appendSlash(false) — сделать редирект на url со слешем в конце.
## aOptions.disableHTTPCache(false) — выдать «антикеширующие заголовки».
  ^cleanMethodArgument[]
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
    $result.headers.cache-control[no-store, no-cache, must-revalidate, proxy-revalidate]
    $result.headers.pragma[no-cache]
  }

#--------------------------------------------------------------------------------------------------

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
  ^cleanMethodArgument[]
  ^BASE:create[$aOptions]
  ^pfAssert:isTrue(def $aOptions.cryptoProvider){Не задан объект для шифрования сессий (options.cryptoProvider).}

  $self._cryptoProvider[$aOptions.cryptoProvider]
  $self._sessionVarName[^ifdef[$aOptions.sessionVarName]{session}]
  $self._sessionCookieName[^ifdef[$aOptions.sessionCookieName]{session}]
  $self._sessionCookieDomain[$aOptions.sessionCookieDomain]
  $self._sessionCookiePath[$aOptions.sessionCookiePath]
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

@BASE
pfMiddleware

@OPTIONS
locals

@create[aOptions]
## aOptions.enable(false) — включить вывод отладочной информации в конце страницы.
## aOptions.sql — класс с sql-соединением
  ^cleanMethodArgument[]
  $self._enabled(^aOptions.enable.bool(false))
  $self._sql[$aOptions.sql]

@processResponse[aAction;aRequest;aResponse;aController;aProcessOptions] -> [response]
  $result[$aResponse]
  ^if($self._enabled && $aResponse.type eq "html"){
    $result.body[^result.body.match[</body>][i]{^self._template[]</body>}]
  }

@_template[]
  <div class="container"><div class="row"><div class="col-sm-12">
     ^self._debugInfo[]
  </div></div></div>

@_debugInfo[]
  <div class="hidden-xs" style="margin-top: 1.5em^; margin-bottom: 0^; color: #555^;">
    <p>Time: ^eval($status:rusage.utime + $status:rusage.stime + $sqlStat.queriesTime + $sphinxStat.queriesTime)[%.6f] (utime: ^status:rusage.utime.format[%.6f], stime: ^status:rusage.stime.format[%.6f]).<br />
    Memory: $status:memory.used KB, free: $status:memory.free KB (total: ^status:memory.ever_allocated_since_start.format[%.0f] KB, after gc: ^status:memory.ever_allocated_since_compact.format[%.0f] KB)
    </p>
    ^if(def $self._sql){
      <div class="sql-log block">
        ^self._queriesStat[$self._sql.stat]
      </div>
    }
  </div>

@_queriesStat[aStat]
  <p class="sql-stat">SQL queries: ${aStat.queriesCount} (^aStat.queriesTime.format[%.6f] сек).
       IM size: ${aStat.identityMap.size}.
       IM usage: ${aStat.identityMap.usage}.
  </p>

  <ol style="sql-queries">
     ^aStat.queries.foreach[_;it]{
       <li style="margin-bottom: 0.5em^; ^if(def $it.exception){color: #94333C}">(^it.time.format[%.6f] сек) $it.query ^if(def $it.limit){limit $it.limit} ^if(def $it.offset){offset $it.offset} ^if(def $it.exception){<span>[^taint[$it.exception.type - $it.exception.comment]]</span>} ($it.results rec, $it.memory KB, $it.type)</li>
     }
  </ol>
