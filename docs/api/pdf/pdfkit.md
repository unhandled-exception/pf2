# Класс pfPDFKit

Класс для генерации pdf-файлов из простых html файлов с css-стилями. В качестве бэкэнда используется пакет [wkhtmltopdf](http://code.google.com/p/wkhtmltopdf/), который базируется на движке WebKit. Основан на идеях из аналогичного Рубишного класса [PDFKit](https://github.com/pdfkit/pdfkit).

## Для работы класса на сервере должны быть установлены

1. Пакет wkhtmltopdf.
2. Пакет webfonts (есть в портах FreeBSD и репозиториях Linux).

## Использование

    # Инициализируем класс
      ^use[pf2/api/pdfkit.p]
      $pdfkit[^pfPDFKit::create[]]
    # Конструктору можно передать путь к бинарнику wkhtmltopdf от request:document-root
    # $pdfkit[^pfPDFKit::create[$.binPath[/path/to/wkhtmltopdf]]]

    # Преобразование делается одним методом — toPDF.
    # Если ему на вход передать строку, то он вернет нам файлик, который можно сохранить на диск или вернуть пользователю сразу.
      $f[^pdfkit.toPDF[<html><head><meta name="pdfkit-page_size" content="A4"></head><body><p>Hello, world!</body></html>]]
      ^f.save[binary;/temp/test.pdf]

    # Можно сконвертировать веб-страничку или файл с диска
      $f[^pdfkit.toPDF[$.url[http://yandex.ru]]]
      $f[^pdfkit.toPDF[$.fileName[/temp/test.html]]]

    # Или файловый объект Парсера
      $f[^pdfkit.toPDF[^file::load[text;/temp/test.html]]]

    # Можно сразу сохранить файл на диск
      ^pdfkit.toPDF[$.url[http://yandex.ru];$.toFile[/temp/yandex.pdf]]

    # Можно задать любую опцию wkhtmltopdf через свойство options.
    # Опции задаются без двойных дефисов в начале. Разделители дефисы или подчеркивания.
      $pdfkit.options.no_pdf_compression(true)
      $pdfkit.options.page_size[Letter]

    # Если шаблон является строкой или файловым объектом, то можно задать один или несколько файлов с css-стилями,
    # которые будут автоматически вставлены перед тегом </head>
      ^pdfkit.appendStylesheet[/temp/test-1.css]
      ^pdfkit.appendStylesheet[/temp/test-2.css]

    # Параметры можно задать через тег meta прямо в шаблоне, добавиви к имени параметра префикс pdfkit-.
      $f[^pdfkit.toPDF[<html><head><meta name="pdfkit-page-size" content="A4"></head><body><p>Hello, world!</body></html>]]


## Особенности

* Если выдаете файл сразу в браузер, то не забудьте выставить корректные имя файла и content-type — класс возвращает дефолтный файл, который формирует file::exec, а в нем эти поля «стандартные».
* Если необходимо включить в шаблон изображения, css- или js-файлы, то необходимо указывать для них url'ы с доменами или полные пути в файловой системе, иначе wkhtmltopdf не сможет их найти.
* Генерация pdf-ов процесс не самый быстрый и ресурсоемкий, поэтому лучше это делать асинхронно и результаты кешировать на диске. :)