
+ Переносим код метода rewriteAction в processRequest. Удаляем rewrieAction.
+ Прибиваем передачу управления методу onModule, если он определен в модуле. [Вряд ли это кому-то вообще нужно было хотябы раз. :)]
+ Убрать получение пути из _action. Получаем путь через request:uri.
+ Переписать _findHandler: два раза зовем _makeAction_name, странная логика поиска метода по глаголу.

— Сделать обработку json'а в postProcess. $result[$.body[hash] $.type[json]] -> pfResponse[$.type[json] $.body[^json:string[$result.body]]] (???)

— Переделываем pfRouter. Убираем префиксы, связваем роутер с модулем. Делаем универсальные методы для работы с путями и переменными.
— Модули монтируем в путь с переменными.


Как смонитровать моудль в путь с перемеными
-------------------------------------------

Поиск модуля в uri выполняется в _findModule. _findModule берет список модулей и последовательно сравнивает mountTo каждого модуля регулярным выражением «начало строки + mountTo». Как только нашли первое совпадение, выходим из метода и возвращаем объект с найденным модулем.

В _findModule можно сделать проверку по более сложному выражению. Т.е. мы в assignModule компилируем регулярку для mountTo и ищем по ней в _findModule. Останется разобраться как пробросить в экшн переменные из имени модуля, если они там есть.

_findModule должен будет вернуть начало (prefix) и остаток (action) uri. И переменны из префикса.


Новый синтаксис роутов
----------------------

^router.where[$.userID[\d+] $.slug[\s+]]
^router.defaults[$.filter[name]]


Функции:
^router.assign[:userID/edit;user/edit;$.where[$.userID[\d+]]] -> ^onUserEdit[$.userID[...]]
^router.assign[:userID/edit;&edit;$.as[user/edit]] — ^edit[$.userID[...]]

Модули:
^assignModule[settings;path/to/settings.p@modSettings]

// ^assignModule[account;path/to/account.p@modAccount#clients/:clientID/account;$.create[$.arg1[...] $.arg2[...]]]
// ^assignModule[profile;path/to/profile.p@modProfile#clients/:clientID/profile]

^assignModule[account;path/to/account.p@modAccount;
  $.mountTo[clients/:clientID/account]
  $.where[$.clientID[\d+]]
  $.defaults[$.filter[name]]
  $.options[$.constParam[...]]
]
-> ^router.assign[clients/:clientID/account;@account;...]
-> ^router.assign[clients/:clientID/account;$.module[account];...]


^router.assign[old/uri/:var;$.redirect[new/uri/:var]]
^router.assign[old/uri/:var;$.redirect[http://some.domain/uri/:var]]
^router.assign[old/uri/:var;
  $.redirect[
    $.to[http://some.domain/uri/:var]
    $.status[303]
  ]
]

^router.assign[about;$.render[about.pt]]
^router.assign[about;$.render[$.template[about.pt] $.context[$.var[....]]]]



Откуда брать первоначальный экшн
--------------------------------
Экшн брать из request:uri вместо form:_action

RewriteCond %{REQUEST_FILENAME} !-f
RewriteRule ^ _ind.html [L]


