Список классов библиотеки
=========================

Автоматически получаем командой в папке lib:
````
find . -name "*.p" -exec grep "^@CLASS" -A 1 -H {} \; | awk '$0 !~ /(--|@CLASS)/{split($0, m, "-"); if(mod != m[1]){printf("\n### %s\n", m[1])} print "*", m[2]; mod = m[1]}'
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

### ./common.p
* pfClass
* pfMixin
* pfHashMixin
* pfAssert
* pfString
* pfValidate
* pfCFile
* pfRuntime
* pfOS

### ./console/console.p
* pfConsole

### ./net/curl_file.p
* pfCurlFile

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

### ./sql/models/generics/tagging/sql_tagging.p
* pfTagging
* pfSQLCTTagsModel
* pfSQLCTContentModel
* pfSQLCTCountersModel

### ./sql/models/sql_table.p
* pfSQLTable
* pfSQLBuilder
