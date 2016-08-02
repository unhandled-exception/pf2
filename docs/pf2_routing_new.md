
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
^router.requirements[...] (^routes.where[...]) — добавляет ограничения
^assignModule[clients#people/:id;path/to/cont.p@Controller::create] -> assignModule + router.assign[people/:id;clients]

^router.assign[clients/:id/name;clients#name/:id;$.as[clients_name]]
   module#path/to/:action или module@onActionFunction (без модуля — @onActionFunction)
   $.name -> $.as… по as строим обратный индекс
   prefix: clients/:id -> clients/104

$.requirements -> $.where

^router.resource[clients;path/to/clients.p@Clients] … формируем список марщрутов для редактирования одной командой… ???


Откуда брать первоначальный экшн
--------------------------------
Экшн брать из request:uri вместо form:_action

RewriteCond %{REQUEST_FILENAME} !-f
RewriteRule ^ _ind.html [L,QSA]


