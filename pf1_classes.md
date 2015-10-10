# Список классов, которые надо оставить из PF1:

Большие подсистемы (sql, авторизация) переносим как есть, только распределяем по пакетам и убираем ненужные use. После этого уже делаем рефакторинг.

### ./api/archives/
+ pfZipArchiver

### ./api/mobile/sms/
+ pfZagruzkaSMSGate

### ./api/office/excel/
+ pfTableToXLS

### ./api/pdf/pdfkit/
* pfPDFKit

### ./api/qiwi/wallet/
* pfQiwiWallet

### ./api/yandex/speechkit/
* pfYandexSpeechKit

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

### ./debug/pfRuntime.p +
+ pfRuntime

### ./io/ +
+ pfCFile
+ pfConsole
+ pfCurlFile
+ pfOS


### ./modules/
* pfModule
* pfRouter

### ./security/
* pfSecurityCrypt

### ./sql/generics/settings/
* pfSQLSettings

### ./sql/orm/generics/queue/
* pfSQLQueue

### ./sql/orm/generics/tagging/
* pfTagging
* pfSQLCTTagsModel
* pfSQLCTContentModel
* pfSQLCTCountersModel

### ./sql/orm/pfSQLTable.p
* pfSQLTable
* pfSQLBuilder

### ./sql/orm/service/
* pfTableControllerGenerator
* pfTableFormGenerator
* pfTableFormGeneratorBootstrap2Widgets
* pfTableFormGeneratorBootstrap3Widgets
* pfTableModelGenerator

### ./sql/
* pfMySQL
* pfSQL
* pfSQLite

### ./templet/pfTemple.p
* pfTemple
* pfTempleStorage
* pfTempleEngine
* pfTempleParserEngine
* pfTempleParserPattern

### ./tests/ +
+ pfAssert

### ./types/ +
+ pfClass
+ pfString
+ pfValidate

### ./web/helpers/
* pfAntiFlood
* pfAntiFloodStorage
* pfAntiFloodHashStorage
* pfAntiFloodDBStorage

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
* pfURLTranslit



## Под вопросом:

### ./api/yandex/mail/pfYandexMail.p
* pfYandexMail

### ./collections/
* pfQueue
* pfStack
