# PF2 Library

@CLASS
pfURLTranslit

@OPTIONS
locals

@USE
pf2/lib/common.p

@BASE
pfClass

## Транслитерация ссылок (приведение их в соответствие с форматом URL).
## Латинские буквы и цифры остаются, а русские + знаки препинания преобразуются
## одним из способов (способы нужны каждый для своей задачи).
##
## Класс можно использовать статически и динамически.

@create[]
  ^BASE:create[]
  ^self._init[]

@auto[]
  ^self._init[]

@toURL[aString;aOptions]
## Преобразовать строку в "красивый читаемый URL".
## aOptions.allowSlashes(0) — игнорировать ли символ "/", пропуская его неисправленным,
##                            либо удалять его из строки
  ^self.cleanMethodArgument[]
  $lSlash[^if(^aOptions.allowSlashes.int(0)){/}]

  $result[^aString.trim[both]]
  $result[^result.match[[\s\.,?!\[\](){}]+][g][-]]
  $result[^result.match[[\-_]+][g][-]]
  $result[^result.trim[both;-_]]

  $result[^result.lower[]]

  $result[^result.match[(?:ь|ъ)([$self._vowel])][g]{j$match.1}]
  $result[^result.match[(?:ь|ъ)][g][]]

  $result[^result.replace[$self._letters]]
  $result[^result.match[j{2,}][g][j]]

  $result[^result.match[[^^${lSlash}0-9a-z_\-]+][g][]]

@toSupertag[aString;aOptions]
## Преобразовать строку в "супертаг" — короткий простой
## идентификатор, состоящий из латинских букв и цифр.
## aOptions.allowSlashes(0) — игнорировать ли символ "/", пропуская его неисправленным,
##                            либо удалять его из строки
  ^self.cleanMethodArgument[]
  $lSlash[^if(^aOptions.allowSlashes.int(0)){/}]

  $result[^self.toURL[$aString;$aOptions]]
  $result[^result.match[[^^${lSlash}0-9a-zA-Z\-]+][g][]]
  $result[^result.match[[\-_]+][g]{-}]
  $result[^result.match[-+^$][g][-]]

@toWiki[aString;aOptions]
## Преобразовать произвольную строку в вики-адрес
## например: "Привет мир" => "ПриветМир"
## aOptions.allowSlashes(0) — игнорировать ли символ "/", пропуская его неисправленным,
##                            либо удалять его из строки
  ^self.cleanMethodArgument[]
  $lSlash[^if(^aOptions.allowSlashes.int(0)){/}]

  $result[^aString.match[[^^\- 0-9a-zA-Zа-яА-ЯёЁ${lSlash}]+][g][ ]]

  $lStrings[^result.split[ ]]
  $result[]
  ^lStrings.menu{
    $result[${result}^lStrings.piece.match[^^\s*(.)(.*)][]{^match.1.upper[]^if(def $match.2){^match.2.lower[]}}]
  }

@fromWiki[aString]
## Пробуем восстановить примерный вид исходной строки по вики-адресу
## например: "ПриветМир" => "Привет Мир"
  $result[^aString.match[([^^\-\/])([A-ZА-Я][a-zа-я0-9])][g]{$match.1 $match.2}]
  $result[^result.match[([^^0-9 \-\/])([0-9])][g]{$match.1 $match.2}]

@encode[aString;aOptions]
## Транслитерировать текст
## aOptions.allowSlashes(0) — игнорировать ли символ "/", пропуская его неисправленным,
##                            либо удалять его из строки
  $result[^self.bidi[$aString;encode;$aOptions]]

@decode[aString;aOptions]
## Де транслитерировать текст :)
## aOptions.allowSlashes(0) — игнорировать ли символ "/", пропуская его неисправленным,
##                            либо удалять его из строки
  $result[^self.bidi[$aString;decode;$aOptions]]


@bidi[aString;aDirection;aOptions]
## преобразовать строку в "формально правильный URL"
## с возможностью восстановления.
## Другое значение $aDirection[encode|decode] позволяет восстановить
## строку обратно с незначительными потерями
## aOptions.allowSlashes(0) — игнорировать ли символ "/", пропуская его неисправленным,
##                            либо удалять его из строки
  ^self.cleanMethodArgument[]
  $lSlash[^if(^aOptions.allowSlashes.int(0)){/}]

  ^if($aDirection eq "encode"){
    $result[^aString.match[[^^\- \'_0-9a-zA-Zа-яА-ЯёЁ${lSlash}]][g][]]
    $result[^result.match[([а-яА-ЯёЁ ]+)][g]{+^match.1.replace[$self._tran]+}]
  }{
     $result[$aString]
     $result[^result.match[\+(.*?)\+][g]{^match.1.replace[$self._detran]}]
     ^if(!def $lSlash){^result.replace[^table::create[nameless]{/	}]}
	 }

@_init[]
## Инициализируем необходимые переменные

  $self._letters[^table::create{from	to
а	a
б	b
в	v
г	g
д	d
е	e
з	z
и	i
к	k
л	l
м	m
н	n
о	o
п	p
р	r
с	s
т	t
у	u
ф	f
ы	y
э	e
й	j
х	h
ё	e
ж	zh
ц	ts
ч	ch
ш	sh
щ	sch
ю	ju
я	ja}]

  $self._vowel[аеёиоуыэюя]

  $self._tran[^table::create{from	to
А	A
Б	B
В	V
Г	G
Д	D
Е	E
Ё	JO
Ж	ZH
З	Z
И	I
Й	JJ
К	K
Л	L
М	M
Н	N
О	O
П	P
Р	R
С	S
Т	T
У	U
Ф	F
Х	H
Ц	C
Ч	CH
Ш	SH
Щ	SHH
Ъ	_~
Ы	Y
Ь	_'
Э	EH
Ю	JU
Я	JA
а	a
б	b
в	v
г	g
д	d
е	e
ё	jo
ж	zh
з	z
и	i
й	jj
к	k
л	l
м	m
н	n
о	o
п	p
р	r
с	s
т	t
у	u
ф	f
х	h
ц	c
ч	ch
ш	sh
щ	shh
ъ	~
ы	y
ь	'
э	eh
ю	ju
я	ja
 	__
_	__}]

  $self._detran[^table::create{from	to
SHH	Щ
JO	Ё
ZH	Ж
JJ	Й
KH	Х
CH	Ч
SH	Ш
EH	Э
JU	Ю
JA	Я
H	Х
A	А
B	Б
V	В
G	Г
D	Д
E	Е
Z	З
I	И
K	К
L	Л
M	М
N	Н
O	О
P	П
R	Р
S	С
T	Т
U	У
F	Ф
C	Ц
Y	Ы
shh	щ
_'	Ь
_~	Ъ
jo	ё
zh	ж
jj	й
kh	х
ch	ч
sh	ш
eh	э
ju	ю
ja	я
a	а
b	б
v	в
g	г
d	д
e	е
z	з
i	и
k	к
l	л
m	м
n	н
o	о
p	п
r	р
s	с
t	т
u	у
f	ф
c	ц
~	ъ
y	ы
'	ь
__	^#20}]
