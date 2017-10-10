ORM-классы
==========

Набор классов для объектно-реляционного отображения. В Парсере есть универсальный и очень удобный интерфейс доступа к реляционным СУБД и, вместе с широчайшими возможностями языка как шаблонизатора, работа с базами данных становится очень легкой задачей. Тем не менее, хочется иметь еще более простой способ доступа к данным. :)

## pf2/lib/sql/models/sql_table.p@pfSQLTable

Описание охватывает не все возможности класса, очень рекомендую почитать комментарии к методам классов в исходниках.

Шлюз таблицы данных (по классификации Мартина Фаулера — [Table Data Gateway](http://design-pattern.ru/patterns/table-data-gateway.html)). Позволяет выполнять с табличкой стандартный набор [CRUD](http://ru.wikipedia.org/wiki/CRUD)-операций. В самом простом случае один клас pfSQLTable связан с одной табличкой в базе данных, но можно сделать и так, чтобы наш класс прозрачно делал джоины к другим таблицам. Фактически pfSQLTable очень близко соответствует понятию [«представление»](http://ru.wikipedia.org/wiki/%D0%9F%D1%80%D0%B5%D0%B4%D1%81%D1%82%D0%B0%D0%B2%D0%BB%D0%B5%D0%BD%D0%B8%D0%B5_%28%D0%B1%D0%B0%D0%B7%D1%8B_%D0%B4%D0%B0%D0%BD%D0%BD%D1%8B%D1%85%29) (view) в СУБД.

### Пример. Cтруктура базы данных клиентов

    CREATE TABLE IF NOT EXISTS `clients` (
      `client_id` INT UNSIGNED NOT NULL AUTO_INCREMENT ,
      `title` VARCHAR(250) NOT NULL ,
      `phone` VARCHAR(250) NULL ,
      `address` TEXT NULL ,
      `post_address` TEXT NULL ,
      `email` VARCHAR(250) NULL ,
      `url` VARCHAR(250) NULL ,
      `comment` TEXT NULL ,
      `created_at` DATETIME NULL ,
      `updated_at` DATETIME NULL ,
      PRIMARY KEY (`client_id`));

    CREATE TABLE IF NOT EXISTS `clients_to_users` (
      `client_id` INT(10) UNSIGNED NOT NULL ,
      `user_id` INT(10) UNSIGNED NOT NULL ,
      `created_at` DATETIME NULL DEFAULT NULL ,
      PRIMARY KEY (`client_id`, `user_id`) ,
      INDEX `user_idx` (`user_id` ASC) );

    CREATE TABLE IF NOT EXISTS `auth_users` (
      `id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT ,
      `name` VARCHAR(200) NULL ,
      `is_active` TINYINT(1) UNSIGNED NOT NULL DEFAULT 1 ,
      PRIMARY KEY (`id`) ,
      UNIQUE INDEX `name_unique` (`name` ASC) );

У нас есть клиенты (clients) и менеджеры (`auth_users`), которые работают с клиентом (`clients_to_users`). У клиента может быть несколько менеджеров одновременно.

### Напишем класс «Клиенты»

    @CLASS
    Сlients

    @BASE
    pfSQLTable

    @create[aOptions]
      ^BASE:create[clients;aOptions]
      $_tableAlias[c]

      ^addField[clientID;$.dbField[client_id] $.plural[clients] $.primary(true) $.processor[uint]]
      ^addField[title;$.default[__ Новый клиент __]]
      ^addField[phone]
      ^addField[address]
      ^addField[postAddress;$.dbField[post_address]]
      ^addField[email]
      ^addField[url]
      ^addField[comment]
      ^addField[createdAt;$.dbField[created_at] $.processor[auto_now] $.skipOnUpdate(true)]
      ^addField[updatedAt;$.dbField[updated_at] $.processor[auto_now]]

      $_defaultOrderBy[$.title[asc] $.clientID[asc]]


В конструкторе мы вызываем базовый класс, передаем ему название нашей таблички в БД и назначаем алиас, который бедт использоваться в селектах (если алиас не задать, то он автоматически будет равен имени таблицы). Метод addField добавляет новое поле в нашей программе. Я привык в программе называть поля в стиле «camelCase», а в базе отделяю слова в названиях полей символом подчеркивания, поэтому для некоторых полей указано название поля в базе (dbField). Поле clientID обозначено первичным ключем (`$.primary(true)`) и для него задано название поля во множественном числе (`$.plural[clients]`), которое будет использоваться в выборках.

Обратите внимание, что мы нигде не указали тип поля в БД. Так и должно быть, поскольку класс pfSQLTable описывает как ваша программа видит таблицу в базе данных, а не то, как табличка устроена в конкретной СУБД. Тем не менее, иногда полезно знать некоторые особенности устройства базы данных, чтобы строить эффективные запросы и для этого предназначена система процессоров, но об этом чуть позже.

Если не нравится «батарея» методов addField, то можно записать описание полей чуть короче:

    ^addFields[
      $.clientID[$.dbField[client_id] $.plural[clients] $.primary(true) $.processor[uint]]
      $.title[$.default[__ Новый клиент __]]
      $.phone[]
      $.address[]
      $.postAddress[$.dbField[post_address]]
      $.email[]
      $.url[]
      $.comment[]
      $.createdAt[$.dbField[created_at] $.processor[auto_now] $.skipOnUpdate(true)]
      $.updatedAt[$.dbField[updated_at] $.processor[auto_now]]
    ]


### CRUD

Воспользуемся классом в программе:

    @main[]
    # Создаем объект для соединения с СУБД
      $csql[^pfSQLConnection::create[mysql://user:password@localhost/test_db]]

    # Создаем объект таблицы клиентов
      $ct[^clients::create[$.sql[$csql]]]

Теперь можно приступать непосредственно к работе с данными:

    # Создаем нового клиента
      $clientID[^ct.new[$.title[Студия Лебедева] $.url[http://artlebedev.ru]]]

    # Изменяем данные
      ^ct.modify[$clientID;$.phone[+7 495 926-18-00]]

    # Достаем запись из базы данных по первичному ключу
      $client[^ct.get[$clientID]]

    # Метод get возвращает хеш со всеми полями, которые мы задали через метод addField
      $client.title - $client.url - $client.phone - $client.createdAt - $client.updatedAt

    # Если нам надо удалить клиента,
    # то вызываем метод ^ct.delete[$clientID]

В результате мы получим строку:

    Студия Лебедева - http://artlebedev.ru - +7 495 926-18-00 - 2012-06-08 12:48:00 - 2012-06-08 12:48:01

Мы не написали вручную ни одного запроса к базе данных, но смогли добавить, изменить и получить запись. Магия! :)

### Процессоры

Посмотрим на результат работы предыдущего примера. Поля createdAt и updatedAt мы нигде явно не задавали, но данные для них были сформированы автоматически — это результат работы «процессоров». Как я уже писал выше, класс pfSQLTable ничего не знает о внутреннем устройстве таблицы в БД, но в некоторых случаях подобное неведение мешает строить эффективные запросы. Например, целочисленный первичный ключ хотелось бы преобразовывать в число, а не задавать как строку — в этом случае MySQL эффективнее использует индексы. Некоторые поля надо обновлять автоматически: при вставке новой записи хочется записать в поле createdAt текущие дату и время, а при обновлении проделать такую же операцию с полем updatedAt. Для решения этих задач предусмотрен механизм процессоров.

Процессор — это правило по которому производится преобразование значения поля при вставке его в sql-запрос. Фактически это встроенный механизм сериализации Парсеровских объектов, который запускается везде, где нам надо подставить значение объекта в запрос. Самый простой процессор (`auto_default`) применятся, если не указать имя процессора в описании поля. Он выполняет следующие операции с объектом: выполняет taint и заключает значение в кавычки, а если значение не определено и в методе addField указан ключ `$.default[__ Новый клиент __]`, то подставляет значение по-умолчанию.

В нашей табличке есть четыре поля с процессорами:

    ^addField[clientID;$.dbField[client_id] $.plural[clients] $.primary(true) $.processor[uint]]
    ^addField[title;$.default[__ Новый клиент __]]
    ^addField[createdAt;$.dbField[created_at] $.processor[auto_now] $.skipOnUpdate(true)]
    ^addField[updatedAt;$.dbField[updated_at] $.processor[auto_now]]

Поле clientID первичный целочисленный ключ (`auto_increment`) и для него мы задаем процессор «uint», т.е. преобразование значения в целое число без знака. Для поля title не задан процессор, но задано значение по-умолчанию (default), которое подставляется если поле не определено. Для полей createdAt и updatedAt заданы процессоры auto_now, которые подставляют в поле текущие дату и время, если явно не задано значение поля. Поскольку поле createdAt не надо менять при обновлении записи, то для него мы задали параметр $.skipOnUpdate(true) (есть еще ключик skipOnInsert, который отменяет изменение поля при вставке записи — его можно было использовать для поля updatedAt, если мы хотим при создании новой записи получить значение null в поле `updated_at`).

Мы можем передать методу modify обект date — `^ct.modify[$.updatedAt[^date::now[]]]` — и класс автоматически вызовет метод sql-date при подстановке значения поля в запрос. Процессоры с префиксом auto_ «умеют» подставлять осмысленные данные, если не задано значение поля.

Помните, что процессоры работают только при формировании запроса, но никак не влияют на результаты, полученные из СУБД. Мы можем подставить объект date в запрос, но при выборке из базы получим это значение в виде строки, т.е. нам надо будет преобразовать в коде объект в дату.

Стандартные процессоры:

     auto_default - если не задано значение, то возвращает field.default (поведение по-умолчанию)
     uint, auto_uint - целое число без знака, если не задан default, то приведение делаем без значения по-умолчанию
     int, auto_int - целое число, если не задан default, то приведение делаем без значения по-умолчанию
     double, auto_double - целое число, если не задан default, то приведение делаем без значения по-умолчанию
     bool, auto_bool - 1/0
     datetime - дата и время (если нам передали дату, то делаем sql-string)
     date - дата (если нам передали дату, то делаем sql-string[date])
     time - время (если нам передали дату, то делаем sql-string[time])
     now, auto_now - текущие дата время (если не задано значение поля)
     curtime, auto_curtime - текущее время (если не задано значение поля)
     curdate, auto_curdate - текущая дата (если не задано значение поля)
     json - сереиализует значение в json
     null - если не задано значение, то возвращает null
     uint_null - преобразуем зачение в целое без знака, если не задано значение, то возвращаем null
     uid, auto_uid - уникальный идентификатор (math:uuid)
     inet_ip — преобразует строку в числовое представление IP
     first_upper - удаляет ведущие пробелы и капитализирует первую букву

Обратите внимание на процессор json, который позволяет записывать в поле БД сериализованное представление хешей или объектов Парсера.

### Выборки

Работа с единичной записью в БД интересна, но большинству программ требуется делать какие-то выборки из базы данных. Стандартные выборки можно делать методом all класса:

    # Выбираем всех клиентов
      $allClients[^ct.all[]]

    # В результате получаем хеш хешей, в котором первичным ключем является clientID,
    # а значениями хеши с данными
      ^allClients.foreach[k;v]{
        $v.clientID — $v.title
      }[<br />]

    # Или получить результ в виде таблицы
      $allClients[^ct.all[$.asTable(true)]]

    # Можно ограничить выборку десятью записями
      $allClients[^ct.all[$.limit(10)]]

Если мы передали методу all ключи, соответствующие именам полей, то формируется запрос на проверку равенства значений заданных полей таблицы.

    # Сформируем запрос select ... from clients where url = "http://artlebedev.ru" and title = "Студия Лебедева"
      ^ct.all[$.url[http://artlebedev.ru] $.title[Студия Лебедева]]

Можно делать сравнение не только на равенство. Для этого надо указать условие в следующем формате:

    # Формат: $.[поле оператор][значение]
    # Следующий запрос сформирует запрос select ... from clients where client_id <= 100
      $.[clientID <=][100]

Поддерживаются операторы:

* `< (меньше)`
* `> (больше)`
* `<= (меньше или равно)`
* `>= (больше или равно)`
* `!= (не равно)`
* `like (сравнение строки, преобразуется в like "значение")`
* `= (равно, но его можно не указывать совсем)`

Чтобы проверить поле на null используем оператор is:

    $.[clientID is][null] => client_id is null
    $.[clientID is][not null] => client_id is not null

Значением могут быть не только строки «null» и «not null» — любое «пустое значение» преобразуется в null, а непустое в not null:

    $.[clientID is][] => client_id is null
    $.[clientID is][12345] => client_id is not null

Если нам надо проверить входит ли значение поля в некоторый диапазон, то используем оператор range, который формирует sql-выражение between. Значением может быть хеш или объект с полями from и to. Диапазо открытый, т.е. границы проверяются на <= и >=.

    # select from clients where created_at between "2000-01-01" and "2012-03-18"
      $.[createdAt range][$.from["2000-01-01"] $.to[$_today]]

    # Негативная проверка
    # select from clients where not(created_at between "2000-01-01" and "2012-03-18")
      $.[createdAt !range][$.from["2000-01-01"] $.to[$_today]]

Если мы хотим одновременно проверить на равенство несколько значений (множество), то можно воспользоваться оператором in:

    # select ... from clients where client_id in (13, 14, 25)
      ^ct.all[$.[clientID in][13,14,25]]

    # Негативная проверка
    # select ... from clients where client_id not in (13, 14, 25)
      ^ct.all[$.[clientID !in][13,14,25]]

В качестве значения поля для оператора in могут выступать строкы, хеш или таблица. Строка должна быть в csv-формате: значения разделяются запятыми, а в качестве ограничителей можно использовать двойные кавычки (если значение содержит кавычки то их надо удвоить; пример: `слово, "два слова", "слово, запятая", "фраза ""с кавычками"""`). Если значение поля хеш, то в качестве значений используются ключи хеша. Для таблиц имя колонки должно соответствовать имени поля, но можно задать произвольное название колонки, указав параметр с именем поля и суффиксом «Column», которое содержит название колонки с данными. Хеши и таблицы удобно использовать для подстановки результатов других выборок (подробности описаны ниже).

      ^ct.all[$.[clientID in][$.13[] $.14[] $.15[]]]
      ^ct.all[$.[clientID in][^table::{clientID ...}]]
      ^ct.all[$.[clientID in][^table::{id ...}] $.clientIDColumn[id]]

Для того чтобы записать несколько условий с одним и тем же оператором добавьте после любой идентификатор, например число:

     $.[clientID != (1)][15]
     $.[clientID != (2)][12]

### Сортировка результата

Если в таблице определен первичный ключ, то сортировка идет именно по нему, но такое поведение вряд ли подходит для большинства запросов. Класс предоставляет несколько вариантов управления сортировкой.

При выборке через метод all можно явно указать параметр orderBy. Поддерживается два варианта с хешем или выражение (в последнем случае лучше использовать фигурные скобки):

    # select ... from clients order by title.asc, client_id desc
      ^ct.all[$.orderBy[$.title[asc] $.clientID[desc]]]
      ^ct.all[$.orderBy{title asc, $ct.clientID desc}]

Чтобы задать значение сортировки «по-умолчанию» необходимо в конструкторе таблицы, после определения полей, задать свойство $_defaultOrderBy. В нашем примере параметр выглядит так:

    $_defaultOrderBy[$.title[asc] $.clientID[asc]]

Теперь любой запрос all без явного указания параметра orderBy будет отсортирован именно в порядке `_defaultOrderBy`.

Часто нам надо иметь несколько режимов сортировки результата, но в _defaultOrderBy можно определить только один, да и указывать в каждом запросе режим сортировки не лучший выбор — если вам понадобится глобально заменить направление сортировки одного из полей, то понадобится править кучу кода. Чтобы избежать этих проблем мы можем перекрыть метод `_allOrder` в классе Clients:

    @_allOrder[aOptions]
      ^switch[$aOptions.order]{
        ^case[added]{$result[$createdAt desc, $clientID desc]}
        ^case[DEFAULT]{$result[^BASE:_allOrder[$aOptions]]}
      }

Теперь мы можем выбирать режим сортировки результата:

    # Сортировка по названию (используется значение из _defaultOrderBy)
      $allClients[^ct.all[]]

    # Сортировка по времени добавления
      $allClients[^ct.all[$.order[added]]]

Метод all при формировании частей выражения select вызывает методы `_allWhere, _allOrder, _allJoin, _allGroup` и некоторые другие, которые мы можем перекрывать, чтобы точечно влиять на содержимое запроса. Во все эти методы передается первый параметр функции all, т.е. все методы видят параметры запросв. Обратите внимание, что вместо того, чтобы написать «client_id desc» мы написали «$ct.clientID desc». Свойства класса с именами полей возвращают имя поля в базе данных и если мы решим изменить название поля в БД, то нам достаточно будет изменить только параметр dbField поля.

### Сложные условия

Часто возникает необходимость выбирать данные по нескольким значениям первичных ключей. Предположим, что мы хотим выбрать всех менеджеров для клиента или всех клиентов для конкретного менеджера. Давайте добавим еще одну табличку:

    @CLASS
    Managers

    @BASE
    pfSQLTable

    @create[aOptions]
      ^BASE:create[clients_to_users;
        $.allAsTable(true)
        $.tableAlias[cu]
      ]
      ^addField[clientID;$.plural[clients] $.dbField[client_id] $.processor[uint]]
      ^addField[userID;$.plural[users] $.dbField[user_id] $.processor[uint]]
      ^addField[createdAt;$.dbField[created_at] $.processor[auto_now] $.skipOnUpdate(true)]

В этой табличке у нас составной первичный ключ, поэтому мы не указываем ни одному полю ключ primary. В конструкторе базового класса указываем, что возвращать результаты метод all будет в виде таблицы (хеш без уникального первичного ключа построить не получится). Для этой таблички не будет работать методы get, modify и delete, но вместо них можно использовать one, modifyAll и deleteAll.

    # Создаем объект
      $mt[^Managers::create[$.sql[$csql]]]

    # Добавляем записи (связывае менеджера и пользователя)
    # Метод new, в данном случае, не возвращает значение первичного ключа!
      ^mt.new[$.clientID[1] $.userID[1]]
      ^mt.new[$.clientID[2] $.userID[1]]

    # Если надо удалить запись, то можем написать
    # ^mt.deleteAll[$.clientID[2] $.userID[1]]

У полей clientID и userID заданы значения множественного числа clients и users, которые можно удобно использовать при выборке:

    # Достаем из базы всех клиентов
      $allClients[^ct.all[]]

    # А теперь всех менеджеров для клиентов
      $managersForClients[^mt.all[$.clients[$allClients]]]

В результате мы получичил хеш со всеми клиентами в allClients и таблицу с менедежрами для всех клиентов в managersForClients. Обратите внимание, что мы передали методу mt.all в параметре clients результат предыдущей выборки и метод сам преобразовал вызов в выражение client_id in (1, 2, ...), где значениями множества явились ключи хеша. В качестве значения параметра clients могут выступать хеш, таблица или строка — система автоматически сформирует код для преобразования значения в множество. Того же эффекта можно было добиться использовав оператор in:

      $managersForClients[^mt.all[$.[clientID in][$allClients]]]

Но часто удобнее использовать множественное число вместо названия первичного ключа. С множественным числом можно использовать и негативную проверку:

      $managersForClients[^mt.all[$.[clients !in][$allClients]]

Теперь мы можем выполнить и обратную операцию: получить всех клиентов для менеджеров.

    # Достаем всех менеджеров
      $allManagers[^mt.all[]]

    # А теперь достаем всех клиентов для менеджеров
      $clientsForManagers[^ct.all[$.clients[$allManagers]]]

В allManagers у нас была таблица на основании которой было построено выражение where client_id in (1, 2, ...), причем значения брались из поля clientID таблицы allManagers. Если нам надо указать иное поле (например, таблица построена вручную или получена из поисковой системы, которая именует поле с клиентами просто id), то можно задать имя колонки в таблице:

    # Название параметра с именем колонки получается добавлением к нему суффикса Column
      $clientsForManagers[^ct.all[$.clients[$allManagers] $.clientsColumn[id]]]

По-умолчанию все условия объединяются союзом «и» (and), но иногда может потребоваться использовать союз «или» (or) или отрицание (not). Сделать это можно, использовав в условиях группирующие ключи $.OR, $.AND, $.NOT. Простой пример:

      ^all[
        $.[clientID !=][15]
        $.OR[
          $.AND[$.[clientID >=][22] $.[clientID <=][30]]
          $.[AND 2][$.[clientID] >=][35] $.[clientID < 45]]
          $.[title like][Студия%]
        ]
        $.NOT[
          $.createdAt[^date::now[]]
        ]
      ]

    # Получим запрос:
      select ... from clients
      where client_id <> 15 and
      ((client_id >= 22 and client_id <= 30)
        or (client_id >= 35) and client_id < 45)
        or title like "Студия%"
      )
      and not (created_at != "2012-06-17 20:26:15")

Ключи AND и OR связывают все условия в группе условиями and и or соответственно, а NOT связывает ключом and, но добавляет для всей группы отрицание (not). Если нужно объединить несколько однозначных групп, то можно использовать любой дополнительный идентификатор, который указывается в ключе после пробела («AND 2» в примере). Группы можно неограниченно вкладывать друг в друга.


### Выборки с произвольным условием

Вы можете задать свое условие для выборки из таблицы, не перекрывая метод `_allWhere`:

    # Выберем всех клиетов, которые были добавлены за последний месяц
    # и не имеющих адреса электропочты
    $_now[^date::now[]]
    $clients[^ct.all[
      $.where{$ct.createdAt between date_sub("^_now.sql-string[]", interval 1 month) and "^_now.sql-string[]"}
    ]]

Параметр where должен быть кодом, тогда в нем будут работать макроподстановки имен полей. Хотя задание своего параметра и удобнее, но лучше придумать дополнительный параметр и реализовать его в методе `_allWhere` класса Clients:

    @_allWhere[aOptions]
    ## aOptions.period[last-month|...]
      ^self.cleanMethodArgument[]
      $result[
        ^BASE:_allWhere[$aOptions]

        ^if(^aOptions.contains[period]){
          ^switch[$aOptions]{
    #       Переменные _now и _today в pfSQLTable уже есть. :)
            ^case[last-month]{and $createdAt between date_sub("^_now.sql-string[]", interval 1 month) and "^_now.sql-string[]"}
          }
        }
      ]

### Выражения в полях и джоины

Иногда удобно доставать вместе с основными полями еще и некоторые поля из связанных таблиц. Давайте немного расширим класс Managers:

    @CLASS
    Managers

    @BASE
    pfSQLTable

    @create[]
      ^BASE:create[clients_to_users;
        $.allAsTable(true)
        $.tableAlias[cu]
      ]

      ^addField[clientID;$.plural[clients] $.dbField[client_id] $.processor[uint]]
      ^addField[userID;$.plural[users] $.dbField[user_id] $.processor[uint]]
      ^addField[createdAt;$.dbField[created_at] $.processor[auto_now] $.skipOnUpdate(true)]
      ^addField[name;$.fieldExpression[au.name]]
      ^addField[isActive;$.fieldExpression[au.is_active] $.processor[bool]]

    @_allJoin[aOptions]
      $result[join auth_users as au on ($userID = au.id)]

    @_allOrder[aOptions]
      $result[$name asc, $userID asc]

Мы добавили два поля name и isActive для которых задали параметр fieldExpression с именами полей в табличке `auth_users`. Связали таблички в методе `_allJoin` и добавили сортировку выборки по имени менеджера. Теперь мы можем получить одним запросом сразу все данные о менеджере:

    # Все менеджеры для клиента с id: 1
      $mfc[^mt.all[$.clientID[1]]]
      ^mfc.menu{$mfc.userID — $mfc.name}[<br />]

    # Можем выбрать только активных менеджеров
      $mfc[^mt.all[$.clientID[1] $.isActive(true)]]

Предположим, что мы хотим вывести имя менеджера в верхнем регистре, тогда мы напишем `^addField[name;$.expression[upper(au.name)] $.fieldExpression[au.name]]`, и теперь из all мы получим ИМЯ МЕНЕДЖЕРА, но при этом сможем писать `^all[$.name[имя менеджера]]`.

Фактически мы сделали в нашей программе «представление» (view) из нескольких таблиц в БД. Можно еще больше усложнить код и сделать так, чтобы список имен менеджеров стал полем в классе Clients.

    @CLASS
    Clients

    @BASE
    pfSQLTable

    @create[]
      ^BASE:create[clients;
        $.allAsTable(true)
        $.tableAlias[c]
      ]

      ^addField[clientID;$.plural[clients] $.dbField[client_id] $.primary(true) $.processor[uint]]
      ^addField[title;$.default[__ Новый клиент __]]
      ^addField[phone]
      ^addField[address]
      ^addField[postAddress;$.dbField[post_address]]
      ^addField[email]
      ^addField[url]
      ^addField[comment]
      ^addField[createdAt;$.dbField[created_at] $.processor[auto_now] $.skipOnUpdate(true)]
      ^addField[updatedAt;$.dbField[updated_at] $.processor[auto_now]]

      ^addField[managers;$.expression[group_concat(au.name separator ", ")]]
      ^addField[manCnt;$.expression[count(au.id)]]

    @_allJoin[aOptions]
      $result[
        left join clients_to_users as cu on $clientID = cu.client_id
        left join auth_users as au on cu.user_id = au.user_id
      ]

    @_allGroup[aOptions]
      $result[$clientID]

    @_allOrder[aOptions]
      $result[^switch[$aOptions.order]{
        ^case[added]{$createdAt desc, $clientID desc}
        ^case[DEFAULT]{$title asc, $clientID asc}
      }]

При создании и обновлении записей меняться будут только поля, относящиеся к нашей табличке. Но никто не мешает вам перекрыть методы new и delete и реализовать собственную схему обновления данных в связанных таблицах (это похоже на методику обновления view в СУБД через тригеры).


### Агрегации (выборки с группировкой данных)

Помимо получения записей из таблицы требуется получать обобщенные данные о записях — в SQL'е для этого используются агрегатные функции. Класс pfSQLTable предоставляет несколько функций для простого построения запросов с группировкой.

Самая простая функция — count. Она позволяет получить количество записей в таблице и указать, при необходимости, условия.

    # Количество записей в таблице
      ^ct.count[]
    # Количество записей с clientID больше 20
      ^ct.count[$.[clientID >][20]]

Для сложных случаев предназначен метод aggregate. Функция принимает произвольное количество параметров в каждом из которых описываются поля выборки. Последними параметрами могут следовать хеши с условиями выборки и sql-параметрами, аналогично методу all.

Интерфейс метода выглядит следующим образом:

    ^aggregate[func1(args) as field1;func2(args) [as field2];expression as field;...;$.groupBy[...] + conditions]

Можно задать любую групирующую функцию, поддерживаемую СУБД. Имя поля в результирующей таблице или хеше можно задать через оператор as (если алиас не указать, то именем поля будет все выражение). Несколько примеров:

    # Простая статистическая группировка (вернет таблицу с двумя полями maxClientID и lastDate)
    # и одной строкой
      ^ct.aggregate[max($ct.clientID) as maxClientID;max(cl.created_at) as lastDate;$.asTable(true)]

    # Получим количество новых клиентов, сгруппированых по дате
    # и откинем всех клиентов с id < 20.
    # В результате получим таблицу с колонками dt/cnt/clients отсортированную по дате.
    # Колонка clients содержит список идентификаторов клиентов через запятую.
      ^ct.aggregate[date($ct.createdAt) as dt;count(*) as cnt;group_concat(distinct $ct.clientID) as clients;
        $.groupBy{dt asc}
        $.[clientID >=][20]
      ]

Внимательный читатель уже обратил внимание, что метод aggregate можно использовать без группировки, тогда он превращается в гибкий инструмент для выборок из таблицы.

    # Выбираем только поля clientID и title из таблицы:
      ^ct.aggregate[$ct.clientID as clientID;$ct.title as title]

Или можно воспользоваться алиасом select на метод aggregate.

    ^ct.select[$ct.clientID as clientID;$ct.title as title]

Писать каждый раз имена полей и алиасы не очень удобно, но можно сильно упростить работу, воспользовавшись встроенной функцией `_fields`. Тогда запрос на выборку двух полей будет короче:

    # Табличка с полями clientID/title
      ^ct.aggregate[_fields(clientID, title)]

    # Полям можно задать алиасы
      ^ct.aggregate[_fields(clientID, title as Title)]

    # Если нам надо получить все поля, то вместо имен указывааем звездочку
      ^ct.aggregate[_fields(*)]

    # А теперь добавим поле с названием клиента в верхнем регистре
      ^st.aggregate[_fields(*);upper($ct.title) as upperTitle]


## Интересные случаи

### Удаление строк из таблицы с возможностью восстановления

Добавляем поле `is_active tinyint(1)` в таблицу и ...

    @BASE
    pfSQLTable

    @create[aTableName;aOptions]
      ^BASE:create[$aTableName;$aOptions]

      ^addField[id;$.primary(true) $.processor[uint]]
      ...
      ^addField[isActive;$.dbField[is_active] $.processor[bool] $.default(1)]

    @_allWhere[aOptions]
    ## aOptions
      ^self.cleanMethodArgument[]
      $result[
        ^BASE:_allWhere[$aOptions]
        ^switch[$aOptions.active]{
           ^case[any]{}
           ^case[inactive]{and $isActive = 0}
           ^case[DEFAULT;active]{and $isActive = 1}
        }
      ]

    @delete[aID]
      $result[^modify[$aID;$.isActive(false)]]

    @restore[aID]
      $result[^modify[$aID;$.isActive(true)]]

Теперь у нас есть возможность удалять и восстанавливать записи. При выборках мы будем получать только активные записи, но если написать `^all[$.active[inactive]]`, то получим всё, что «удалили» (`^all[$.active[any]]` — любые записи).

### Объединение результатов нескольких запросов

Метод union выполняет несколько запросов и возвращает объединенный результат. Функция делает несколько запросов вместо использования sql-оператора union (Парсер не может автоматически задавать разные limit и offset для выражений «select .. union», поэтому приходится гонять запросы по одному). Каждый параметр оператора выборки — это условие для отдельных запросов.

В примере мы выбираем первую и последнюю пятерки клиентов:

    $headAndTail[^ct.union[
      $.orderBy[$.clientID[asc]] $.limit(5)
    # В первом параметре можно задать тип результата, который вернет union.
      $.asTable(true)
    ][
      $.orderBy[$.clientID[desc]] $.limit(5)
    ]]

    # Отсортируем результат:
    ^headAndTail.sort($headAndTail.cleintID)[asc]

### Получение первой и последней записи из таблицы

Можно вызвать метод one:

    $first[^ct.one[$.orderBy[$.clientID[asc]] $.limit(1)]]
    $last[^ct.one[$.orderBy[$.clientID[desc]] $.limit(1)]]

Или сделать свойства в классе Clients:

    @GET_first[]
      $result[^ct.one[$.orderBy[$.clientID[asc]] $.limit(1)]]

    @GET_last[]
      $result[^ct.one[$.orderBy[$.clientID[desc]] $.limit(1)]]

И обращаться в коде как к переменной:

    $ct.first.title - $ct.first.clientID

В этом коде есть проблема: если в sql-классах не включено кеширование запросов в памяти (identity map), то повторное обращение к свойству first приведет к повторному запросу базы данных. Чтобы этого избежать слегка изменим класс:

    @create[aOptions]
      ...
      ^__cleanProps[]

    @GET_first[]
      ^if(!def $self._first){
        $_self._first[^ct.one[$.orderBy[$.clientID[asc]] $.limit(1)]]
      }
      $result[$self._first]

    @GET_last[]
      ^if(!def $self._last){
        $_self._last[^ct.one[$.orderBy[$.clientID[desc]] $.limit(1)]]
      }
      $result[$self._last]

    @__cleanProps[]
      $result[]
      $self._first[]
      $self._last[]

    @new[aData;aSQLOptions]
      $result[^BASE:new[$aData;$aSQLOptions]]
    # Небольшой хак: очищаем закешированные данные для _first и _last.
      ^__cleanProps[]

Аналогично new можно переопределить методы modify и delete.

### Сложное условие в поле

Выражения в полях могут быть очень сложными. В примере мы добавляем «виртуальную колонку» dayIdent из которой мы сможем понять когда добавили клиента («сегодня», «вчера» или давным-давно в далекой галактике).

    ^addField[dayIdent;
      $.expression{
        case
          when $createdAt >= "^_today.sql-string[]" then "today"
          when $createdAt >= date_sub("^_today.sql-string[]", interval 1 day) then "yesterday"
          else "a long time ago"
        end
      }
      $.skipOnUpdate(true) $.skipOnInsert(true)
    ]

Обновлять колонку нам не надо, поэтому для безопасности я добавил skipOnInsert и skipOnUpdate. dayIdent можно использовать и в выборках, но в where выражение будет подставлено целиком (обычно это не является проблемой).
