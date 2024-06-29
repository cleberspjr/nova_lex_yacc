%{
#include <stdio.h>
#include "y.tab.h" 
#include <string.h>
%}

%% 
"PRINT"         { return PRINT_LC; }
";"       { return TERM; }
"BLOCO" { return BLOCK; }
"FIM" { return FIM; }
"NUMERO" { 
    return NUMERO; 
}

"CADEIA" { 
    return CADEIA; 
}

[0-9]+ { yylval.number=atoi(yytext); return NUMBER; }
\"([^\"\n])*\"    { yylval.string=strdup(yytext); return STR; }
[a-zA-Z]+ { yylval.string=strdup(yytext); return IDENT;} 



"("         { return ABREP; }
")"         { return FECHAP; }

"=" { return IGUAL; }
"+" { return MAIS;}

"," { 
    return VIRGULA; 
}

_[a-zA-Z0-9]+_ {
    yylval.string=strdup(yytext);
    return BLOCK_ID;
}

[\t ]+      { /* Ignorar espaços em branco e tabulações */ }
\n { /* Ignorar quebras de linha */ }
.           { printf("Caractere não reconhecido: %s\n", yytext); }

%%
