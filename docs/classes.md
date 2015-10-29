Список классов библиотеки
=========================

Автоматически получаем командой в папке lib:
````
find . -name "*.p" | sort | xargs grep "^@CLASS" -A 1 -H | awk '$0 !~ /(--|@CLASS)/{split($0, m, "-"); if(mod != m[1]){printf("\n### %s\n", m[1])} if(substr(m[2], 1, 2) != "__"){print "*", m[2]; mod = m[1]}} END{ printf("\n"); }'
````

### ./api/archives/zip.p
* pfZipArchiver

### ./api/mobile/sms/zagruzka.p
* pfZagruzkaSMSGate

### ./api/office/excel.p
* pfTableToXLS

### ./api/pdf/pdfkit.p
* pfPDFKit

### ./api/qiwi/wallet.p
* pfQiwiWallet

### ./api/yandex/speechkit.p
* pfYandexSpeechKit

### ./common.p
* pfClass
* pfMixin
* pfHashMixin
* pfChainMixin
* pfAssert
* pfString
* pfValidate
* pfCFile
* pfRuntime
* pfOS

### ./console/commands/generate.p
* pfConsoleGenerateCommand

### ./console/console_app.p
* pfConsoleApp
* pfConsoleAppStdout
* pfConsoleCommand
* pfConsoleCommandWithSubcommands

### ./net/curl_file.p
* pfCurlFile

### ./security/sql_security.p
* pfSQLSecurityCrypt

### ./sql/connection.p
* pfSQLConnection

### ./sql/models/generators/sql_table_generators.p
* pfTableModelGenerator
* pfTableFormGenerator
* pfTableFormGeneratorBootstrap2Widgets
* pfTableFormGeneratorBootstrap3Widgets
* pfTableControllerGenerator

### ./sql/models/generics/queue/sql_queue.p
* pfSQLQueue

### ./sql/models/generics/settings/sql_settings.p
* pfSQLSettings

### ./sql/models/generics/tagging/sql_tagging.p
* pfTagging
* pfSQLCTTagsModel
* pfSQLCTContentModel
* pfSQLCTCountersModel

### ./sql/models/sql_table.p
* pfSQLTable
* pfSQLBuilder

### ./sql/models/structs.p
* pfModelModule
* pfModelTable
* pfModelChainMixin

### ./web/auth.p
* pfAuthBase
* pfAuthStorage
* pfAuthSecurity
* pfAuthApache
* pfAuthCookie
* pfAuthDBStorage
* pfAuthDBRolesStorage
* pfAuthDBRolesSecurity

### ./web/helpers/antiflood.p
* pfAntiFlood
* pfAntiFloodStorage
* pfAntiFloodHashStorage
* pfAntiFloodDBStorage

### ./web/helpers/cache.p
* pfCache

### ./web/helpers/scroller.p
* pfScroller

### ./web/helpers/translit.p
* pfURLTranslit

### ./web/templates.p
* pfTemplate
* pfTemplateStorage
* pfTemplateEngine
* pfTemplateParserEngine
* pfTemplateParserPattern

### ./web/web.p
* pfModule
* pfRouter
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
* pfSiteModule
* pfSiteApp
