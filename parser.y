%{
int yylex(void);
void yyerror(char* s);
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Declaração de variáveis externas
extern FILE *yyin;

// Estrutura para representar um nó na tabela de símbolos
typedef struct node {
    char id[10];
    int int_val;
    char *str_val;
    struct node *next;
    int type; // 0 para int, 1 para string
} node_t;

// Estrutura para representar a tabela de símbolos
typedef struct symbol_table {
    node_t *symbols;
    struct symbol_table *next;
} symbol_table_t;

// Estrutura para representar um escopo
typedef struct escope {
    symbol_table_t* symbol_table;
    struct escope* next;
    char* name;
} escope_t;

// Pilha de escopos
escope_t *escope_stack = NULL;

// Funções para manipular a pilha de escopos e a tabela de símbolos
void push_symbol_table(char* name);
void pop_symbol_table(char* name);
node_t* get_node(symbol_table_t *symbol_table, char *lex);
node_t* get_node_from_stack(char *lex);
node_t* insertint(symbol_table_t *symbol_table, char *lex, int int_val);
node_t* insertstr(symbol_table_t *symbol_table, char *lex, char *value);
node_t* delete_node(symbol_table_t *symbol_table, char *lex);

// Função para remover aspas de uma string
char* remove_quotes(char* str) {
    char* new_str = strdup(str);
    size_t len = strlen(new_str);
    if (len > 0 && new_str[0] == '"') {
        memmove(new_str, new_str + 1, len - 1);
        new_str[len - 2] = '\0';
    }
    return new_str;
}
%}

%union {
    int number;
    char *string;
}

%token <number> NUMBER
%token <string> IDENT BLOCK_ID STR
%token IGUAL MAIS TERM PRINT_LC DEL ABREP FECHAP BLOCK FIM NUMERO CADEIA VIRGULA

%%

// Regra inicial
entrada:
    entrada list
    |
    ;

// Lista de comandos
list:
    BLOCK BLOCK_ID {
        // Entrando em um novo bloco
        //printf("Entering block: %s\n", $2);
        push_symbol_table($2);
    }
    | FIM BLOCK_ID {
        // Saindo de um bloco
        //printf("Exiting block: %s\n", $2);
        pop_symbol_table($2);
    }
    | exp
    ;

// Expressões
exp:
    decl
    | assign
    | print
    | del
    ;

// Declaração de variáveis
decl:
    NUMERO ident_list TERM {
        // Declaração de múltiplos identificadores do tipo NUMERO
    }
    | CADEIA ident_list TERM {
        // Declaração de múltiplos identificadores do tipo CADEIA
    }
    ;

// Lista de identificadores
ident_list:
    IDENT {
        // Inserindo um identificador do tipo NUMERO
        insertint(escope_stack->symbol_table, $1, 0);
        //printf("Declaration: %s\n", $1);
    }
    | IDENT IGUAL NUMBER {
        // Inserindo um identificador do tipo NUMERO com valor inicial
        insertint(escope_stack->symbol_table, $1, $3);
        //printf("Declaration: %s = %d\n", $1, $3);
    }
    | IDENT IGUAL NUMBER MAIS NUMBER {
        // Inserindo um identificador do tipo NUMERO com valor inicial sendo uma soma
        int result = $3 + $5;
        insertint(escope_stack->symbol_table, $1, result);
        //printf("Declaration: %s = %d\n", $1, result);
    }
    | IDENT IGUAL STR {
        // Inserindo um identificador do tipo CADEIA com valor inicial
        char *str_val = remove_quotes($3);
        insertstr(escope_stack->symbol_table, $1, str_val);
        //printf("Declaration: %s = \"%s\"\n", $1, str_val);
        free(str_val);
    }
    | IDENT VIRGULA ident_list {
        // Inserindo múltiplos identificadores do tipo NUMERO
        insertint(escope_stack->symbol_table, $1, 0);
        //printf("Declaration: %s\n", $1);
    }
    | IDENT IGUAL NUMBER VIRGULA ident_list {
        // Inserindo múltiplos identificadores do tipo NUMERO com valor inicial
        insertint(escope_stack->symbol_table, $1, $3);
        //printf("Declaration: %s = %d\n", $1, $3);
    }
    | IDENT IGUAL NUMBER MAIS NUMBER VIRGULA ident_list {
        // Inserindo múltiplos identificadores do tipo NUMERO com valor inicial sendo uma soma
        int result = $3 + $5;
        insertint(escope_stack->symbol_table, $1, result);
        //printf("Declaration: %s = %d\n", $1, result);
    }
    | IDENT IGUAL STR VIRGULA ident_list {
        // Inserindo múltiplos identificadores do tipo CADEIA com valor inicial
        char *str_val = remove_quotes($3);
        insertstr(escope_stack->symbol_table, $1, str_val);
        //printf("Declaration: %s = \"%s\"\n", $1, str_val);
        free(str_val);
    }
    ;

// Atribuição de valores a variáveis
assign:
    IDENT IGUAL NUMBER TERM {
        // Atribuição de um número a um identificador
        node_t* found_node = get_node_from_stack($1);
        if (found_node == NULL) {
            insertint(escope_stack->symbol_table, $1, $3);
            //printf("Assignment: %s = %d\n", $1, $3);
        } else if (found_node->type == 0) {
            found_node->int_val = $3;
            //printf("Assignment: %s = %d\n", $1, $3);
        } else {
            printf("Erro: tipos não compatíveis\n");
        }
    }
    | IDENT IGUAL NUMBER MAIS NUMBER TERM {
        // Atribuição de uma soma a um identificador
        node_t* found_node = get_node_from_stack($1);
        int result = $3 + $5;
        if (found_node == NULL) {
            insertint(escope_stack->symbol_table, $1, result);
            //printf("Assignment: %s = %d\n", $1, result);
        } else if (found_node->type == 0) {
            found_node->int_val = result;
            //printf("Assignment: %s = %d\n", $1, result);
        } else {
            printf("Erro: tipos não compatíveis\n");
        }
    }
    | IDENT IGUAL IDENT MAIS IDENT TERM {
        // Atribuição da soma de dois identificadores a um terceiro identificador
        node_t* found_node1 = get_node_from_stack($3);
        node_t* found_node2 = get_node_from_stack($5);
        node_t* found_node_dest = get_node_from_stack($1);

        if (found_node1 && found_node2) {
            if (found_node1->type == found_node2->type) {
                if (found_node1->type == 1) {
                    // Concatenação de strings
                    char *result = (char *)malloc(strlen(found_node1->str_val) + strlen(found_node2->str_val) + 1);
                    strcpy(result, found_node1->str_val);
                    strcat(result, found_node2->str_val);
                    if (found_node_dest == NULL) {
                        insertstr(escope_stack->symbol_table, $1, result);
                        //printf("Assignment: %s = \"%s\"\n", $1, result);
                    } else if (found_node_dest->type == 1) {
                        free(found_node_dest->str_val);
                        found_node_dest->str_val = result;
                       // printf("Assignment: %s = \"%s\"\n", $1, result);
                    } else {
                        printf("Erro: tipos não compatíveis\n");
                        free(result);
                    }
                } else {
                    // Soma de inteiros
                    int result = found_node1->int_val + found_node2->int_val;
                    if (found_node_dest == NULL) {
                        insertint(escope_stack->symbol_table, $1, result);
                        //printf("Assignment: %s = %d\n", $1, result);
                    } else if (found_node_dest->type == 0) {
                        found_node_dest->int_val = result;
                       // printf("Assignment: %s = %d\n", $1, result);
                    } else {
                        printf("Erro: tipos não compatíveis\n");
                    }
                }
            } else {
                printf("Erro: tipos não compatíveis\n");
            }
        } else {
            printf("Erro: variável não declarada\n");
        }
    }
    | IDENT IGUAL IDENT MAIS NUMBER TERM {
        // Atribuição da soma de um identificador e um número a um terceiro identificador
        node_t* found_node1 = get_node_from_stack($3);
        node_t* found_node_dest = get_node_from_stack($1);

        if (found_node1) {
            if (found_node1->type == 0) {
                int result = found_node1->int_val + $5;
                if (found_node_dest == NULL) {
                    insertint(escope_stack->symbol_table, $1, result);
                    //printf("Assignment: %s = %d\n", $1, result);
                } else if (found_node_dest->type == 0) {
                    found_node_dest->int_val = result;
                    //printf("Assignment: %s = %d\n", $1, result);
                } else {
                    printf("Erro: tipos não compatíveis\n");
                }
            } else {
                printf("Erro: tipos não compatíveis\n");
            }
        } else {
            printf("Erro: variável não declarada\n");
        }
    }
    | IDENT IGUAL STR TERM {
        // Atribuição de uma string a um identificador
        node_t* found_node = get_node_from_stack($1);
        char *str_val = remove_quotes($3);
        if (found_node == NULL) {
            insertstr(escope_stack->symbol_table, $1, str_val);
            //printf("Assignment: %s = \"%s\"\n", $1, str_val);
        } else if (found_node->type == 1) {
            free(found_node->str_val);
            found_node->str_val = str_val;
            //printf("Assignment: %s = \"%s\"\n", $1, str_val);
        } else {
            printf("Erro: tipos não compatíveis\n");
            free(str_val);
        }
    }
    ;

// Impressão de valores
print:
    PRINT_LC IDENT TERM {
        // Imprimindo o valor de um identificador
        node_t* found_node = get_node_from_stack($2);
        if (found_node) {
            if (found_node->type == 0) {
                printf("%d\n", found_node->int_val);
            } else {
                printf("\"%s\"\n", found_node->str_val);
            }
        } else {
            printf("Erro: variável não declarada\n");
        }
    }
    ;

// Remoção de variáveis
del:
    DEL IDENT TERM {
        // Removendo um identificador da tabela de símbolos
        delete_node(escope_stack->symbol_table, $2);
        printf("Deleted: %s\n", $2);
    }
    ;

%%

// Função principal
int main(int argc, char *argv[]) {
    if (argc > 1) {
        FILE *file = fopen(argv[1], "r");
        if (!file) {
            fprintf(stderr, "Could not open %s\n", argv[1]);
            return 1;
        }
        yyin = file;
    }
    return yyparse();
}

// Funções auxiliares

// Empilhar uma nova tabela de símbolos
void push_symbol_table(char* name) {
    escope_t *new_escope = (escope_t *)malloc(sizeof(escope_t));
    symbol_table_t *new_symbol_table = (symbol_table_t *)malloc(sizeof(symbol_table_t));
    new_symbol_table->symbols = NULL;
    new_symbol_table->next = NULL;

    new_escope->symbol_table = new_symbol_table;
    new_escope->next = escope_stack;
    new_escope->name = strdup(name);

    escope_stack = new_escope;
}

// Desempilhar a tabela de símbolos
void pop_symbol_table(char* name) {
    if (escope_stack == NULL) return;

    escope_t *temp = escope_stack;
    escope_stack = escope_stack->next;

    free(temp->name);

    // Liberar todos os nós da tabela de símbolos
    node_t *current = temp->symbol_table->symbols;
    while (current != NULL) {
        node_t *next = current->next;
        if (current->type == 1) {
            free(current->str_val);
        }
        free(current);
        current = next;
    }

    free(temp->symbol_table);
    free(temp);
}

// Buscar um nó na tabela de símbolos
node_t* get_node(symbol_table_t *symbol_table, char *lex) {
    node_t *current = symbol_table->symbols;
    while (current != NULL) {
        if (strcmp(current->id, lex) == 0) {
            return current;
        }
        current = current->next;
    }
    return NULL;
}

// Buscar um nó na pilha de escopos
node_t* get_node_from_stack(char *lex) {
    escope_t *current_escope = escope_stack;
    while (current_escope != NULL) {
        node_t *found_node = get_node(current_escope->symbol_table, lex);
        if (found_node != NULL) {
            return found_node;
        }
        current_escope = current_escope->next;
    }
    return NULL;
}

// Inserir um nó do tipo int na tabela de símbolos
node_t* insertint(symbol_table_t *symbol_table, char *lex, int int_val) {
    node_t *new_node = (node_t *)malloc(sizeof(node_t));
    strcpy(new_node->id, lex);
    new_node->int_val = int_val;
    new_node->str_val = NULL;
    new_node->type = 0;
    new_node->next = symbol_table->symbols;
    symbol_table->symbols = new_node;
    return new_node;
}

// Inserir um nó do tipo string na tabela de símbolos
node_t* insertstr(symbol_table_t *symbol_table, char *lex, char *value) {
    node_t *new_node = (node_t *)malloc(sizeof(node_t));
    strcpy(new_node->id, lex);
    new_node->int_val = 0;
    new_node->str_val = strdup(value);
    new_node->type = 1;
    new_node->next = symbol_table->symbols;
    symbol_table->symbols = new_node;
    return new_node;
}

// Remover um nó da tabela de símbolos
node_t* delete_node(symbol_table_t *symbol_table, char *lex) {
    node_t **indirect = &symbol_table->symbols;

    while (*indirect != NULL) {
        if (strcmp((*indirect)->id, lex) == 0) {
            node_t *temp = *indirect;
            *indirect = temp->next;

            if (temp->type == 1) {
                free(temp->str_val);
            }
            free(temp);
            return NULL;
        }
        indirect = &(*indirect)->next;
    }
    return NULL;
}

void yyerror(char* s) {
    fprintf(stderr, "Error: %s\n", s);
}
