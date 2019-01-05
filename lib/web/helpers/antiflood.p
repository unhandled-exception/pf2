# PF2 Library

@CLASS
pfAntiFlood

## Класс для защиты форм от дублирования

@OPTIONS
locals

@USE
pf2/lib/common.p

@BASE
pfClass

@create[aOptions]
## aOptions.storage[pfAntiFloodHashStorage] — хранилище данных
## aOptions.path — путь к файлам для дефолтного хранилища
## aOptions.fieldName[form_token] — имя поля формы
## aOptions.expires(15*60) — сколько секунд хранить пару ключ/значение [для дефолтного хранилища]
## aOptions.ignoreLockErrors(false) — игнорировать ошибки блокировки при проверке формы
  ^self.cleanMethodArgument[]
  ^BASE:create[$aOptions]

  $self._expires(^aOptions.expires.int(15*60))
  $self._storage[^if(def $aOptions.storage){$aOptions.storage}{
    ^pfAntiFloodHashStorage::create[
      $.path[$aOptions.path]
      $.ignoreLockErrors(^aOptions.ignoreLockErrors.bool(false))
      $.expires($self._expires)
    ]
  }]
  ^self.defReadProperty[storage]

  $self._fieldName[^if(def $aOptions.fieldName){$aOptions.fieldName}{form_token}]
  ^self.defReadProperty[fieldName]


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

@OPTIONS
locals

@BASE
pfClass

@create[aOptions]
  ^BASE:create[]

@generateToken[]
## Генерирует новый токен
  ^throw[pf.runtime;A generateToken method is not implemented.]

@validateToken[aToken]
## Проверяет валидность токена
  $result(false)

@cleanup[]
  $result[]


#--------------------------------------------------------------------------------------------------

@CLASS
pfAntiFloodHashStorage

## Хранилище токенов (uuid) в хеш-файле

@OPTIONS
locals

@BASE
pfAntiFloodStorage

@create[aOptions]
## aOptions.path[/../antiflood] — имя хеш-файла для хранения ключей
## aOptions.expires(15*60) — сколько секунд хранить пару ключ/значение
## aOptions.autoCleanup(true) — автоматически очищать неиспользуемые пары
## aOptions.cleanupTimeout(60*60) — время в секундах между очистками хешфайла
## aOptions.ignoreLockErrors(false) — игнорировать ошибки блокировки при проверке формы
  ^self.cleanMethodArgument[]
  ^BASE:create[$aOptions]

  $self._path[^if(def $aOptions.path){$aOptions.path}{/../antiflood}]
  ^self.defReadProperty[path]

  $self._expires(^aOptions.expires.int(15*60) * (1.0/(24*60*60)))

  $self._autoCleanup(^aOptions.autoCleanup.bool(true))
  $self._cleanupTimeout(^aOptions.cleanupTimeout.int(60*60))
  $self._cleanupKey[LAST_CLEANUP]

  $self._hashFile[]
  $self._lockKey[GET_LOCK]

  $self._ignoreLockErrors(^aOptions.ignoreLockErrors.bool(false))
  $self._safeValue[0]
  $self._doneValue[1]


@GET_hashFile[]
  ^if(!def $self._hashFile){
    $self._hashFile[^hashfile::open[$self._path]]
  }
  $result[$self._hashFile]

@generateToken[]
## Генерирует новый токен
  ^self._process{
    $lUID[^math:uuid[]]
    ^self._set[$lUID;$self._safeValue]
  }
  $result[$lUID]

@validateToken[aToken]
## Проверяет валидность токена
  $result(false)
  $aToken[^aToken.trim[both]]
  ^try{
    ^self._process{
      ^if(def $aToken && ^self._get[$aToken] eq $self._safeValue){
        ^self._set[$aToken;$self._doneValue]
        $result(true)
      }
    }
  }{
    ^if($self._ignoreLockErrors && $exception.type eq "storage.locked"){
      $exception.handled(true)
      $result(true)
    }
  }

@cleanup[]
## Удаляет старые записи из хешфайла.
  $result[]
  $lNow[^date::now[]]
  ^if(^hashFile.[$self._cleanupKey].int(0) + $self._cleanupTimeout < ^lNow.unix-timestamp[]){
    ^hashFile.cleanup[]
    $hashFile.[$self._cleanupKey][^lNow.unix-timestamp[]]
  }


@_get[aKey;aOptions]
## Получает ключ из хранилища
  $result[$hashFile.[$aKey]]

@_set[aKey;aValue;aOptions]
## Записывает ключ в хранилище
  $hashFile.[$aKey][
    $.value[$aValue]
    ^if($self._expires){$.expires($self._expires)}
  ]
  $result[]

@_delete[aKey]
## Удаляет ключ из хранилища
  ^if(def $aKey){
    ^hashFile.delete[$aKey]
  }
  $result[]

@_process[aCode]
## Метод в который необходимо "завернуть" вызовы _get/_set
## чтобы обеспечить атомарность операций
  ^try{
    $hashFile.[$self._lockKey][^math:uuid[]]
    $result[$aCode]

    ^if($self._autoCleanup){
      ^self.cleanup[]
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
## Поддерживает MySQL и Postgres.
## В PG надо подключить расширение pgcrypto.

@OPTIONS
locals

@BASE
pfAntiFloodStorage

@create[aOptions]
## aOptions.sql[] — sql-класс
## aOptions.cryptoProvider — класс шифрования
## aOptions.table[antiflood]
## aOptions.expires(15*60) — сколько секунд хранить пару ключ/значение
## aOptions.autoCleanup(true) — автоматически очищать неиспользуемые пары
  ^self.cleanMethodArgument[]
  ^self.assert(def $aOptions.sql)[Не задан sql-класс.]
  ^self.assert(def $aOptions.cryptoProvider)[Не задан класс для шифрования токена.]

  ^BASE:create[$aOptions]

  $self._csql[$aOptions.sql]
  $self._tableName[^if(def $aOptions.table){$aOptions.table}{antiflood}]
  $self._cryptoProvider[$aOptions.cryptoProvider]

  $self._expires(^aOptions.expires.int(15*60))
  $self._autoCleanup(^aOptions.autoCleanup.bool(true))

@GET_CSQL[]
  $result[$self._csql]

@generateToken[]
## Генерирует новый токен
  ^self.CSQL.transaction{
    ^if($self._autoCleanup && ^math:random(5) == 1){
      ^self.cleanup[]
    }

    $lSalt[^math:uid64[]]
    $lSalt[^lSalt.lower[]]
    $lNow[^date::now[]]
    ^self.CSQL.void{
       insert into $self._tableName (salt, created_at)
            values ('$lSalt', '^lNow.sql-string[]')
    }
    $lID[^self.CSQL.lastInsertID[]]
  }
  $result[^self._packToken[$lID;$lSalt]]

@validateToken[aToken]
## Проверяет валидность токена
  $result(false)
  $lToken[^self._unpackToken[^aToken.trim[both]]]
  ^if($lToken){
    ^self.CSQL.transaction{
      $lNow[^date::now[]]
      $lExpires[^date::create($lNow - (^self._expires.int[]/24/60/60))]
      $lID[^self.CSQL.string{
        select id
          from $self._tableName
         where id = '^taint[$lToken.id]'
               and salt = '^taint[$lToken.salt]'
               and processed_at is null
               and created_at >= '^lExpires.sql-string[]'
         limit 1
         for update
      }[$.default{}][$.isForce(true)]]
      ^if(def $lID){
        $result(true)
        ^self.CSQL.void{update $self._tableName set processed_at = '^_now.sql-string[]' where id ='$lID'}
      }
    }
  }

@cleanup[]
## Удаляет из стораджа устаревшие записи (expires sec + 12 hours)
  $result[]
  $lExpires[^date::create(
    ^date::now[]
    - (^self._expires.int[]/24/60/60)
    - 0.5
  )]

  ^self.CSQL.void{
     delete from $self._tableName
      where created_at < '^lExpires.sql-string[]'
  }

@_packToken[aID;aSalt]
  $result[^self._cryptoProvider.makeToken[
    $.id[$aID]
    $.salt[$aSalt]
  ][
    $.log[-- Encrypt an antiflood token.]
  ]]

@_unpackToken[aToken]
## result[$.id $.salt]
  $result[^self.unsafe{^self._cryptoProvider.parseAndValidateToken[$aToken;
    $.log[-- Decrypt an antiflood token.]
  ]}]
