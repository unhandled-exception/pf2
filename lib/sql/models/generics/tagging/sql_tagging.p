#PF2 library

@USE
pf/sql/models/sql_table.p


@CLASS
pfTagging

## Класс ддя тегирования контента в базе данных.

@OPTIONS
locals

@BASE
pfClass

@create[aOptions]
## aOptions.sql - ссылка на sql-класс.
## aOptions.tagsSeparator[,] - разделитель тегов
## aOptions.contentType(0) - стандартный content_type_id
## aOptions.tablesPrefix
## aOptions.tagsModel
## aOptions.contentModel
## aOptions.countersModel
  ^self.cleanMethodArgument[]

  $self._CSQL[$aOptions.sql]
  ^self.defReadProperty[CSQL]

  $self._tablesPrefix[$aOptions.tablesPrefix]
  $self._tagsSeparator[^if(def $aOptions.tagsSeparator){$aOptions.tagsSeparator}{,}]

  $self._contentType[^aOptions.contentType.int(0)]
  ^self.defReadProperty[contentType]

# Переменные с моделями, но они нужны только для работы свойств
  $self._tags[$aOptions.tagsModel]
  $self._content[$aOptions.contentModel]
  $self._counters[$aOptions.countersModel]

@GET_tags[]
  ^if(!def $self._tags){
    $self._tags[^pfSQLCTTagsModel::create[${self._tablesPrefix}tags;
      $.sql[$CSQL]
      $.tagging[$self]
    ]]
  }
  $result[$self._tags]

@GET_content[]
  ^if(!def $self._content){
    $self._content[^pfSQLCTContentModel::create[${self._tablesPrefix}tags_content;
      $.sql[$CSQL]
      $.tagging[$self]
    ]]
  }
  $result[$self._content]

@GET_counters[]
  ^if(!def $self._counters){
    $self._counters[^pfSQLCTCountersModel::create[${self._tablesPrefix}tags_counters;
      $.sql[$CSQL]
      $.tagging[$self]
    ]]
  }
  $result[$self._counters]

@assignTags[aContent;aTags;aOptions]
## Тегирует контент (можно протегировать сразу много объектов по куче тегов)
## aContent — string|int|hash|table. Для хеша id берем из ключа, для таблицы из колонки.
## aOptions.contentTableColumn[contentID] — имя колонки в таблице с контентом, содержащее ID
## aTags — string|table|hash
## aOptions.tagsTableColumn[tagID] — имя колонки в таблице с тегами, содержащее tagID
## aOptions.mode[new|append] — заново протегировать контент или добавить теги к уже существующим
## aOptions.contentType
## TODO:
## aOptions.appendParents(false) - добавить родительские теги
  ^self.cleanMethodArgument[]
  ^CSQL.transaction{
    $lTags[$aTags]
    ^if($aTags is string){
#     Если передали строку, то достаем из нее теги и добавляем, при необходимости
      $lTags[^hash::create[]]
      $lAllTags[^tags.all[]]
      $lTagsParts[^aTags.split[$self._tagsSeparator;lv;title]]
      ^lTagsParts.foreach[k;v]{
        $lTagTitle[^tags.normalizeString[$v.title]]
        ^if(^lAllTags.locate[lowerTitle;^lTagTitle.lower[]]){
          $lTags.[$lAllTags.tagID][$lAllTags.title]
        }{
           $lNewTagID[^tags.new[^tags.assignSlug[$.title[$lTagTitle]]]]
           $lTags.[$lNewTagID][$lTagTitle]
         }
      }
    }

    $lContentType[^aOptions.contentType.int($self._contentType)]
    ^if(!def $aOptions.mode || $aOptions.mode eq "new"){
#     Удаляем старые связи тегов и контента
      ^content.deleteAll[
        $.[contentID in][$aContent]
        $.contentType[$lContentType]
      ]
    }
    ^lTags.foreach[lTagID;lTagTitle]{
#     Тегируем контент
      ^switch[$aContent.CLASS_NAME]{
        ^case[table;hash]{^throw[not.implemented]}
        ^case[string;int]{
          ^content.newOrModify[
            $.tagID[$lTagID]
            $.contentID[$aContent]
            $.contentType[$lContentType]
          ]
        }
      }
    }
  }

  ^counters.recount[]

#----- Таблички в БД -----

@CLASS
pfSQLCTTagsModel

@OPTIONS
locals

@BASE
pfSQLTable

@create[aTableName;aOptions]
  ^self.cleanMethodArgument[]
  ^BASE:create[$aTableName;
    $.sql[$aOptions.sql]
    $.allAsTable(true)
  ]

  $self._tagging[$aOptions.tagging]
  ^self.defReadProperty[tagging]

  ^self.addFields[
    $.tagID[$.dbField[tag_id] $.plural[tags] $.processor[uint] $.primary(true) $.widget[none]]
    $.parentID[$.dbField[parent_id] $.plural[parents] $.processor[uint] $.label[]]
    $.threadID[$.dbField[thread_id] $.plural[threads] $.processor[uint] $.label[]]
    $.title[$.label[] $.processor[tag_title]]
    $.slug[$.label[]]
    $.description[$.label[]]
    $.sortOrder[$.dbField[sort_order] $.processor[int] $.label[]]
    $.isActive[$.dbField[is_active] $.processor[bool] $.default(1) $.widget[none]]
    $.createdAt[$.dbField[created_at] $.processor[auto_now] $.skipOnUpdate(true) $.widget[none]]
    $.updatedAt[$.dbField[updated_at] $.processor[auto_now] $.widget[none]]
  ]

  ^self.addFields[
    $.lowerTitle[$.expression[lower($title)] $.processor[tag_lower_title]]
  ]

  $self._defaultOrderBy[$.sortOrder[asc] $.title[asc] $.tagID[asc]]

  $self._transliter[]

@GET_transliter[]
  ^if(!def $self._transliter){
    ^use[pf2/lib/web/helpers/translit.p]
    $self._transliter[^pfURLTranslit::create[]]
  }
  $result[$self._transliter]

@delete[aTagID]
  $result[^self.modify[$aTagID;$.isActive(false)]]

@restore[aTagID]
  $result[^self.modify[$aTagID;$.isActive(true)]]

@fieldValue[aField;aValue]
  ^if($aField is string){
    $aField[$self._fields.[$aField]]
  }
  $result[^switch[$aField.processor]{
    ^case[tag_title]{"^taint[^self.normalizeString[$aValue]]"}
    ^case[tag_lower_title]{"^taint[^self.normalizeString[^aValue.lower[]]]"}
    ^case[DEFAULT]{^BASE:fieldValue[$aField;$aValue]}
  }]

@normalizeString[aString]
  $result[^aString.match[\s+][g][ ]]
  $result[^result.trim[]]

@assignSlug[aData]
  ^self.cleanMethodArgument[]
  $lData[^hash::create[$aData]]
  ^if(!^lData.contains[slug] || (^lData.contains[slug] && !def ^lData.slug.trim[])){
    $lData.slug[^transliter.toURL[$lData.title]]
  }
  $result[$lData]

#--------------------------------------------------------------------------------

@CLASS
pfSQLCTContentModel

@OPTIONS
locals

@BASE
pfSQLTable

@create[aTableName;aOptions]
  ^self.cleanMethodArgument[]
  ^BASE:create[$aTableName;
    $.sql[$aOptions.sql]
    $.allAsTable(true)
  ]

  $self._tagging[$aOptions.tagging]
  ^self.defReadProperty[tagging]

  ^self.addFields[
    $.tagID[$.dbField[tag_id] $.plural[tags] $.processor[uint] $.label[]]
    $.contentID[$.dbField[content_id] $.plural[content] $.processor[uint] $.label[]]
    $.contentType[$.dbField[content_type_id] $.plural[contentTypes] $.processor[uint] $.default($self._tagging.contentType) $.label[]]
    $.createdAt[$.dbField[created_at] $.processor[auto_now] $.skipOnUpdate(true) $.widget[none]]
    $.updatedAt[$.dbField[updated_at] $.processor[auto_now] $.widget[none]]
  ]

@_allJoin[aOptions]
## aOptions.orderByTags(false)
  $result[^BASE:_allJoin[$aOptions]
    ^if(^aOptions.orderByTags.bool(false)){
      join $self._tagging.tags.TABLE_EXPRESSION on ($tagID = $self._tagging.tags.tagID)
    }
  ]

@_allOrder[aOptions]
## aOptions.orderByTags(false)
  ^if(^aOptions.orderByTags.bool(false)){
    $result[$self._tagging.tags.sortOrder asc, $self._tagging.tags.title asc, $self._tagging.tags.tagID asc]
  }{
     $result[^BASE:_allOrder[$aOptions]]
   }

@counts[aOptions]
  ^self.cleanMethodArgument[]
  $result[^self.aggregate[
    _fields(tagID, contentType);
    count(*) as cnt;
    $aOptions
    $.groupBy[$.tagID[asc] $.contentType[asc]]
  ]]

#--------------------------------------------------------------------------------

@CLASS
pfSQLCTCountersModel

@OPTIONS
locals

@BASE
pfSQLTable

@create[aTableName;aOptions]
  ^self.cleanMethodArgument[]
  ^BASE:create[$aTableName;
    $.sql[$aOptions.sql]
    $.allAsTable(true)
  ]

  $self._tagging[$aOptions.tagging]
  ^self.defReadProperty[tagging]

  ^self.addFields[
    $.tagID[$.dbField[tag_id] $.plural[tags] $.processor[uint] $.label[]]
    $.contentType[$.dbField[content_type_id] $.plural[contentTypes] $.default($self._tagging.contentType) $.processor[int] $.label[]]
    $.cnt[$.processor[uint] $.label[]]
    $.createdAt[$.dbField[created_at] $.processor[auto_now] $.skipOnUpdate(true) $.widget[none]]
    $.updatedAt[$.dbField[updated_at] $.processor[auto_now] $.widget[none]]
  ]

@recount[aOptions]
  $aOptions[^hash::create[$aOptions]]
  ^self.CSQL.transaction{
    $lCounts[^self._tagging.content.counts[$aOptions]]
    ^self.deleteAll[$aOptions]
    ^lCounts.foreach[k;v]{
      ^self.newOrModify[$v.fields]
    }
  }
