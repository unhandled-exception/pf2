# PF2 Library

@CLASS
pfAntiFlood

## Класс для защиты форм от дублирования

@USE
pf2/lib/common.p

@BASE
pfClass

@create[aOptions]
## aOptions.storage[pfAntiFloodHashStorage] - хранилище данных
## aOptions.path - путь к файлам для дефолтного хранилища
## aOptions.fieldName[form_token] - имя поля формы
## aOptions.expires(15*60) - сколько секунд хранить пару ключ/значение [для дефолтного хранилища]
## aOptions.ignoreLockErrors(false) - игнорировать ошибки блокировки при проверке формы
  ^cleanMethodArgument[]
  ^BASE:create[$aOptions]

  $_expires(^aOptions.expires.int(15*60))
  $_storage[^if(def $aOptions.storage){$aOptions.storage}{
    ^pfAntiFloodHashStorage::create[
      $.path[$aOptions.path]
      $.ignoreLockErrors(^aOptions.ignoreLockErrors.bool(false))
      $.expires($_expires)
    ]
  }]
  ^defReadProperty[storage]

  $_fieldName[^if(def $aOptions.fieldName){$aOptions.fieldName}{form_token}]
  ^defReadProperty[fieldName]


@field[aToken;aFieldName]
## Возвращает html-код для поля
## aToken — ксли не задан токен, то он формируется автоматически.
## aFieldName[_fieldName]
  ^if(!def $aToken){$aToken[^storage.generateToken[]]}
  $result[<input type="hidden" name="^if(def $aFieldName){$aFieldName}{$fieldName}" value="$aToken" />]

@protect[aTokenVarname;aCode]
## Формирует token в переменной aTokenVarname и выполняет код
  $caller.[$aTokenVarname][^storage.generateToken[]]
  $result[$aCode]

@process[aRequest;aNormalCode;aFailCode]
## Выполняет проверку полей запроса aRequest и выполняет код aNormalCode
## Если проверка прошла неудачно, то выполняет aFailCode
  $result[^if(^storage.validateToken[$aRequest.[$fieldName]]){$aNormalCode}{$aFailCode}]

@validateRequest[aRequest]
## Выполняет проверку полей запроса aRequest и возвращает результат.
  $result(^storage.validateToken[$aRequest.[$fieldName]])

#--------------------------------------------------------------------------------------------------

@CLASS
pfAntiFloodStorage

## Интерфейс хранилища

@BASE
pfClass

@create[aOptions]
  ^BASE:create[]

@generateToken[][lUID]
## Генерирует новый токен
  ^_abstractMethod[]

@validateToken[aToken]
## Проверяет валидность токена
  $result(false)

@cleanup[]
  $result[]


#--------------------------------------------------------------------------------------------------

@CLASS
pfAntiFloodHashStorage

## Хранилище токенов (uuid) в хеш-файле

@BASE
pfAntiFloodStorage

@create[aOptions]
## aOptions.path[/../antiflood] - имя хеш-файла для хранения ключей
## aOptions.expires(15*60) - сколько секунд хранить пару ключ/значение
## aOptions.autoCleanup(true) - автоматически очищать неиспользуемые пары
## aOptions.cleanupTimeout(60*60) - время в секундах между очистками хешфайла
## aOptions.ignoreLockErrors(false) - игнорировать ошибки блокировки при проверке формы
  ^cleanMethodArgument[]
  ^BASE:create[$aOptions]

  $_path[^if(def $aOptions.path){$aOptions.path}{/../antiflood}]
  ^defReadProperty[path]

  $_expires(^aOptions.expires.int(15*60) * (1.0/(24*60*60)))

  $_autoCleanup(^aOptions.autoCleanup.bool(true))
  $_cleanupTimeout(^aOptions.cleanupTimeout.int(60*60))
  $_cleanupKey[LAST_CLEANUP]

  $_hashFile[]
  $_lockKey[GET_LOCK]

  $_ignoreLockErrors(^aOptions.ignoreLockErrors.bool(false))
  $_safeValue[0]
  $_doneValue[1]


@GET_hashFile[]
  ^if(!def $_hashFile){
    $_hashFile[^hashfile::open[$_path]]
  }
  $result[$_hashFile]

@generateToken[][lUID]
## Генерирует новый токен
  ^_process{
    $lUID[^math:uuid[]]
    ^_set[$lUID;$_safeValue]
  }
  $result[$lUID]

@validateToken[aToken]
## Проверяет валидность токена
  $result(false)
  $aToken[^aToken.trim[both]]
  ^try{
    ^_process{
      ^if(def $aToken && ^_get[$aToken] eq $_safeValue){
        ^_set[$aToken;$_doneValue]
        $result(true)
      }
    }
  }{
    ^if($_ignoreLockErrors && $exception.type eq "storage.locked"){
      $exception.handled(true)
      $result(true)
    }
  }

@cleanup[][lNow]
## Удаляет старые записи из хешфайла.
  $result[]
  $lNow[^date::now[]]
  ^if(^hashFile.[$_cleanupKey].int(0) + $_cleanupTimeout < ^lNow.unix-timestamp[]){
    ^hashFile.cleanup[]
    $hashFile.[$_cleanupKey][^lNow.unix-timestamp[]]
  }


@_get[aKey;aOptions]
## Получает ключ из хранилища
  $result[$hashFile.[$aKey]]

@_set[aKey;aValue;aOptions]
## Записывает ключ в хранилище
  $hashFile.[$aKey][
    $.value[$aValue]
    ^if($_expires){$.expires($_expires)}
  ]
  $result[]

@_delete[aKey]
## Удаляет ключ из хранилища
  ^if(def $aKey){
    ^hashFile.delete[$aKey]
  }
  $result[]

@_process[aCode][lNow]
## Метод в который необходимо "завернуть" вызовы _get/_set
## чтобы обеспечить атомарность операций
  ^try{
    $hashFile.[$_lockKey][^math:uuid[]]
    $result[$aCode]

    ^if($_autoCleanup){
      ^cleanup[]
    }
  }{
    ^if($exception.type eq "file.access" && ^exception.comment.pos[pa_sdbm_open] > -1){
      ^throw[storage.locked;$exception.source;$exception.comment]
    }
  }{
    ^hashFile.release[]
  }


#--------------------------------------------------------------------------------------------------

@CLASS
pfAntiFloodDBStorage

## Хранилище токенов в базе данных.
## Только для MySQL, лучше использовать innodb-engine.
## token = hex(aes('id|salt', password))

@BASE
pfAntiFloodStorage

@create[aOptions]
## aOptions.sql[] - sql-класс
## aOptions.table[antiflood]
## aOptions.password[] - пароль для шифрования токена
## aOptions.expires(15*60) - сколько секунд хранить пару ключ/значение
## aOptions.autoCleanup(true) - автоматически очищать неиспользуемые пары
  ^cleanMethodArgument[]
  ^pfAssert:isTrue(def $aOptions.sql)[Не задан sql-класс.]
  ^pfAssert:isTrue(def $aOptions.password)[Не задан пароль для шифрования токена.]

  ^BASE:create[$aOptions]

  $_csql[$aOptions.sql]
  $_tableName[^if(def $aOptions.table){$aOptions.table}{antiflood}]
  $_password[$aOptions.password]

  $_expires(^aOptions.expires.int(15*60))
  $_autoCleanup(^aOptions.autoCleanup.bool(true))

@GET_CSQL[]
  $result[$_csql]

@generateToken[][lID;lSalt]
## Генерирует новый токен
  ^CSQL.transaction{
    ^if($_autoCleanup && ^math:random(5) == 1){
      ^cleanup[]
    }

    $lSalt[^math:uid64[]]
    $lSalt[^lSalt.lower[]]
    ^CSQL.void{
       insert into $_tableName (salt)
            values (0x$lSalt)
    }
    $lID[^CSQL.lastInsertID[]]
  }
  $result[^_packTocken[$lID;$lSalt]]

@validateToken[aToken][lToken;lID;lNow]
## Проверяет валидность токена
  $result(false)
  $lToken[^_unpackToken[^aToken.trim[both]]]
  ^if($lToken){
    ^CSQL.transaction{
      $lNow[^date::now[]]
      $lID[^CSQL.string{
        select id
          from $_tableName
         where id = "^taint[$lToken.id]"
               and salt = 0x^taint[$lToken.salt]
               and processed_at is null
               and created_at >= date_sub("^lNow.sql-string[]", interval ^_expires.int[] second)
         limit 1
         for update
      }[$.default{}][$.isForce(true)]]
      ^if(def $lID){
        $result(true)
        ^CSQL.void{update $_tableName set processed_at = "^_now.sql-string[]" where id ="$lID"}
      }
    }
  }

@cleanup[][lNow]
## Удаляет из стораджа устаревшие записи (expires sec + 12 hours)
  $result[]
  $lNow[^date::now[]]
  ^CSQL.void{
     delete from $_tableName
      where created_at between
              date_sub("^lNow.sql-string[]", interval 10 year)
              and date_sub("^lNow.sql-string[]", interval ^_expires.int[] + (60*60*12) second)
  }

@_packTocken[aID;aSalt]
  $result[^CSQL.string{select lower(hex(aes_encrypt('^taint[$aID|$aSalt]', '$_password')))}[][$.log[-- Encrypt an antiflood token.]]]

@_unpackToken[aToken][lString]
## result[$.id $.salt]
  $result[^hash::create[]]
  $lString[^CSQL.string{select aes_decrypt(unhex('^taint[$aToken]'), '$_password')}[][$.log[-- Decrypt an antiflood token.]]]
  ^lString.match[^^(\d+)\|([a-f0-9]{16})^$][]{
    $result.id[$match.1]
    $result.salt[$match.2]
  }
