PF2 — веб-фреймворк для Parser 3
================================

PF2 помогает разработчикам писать веб-приложения. Фреймворк реализует шаблон проектирования MVC. PF2 — переработанная версия [библиотеки PF](https://bitbucket.org/ovolchkov/parser3-pf).

Стабильная версия в ветке master. Разрабатываем в бранче develop и ветках feature/name.

Авторы:
* Олег Волчков ([oleg@volchkov.net](mailto:oleg@volchkov.net), [unhandled-exception.ru](http://unhandled-exception.ru))
* Алексей Марьин ([groundzero.ru](http://groundzero.ru))

## Установка и простое приложение

В [папку с классами](http://www.parser.ru/docs/lang/app1pathclass.htm) загрузите библиотеку. Папка должна называться pf2. Папку со своими классами и классами pf2 положите вне веб пространства.

```
$CLASS_PATH[^table::create{path
/../classes/
}]
```

Пример:
```
cd ~/mysite.ru/classes
git clone https://github.com/unhandled-exception/pf2.git
```

В Апаче пропишите команды:
```
ReqriteEngine on
RewriteCond %{REQUEST_FILENAME} !-f
RewriteRule ^ index.html [L]
```

Теперь все запросы к нашему сайту веб-сервер отправит на файл index.html.

В index.html напишем первое приложение:

```
@USE
pf2/lib/web/controllers.p


@main[][locals]
  $site[^Site::create[]]
  ^site.run[]


@CLASS
Site

@BASE
pfController

@OPTIONS
locals

@create[aOptions]
  ^BASE:create[$aOptions]
  ^router.assign[/hello/:name;/hello]

@/[aRequest]
  Это мой сайт.

@/hello[aRequest]
  Привет, ^ifdef[$aRequest.name]{мир}!

@NOTFOUND[aRequest]
  $result[
    $.status[404]
    $.body[Страница не найдена.]
  ]
```

Попробуйте открыть страницы mysite.ru/, mysite.ru/hello/world/, mysite,ru/hello/pf2, mysite.ru/404.

## Примеры

### [pf2-secrets-app](https://github.com/unhandled-exception/pf2-secrets-app)

Законченное приложение на pf2 с моделями, контролерами и шаблонами. Сайт помогает пользователям передавать секретные сообщения коллегам и друзьям через интернет. Сообщение защищаем пин-кодом и уничтожаем как только получатель откроет ссылку и введет правильный пин-код.

## Документация

* [Контролеры и маршрутизация](docs/controllers.md)

* [Концепция и стили кодирования](docs/concepts.md)
* [Список классов в модулях](classes.md)

