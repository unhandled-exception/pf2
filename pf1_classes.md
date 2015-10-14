# Список классов, которые надо оставить из PF1:

Большие подсистемы (sql, авторизация) переносим как есть, только распределяем по пакетам и убираем ненужные use. После этого уже делаем рефакторинг.

### ./api/archives/
+ pfZipArchiver

### ./api/mobile/sms/
+ pfZagruzkaSMSGate

### ./api/office/excel/
+ pfTableToXLS

### ./api/pdf/pdfkit/
+ pfPDFKit

### ./api/qiwi/wallet/
+ pfQiwiWallet

### ./api/yandex/speechkit/
+ pfYandexSpeechKit

### ./debug/pfRuntime.p +
+ pfRuntime

### ./tests/ +
+ pfAssert

### ./types/ +
+ pfClass
+ pfString
+ pfValidate

### ./io/ +
+ pfCFile
+ pfConsole
+ pfCurlFile
+ pfOS

### ./sql/generics/settings/
+ pfSQLSettings

### ./sql/orm/generics/queue/
+ pfSQLQueue

### ./sql/orm/generics/tagging/
+ pfTagging
+ pfSQLCTTagsModel
+ pfSQLCTContentModel
+ pfSQLCTCountersModel

### ./sql/orm/pfSQLTable.p
+ pfSQLTable
+ pfSQLBuilder

### ./sql/orm/service/
+ pfTableControllerGenerator
+ pfTableFormGenerator
+ pfTableFormGeneratorBootstrap2Widgets
+ pfTableFormGeneratorBootstrap3Widgets
+ pfTableModelGenerator

### ./sql/
+ pfSQL -> pfSQLConnection

Классы pfMySQL и pfSQLite похоже не нужны совсем. Может быть понадобится сделать класс pfSQLDialect, которые использовать в орме.

### ./security/
+ pfSecurityCrypt -> pfSQLSecurityCrypt.

### ./auth/
* pfAuthApache
* pfAuthBase
* pfAuthCookie
* pfAuthDBStorage
* pfAuthSecurity
* pfAuthStorage

### ./auth/roles/
* pfAuthDBRolesSecurity
* pfAuthDBRolesStorage

### ./cache/pfCache.p
* pfCache

### ./templet/pfTemple.p
* pfTemple
* pfTempleStorage
* pfTempleEngine
* pfTempleParserEngine
* pfTempleParserPattern

### ./web/helpers/
+ pfAntiFlood
+ pfAntiFloodStorage
+ pfAntiFloodHashStorage
+ pfAntiFloodDBStorage

### ./modules/
* pfModule
* pfRouter

### ./web/
* pfHTTPRequest
* pfHTTPRequestMeta
* pfHTTPRequestHeaders
* pfHTTPResponse
* pfHTTPResponseRedirect
* pfHTTPResponsePermanentRedirect
* pfHTTPResponseNotFound
* pfHTTPResponseBadRequest
* pfHTTPResponseNotModified
* pfHTTPResponseNotAllowed
* pfHTTPResponseForbidden
* pfHTTPResponseGone
* pfHTTPResponseServerError
* pfScroller
* pfSiteApp
* pfSiteManager
* pfSiteModule

### ./wiki/pfURLTranslit.p
+ pfURLTranslit



## Под вопросом:

### ./api/yandex/mail/pfYandexMail.p
* pfYandexMail

### ./collections/
* pfQueue
* pfStack
