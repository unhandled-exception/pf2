# Тесты для pf2

Бинарник parser3 кладем в `$HOME/bin`, парсеровские драйверы для СУБД в `$HOME/bin/lib`. Нативные драйверы для СУБД класть рядом с парсеровскими драйверами или в пути для сошек, досутпные парсеру средствами ОС.

В репозитории https://github.com/unhandled-exception/pf2 тесты автоматически запускаются на каждый push через GitHub Actions. Пример запуска тестов смотрите в [/.github/workflows/ut.yml](/.github/workflows/ut.yml).

Тестовый фреймворк lib/tests/unittest.p не использует классов pf2 и может быть использован для тестирования любого Парсеровского кода.

## Настраиваем локальное окружения

### Ubuntu Linux

* Со страницы https://www.parser.ru/download/linux/ берем архив «комплект для установки» для Ubuntu
* Распаковываем архив в `$HOME/bin`
* Устанавливаем Docker по инструкции https://docs.docker.com/engine/install/ubuntu/
* Устанавливаем на машину пакеты с клиентом Постгреса (нужен для старта контейнеров):
```
> sudo apt update
> sudo apt install postgresql-client-common postgresql-client
```
* Копируем драйверы для MySQL 8:
```
cp ut/_libs/ubuntu_24.04/x64/libparser3mysql8.so $HOME/bin/lib/
cp ut/_libs/ubuntu_24.04/x64/libmysqlclient8.so $HOME/bin/lib/system/
```

### Apple OSX

* Со страницы https://www.parser.ru/download/macosx/ берем архив «комплект для установки»
* Распаковываем архив в `$HOME/bin`
* Устанавливаем Docker Desktop по инструкции https://docs.docker.com/docker-for-mac/install/
* Устанавливаем пакеты через Homebrew:
```
> brew update
> brew install postgresql curl
```
* Копируем драйверы для MySQL 8 и Постгреса:
```
cp ut/_libs/osx/x64/libparser3mysql8.so $HOME/bin/lib/
cp ut/_libs/osx/x64/libmysqlclient8.so $HOME/bin/lib/system/
cp ut/_libs/osx/x64/libpq.so $HOME/bin/lib/system/
```
* Делаем симлинк на libcurl
```
 > ln -s /usr/local/opt/curl/lib/libcurl.4.dylib $HOME/bin/lib/system/libcurl.so
```

## Запускаем тесты

Поднимаем контейнеры
```
> ./start_test_containers.sh
```

Запускаем тесты
```
> ./run_tests.p
или
> parser3.cgi run_tests.p
```

Чтобы запустить только нужные тесты, укзываем регулярку параметром для run_tests.p (регексп компилируется с ключем i):
```
./run_tests.p testAsserts
```

Список тестов `./run_tests.p -l`

Хелп по ключам `./run_tests.p -h`

Остановить тестовые контейнеры: `./stop_test_containers.sh`
