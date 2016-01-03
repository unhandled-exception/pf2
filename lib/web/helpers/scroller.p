# PF2 Library

@USE
pf2/lib/common.p

@CLASS
pfScroller

## Скролер (построение "страничной" навигации)

## В текущей реализации - класс-адаптер для класса scroller Михаила Петрушина.
## http://www.parser.ru/examples/mscroller/
## Копия класса scraller переименована в __AL_Scroller__и лежит в этом пакете.
## Прямой вызов оригинального скроллера в контексте классов PF запрещен.

## Важные отличия: если не определен номер текущей страницы, то он не берется из
## formName, а считается равным 1. Это нужно, чтобы избежать обращения к классу
## form непосредственно из скроллера. Кроме того в методе _print удалены некоторые
## "лишние" параметры (tag_name, tag_attr).

@BASE
pfClass

@create[aItemsCount;aItemsPerPage;aCurrentPage;aOptions]
## aOptions.formName[page] - название элемента формы через который передается номер страницы.
## aOptions.direction[forward|backward] - направление нумерации страниц
  ^pfAssert:isTrue(def $aItemsCount)[Не задано количество элементов скролера.]
  ^pfAssert:isTrue($aItemsCount >= 0)[Количество элементов скролера не может быть меньше нуля.]
  ^pfAssert:isTrue(def $aItemsPerPage)[Не задано количество элементов на странице скролера.]
  ^pfAssert:isTrue($aItemsPerPage >= 1)[Количество элементов на странице скролера не может быть меньше 1.]

  ^cleanMethodArgument[]
  $_directions[$.forward(1) $.backward(-1) $._default(1)]
  $_scroller[^__AL_Scroller__::init[$aItemsCount;$aItemsPerPage;$aOptions.formName;$_directions.[$aOptions.direction];$aCurrentPage]]

#----- Properties -----

# $itemsCount 		- количество записей
# $limit		- количество записей на страницу
# $offset 		- смещение для получение первой записи текущей страницы (надодля sql запросов)
# $pagesCount 		- количество страниц
# $currentPage 		- N текущей страницы
# $currentPageNumber	- порядковый номер текущей страницы
# $currentPageName 	- название текущей страницы
# $direction 		- направление нумерации страниц ( < 0 то последняя страница имеет номер 1 )
# $firstPage 		- N первой страницы
# $lastPage 		- N последней страницы
# $formName		- название элемента формы через который передается номер страницы (по умолчанию "page")

@GET[aType]
  $result($pagesCount > 1)

@GET_itemsCount[]
  $result[$_scroller.items_count]

@GET_limit[]
  $result[$_scroller.limit]

@GET_offset[]
  $result[$_scroller.offset]

@GET_pagesCount[]
  $result[$_scroller.page_count]

@GET_currentPage[]
  $result[$_scroller.current_page]

@GET_currentPageNumber[]
  $result[$_scroller.current_page_number]

@GET_currentPageName[]
  $result[$_scroller.current_page_name]

@GET_direction[]
  ^if($_scroller.direction >= 0){
    $result[forward]
  }{
     $result[backward]
   }

@GET_firstPage[]
  $result[$_scroller.first_page]

@GET_lastPage[]
  $result[$_scroller.last_page]

@GET_formName[]
  $result[$_scroller.form_name]

@asHTML[aOptions]
  $result[^_print[html;$aOptions]]

@asXML[aOptions]
  $result[^_print[xml;$aOptions]]

@_print[aMode;aOptions]
## выводит html постраничной навигации
## принимает параметры (хеш)
## $aMode			- тип вывода. сейчас умеет: html|xml
## aOptions.navCount		- количество отображаемых ссылок на страницы (по умолчанию 5)
## aOptions.separator		- разделитель пропусков в страницах (по умолчанию "…")
## aOptions.title		- заголовок постраничной навигации (по умолчанию "Страницы: ")
## aOptions.leftDivider		- разделитель между "Назад" и первой страницей (по умолчанию "")
## aOptions.rightDivider	- разделитель между последней страницей и "Дальше" (по умолчанию: "|")
## aOptions.backName		- "< Назад"
## aOptions.forwardName		- "Дальше >"
## aOptions.targetURL		- URL куда мы будем переходить (по умолчанию "./")

  ^cleanMethodArgument[]

  $result[^_scroller.print[
     $.mode[$aMode]
     $.nav_count[$aOptions.navCount]
     $.separator[$aOptions.separator]
     $.title[$aOptions.title]
     $.left_divider[$aOptions.leftDivider]
     $.right_divider[$aOptions.rightDivider]
     $.back_name[$aOptions.backName]
     $.forward_name[$aOptions.forwardName]
     $.target_url[$aOptions.targetURL]
  ]]

#--------------------------------------------------------------------------------------------------

@CLASS
__AL_Scroller__

# $Id: scroller.p,v 1.14 2005/08/16 07:54:59 misha Exp $

@init[items_count;items_per_page;form_name;direction;page][is_full_page]
# конструктор. первые 2 параметра обязательны.
# при инициализации расчитываются все параметры постраничной навигации

# доступные поля:
# $items_count      - количество записей
# $limit        - количество записей на страницу
# $page_count       - количество страниц
# $current_page     - N текущей страницы
# $current_page_number  - порядковый номер текущей страницы
# $current_page_name  - название текущей страницы
# $offset         - смещение для получение первой записи текущей страницы (надодля sql запросов)
# $direction      - направление нумерации страниц ( < 0 то последняя страница имеет номер 1 )
# $first_page       - N первой страницы
# $last_page      - N последней страницы
# $form_name      - название элемента формы через который передается номер страницы (по умолчанию "page")

# пример создания объекта: $my_scroller[^scroller::init[$total_items_count;50;page]]

^if(!def $items_count){
  ^throw[scroller;Items count must be defined.]
}
^if(!^items_per_page.int(0)){
  ^throw[scroller;Items per page must be defined and not equal 0.]
}
$self.mode[xml]
$self.form_name[^if(def $form_name){$form_name}{page}]
^if(!def $page){
  $page[$form:[$self.form_name]]
}
$self.items_count(^items_count.int(0))
$limit(^items_per_page.int(0))
$page_count(^math:ceiling($self.items_count / $limit))
^if(^direction.int(0) < 0){
  $current_page(^page.int($page_count))
  ^if($current_page > $page_count){
    $current_page($page_count)
  }{
    ^if($current_page < 1){$current_page(1)}
  }
  $current_page_number($page_count - $current_page + 1)
  $current_page_name($current_page_number)
  ^if($page_count && $current_page < $page_count){
    $is_full_page(^if($self.items_count % $limit){1}{0})
    $offset($self.items_count % $limit + ($page_count - $current_page - $is_full_page) * $limit)
  }{
    $offset(0)
  }
  $self.direction(-1)
  $first_page($page_count)
  $last_page(1)
}{
  $current_page(^page.int(1))
  ^if($current_page > $page_count){
    $current_page($page_count)
  }{
    ^if($current_page < 1){$current_page(1)}
  }
  $current_page_number($current_page)
  $current_page_name($current_page)
  $self.direction(+1)
  $first_page(1)
  $last_page($page_count)
  ^if($page_count){
    $offset(($current_page - 1) * $limit)
  }{
    $offset(0)
  }
}

@print[in_params][lparams;nav_count;page_number;first_nav;last_nav;separator;url_separator;ipage;i;title]
# выводит html постраничной навигации
# принимает параметры (хеш)
# $mode       - тип вывода. сейчас умеет: html|xml
# $nav_count    - количество отображаемых ссылок на страницы (по умолчанию 5)
# $separator    - разделитель пропусков в страницах (по умолчанию "…")
# $tag_name     - тег в котором все выводим
# $tag_attr     - аттрибуты тега
# $title      - заголовок постраничной навигации (по умолчанию "Страницы: ")
# $left_divider   - разделитель между "Назад" и первой страницей (по умолчанию "")
# $right_divider  - разделитель между последней страницей и "Дальше" (по умолчанию: "|")
# $back_name    - "< Назад"
# $forward_name   - "Дальше >"
# $target_url   - URL куда мы будем переходить (по умолчанию "./")

# пример вызова (после создания объекта $scroller):
# ^my_scroller.print[
#   $.mode[html]
#   $.target_url[./]
#   $.nav_count(9)
#   $.left_divider[|]
# ]

^if($page_count > 1){
  $lparams[^hash::create[$in_params]]
  ^if(def $lparams.mode){
    $mode[$lparams.mode]
  }
  $nav_count(^lparams.nav_count.int(5))
  $first_nav($current_page_number - $nav_count \ 2)
  ^if($first_nav < 1){
    $first_nav(1)
  }
  $last_nav($first_nav + $nav_count - 1)
  ^if($last_nav > $page_count){
    $last_nav($page_count)
    $first_nav($last_nav - $nav_count)
    ^if($first_nav < 1){$first_nav(1)}
  }
  $separator[^if(def $lparams.separator){$lparams.separator}{…}]
  $url_separator[^if(^lparams.target_url.pos[?]>=0){^taint[&]}{?}]
  ^if(def $lparams.tag_name){
    <$lparams.tag_name $lparams.tag_attr>
  }
  $title[^if(def $lparams.title){$lparams.title}{Страницы: }]
  ^if($mode eq "html"){
    $title
  }{
    <title>$title</title>
    ^if(def $lparams.left_divider){<left-divider>$lparams.left_divider</left-divider>}
    ^if(def $lparams.right_divider){<right-divider>$lparams.right_divider</right-divider>}
  }
  ^if($current_page != $first_page){
    ^print_nav_item[back;^if(def $lparams.back_name){$lparams.back_name}{&larr^; Назад};$lparams.target_url;$url_separator;^eval($current_page - $direction)]
    ^if($mode eq "html"){
      ^if(def $lparams.left_divider){$lparams.left_divider}
    }
  }
  ^if($first_nav > 1){
    ^print_nav_item[first;1;$lparams.target_url;$url_separator;$first_page]
    ^if($first_nav > 2){
      ^print_nav_item[separator;$separator]
    }
  }
  ^for[i]($first_nav;$last_nav){
    ^if($direction < 0){
      $ipage($page_count - $i + 1)
    }{
      $ipage($i)
    }
    ^print_nav_item[^if($ipage == $current_page){current};$i;$lparams.target_url;$url_separator;$ipage]
  }
  ^if($last_nav < $page_count){
    ^if($last_nav < $page_count - 1){
      ^print_nav_item[separator;$separator]
    }
    ^print_nav_item[last;$page_count;$lparams.target_url;$url_separator;$last_page]
  }
  ^if($current_page != $last_page){
    ^if($mode eq "html"){
      ^if(def $lparams.right_divider){$lparams.right_divider}{|}
    }
    ^print_nav_item[forward;^if(def $lparams.forward_name){$lparams.forward_name}{Дальше&nbsp^;&rarr^;};$lparams.target_url;$url_separator;^eval($current_page + $direction)]
  }
  ^if(def $lparams.tag_name){</$lparams.tag_name>}
}

@print_nav_item[type;name;url;url_separator;page_num]
# выводит элемент постраничной навигации
^if($mode eq "html"){
  ^if($type eq "separator"){
    $result[$name]
  }{
    ^if($type ne "current" && def $page_num){
      $result[<a href="^untaint[html]{^if(def $url){$url}{./}^if($page_num != $first_page){${url_separator}$form_name=$page_num}}"><span>$name</span></a>]]
    }{
      $result[<span>$name</span>]
    }
  }
}{
  $result[<page
    ^if(def $type){ type="$type"}
    ^if($type ne "current" && def $page_num){
      href="^untaint[xml]{^if(def $url){$url}{./}^if($page_num != $first_page){${url_separator}$form_name=$page_num}}"
    }
    num="$name"
  />]
}
