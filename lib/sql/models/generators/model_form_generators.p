# PF2 library

@USE
pf2/lib/common.p

@CLASS
pfTableFormGenerator

## Генерирует «заготовку» формы по модели
## Этот класс — пример написания генераторов кода и заточен под библиотеку Бутстрап 2
## и мой подход к работе с шаблонами, поэтому не надо ждать от него универсальности.

## Виджеты:
##   none — без виджета (пропускаем поле)
##   [input] — стандартный виджет, если не указано иное
##   password
##   hidden
##   textarea
## Виджеты-заготовки (для них  форме выводится шаблончик, который надо дописать программисту :)
##   checkbox
##   radio
##   select

@OPTIONS
locals

@BASE
pfClass

@create[aOptions]
## aOptions.widgets[object]
  ^self.cleanMethodArgument[]
  ^BASE:create[]
  $self._defaultArgName[aFormData]

  $self._widgets[^if(def $aOptions.widgets){$aOptions.widgets}{^pfTableFormGeneratorBootstrap2Widgets::create[]}]

@generate[aModel;aOptions]
## aOptions.argName
  ^pfAssert:isTrue($aModel is pfSQLTable)[Модель "$aModel.CLASS_NAME" должна быть наследником pfSQLTable.]
  $aOptions[^hash::create[$aOptions]]
  $aOptions.argName[^if(def $aOptions.agrName){$aOptions.argName}{$self._defaultArgName}]
  $result[^hash::create[]]

  ^aModel.FIELDS.foreach[k;v]{
    ^if(^self._hasWidget[$v;$aModel]){
      $result.[^result._count[]][^self._makeWidgetLine[$v;$aOptions]]
    }
  }
  $result[@form^[$aOptions.argName^;aOptions^]
  ^^cleanMethodArgument^[^]
  ^^cleanMethodArgument^[$aOptions.argName^]
  ^self._widgets.formWidget{
    ^result.foreach[k;v]{$v^#0A^#0A}
    ^self._widgets.submitWidget[$aOptions]
  }
  ]
  $result[^result.match[(^^\s*^$)][gmx][^#0A]]
  $result[^result.match[\n{3,}][g][^#0A]]

@_hasWidget[aField;aModel]
  $result($aField.widget ne none)

@_makeWidgetLine[aField;aOptions]
  $result[^switch[$aField.widget]{
    ^case[;input;password]{^self._widgets.inputWidget[$aField;$aField.widget;$aOptions]}
    ^case[hidden]{^self._widgets.hiddenWidget[$aField;$aOptions]}
    ^case[textarea]{^self._widgets.textareaWidget[$aField;$aOptions]}
    ^case[checkbox;radio]{^self._widgets.checkboxWidget[$aField;$aField.widget;$aOptions]}
    ^case[select]{^self._widgets.selectWidget[$aField;$aOptions]}
  }]

#--------------------------------------------------------------------------------------------------
# Виджеты для генератора форм
#--------------------------------------------------------------------------------------------------

@CLASS
pfTableFormGeneratorBootstrap2Widgets

## Bootstrap 2

@OPTIONS
locals

@BASE
pfClass

@create[aOptions]
  ^BASE:create[]

@formWidget[aBlock]
  $result[<form action="" method="post" class="form-horizontal">
    $aBlock
  </form>]

@inputWidget[aField;aType;aOptions]
  $result[
    <div class="control-group">
      <label for="f-$aField.name" class="control-label">$aField.label</label>
      <div class="controls">
        <input type="^if(def $aType){$aType}{text}" name="$aField.name" id="f-$aField.name" value="^$${aOptions.argName}.$aField.name" class="input-xxlarge" placeholder="" />
      </div>
    </div>]

@textareaWidget[aField;aOptions]
  $result[
    <div class="control-group">
      <label for="f-$aField.name" class="control-label">$aField.label</label>
      <div class="controls">
        <textarea name="$aField.name" id="f-$aField.name" class="input-xxlarge" rows="7" placeholder="" />^$${aOptions.argName}.$aField.name</textarea>
      </div>
    </div>]

@checkboxWidget[aField;aType;aOptions]
  $lVarName[^$${aOptions.argName}.$aField.name]
  $aType[^if(def $aType){$aType}{checkbox}]
  $result[
    <div class="control-group">
      <div class="controls">
        <label class="$aType"><input type="$aType" name="$aField.name" id="f-${aField.name}1" value="1" ^^if($lVarName){checked="true"} /> $aField.label</label>
      </div>
    </div>]

@selectWidget[aField;aOptions]
  $result[
    <div class="control-group">
      <label for="f-$aField.name" class="control-label">$aField.label</label>
      <div class="controls">
        <select name="$aField.name" id="f-$aField.name" class="input-xxlarge" placeholder="">
          <option value=""></option>
^#          <option value="" ^^if(^$${aOptions.argName}.$aField.name eq ""){selected="true"}></option>
        </select>
      </div>
    </div>]

@hiddenWidget[aField;aOptions]
  $result[    <input type="hidden" name="$aField.name" value="^$${aOptions.argName}.$aField.name" />]

@submitWidget[aOptions]
  ^self.cleanMethodArgument[]
  $result[^^REQUEST.CSRF.tokenField^[^]
    <div class="control-group">
      <div class="controls">
        <input type="submit" id="f-sub" value="Сохранить" class="btn btn-primary" />
        или <a href="^^linkTo^[/^]" class="action">Ничего не менять</a>
      </div>
    </div>
  ]

#--------------------------------------------------------------------------------------------------

@CLASS
pfTableFormGeneratorBootstrap3Widgets

## Bootstrap 3

@OPTIONS
locals

@BASE
pfClass

@create[aOptions]
  ^BASE:create[]

@formWidget[aBlock]
  $result[<form action="" method="post">
    $aBlock
  </form>]

@inputWidget[aField;aType;aOptions]
  $result[
    <div class="form-group">
      <label for="f-$aField.name" class="control-label col-sm-3">$aField.label</label>
      <div class="col-sm-9">
        <input type="^if(def $aType){$aType}{text}" name="$aField.name" id="f-$aField.name" value="^$${aOptions.argName}.$aField.name" class="form-control" placeholder="" />
      </div>
    </div>]

@textareaWidget[aField;aOptions]
  $result[
    <div class="form-group">
      <label for="f-$aField.name" class="control-label col-sm-3">$aField.label</label>
      <div class="col-sm-9">
        <textarea name="$aField.name" id="f-$aField.name" class="form-control" rows="7" placeholder="" />^$${aOptions.argName}.$aField.name</textarea>
      </div>
    </div>]

@checkboxWidget[aField;aType;aOptions]
  $lVarName[^$${aOptions.argName}.$aField.name]
  $aType[^if(def $aType){$aType}{checkbox}]
  $result[
    <div class="form-group">
      <div class="col-sm-offset-3 col-sm-9">
        <div class="$aType"><label><input type="$aType" name="$aField.name" id="f-${aField.name}1" value="1" ^^if($lVarName){checked="true"} /> $aField.label</label></div>
      </div>
    </div>]

@selectWidget[aField;aOptions]
  $result[
    <div class="form-group">
      <label for="f-$aField.name" class="control-label col-sm-3">$aField.label</label>
      <div class="col-sm-9">
        <select name="$aField.name" id="f-$aField.name" class="form-control" placeholder="">
          <option value=""></option>
^#          <option value="" ^^if(^$${aOptions.argName}.$aField.name eq ""){selected="true"}></option>
        </select>
      </div>
    </div>]

@hiddenWidget[aField;aOptions]
  $result[    <input type="hidden" name="$aField.name" value="^$${aOptions.argName}.$aField.name" />]

@submitWidget[aOptions]
  ^self.cleanMethodArgument[]
  $result[^^REQUEST.CSRF.tokenField^[^]
    <div class="form-group">
      <div class="col-sm-offset-3 col-sm-9">
        <input type="submit" id="f-sub" value="Сохранить" class="btn btn-primary" />
        или <a href="^^linkTo^[/^]" class="action">Ничего не менять</a>
      </div>
    </div>
  ]

#--------------------------------------------------------------------------------------------------

@CLASS
pfTableFormGeneratorBootstrap4HorizontalWidgets

## Bootstrap 4 (horizontal)

@OPTIONS
locals

@BASE
pfClass

@create[aOptions]
  ^BASE:create[]

@formWidget[aBlock]
  $result[<form action="" method="post" class="form-horizontal form-default">
    ^^REQUEST.CSRF.tokenField^[^]
    $aBlock
  </form>]

@inputWidget[aField;aType;aOptions]
  $result[
    <div class="form-group row">
      <label for="f-$aField.name" class="col-sm-3 col-form-label">$aField.label</label>
      <div class="col-sm-9">
        <input type="^if(def $aType){$aType}{text}" name="$aField.name" id="f-$aField.name" value="^$${aOptions.argName}.$aField.name" class="form-control" placeholder="" />
      </div>
    </div>]

@textareaWidget[aField;aOptions]
  $result[
    <div class="form-group row">
      <label for="f-$aField.name" class="col-sm-3 col-form-label">$aField.label</label>
      <div class="col-sm-9">
        <textarea name="$aField.name" id="f-$aField.name" class="form-control" rows="7" placeholder="" />^$${aOptions.argName}.$aField.name</textarea>
      </div>
    </div>]

@checkboxWidget[aField;aType;aOptions]
  $lVarName[^$${aOptions.argName}.$aField.name]
  $aType[^if(def $aType){$aType}{checkbox}]
  $result[
    <div class="form-group row">
      <div class="col-sm-offset-3 col-sm-9">
      <label><input type="$aType" name="$aField.name" id="f-${aField.name}1" value="1" ^^if($lVarName){checked="true"} class="form-check-input" /> $aField.label</label>
      </div>
    </div>]

@selectWidget[aField;aOptions]
  $result[
    <div class="form-group row">
      <label for="f-$aField.name" class="col-sm-3 col-form-label">$aField.label</label>
      <div class="col-sm-9">
        <select name="$aField.name" id="f-$aField.name" class="form-control" placeholder="">
          <option value=""></option>
^#          <option value="" ^^if(^$${aOptions.argName}.$aField.name eq ""){selected="true"}></option>
        </select>
      </div>
    </div>]

@hiddenWidget[aField;aOptions]
  $result[    <input type="hidden" name="$aField.name" value="^$${aOptions.argName}.$aField.name" />]

@submitWidget[aOptions]
  ^self.cleanMethodArgument[]
  $result[<div class="form-group row">
      <div class="offset-sm-3 col-sm-9">
        <input type="submit" id="f-sub" value="Сохранить" class="btn btn-primary" />
        <a href="^^linkTo^[/^]" class="btn btn-outline-primary ml-2">Ничего не менять</a>
      </div>
    </div>
  ]

#--------------------------------------------------------------------------------------------------

@CLASS
pfTableFormGeneratorBootstrap4VerticalWidgets

## Bootstrap 4 (vertical)

@OPTIONS
locals

@BASE
pfClass

@create[aOptions]
  ^BASE:create[]

@formWidget[aBlock]
  $result[<form action="" method="post" class="form-horizontal form-default">
    ^^REQUEST.CSRF.tokenField^[^]
    $aBlock
  </form>]

@inputWidget[aField;aType;aOptions]
  $result[
    <div class="form-group">
      <label for="f-$aField.name">$aField.label</label>
      <input type="^if(def $aType){$aType}{text}" name="$aField.name" id="f-$aField.name" value="^$${aOptions.argName}.$aField.name" class="form-control" placeholder="" />
    </div>]

@textareaWidget[aField;aOptions]
  $result[
    <div class="form-group">
      <label for="f-$aField.name">$aField.label</label>
      <textarea name="$aField.name" id="f-$aField.name" class="form-control" rows="7" placeholder="" />^$${aOptions.argName}.$aField.name</textarea>
    </div>]

@checkboxWidget[aField;aType;aOptions]
  $lVarName[^$${aOptions.argName}.$aField.name]
  $aType[^if(def $aType){$aType}{checkbox}]
  $result[
    <div class="form-group">
      <div class="form-check">
        <label class="form-check-label"><input type="$aType" name="$aField.name" id="f-${aField.name}1" value="1" ^^if($lVarName){checked="true"} class="form-check-input" /> $aField.label</label>
        </div>
      </div>
    </div>]

@selectWidget[aField;aOptions]
  $result[
    <div class="form-group">
      <label for="f-$aField.name">$aField.label</label>
      <select name="$aField.name" id="f-$aField.name" class="form-control" placeholder="">
        <option value=""></option>
^#        <option value="" ^^if(^$${aOptions.argName}.$aField.name eq ""){selected="true"}></option>
      </select>
    </div>]

@hiddenWidget[aField;aOptions]
  $result[    <input type="hidden" name="$aField.name" value="^$${aOptions.argName}.$aField.name" />]

@submitWidget[aOptions]
  ^self.cleanMethodArgument[]
  $result[<div class="form-group">
      <input type="submit" id="f-sub" value="Сохранить" class="btn btn-primary" />
      <a href="^^linkTo^[/^]" class="btn btn-outline-primary ml-2">Ничего не менять</a>
    </div>
  ]

#--------------------------------------------------------------------------------------------------

@CLASS
pfTableFormGeneratorSemanticUIWidgets

## SemanticUI — http://semantic-ui.com/

@OPTIONS
locals

@BASE
pfClass

@create[aOptions]
  ^BASE:create[]

@formWidget[aBlock]
  $result[<form action="" method="post" class="ui form">
    $aBlock
  </form>
  <script>
    jQuery(function(){
      ^^^$('select.dropdown').dropdown()^^^;
      ^^^$('.ui.checkbox').checkbox()^^^;
    })^^^;
  </script>]

@inputWidget[aField;aType;aOptions]
  $result[
    <div class="field">
      <label for="f-$aField.name">$aField.label</label>
      <input type="^if(def $aType){$aType}{text}" name="$aField.name" id="f-$aField.name" value="^$${aOptions.argName}.$aField.name" class="" placeholder="" />
    </div>]

@textareaWidget[aField;aOptions]
  $result[
    <div class="field">
      <label for="f-$aField.name">$aField.label</label>
      <textarea name="$aField.name" id="f-$aField.name" rows="7" class="" placeholder="" />^$${aOptions.argName}.$aField.name</textarea>
    </div>]

@checkboxWidget[aField;aType;aOptions]
  $lVarName[^$${aOptions.argName}.$aField.name]
  $aType[^if(def $aType){$aType}{checkbox}]
  $result[
    <div class="ui ^if($aType eq "radio"){radio }checkbox field">
      <input type="$aType" name="$aField.name" id="f-${aField.name}1" value="1" ^^if($lVarName){checked="true"} />
      <label for="f-$aField.name">$aField.label</label>
    </div>]

@selectWidget[aField;aOptions]
  $result[
    <div class="field">
      <label for="f-$aField.name">$aField.label</label>
      <select name="$aField.name" id="f-$aField.name" class="ui dropdown" placeholder="">
        <option value=""></option>
^#        <option value="" ^^if(^$${aOptions.argName}.$aField.name eq ""){selected="true"}></option>
      </select>
    </div>]

@hiddenWidget[aField;aOptions]
  $result[    <input type="hidden" name="$aField.name" value="^$${aOptions.argName}.$aField.name" />]

@submitWidget[aOptions]
  ^self.cleanMethodArgument[]
  $result[^^REQUEST.CSRF.tokenField^[^]
    <div class="ui hidden divider"></div>
    <button type="submit" class="ui primary button">Сохранить</button>
    или <a href="^^linkTo^[/^]" class="action">Ничего не менять</a>
  ]
