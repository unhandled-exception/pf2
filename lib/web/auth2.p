@USE
pf2/lib/web/controllers2.p
pf2/lib/sql/models/structs.p

## Пакет с классами для авторизации

@CLASS
pfAuthBase

## Прототип класса мидлваре и класса авторизации.
##
## Наследоваться от него необязательно. Достаточно, чтобы наследник реализовывал инетрефейс мидлваре
## и добавлял в объект запроса поле с объектом пользователя.

@BASE
pfMiddleware

@OPTIONS
locals

@create[aOptions]
## aOptions.userFieldName[currentUser] — имя поля с объектом user в объекте запроса
  ^cleanMethodArgument[]
  ^BASE:create[$aOptions]

  $self._userFieldName[^ifdef[$aOptions.userFieldName]{currentUser}]
  $self._request[]

## Объект для хранения данных авторизации
## Содержит минимально-необходимый набор полей, которые любой класс авторизации должен писать в объект пользователя.
  $self._user[
    $.id[]
    $.isAuthenticated(false) # Аутентифицирован
    $.isAnonymous(true) # Анонимный пользователь
    $.isActive(false) # Активный. Устанавливаем в false, если надо разлогинить
    $.data[]
    $.can[$self.can] # Ссылка на функцию првоерки прав
  ]

@GET_user[]
  $result[$self._user]

@processRequest[aAction;aRequest;aController;aProcessOptions] -> []
  $result[]
  $self._request[$aRequest]
  ^authenticate[$aRequest]
  ^aRequest.assign[$self._userFieldName;$self._user]

@authenticate[aRequest]
  $result[]

@can[aPermisson] -> [bool]
  $result(false)

#--------------------------------------------------------------------------------------------------

@CLASS
pfRemoteUserAuth

## Авторизация на основе поля REMOTE_USER.
## Подходит для basic-auth в Apache.
##
## В наследнике можно перекрыть метод getUser, чтобы загружить из базы данных данные пользователя по логину.

@BASE
pfAuthBase

@OPTIONS
locals

@create[aOptions]
  ^cleanMethodArgument[]
  ^BASE:create[$aOptions]

@authenticate[aRequest]
  $result[]
  $self._user.id[^ifdef[$aRequest.ENV.REMOTE_USER]{$aRequest.ENV.REDIRECT_REMOTE_USER}]
  $self._user.isAuthenticated(true)
  $self._user.isAnonymous(false)
  $self._user.isActive(true)
  ^if(def $self._user.id){
    $self._user.data[^getUser[$self._user.id]]
  }

@getUser[aID;aOptions]
  $result[$.login[$aID]]

#--------------------------------------------------------------------------------------------------

@CLASS
pfUserRolesAuth

## Авторизация на основе кук с поддержкй ролей пользователей.
## Реализует интерфейс мидлваре. Данные хранит в СУБД.

@BASE
pfClass

@OPTIONS
locals

@create[aOptions]
## aOptions.sql
## aOptions.cryptoProvider
## aOptions.userFieldName[currentUser] — имя поля с объектом user в объекте запроса
## aOptions.usersTableName
## aOptions.usersModel[pfUsersModel]
## aOptions.authCookieName[auth_token] — имя куки для хранения сессий.
## aOptions.authCookieDomain — домен для куки сессии
## aOptions.authCookiePath — путь для куки сессии
## aOptions.expires[days(365)|date|session] — срок жизни куки. По-умолчанию ставим ограничение куку на год.
  ^cleanMethodArgument[]
  $self.CSQL[$aOptions.sql]
  $self._cryptoProvider[$aOptions.cryptoProvider]

  $self._userFieldName[^ifdef[$aOptions.userFieldName]{currentUser}]
  $self._request[]

  $self._authCookieName[^ifdef[$aOptions.authCookieName]{auth_token}]
  $self._authCookieDomain[$aOptions.authCookieDomain]
  $self._authCookiePath[$aOptions.authCookiePath]
  $self._expires[^ifdef[$aOptions.expires]{365}]

  $self._usersTableName[^ifdef[$aOptions.usersTableName]{auth_users}]
  $self.users[^ifdef[$aOptions.usersModel]{^self._createUsersModel[]}]

  $self._currentUser[^self._makeUser[]]
  $self._hasAuthCookie(false)

  $self._tokenData[^hash::create[]]

@GET_currentUser[]
  $result[$self._currentUser]

@_createUsersModel[aOptions]
  $result[^pfUsersModel::create[
    $.sql[$CSQL]
    $.tableName[$self._usersTableName]]
  ]

@processRequest[aAction;aRequest;aController;aProcessOptions] -> []
  $result[]
  ^if(def $aRequest.cookie.[$self._authCookieName]){
    ^authenticate[$aRequest]
    $self._hasAuthCookie(true)
  }
  ^aRequest.assign[$self._userFieldName][$self.currentUser]

@processResponse[aAction;aRequest;aResponse;aController;aProcessOptions] -> [response]
  $result[$aResponse]
  ^if($self.currentUser.isActive && $self.currentUser.isAuthenticated){
    $result.cookie.[$self._authCookieName][
      $.value[^self._makeAuthToken[]]
      $.httponly(true)
      $.expires[$self._expires]
      ^if(def $self._authCookieDomain){$.domain[$self._authCookieDomain]}
      ^if(def $self._authCookiePath){$.path[$self._authCookiePath]}
    ]
  }{
#    Если у нас неактивный пользователь и у нас была авторизационная кука, то удаляем ее.
     ^if($self._hasAuthCookie){
       $result.cookie.[$self._authCookieName][]
     }
   }

@authenticate[aRequest;aOptions] -> []
  $result[]
  ^try{
    $lToken[^self._cryptoProvider.parseAndValidateToken[$aRequest.cookie.[$self._authCookieName];
      $.log[-- Decrypt an auth cookie ($self._authCookieName).]
    ]]
    $lUser[^self.users.one[
      $.userID[$lToken.id]
      $.secureToken[$lToken.token]
      $.isActive(true)
    ]]
    ^if($lUser){
      ^self._currentUser.delete[]
      ^self._currentUser.add[^self._makeUser[
        $.id[$lUser.userID]
        $.data[$lUser]
        $.isActive(true)
        $.isAnonymous(false)
        $.isAuthenticated(true)
      ]]
    }
  }{
     ^if($exception.type eq "security.invalid.signature"){
       $exception.handled(true)
     }
   }

@_makeAuthToken[aOptions] -> [serialized binary string]
  $result[]
  ^if($self._currentUser.isAuthenticated){
    $result[^self._cryptoProvider.makeToken[
      $.id[$self._currentUser.id]
      $.token[$self._currentUser.data.secureToken]
    ][
      $.log[-- Encrypt an auth cookie ($self._authCookieName).]
    ]]
  }

@login[aRequest;aOptions] -> [bool]
  $result(false)
  $lUser[^self.users.one[
    $.login[$aRequest.login]
    $.isActive(true)
  ]]
  ^if($lUser){
    ^self._currentUser.delete[]
    ^self._currentUser.add[^self._makeUser[
      $.id[$lUser.userID]
      $.data[$lUser]
      $.isActive(true)
      $.isAnonymous(false)
      $.isAuthenticated(true)
    ]]
    $result(true)
  }

@logout[aRequest;aOptions] -> []
  $result[]
  ^self._currentUser.delete[]
  ^self._currentUser.add[^self._makeUser[
    $.isActive(false)
  ]]

@can[aPermission;*aCode] -> [bool | *aCode result]
## Варианта вызова метода:
## — ^if(^aRequest.currentUser.can[...]){__code__}
## — ^aRequest.currentUser.can[...]{__true code__}
## — ^aRequest.currentUser.can[...]{__true code__}{__false code__}
  $result(
    $self._currentUser.isAuthenticated
    && ^self.users.can[$self._currentUser.data;$aPermission]
  )
  ^if($aCode){
    ^if($result){
      $result[$aCode.0]
    }{
       $result[$aCode.1]
     }
  }

@_makeUser[aOptions] -> [hash]
  $result[
    $.id[]
    $.isAuthenticated(false) # Аутентифицирован
    $.isAnonymous(true) # Анонимный пользователь
    $.isActive(false) # Активный. Устанавливаем в false, если надо разлогинить
    $.data[]
    $.MANAGER[$self]
    $.can[$self.can]
  ]
  ^result.add[$aOptions]

#--------------------------------------------------------------------------------------------------

@CLASS
pfUsersModel

## Базовая модель для хранения пользователей

@BASE
pfModelTable

@OPTIONS
locals

@create[aOptions]
## aOptions.tableName[auth_users]
  ^BASE:create[^hash::create[$aOptions]
    $.tableName[^ifdef[$aOptions.tableName]{auth_users}]
  ]

  ^addFields[
    $.userID[$.dbField[user_id] $.processor[uint] $.primary(true) $.widget[none]]
    $.login[$.label[]]
    $.password[$.label[]]
    $.secureToken[$.dbField[secure_token] $.label[]]
    $.isAdmin[$.dbField[is_admin] $.processor[bool] $.default(false) $.label[]]
    $.isActive[$.dbField[is_active] $.processor[bool] $.default(true) $.widget[none]]
    $.createdAt[$.dbField[created_at] $.processor[auto_now] $.skipOnUpdate(true) $.widget[none]]
    $.updatedAt[$.dbField[updated_at] $.processor[auto_now] $.widget[none]]
  ]

@delete[aUserID]
  $result[^modify[$aUserID;$.isActive(false)]]

@restore[aUserID]
  $result[^modify[$aUserID;$.isActive(true)]]

@makePasswordHash[aPassword;aSalt] -> [string]
  $result[^math::crypt[$aPassword;^ifdef[$aSalt]{^$apr1^$}]]

@can[aUser;aPermission] -> [bool]
  $result(false)
  ^if($aUser){
    $result($aUser.isAdmin)
  }
