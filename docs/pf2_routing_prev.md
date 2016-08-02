Маршрутизация в PF2 до введения глобальной марщрутизации
========================================================

Маршрутизация — процесс поиска обработчика по uri.
Обработчик — функция с одним параметром (@onAction[aRequest]), в параметре передаем объет с запросом.

lib/web/controllers.p
---------------------

Модуль — объект класса pfController.

Модули могут быть вложенными. Всегда есть один главнй модуль — менеджер. Точка входа в приложение — метод pfController.run.

Модуль вкладываются друг в друга через pfController.AssignModule[aName;aClassDef;aArgs].
Модуль монтируется в точку $aName отностиельно текущего модуля или в aArgs.mountTo.


@pfController.run[aRequest;aOptions] -> []

  Определяет объект объект с запросом. Объект берем из параметра метода, из поля self.request или создаем объект класса pfRequest.

  uri передается в поле request.ACTIOM

  Вызывает метод pfController.dispatch[request.ACTION;request].
  Результат диспатча — объект pfResponse.

  В конце выполняет response.apply, который выставляет заголовки и отдает Парсеру тело ответа.


@pfController.dispatch[aAction;aRequest;aOptions]
// aAction — часть uri, которую надо обработать модулю
// aOptions.prefix — часть uri, которую уже обработали вышестоящие модули
//                   префикс является ссылкой на корень текущего модуля.

  Определяет процедуру прохождения запроса по контролеру. Непосредственно никакой маршрутизации не выполняет. Перекрываем, если нам надо глобально поменять схему обработки запроса. Стадии: обработка запроса, обработка экшна, обработка ответа или исключения. Чтобы поменять стадии, то перекрываем методы processRequest, processAction, processResponse и processException.

  Устанавливает переменные self.request и self.action по параметрам. Нужно для «глобального» доступа к запросу и куску uri в обработчиках.

  Запускает цикл мидваре для запросов. Мидлвари просматриваются в прямом порядке. Для каждого вызываем pfMiddleware.processRequest[action;request;options]. Если результат объект, то прерываем дальнейшую обработку запроса и возвращаем, объект pfResponse который вернула мидлваре.

  Запускам метод self.processRequest[action;request;options]. Метод возвращает модифицированный объект запроса. Если в поле request.response есть объект, то прерываем обработку запроса и возвращаем объект request.response как результат диспатча.

  Снова присваимваем переменные self.action и self.request, но уже с объектами прошедшими обработку мидлваре и self.processRequest.

  Внтури try делаем последовательно вызовы self.processAction[action;request;prefix;options] -> [response] и self.processResponse[action;request;response;options] -> [response].

  В catch-секции вызываем self.processException[action;request;exception;options] -> [response].

  После try вызываем цепочку response-мидлварей в обратном порядке. Для каждой мидлвари вызываем метод pfMiddleware.processResponse[action;request;response;self;options]. response «по конвееру» передаем каждому следующему мидлваре.

  Результат обработки — response — возврашаем в вызывающий метод.


@processRequest[aAction;aRequest;aOptions] -> [$.action[] $.request[] $.prefix[] $.response[]]
// $result[$.action[] $.request[] $.prefix[] $.render[]] — экшн, запрос, префикс, параметры шаблона, которые будут переданы обработчикам
  Выполняет обраотку обхекта запроса.

  Вызывает метод self.rewriteAction[action;request;options], который возвращает объект rewrirte[$.action $.args $.prefix $.render].

  Добавляет поля объекта rewrite.args в request через метод request.assign[rewrite.args].

  Возвращает из метода объкет [$.action $.request $.prefix $.render].

@rewriteAction[aAction;aRequest;aOptions]
// Вызывается каждый раз перед диспатчем — внутренний аналог mod_rewrite.
// $result.action — новый экшн.
// $result.args — параметры, которые надо добавить к аргументам и передать обработчику.
// $result.prefix — локальный префикс, который необходимо передать диспетчеру
// Стандартный обработчик проходит по карте преобразований и ищет подходящий шаблон,
// иначе возвращает оригинальный экшн.

  Вызывает метод роутинга класса pfRouter — router.router[action;$.args[$aRequest]] -> [$.action $.args $.prefix $.render]

  Если роутер не вернул результат, то возвращаем объект-заглушку: [$.action[$aAction] $.args[] $.prefix[]]
  Если result.args пустой, то кладем в result.args переменную пустой хеш.

@processAction[aAction;aRequest;aLocalPrefix;aOptions] -> [response]
// Производит вызов экшна.
// aOptions.prefix — префикс, сформированный в processRequest.

  Сохраняем aAction и aRequest в локальных переменных.

  Если задан aLocalPrefix, то записываем его в self.localPrefix. Если задан aOptions.prefix, то записываем его в переменную self.prefix. Эти переменные могут понадобится в обработчиках.

  Ищем имя модуля в экшне через метод _findModule[aAction]. _findModule берет список модулей и последовательно сравнивает mountTo каждого модуля регулярным выражением «начало строки + mountTo». Как только нашли первое совпадение, выходим из метода и возвращаем объект с найденным модулем.

  Если модуль найден:
  * Кладем в self.activeModule имя моудля.
  * Если у нас есть метод onModule, то зовем его вместо вызова метода dispatch модуля.
  * Иначе зовем метод dispatch модуля: ^module.dispatch[action;request;$.prefix[$self.uriPrefix/(aLocalPrefix|module.mountTo)]].

  Если модуля не найден:
  * Ищем обработчик через метод _findHandler[action;request].
  * Если обработчик найден, то зовем (^self.[handler][request]) его и кладем результат в result.
  * Если обработчика нет, то вызываем abort(404).

@abort[aStatus;aData]
  ^throw[http.^aStatus.int(500);$aData]

@_findHandler[aAction;aRequest]
// Ищет и возвращает имя функции-обработчика для экшна.

  Строит имя функции по action. Делит обработчик по слешам, капитализирует первую букву частей и собирает в строку с префиксом on. /one/two/three —> onOneTwoThree.

  Если не удалось построить имя функции или функции нет, то ищем обработчик onDEFAULT. Если он есть, то присваиваем его имя в result.

  Ищем метод по http-методу из aRequest. Если есть метод onActionVERB (onOneTwoThreeGET), то возвращаем его.


@processResponse[aAction;aRequest;aResponse;aOptions] -> [response]
// aOptions.passPost(false) — не делать постобработку запроса.
// aOptions.passWrap(false) — не формировать объект вокруг ответа из строк и чисел.

  Метод вызывается для обработки результата работы экшна. Возвращает response-объект Умеет оборачивать простые типы данных в response-объекты.

  Для строк и чисел: создает объект pfResponse[value;$.type[self._defaultResponseType]].
  Для хешей: pfResponse[response.body;response]. Используем поля из response в конструкторе pfResponse. По-умолчанию $.type[self._defaultResponseType].

  Ищем постобработчик в контролере по шаблону postTYPE (postHTML, postTEXT, postJSON) или postDEFAULT. Если нашли, то вызываем его и результат кладем в result.


@processException[aAction;aRequest;aException;aOptions] -> [response]
// Обрабатывает исключительную ситуацию, возникшую в обработчике.
// aOptions.passProcessResponse(false)

  Метод вызывает dispatch, если в processAction или processResponse возник эксепшн.

  Смотрит на значение aException.type и выполняет действия:
  * http.404: Ищет метод onNOTFOUND и зовет его, если возможно.
  * http.301: $result[^pfResponseRedirect::create[$aException.source;301]]
  * http.302: $result[^pfResponseRedirect::create[$aException.source]]

  Если ответ не обработан, то зовет обработчик processResponse[action;request;[result];options].
  Если нам передали passProcessResponse(true), то постобработку не делаем. Это нужно, если мы перекрываем метод processException и не хотим сделать двойную обработку результата обработки исключения.





