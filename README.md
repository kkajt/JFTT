# Kompilator na kurs "Języki formalne i techniki translacji" 2018/2019

## Autor
<b>Kajetan Korzycki</b><br>
236799

## O projekcie
Kompilator prostego języka impreatywnego do kodu maszyny rejestrowej z użyciem BISON-a i FLEX-a wykonany na potrzeby kursu.
Polecenie znajduje się w pliku <i>zadanie.pdf</i>.

## Technologia
Wykorzystano następujące technologie:
- <b>Flex</b> w wersji 2.6.4
- <b>Bison</b> w wersji 3.2.2

Do kompilacji programu stworzono odpowiedni plik <b>Makefile</b> korzystający z kompilatora <b>g++</b>.

## Kompilacja 
`make`

## Uruchomienie
`./kompilator plik_wejściowy plik_wyjściowy`