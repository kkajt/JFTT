%option yylineno
%option noyywrap

%{

#include <string>
#include <vector>
#include "parser.hpp"

using namespace std;
%}

DIGIT	[0-9]
PIDID 	[_a-z]+
%x COMMENT

%%

"["				BEGIN(COMMENT);
<COMMENT>{
	[^\]]		;
	"]"			BEGIN(INITIAL);
}
	

{DIGIT}+		{yylval.intval = stoll(yytext); return NUMBER;}

":="			{return ASSIGN;}
"<="			{return LEQ;}
">="			{return GEQ;}
"!="			{return NEQ;}
DECLARE			{return DECLARE;}
IN 				{return IN;}
END				{return END;}
DO				{return DO;}
ELSE			{return ELSE;}
ENDIF			{return ENDIF;}
IF				{return IF;}
THEN			{return THEN;}
ENDWHILE		{return ENDWHILE;}
WHILE			{return WHILE;}
ENDDO			{return ENDDO;}
FOR				{return FOR;}
FROM			{return FROM;}
TO				{return TO;}
DOWNTO			{return DOWNTO;}
READ			{return READ;}
WRITE			{return WRITE;}
ENDFOR			{return ENDFOR;}
{PIDID}			{yylval.pidid = (char*) strdup(yytext);
				return PIDENTIFIER;}
[ \t\n\r]+		
.				{ return(yytext[0]);}

%%