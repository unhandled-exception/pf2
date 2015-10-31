# PF2 Library

@USE
pf2/lib/common.p


@CLASS
_pfHTTPRequest

@create[aOptions][ifdef]
## aOptions — хеш с переменными объекта, которые надо заменить. [Для тестов.]
  $ifdef[$pfClass:ifdef]
  $__CONTEXT__[^hash::create[]]

  $fields[^ifdef[$aOptions.fields]{$form:fields}]
  $tables[^ifdef[$aOptions.tables]{$form:tables}]
  $files[^ifdef[$aOptions.files]{$form:files}]

  $cookies[^ifdef[$aOptions.cookies]{$cookie:fields}]
  $headers[^ifdef[$aOptions.headers]{$request:headers}]

  $ENV[^ifdef[$aOptions.ENV]{$env:fields}]

  $method[^ifdef[^aOptions.method.lower[]]{^request:method.lower[]}]
# Если метод нам пришел post с полем _method, то берем method из поля.
  ^if($method eq "post" && def $fields._method){
    $method[^switch[^fields._method.lower[]]{
      ^case[DEFAULT]{post}
      ^case[put]{put}
      ^case[delete]{delete}
      ^case[patch]{patch}
    }]
  }

  $URI[^ifdef[$aOptions.URI]{$request:uri}]
  $QUERY[^ifdef[$aOptions.QUERY]{$request:query}]
  $PATH[^URI.left(^URI.pos[?])]

  $ACTION[^ifdef[$aOptions.ACTION]{^ifdef[$fields.action]{$fields._action}}]

  $PORT[^ifdef[$aOptions.PORT]{^ENV.SERVER_PORT.int(80)}]
  $isSECURE(^ifdef[$aOptions.isSECURE](^ENV.HTTPS.lower[] eq "on" || $PORT eq "443"))
  $SCHEME[http^if($isSECURE){s}]

  $HOST[^ifdef[$aOptions.HOST]{^header[X-Forwarded-Host;^header[Host;$ENV.SERVER_NAME]]}]
  $HOST[$HOST^if($PORT ne "80" && ($isSECURE && $PORT ne "443")){:$PORT}]

  $REMOTE_IP[^ifdef[$aOptions.REMOTE_IP]{$ENV.REMOTE_ADDR}]
  $DOCUMENT_ROOT[^ifdef[$aOptions.DOCUMENT_ROOT]{$request:document-root}]

  $CHARSET[^ifdef[$aOptions.CHARSET]{$request:charset}]
  $RESPONSE_CHARSET[^ifdef[$aOptions.RESPONSE_CHARSET]{^response:charset.lower[]}]
  $POST_CHARSET[^ifdef[$aOptions.POST_CHARSET]{^request:post-charset.lower[]}]
  $BODY_CHARSET[^ifdef[$aOptions.BODY_CHARSET]{^request:body-charset.lower[]}]

  $BODY[^ifdef[$aOptions.BODY]{$request:body}]
  $_BODY_FILE[$aOptions.BODY_FILE]

  $isAJAX(^ifdef[$aOptions.isAJAX](^headers.[X_REQUESTED_WITH].pos[XMLHttpRequest] > -1))
  $clientAcceptsJSON(^headers.ACCEPT.pos[application/json] >= 0)
  $clientAcceptsXML(^headers.ACCEPT.pos[application/xml] >= 0)

@GET_DEFAULT[aName]
  $result[^if(^__CONTEXT__.contains[$aName]){$__CONTEXT__.[$aName]}{$fields.[$aName]}]

@GET_BODY_FILE[]
  $result[^if(def $_BODY_FILE){$_BODY_FILE}{$request:body-file}]

@assign[*aArgs]
## Добавляет в запрос поля.
## ^assign[name;value]
## ^assign[$.name[value] ...]
  ^if($aArgs.0 is hash){
    $__CONTEXT__.add[$aArgs.0]
  }{
     $__CONTEXT__.[$aArgs.0][$aArgs.1]
   }

@header[aHeaderName;aDefaultValue][CONTEXT]
  $lName[^aHeaderName.trim[both; :]]
  $lName[^lName.replace[-;_]]
  $lName[^lName.replace[ ;_]]
  $result[$headers.[^lName.upper[]]]
  ^if(!def $result){
    $result[$aDefaultValue]
  }

@absoluteUrl[aLocation]
  $aLocation[^pfClass:ifdef[$aLocation]{$URI}]
  ^if(^aLocation.left(1) ne "/"){
    $aLocation[/$aLocation]
  }
  $result[${SCHEME}://${HOST}$aLocation]
