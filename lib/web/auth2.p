@USE
pf2/lib/web/controllers2.p


@CLASS
pfAuthBase

## Базовый класс мидлваре и класса авторизации.

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

# Объект для хранения данных авторизации
  $self._user[
    $.id[]
    $.isAuthenticated(false)
    $.isAnonymous(true)
    $.data[]
    $.can[$self.can]
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

@getUser[aID;aOptions]
  $result[^hash::create[]]

#--------------------------------------------------------------------------------------------------

@CLASS
pfRemoteUserAuth

## Авторизация на основе поля REMOTE_USER

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
  $self._user.data[^getUser[$self._user.id]]
