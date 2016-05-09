# PF2 Library

@USE
pf2/lib/common.p

@CLASS
pfCurlFile

## Класс для загрузки файлов через консольный curl.
##
## Обеспечивает интерфейс, подобный стандартному классу "file",
## но для загрузки используется косольная утилита curl.
## В качестве адреса необходимо указывать строку с полным URL.
##
## Рекомендуем всегда использовать класс common.p@pfCFile.
## pfCurlFile оставлен в библиотеки, поскольку поддерживает опцию write-out,
## которая пока не реализована в Пасреровском классе curl.

@OPTIONS
locals

@BASE
pfClass

@auto[aFilespec]
  ^if(def $MAIN:CURL_PATH && -f $MAIN:CURL_PATH){
    $self._CURL_PATH[$MAIN:CURL_PATH]
  }{
     $self._CURL_PATH[$MAIN:__PF_ROOT__/net/bin/curl]
   }
  $self._protocols[
    $._default(false)
    $.http(true)
    $.https(true)
    $.ftp(true)
    $.file(true)
  ]

  $self._defaultUserAgent[parser3 (pfCurlFile)/$env:PARSER_VERSION]
  $self._throwPrefix[$self.CLASS_NAME]

@load[aFormat;aURL;aArgs1;aArgs2][lMatches]
## ^pfCurlFile::load[format;url;options]
## ^pfCurlFile::load[format;url;new_name;options]

## aFormat[text|binary] — формат файла.
## aURL[] — путь к файлу.

## options.charset[$request:charset] — кодировка.
## options.timeout(2) — таймаут в секундах.
## options.user — имя пользователя.
## options.password — пароль.

## options.offset, aOptions.limit — загрузить только определенное количество байт.
##                               Отработает, если эта фича поддерживается сервером.

## HTTP
## options.compressed(false) — использовать компрессию для http-соединений.
## options.headers[ $.HTTP-ЗАГОЛОВОК[значение] ... ] — значение может быть строкой
##                               или именованной таблицей с одной колонкой.
## options.form[$.name[] ...] — параметры запроса. Значением может выступать
##                               строка или таблица строк с одним столбцом.
##                               Не передаются, если метод HEAD.
## options.body[] — заменяет запрос. Если задан body, то form игнорируется.
## options.any-status — игнорировать ошибочные результаты http-ответов.

## SSL

  ^if($aArgs1 is hash){
    $self._options[^hash::create[$aArgs1]]
    $self._name[]
  }{
     $self._name[$aArgs1]
     ^if($aArgs2 is hash){
       $self._options[^hash::create[$aArgs2]]
     }{
        $self._options[^hash::create[]]
      }
   }

  $self._withStat(false)
  $self._boundary[==========^math:uid64[]]

  ^if(!def ${_options.user-agent}){$self._options.user-agent[$self._defaultUserAgent]}
  $self._options.timeout(^self._options.timeout.int(2))

  $self._URL[^pfString:parseURL[$aURL]]
  ^if(!$self._URL){
    ^self._throw[3]
  }
  $self._format[$aFormat]

  $self._isBinary($aFormat eq "binary")
  $self._isHTTP($self._URL.protocol eq "http" || $self._URL.protocol eq "https")
  $self._isSSL($self._URL.protocol eq "https")
  $self._canParseHeaders($self._isHTTP && $aFormat eq "text")

  $self._headers[^hash::create[]]
  $self._tables[^hash::create[]]
  $self._content-type[]

  $lENV[^hash::create[]]
  ^if(def $self._options.charset){
    $lENV.charset[$self._options.charset]
  }
  ^if($self._isHTTP && def $self._options.body){
    $lENV.stdin[$self._options.body]
  }

  $self._file[^file::exec[$aFormat;$self._CURL_PATH;$lENV;^self._makeOptions[]]]
  ^if($self._file.status){
    ^self._throw[$self._file.status;$self._file.stderr]
  }

# Разделяем результат на заголовки и тело
  ^if($self._isHTTP){
    ^if($self._canParseHeaders){
      ^self._file.text.match[^^(?:HTTP/1\.1\s100.+?\n\n)*(.+?)\n\n(.*)^$][i]{
        $self._file[^file::create[text;$self._URL.url;$match.2]]
        ^match.1.match[^^HTTP\S+\s(\d+)(.*?)\n][]{$self._status($match.1) $self._comment[$match.2]}
        $lMatches[^match.1.match[^^(\S+?):\s+(.*)^$][gm]]
        ^if($lMatches){
          ^lMatches.menu{
            ^if(!def $self._headers.[$lMatches.1]){
              $self._headers.[^lMatches.1.upper[]][$lMatches.2]
              $self._tables.[^lMatches.1.upper[]][^table::create{value^#0A$lMatches.2}]
            }{
               ^self._tables.[^lMatches.1.upper[]].append{$lMatches.2}
             }
          }
        }
        ^if(def $self._headers.[CONTENT-TYPE]){
          ^self._headers.[CONTENT-TYPE].match[^^(\S+?)\^;][]{$self._content-type[$match.1]}
        }
      }
    }{
       ^if(!${_options.any-status}){
         $self._status(200)
       }
     }
  }

@GET_status[]
  $result[^self._status.int(0)]

@GET_comment[]
  $result[$self._comment]

@GET_content-type[]
  $result[^if(def ${_content-type}){$self._content-type}{$self._file.content-type}]

@GET_text[]
  $result[$self._file.text]

  ^if($self._withStat){
    $result[^result.match[${_boundary}.*;;]]
  }

@GET_size[]
  $result[$self._file.size]

@GET_stderr[]
  $result[$self._file.stderr]

@GET_headers[]
  $result[$self._headers]

@GET_name[]
  $result[^if(def $self._name){$self._name}{$self._URL.url}]

@GET_tables[]
  $result[$self._tables]

@GET_data[]
## Возврашает переменную типа file
  $result[$self._file]

@GET_stat[]
  $result[^hash::create[]]

  ^if($self._withStat){
    $result[^data.text.match[${_boundary}(.+)]]
    $result[^table::create{param^#09value^#0A^taint[as-is;$result.1]}]
    $result[^result.hash[param;value;$.type[string]]]
  }

@save[aFormat;aName]
  ^self._file.save[$aFormat;$aName]

@sql-string[]
  $result[^self._file.sql-string[]]

@base64[]
  $result[^self._file.base64[]]

@md5[]
  $result[^self._file.md5[]]

@crc32[]
  $result[^self._file.crc32[]]

@_throw[aStatus;aStdErr][lType;lSource;lComment]
  ^switch[$aStatus]{
    ^case[3]{
      $lType[url.malformat]
      $lSource[URL malformat]
      $lComment[$aStdErr]
    }
    ^case[6]{
      $lType[http.host]
      $lSource[Host not found]
      $lComment[$aStdErr]
    }
    ^case[7]{
      $lType[http.connect]
      $lSource[Failed to connect to host]
      $lComment[$aStdErr]
    }
    ^case[28]{
      $lType[http.timeout]
      $lSource[Operation timeout]
      $lComment[$aStdErr]
    }
    ^case[22]{
      $lType[http.status]
      $lSource[$aStdErr]
      $lComment[$name]
    }
    ^case[DEFAULT]{
      $lType[${_throwPrefix}.fail]
      $lSource[curl: $aStatus]
      $lComment[$aStdErr]
    }
  }
  ^throw[$lType;$lSource;$lComment]

@_makeOptions[][lColumns;lMethod;lParams;lParam]
  $result[^table::create{arg}]

  ^result.append{--connect-timeout}
  ^result.append{^taint[$self._options.timeout]}

  ^if($self._isHTTP){
    ^if(!$self._isBinary){^result.append{--include}}
    ^if(!${_options.any-status}){^result.append{--fail}}

    ^result.append{--user-agent}
    ^result.append{^taint[$self._options.user-agent]}

    ^if(^aOptions.compressed.bool(true)){^result.append{--compressed}}

    $lMethod[^if(def $self._options.method){^self._options.method.upper[]}]
    ^switch[$lMethod]{
      ^case[GET;DEFAULT]{^result.append{--get}}
      ^case[POST]{}
      ^case[HEAD]{^result.append{--head}}
    }

#   Формируем http-заголовки
    ^if($self._options.headers is hash && $self._options.headers){
      ^self._options.headers.foreach[k;v]{
        ^switch(true){
          ^case($v is table){
            $lColumns[^v.columns[]]
            ^v.menu{
              ^result.append{--header}
              ^result.append{${k}: ^taint[$v.[$lColumns.column]]}
            }
          }
          ^case($v is date){
#           Доделать работу с датами
          }
          ^case[DEFAULT]{
            ^result.append{--header}
            ^result.append{${k}: ^taint[$v]}
          }
        }
      }
    }

#   Добавляем данные из формы
    ^if(!def $self._options.body && $self._options.form is hash && $self._options.form && $lMethod ne "HEAD"){
      ^result.append{--data}
      ^result.append{^self._options.form.foreach[k;v]{^if($v is table){$lColumns[^v.columns[]]^v.menu{${k}=^taint[uri][$v.[$lColumns.column]]}[&]}{${k}=^taint[uri][$v]}}[&]}
    }

#   Обрабатываем body
    ^if(def $self._options.body && $lMethod ne "HEAD"){
      ^result.append{--data-binary}
      ^result.append{@-}
    }

  }

  ^if($self._isSSL){
#   Несекьюрный режим
    ^result.append{--insecure}
  }

# Частичная загрузка контента (только если поддерживает удаленный сервер)
  $lLimit[^self._options.limit.int(0)]
  $lOffset[^self._options.offset.int(0)]
  ^if($lLimit|| $lOffset){
    ^result.append{--range}
    ^result.append{${lOffset}-^if($lLimit){$lLimit}}
  }

  ^if(def $self._options.user){
    ^result.append{--user}
    ^result.append{^taint[$self._options.user:$self._options.password]}
  }

  ^if(!$self._isBinary && ^self._options.contains[write-out]){
    $lParams[
      $.content_type(true)
      $.filename_effective(true)
      $.ftp_entry_path(true)
      $.http_code(true)
      $.http_connect(true)
      $.local_ip(true)
      $.local_port(true)
      $.num_connects(true)
      $.num_redirects(true)
      $.redirect_url(true)
      $.remote_ip(true)
      $.remote_port(true)
      $.size_download(true)
      $.size_header(true)
      $.size_request(true)
      $.size_upload(true)
      $.speed_download(true)
      $.speed_upload(true)
      $.ssl_verify_result(true)
      $.time_appconnect(true)
      $.time_connect(true)
      $.time_namelookup(true)
      $.time_pretransfer(true)
      $.time_redirect(true)
      $.time_starttransfer(true)
      $.time_total(true)
      $.url_effective(true)
    ]
    ^if($self._options.[write-out]){
      $lParams[^lParams.intersection[$self._options.[write-out]]]
    }

    ^if($lParams){
      ^result.append{--write-out}
      ^result.append{"${_boundary}^lParams.foreach[lParam;]{$lParam\t%{$lParam}}[\n]"}

      $self._withStat(true)
    }
  }

  ^result.append{-#}
  ^result.append{^taint[$self._URL.url]}

#  ^pfAssert:fail[curl ^result.menu{$result.arg}[ ]]
