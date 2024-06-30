%{
int yylex(void);
void yyerror(char* s);
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Declaração da variável yyin para o Flex/Bison
extern FILE *yyin;

typedef struct node {
    char id[10];
    int int_val;
    char *str_val;
    struct node *next;
    int type; // 0 para int, 1 para string
} node_t;

typedef struct symbol_table {
    node_t *symbols;
    struct symbol_table *next;
} symbol_table_t;

typedef struct escope {
    symbol_table_t* symbol_table;
    struct escope* next;
    char* name;
} escope_t;

escope_t *escope_stack = NULL;

void push_symbol_table(char* name);
void pop_symbol_table(char* name);
node_t* get_node(symbol_table_t *symbol_table, char *lex);
node_t* get_node_from_stack(char *lex);
node_t* insertint(symbol_table_t *symbol_table, char *lex, int int_val);
node_t* insertstr(symbol_table_t *symbol_table, char *lex, char *value);
node_t* delete_node(symbol_table_t *symbol_table, char *lex);

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

entrada:
    entrada list
    |
    ;

list:
    BLOCK BLOCK_ID {
        printf("Entering block: %s\n", $2);
        push_symbol_table($2);
    }
    | FIM BLOCK_ID {
        printf("Exiting block: %s\n", $2);
        pop_symbol_table($2);
    }
    | exp
    ;

exp:
    decl
    | assign
    | print
    | del
    ;

decl:
    NUMERO ident_list TERM {
        // Declaração de múltiplos identificadores
    }
    | CADEIA ident_list TERM {
        // Declaração de múltiplos identificadores
    }
    ;

ident_list:
    IDENT {
        insertint(escope_stack->symbol_table, $1, 0);
        printf("Declaration: %s\n", $1);
    }
    | IDENT IGUAL NUMBER {
        insertint(escope_stack->symbol_table, $1, $3);
        printf("Declaration: %s = %d\n", $1, $3);
    }
    | IDENT IGUAL NUMBER MAIS NUMBER {
        int result = $3 + $5;
        insertint(escope_stack->symbol_table, $1, result);
        printf("Declaration: %s = %d\n", $1, result);
    }
    | IDENT IGUAL STR {
        char *str_val = remove_quotes($3);
        insertstr(escope_stack->symbol_table, $1, str_val);
        printf("Declaration: %s = \"%s\"\n", $1, str_val);
        free(str_val);
    }
    | IDENT VIRGULA ident_list {
        insertint(escope_stack->symbol_table, $1, 0);
        printf("Declaration: %s\n", $1);
    }
    | IDENT IGUAL NUMBER VIRGULA ident_list {
        insertint(escope_stack->symbol_table, $1, $3);
        printf("Declaration: %s = %d\n", $1, $3);
    }
    | IDENT IGUAL NUMBER MAIS NUMBER VIRGULA ident_list {
        int result = $3 + $5;
        insertint(escope_stack->symbol_table, $1, result);
        printf("Declaration: %s = %d\n", $1, result);
    }
    | IDENT IGUAL STR VIRGULA ident_list {
        char *str_val = remove_quotes($3);
        insertstr(escope_stack->symbol_table, $1, str_val);
        printf("Declaration: %s = \"%s\"\n", $1, str_val);
        free(str_val);
    }
    ;

assign:
    IDENT IGUAL NUMBER TERM {
        node_t* found_node = get_node_from_stack($1);
        if (found_node == NULL) {
            insertint(escope_stack->symbol_table, $1, $3);
            printf("Assignment: %s = %d\n", $1, $3);
        } else if (found_node->type == 0) {
            found_node->int_val = $3;
            printf("Assignment: %s = %d\n", $1, $3);
        } else {
            printf("Erro: tipos não compatíveis\n");
        }
    }
    | IDENT IGUAL NUMBER MAIS NUMBER TERM {
        node_t* found_node = get_node_from_stack($1);
        int result = $3 + $5;
        if (found_node == NULL) {
            insertint(escope_stack->symbol_table, $1, result);
            printf("Assignment: %s = %d\n", $1, result);
        } else if (found_node->type == 0) {
            found_node->int_val = result;
            printf("Assignment: %s = %d\n", $1, result);
        } else {
            printf("Erro: tipos não compatíveis\n");
        }
    }
    | IDENT IGUAL IDENT MAIS IDENT TERM {
        node_t* found_node1 = get_node_from_stack($3);
        node_t* found_node2 = get_node_from_stack($5);
        node_t* found_node_dest = get_node_from_stack($1);

        if (found_node1 && found_node2) {
            if (found_node1->type == found_node2->type) {
                if (found_node1->type == 1) {
                    char *result = (char *)malloc(strlen(found_node1->str_val) + strlen(found_node2->str_val) + 1); // +1 para terminador nulo
                    strcpy(result, found_node1->str_val);
                    strcat(result, found_node2->str_val);
                    if (found_node_dest == NULL) {
                        insertstr(escope_stack->symbol_table, $1, result);
                        printf("Assignment: %s = \"%s\"\n", $1, result);
                    } else if (found_node_dest->type == 1) {
                        free(found_node_dest->str_val);
                        found_node_dest->str_val = result;
                        printf("Assignment: %s = \"%s\"\n", $1, result);
                    } else {
                        printf("Erro: tipos não compatíveis\n");
                        free(result);
                    }
                } else {
                    int result = found_node1->int_val + found_node2->int_val;
                    if (found_node_dest == NULL) {
                        insertint(escope_stack->symbol_table, $1, result);
                        printf("Assignment: %s = %d\n", $1, result);
                    } else if (found_node_dest->type == 0) {
                        found_node_dest->int_val = result;
                        printf("Assignment: %s = %d\n", $1, result);
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
        node_t* found_node1 = get_node_from_stack($3);
        node_t* found_node_dest = get_node_from_stack($1);

        if (found_node1) {
            if (found_node1->type == 0) {
                int result = found_node1->int_val + $5;
                if (found_node_dest == NULL) {
                    insertint(escope_stack->symbol_table, $1, result);
                    printf("Assignment: %s = %d\n", $1, result);
                } else if (found_node_dest->type == 0) {
                    found_node_dest->int_val = result;
                    printf("Assignment: %s = %d\n", $1, result);
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
    | IDENT IGUAL IDENT MAIS IDENT MAIS IDENT TERM {
        node_t* found_node1 = get_node_from_stack($3);
        node_t* found_node2 = get_node_from_stack($5);
        node_t* found_node3 = get_node_from_stack($7);
        node_t* found_node_dest = get_node_from_stack($1);

        if (found_node1 && found_node2 && found_node3) {
            if (found_node1->type == found_node2->type && found_node2->type == found_node3->type) {
                if (found_node1->type == 1) {
                    char *result = (char *)malloc(strlen(found_node1->str_val) + strlen(found_node2->str_val) + strlen(found_node3->str_val) + 1); // +1 para terminador nulo
                    strcpy(result, found_node1->str_val);
                    strcat(result, found_node2->str_val);
                    strcat(result, found_node3->str_val);
                    if (found_node_dest == NULL) {
                        insertstr(escope_stack->symbol_table, $1, result);
                        printf("Assignment: %s = \"%s\"\n", $1, result);
                    } else if (found_node_dest->type == 1) {
                        free(found_node_dest->str_val);
                        found_node_dest->str_val = result;
                        printf("Assignment: %s = \"%s\"\n", $1, result);
                    } else {
                        printf("Erro: tipos não compatíveis\n");
                        free(result);
                    }
                } else {
                    int result = found_node1->int_val + found_node2->int_val + found_node3->int_val;
                    if (found_node_dest == NULL) {
                        insertint(escope_stack->symbol_table, $1, result);
                        printf("Assignment: %s = %d\n", $1, result);
                    } else if (found_node_dest->type == 0) {
                        found_node_dest->int_val = result;
                        printf("Assignment: %s = %d\n", $1, result);
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
    ;

print:
    PRINT_LC IDENT TERM {
        node_t* found_node = get_node_from_stack($2);
        if (found_node) {
            if (found_node->type == 0) {
                printf("Value of %s: %d\n", $2, found_node->int_val);
            } else {
                printf("Value of %s: %s\n", $2, found_node->str_val);
            }
        } else {
            printf("Erro: variável não declarada\n");
        }
    }
    ;

del:
    DEL IDENT TERM {
        node_t* node = delete_node(escope_stack->symbol_table, $2);
        if (node) {
            printf("Deleted %s\n", $2);
            if (node->type == 1) {
                free(node->str_val);
            }
            free(node);
        } else {
            printf("Erro: variável não declarada\n");
        }
    }
    ;

%%

int main(int argc, char **argv) {
    ++argv, --argc;
    if (argc > 0) {
        FILE *file = fopen(argv[0], "r");
        if (!file) {
            fprintf(stderr, "Could not open %s\n", argv[0]);
            return 1;
        }
        yyin = file;
    }
    return yyparse();
}

void yyerror(char* s) {
    fprintf(stderr, "Error: %s\n", s);
}

void push_symbol_table(char* name) {
    escope_t* new_escope = (escope_t*)malloc(sizeof(escope_t));
    new_escope->symbol_table = (symbol_table_t*)malloc(sizeof(symbol_table_t));
    new_escope->symbol_table->symbols = NULL;
    new_escope->symbol_table->next = NULL;
    new_escope->name = strdup(name);
    new_escope->next = escope_stack;
    escope_stack = new_escope;
}

void pop_symbol_table(char* name) {
    if (escope_stack != NULL) {
        escope_t* top = escope_stack;
        escope_stack = escope_stack->next;

        // Libera a tabela de símbolos
        node_t* current = top->symbol_table->symbols;
        while (current != NULL) {
            node_t* temp = current;
            current = current->next;
            if (temp->type == 1) {
                free(temp->str_val);
            }
            free(temp);
        }
        free(top->symbol_table);
        free(top->name);
        free(top);
    }
}

node_t* get_node(symbol_table_t *symbol_table, char *lex) {
    node_t* current = symbol_table->symbols;
    while (current != NULL) {
        if (strcmp(current->id, lex) == 0) {
            return current;
        }
        current = current->next;
    }
    return NULL;
}

node_t* get_node_from_stack(char *lex) {
    escope_t* current_scope = escope_stack;
    while (current_scope != NULL) {
        node_t* node = get_node(current_scope->symbol_table, lex);
        if (node != NULL) {
            return node;
        }
        current_scope = current_scope->next;
    }
    return NULL;
}

node_t* insertint(symbol_table_t *symbol_table, char *lex, int int_val) {
    node_t* new_node = (node_t*)malloc(sizeof(node_t));
    strcpy(new_node->id, lex);
    new_node->int_val = int_val;
    new_node->str_val = NULL;
    new_node->next = symbol_table->symbols;
    new_node->type = 0;
    symbol_table->symbols = new_node;
    return new_node;
}

node_t* insertstr(symbol_table_t *symbol_table, char *lex, char *value) {
    node_t* new_node = (node_t*)malloc(sizeof(node_t));
    strcpy(new_node->id, lex);
    new_node->int_val = 0;
    new_node->str_val = strdup(value);
    new_node->next = symbol_table->symbols;
    new_node->type = 1;
    symbol_table->symbols = new_node;
    return new_node;
}

node_t* delete_node(symbol_table_t *symbol_table, char *lex) {
    node_t *current = symbol_table->symbols;
    node_t *prev = NULL;

    while (current != NULL && strcmp(current->id, lex) != 0) {
        prev = current;
        current = current->next;
    }

    if (current == NULL) {
        return NULL; // Node not found
    }

    if (prev == NULL) {
        // Node is the head of the list
        symbol_table->symbols = current->next;
    } else {
        prev->next = current->next;
    }

    return current;
}
