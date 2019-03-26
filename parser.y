%{
#include <stdio.h>
#include <string>
#include <vector>
#include <iostream>
#include <sstream>
#include <fstream>
#include <bitset>

#define YYDEBUG 1


using namespace std;
int yylex (void);
void yyerror (char const *);
extern int yylineno;
extern FILE *yyin;


FILE *read_code(char* input);
void print_code(char* output, vector<string> commands);

long long code_offset = 0;
long long data_offset = 0;
long long iterator_no = 0;

string get_iter_name() {
	return "iterator" + to_string(iterator_no++);
}

long long data_reserve() {
	return data_offset++;
}

long long data_reserve(long long n) {
	long long d = data_offset;
	data_offset+=n;
	return d;
}

typedef struct instruction instruction;

struct jumps {
	long long for_jump;
	long long for_jzero;
};

typedef struct jumps jumps;

struct forStruct {
	long long for_jump;
	long long condStart;
	long long for_jump_to_endfor;
	string finish_var_name;
};
struct jumps* newjump() {
	return (struct jumps*) malloc(sizeof(struct jumps));
}

vector<string> code;

void code_gen(string op) { 
	code.push_back(op);
	code_offset++;
}

long long code_reserve() {
	long long address = code_offset;
	code_gen("LABEL");
	return address;
}

long long get_code_offset() {
	return code_offset;
}

void back_patch(string operation, long long address) {
	code[address] = operation;
}


void print_code();

struct variable {
	string name;
	long long size;
	long long start;
	long long offset;
	bool isArray;
	bool isIterator;
	bool isInitialized;
	struct variable *next;
};
typedef struct variable variable;

variable* var_table = (variable *)0;

struct varStruct {
	vector<string> *commands;
	long long offset;
	string name;
};

struct conditionStruct {
	long long jmpAddr;
	long long startCond;
};

variable* put_var(string var_name, long long size, long long start, bool isIterator, bool isArray, bool isInitialized);
variable* get_var(string var_name);
void delete_var(string var_name);

void declare_var(string var_name, long long size, long long start, bool isArray);

void read(vector<string> *cmds);
void write(vector<string> *cmds);
void multiply();
void divide();
forStruct* genFor(char* pidid, vector<string> *val1, vector<string> *val2, bool down_to);
void finishFor(forStruct *forStr, char* pidid, bool down_to);


vector<string>* gen_num(long long val);
vector<string>* load_var(string var_name);
void add_code(vector<string> *cmds);

%}

%union semrec {
	long long intval;
	char* pidid;
	struct varStruct *varstr;
	std::vector<std::string> *commands;
	struct jumps *jmp;
	struct conditionStruct *cond;
	struct forStruct *forStr;
}

%start program
%token <intval> NUMBER
%token <pidid> PIDENTIFIER 
%token <jmp> IF WHILE DO
%token <forStr> FOR
%token END ENDIF ENDFOR THEN ELSE ELSEIF FROM TO DOWNTO ENDWHILE ENDDO
%token INTEGER READ WRITE DECLARE IN
%token LEQ GEQ NEQ
%token ASSIGN

%type <varstr> identifier
%type <commands> value
%type <cond> condition

%left '-' '+'
%left '*' '/'

%%

program: 
	DECLARE declarations IN commands END {
		code_gen("HALT");
	}
;

declarations:
	declarations PIDENTIFIER';'	{ declare_var($2, 1, 0, false);}
| 	declarations PIDENTIFIER'('NUMBER':'NUMBER')'';'	{
		if ((long long) $6 < (long long)$4) {
			ostringstream os;
			os<<"Zła deklaracja tablicy "<<$2<<endl;
			yyerror(os.str().c_str());
		}
		long long size = $6 - $4 + 1; 
		declare_var($2, size, $4, true);
	} 
|
;

commands:
	commands command
|	command
;

command:
	identifier ASSIGN expression';'	{

		code_gen("COPY D B");

		varStruct* v = (varStruct*) $1;
		variable *tmp = get_var(v->name);
		if (tmp->isIterator) {
			ostringstream os;
			os<<"Niedozwolona modyfikacja iteratora "<<v->name<<"."<<endl;
			yyerror(os.str().c_str());
		}
		tmp->isInitialized = true;
		// A <- address of identifier
		if (v->offset == -1) {
			for(long long i=0; i<v->commands->size(); i++) {
				code_gen(v->commands->at(i));
			}
		}
		else {
			vector<string> *commands = gen_num(v->offset);
			for(long long i=0; i<commands->size(); i++) {
				code_gen(commands->at(i));
			}
			delete commands;
			code_gen("COPY A B");
		}
		code_gen("STORE D");
		delete v->commands;
		delete v;

	}
|	IF condition THEN commands { 
		$1 = new jumps();
		$1->for_jump = code_reserve(); 
		$1->for_jzero = $2->jmpAddr;
	}
	ELSE {
		back_patch("JZERO B " + to_string(get_code_offset()), $1->for_jzero);
	} 
	commands ENDIF {
		back_patch("JUMP " + to_string(get_code_offset()), $1->for_jump);
	}
|	IF condition THEN commands ENDIF {
		back_patch("JZERO B " + to_string(get_code_offset()), $2->jmpAddr);
	}
|	WHILE condition DO commands {
		$1 = new jumps();
		$1->for_jzero = $2->jmpAddr;
		code_gen("JUMP " + to_string($2->startCond));
	}
	ENDWHILE { back_patch("JZERO B " + to_string(get_code_offset()), $2->jmpAddr); }
|	DO {
		$1 = new jumps();
		$1 -> for_jump = get_code_offset();
	}
	commands WHILE condition {
		code_gen("JUMP " + to_string($1->for_jump));
	}
	ENDDO { back_patch("JZERO B " + to_string($5->jmpAddr +2), $5->jmpAddr); }
|	FOR PIDENTIFIER FROM value TO value {
		$1 = genFor((char*)$2, (vector<string> *)$4,(vector<string> *) $6, false);

	}
	DO commands ENDFOR {
		finishFor((forStruct *) $1, (char*) $2, false);
	}
|	FOR PIDENTIFIER FROM value DOWNTO value {
		$1 = genFor((char*)$2, (vector<string> *)$4,(vector<string> *) $6, true);	
	} 
	DO commands ENDFOR {
		finishFor((forStruct *) $1, (char*) $2, true);
	}
|	READ identifier';'	{ 
		varStruct* v = (varStruct*) $2;
		variable *tmp = get_var(v->name);
		if (tmp->isIterator) {
			ostringstream os;
			os<<"Niedozwolona modyfikacja iteratora "<<v->name<<"."<<endl;
			yyerror(os.str().c_str());
		}
		tmp -> isInitialized = true;
		if (v->offset == -1) {
			read(v->commands);
		}
		else {
			vector<string> *commands;
			commands = gen_num(v->offset);
			commands->push_back("COPY A B");
			read(commands);
		}
	}
|	WRITE value';'	{
		vector<string>* commands = (vector<string>*) $2;
		write(commands);
	}
;

expression:
	value	{ 
		vector<string> *commands = (vector<string>*) $1;
		add_code(commands);
	}
|	value '+' value {
		vector<string> *commands = (vector<string>*) $3;
		add_code(commands);
		code_gen("COPY D B");
		commands = (vector<string>*) $1;
		add_code(commands);
		code_gen("ADD B D");
	}
|	value '-' value {
		vector<string> *commands = (vector<string>*)$3;
		add_code(commands);
		code_gen("COPY D B");
		commands = (vector<string>*) $1;
		add_code(commands);
		code_gen("SUB B D");
	} 
|	value '*' value {
		vector<string> *commands = (vector<string>*) $3;
		add_code(commands);
		code_gen("COPY D B");
		commands = (vector<string>*) $1;
		add_code(commands);
		code_gen("COPY C D");
		multiply();
	}
|	value '/' value {
		vector<string> *commands = (vector<string>*) $3;
		add_code(commands);
		code_gen("COPY D B");
		commands = (vector<string>*) $1;
		add_code(commands);
		code_gen("COPY A B");
		code_gen("COPY B D");
		divide();
		code_gen("COPY B C");
	}
|	value '%' value {
		vector<string> *commands = (vector<string>*) $3;
		add_code(commands);
		code_gen("COPY D B");
		commands = (vector<string>*) $1;
		add_code(commands);
		code_gen("COPY A B");
		code_gen("COPY B D");
		divide();
		code_gen("COPY B A");
	}
;

condition:
	value '=' value {
		struct conditionStruct *cond = new conditionStruct();
		cond -> startCond = get_code_offset();
		add_code($3);
		code_gen("COPY D B");
		add_code($1);
		code_gen("COPY A B");
		code_gen("SUB A D");
		code_gen("SUB D B");
		code_gen("SUB B B");
		code_gen("ADD B A");
		code_gen("ADD B D");
		code_gen("JZERO B " + to_string(3+code_offset));
		code_gen("SUB B B");
		code_gen("JUMP "+ to_string(2 + code_offset));
		code_gen("INC B");
		code_gen("LABEL JUMP");
		cond->jmpAddr = get_code_offset() -1;
		$$ = cond;
	}
|	value NEQ value {
		struct conditionStruct *cond = new conditionStruct();
		cond -> startCond = get_code_offset();
		add_code($3);
		code_gen("COPY D B");
		add_code($1);
		code_gen("COPY A B");
		code_gen("SUB A D");
		code_gen("SUB D B");
		code_gen("SUB B B");
		code_gen("ADD B A");
		code_gen("ADD B D");
		code_gen("LABEL JUMP");
		cond->jmpAddr = get_code_offset() -1;
		$$ = cond;
	}
|	value '<' value {
		struct conditionStruct *cond = new conditionStruct();
		cond -> startCond = get_code_offset();
		add_code($1);
		code_gen("COPY D B");
		add_code($3);
		code_gen("SUB B D");
		code_gen("LABEL JUMP");
		cond->jmpAddr = get_code_offset() -1;
		$$ = cond;
	}
|	value '>' value {
		struct conditionStruct *cond = new conditionStruct();
		cond -> startCond = get_code_offset();
		add_code($3);
		code_gen("COPY D B");
		add_code($1);
		code_gen("SUB B D");
		code_gen("LABEL JUMP");
		cond->jmpAddr = get_code_offset() -1;
		$$ = cond;
	}
|	value LEQ value {
		struct conditionStruct *cond = new conditionStruct();
		cond -> startCond = get_code_offset();
		add_code($1);
		code_gen("COPY D B");
		add_code($3);
		code_gen("INC B");
		code_gen("SUB B D");
		code_gen("LABEL JUMP");
		cond->jmpAddr = get_code_offset() -1;
		$$ = cond;
	}
|	value GEQ value {
		struct conditionStruct *cond = new conditionStruct();
		cond -> startCond = get_code_offset();
		add_code($3);
		code_gen("COPY C B");
		add_code($1);
		code_gen("INC B");
		code_gen("SUB B C");
		code_gen("LABEL JUMP");
		cond->jmpAddr = get_code_offset() -1;
		$$ = cond;
	}
;

value:
	NUMBER	{ $$ = gen_num($1);}
|	identifier {
		vector<string> *commands = new vector<string>();
		varStruct* v = (varStruct*) $1;
		variable *tmp = get_var(v->name);
		if (!tmp->isInitialized) {
			ostringstream os;
			os<<"Niezainicjowana zmienna "<<tmp->name<<"."<<endl;
			yyerror(os.str().c_str());
		}

		if (v->offset == -1) {
			commands->insert(commands->end(), v->commands->begin(), v->commands->end());
			commands->push_back("LOAD B");
		}
		else {
			commands = gen_num(v->offset);
			commands->push_back("COPY A B");
			commands->push_back("LOAD B");
		}
		delete v->commands;
		delete v;
		$$ = commands;
	}
;

identifier:
	PIDENTIFIER	{
		variable* temp = get_var($1);
		if (temp == 0) {
			ostringstream os;
			os<<"Zmienna "<<$1<<" nie została zadeklarowana."<<endl;
			yyerror(os.str().c_str());
		}
		if(temp->isArray) {
			ostringstream os;
			os<<"Niewłaściwe użycie zmiennej "<<$1<<"."<<endl;
			yyerror(os.str().c_str());
		}
		struct varStruct *res = new varStruct();
		res->name = $1;
		res->offset = temp->offset;
		$$ = res;
	}

|	PIDENTIFIER'('PIDENTIFIER')' { 
		struct varStruct *res = new varStruct();
		vector<string> *cmds = load_var($3); 
		res->commands = cmds;
		res->commands->push_back("COPY C B");
		variable* temp = get_var($1);
		if (temp == 0) {
			ostringstream os;
			os<<"Zmienna "<<$1<<" nie została zadeklarowana."<<endl;
			yyerror(os.str().c_str());
		}
		else if (!temp->isArray) {
			ostringstream os;
			os<<"Niewłaściwe użycie zmiennej "<<$1<<"."<<endl;
			yyerror(os.str().c_str());
		}
		cmds = gen_num(temp->offset);
		res->commands->insert(res->commands->end(), cmds->begin(), cmds->end());
		res->commands->push_back("ADD C B");
		cmds = gen_num(temp->start);
		res->commands->insert(res->commands->end(), cmds->begin(), cmds->end());
		res->commands->push_back("COPY A C");
		res->commands->push_back("SUB A B");
		res->offset = -1;
		res->name = $1;
		$$ = res;

	}
|	PIDENTIFIER'('NUMBER')'	{
		variable* temp = get_var($1);
		if (temp == 0) {
			ostringstream os;
			os<<"Zmienna "<<$1<<" nie została zadeklarowana."<<endl;
			yyerror(os.str().c_str());
		}
		else if (!temp->isArray) {
			ostringstream os;
			os<<"Niewłaściwe użycie zmiennej "<<$1<<"."<<endl;
			yyerror(os.str().c_str());
		}
		else {
			struct varStruct *res = new varStruct();
			if (temp->start > $3 || temp->start+temp->size-1 < $3) {
				ostringstream os;
				os<<"Indeks spoza zakresu tablicy."<<endl;
				yyerror(os.str().c_str());
			}
			res->name = $1;
			res->offset = temp->offset+$3-temp->start;
			$$ = res;
		}
	}
;

%%

forStruct* genFor(char* pidid, vector<string> *val1, vector<string> *val2, bool down_to) {
	variable* temp = get_var(pidid);
	if (temp != 0) {
		ostringstream os;
		os<<"Zmienna "<<pidid<<" została już zadeklarowana."<<endl;
		yyerror(os.str().c_str());
	}
	// create new variable for iterator with staring value
	put_var(pidid, 1, 0, true, false, true);
	variable *v = get_var(pidid);
	vector<string> *cmds = gen_num(v->offset);
	add_code(cmds);
	code_gen("COPY E B");
	add_code(val1);
	code_gen("COPY A E");
	code_gen("STORE B");
	
	// create new variable for finish value with name iterator_$num
	string iter_finish = get_iter_name();
	put_var(iter_finish, 1, 0, true, false, true);
	v = get_var(iter_finish);
	cmds = gen_num(v->offset);
	add_code(cmds);
	code_gen("COPY E B");
	add_code(val2);
	code_gen("COPY A E");
	code_gen("STORE B");
	

	forStruct *forstr = new forStruct();
	forstr -> finish_var_name = iter_finish;
	forstr -> for_jump = get_code_offset();

	if (!down_to)
		v = get_var(pidid);
	else 
		v = get_var(iter_finish);
	cmds = gen_num(v->offset);
	add_code(cmds);
	code_gen("COPY A B");
	code_gen("LOAD B");
	// move iterator to D register
	code_gen("COPY D B");

	if (!down_to)
		v = get_var(iter_finish);
	else
		v = get_var(pidid); 
	cmds = gen_num(v->offset);
	add_code(cmds);
	code_gen("COPY A B");
	code_gen("LOAD B");
	code_gen("INC B");
	code_gen("SUB B D");

	code_gen("LABEL JZERO"); // if zero jump till the end
	forstr -> for_jump_to_endfor = get_code_offset() -1;
	return forstr;
}

void finishFor(forStruct *forStr, char* pidid, bool down_to) {
		variable *v = get_var(pidid);
		vector<string> *cmds = gen_num(v->offset);
		add_code(cmds);
		code_gen("COPY A B");
		code_gen("LOAD B");
		if (down_to) {
			code_gen("JZERO B "+to_string(get_code_offset() + 5));
			code_gen("DEC B");
		}
		else {
			code_gen("INC B");
		}
		code_gen("STORE B");


		code_gen("JUMP " + to_string(forStr->for_jump));
		back_patch("JZERO B " + to_string(get_code_offset()), forStr->for_jump_to_endfor);
		delete_var(pidid);
		delete_var(forStr->finish_var_name);
}

void delete_var(string var_name) {
	variable *v, *prev;
	if (var_table == 0) return;

	if (var_table->name == var_name) {
		v = var_table;
		var_table = v->next;
		delete v;
		return;
	}
	
	prev = var_table;
	for (v = var_table->next; v!=(variable*)0; v = (variable*) v->next) {
		if (v->name == var_name) {
			prev->next = v->next;
			delete v;
		}
		prev = v;
	}
}

variable* put_var(string var_name, long long size, long long start, bool isIterator, bool isArray, bool isInitialized) {
	variable *new_var = new variable();
	//new_var = (variable*) malloc(sizeof(variable));
	new_var -> name = var_name;
	new_var -> offset = data_reserve(size);
	new_var -> size = size;
	new_var -> start = start;
	new_var -> next = (struct variable *) var_table;
	new_var -> isIterator = isIterator;
	new_var -> isArray = isArray;
	new_var -> isInitialized = isInitialized;
	var_table = new_var;
	return new_var;
}

variable* get_var(string var_name) {
	variable* v;
	for (v = var_table; v!=(variable*)0; v = (variable*) v->next) {
		if (v->name == var_name) return v;
	}
	return 0;
}

// returns commands to load VARIABLE VALUE by name to B register (uses A and B registers)
vector<string>* load_var(string var_name) {
	vector<string> *commands = new vector<string>();
	variable *v;
	v = get_var(var_name);
	if (v == 0) {
		ostringstream os;
		os<<"Zmienna "<< var_name <<" jest niezadeklarowana."<<endl;
		yyerror(os.str().c_str());
	}
	else if (v->isArray) {
		ostringstream os;
		os<<"Zmienna "<< var_name <<" jest tablicą."<<endl;
		yyerror(os.str().c_str());
	}
	else {
		commands = gen_num(v->offset);
		commands->push_back("COPY A B");
		commands->push_back("LOAD B");
	}
	return commands;
}


// adds vector of strings to main code (code_gen)
void add_code(vector<string> *cmds) {
	for(long long i=0; i<cmds->size(); i++) {
			code_gen(cmds->at(i));
	}
	delete cmds;
}

vector<string>* gen_num(long long val){
	vector<string> *commands = new vector<string>();
	commands->push_back("SUB B B");
	if (val == 0) {
		return commands;
	}
	if (val < 10) {
		for (long long i=0; i<val; i++){
			commands->push_back("INC B");
		}
	}
	else {
	    string binary = bitset<64>(val).to_string();
	    long long size = binary.size();
	    for (long long i=0; i<size; i++){
	    	if(binary[i] == '1') {
	    		commands->push_back("INC B");
	    	}
	    	if (i < (size - 1)) {
	    		commands->push_back("ADD B B");
	    	}
	    }
	}
	return commands;


}


void read(vector<string>* cmds){
	code_gen("GET C");
	for(long long i=0; i<cmds->size(); i++) {
		code_gen(cmds->at(i));
	}
	code_gen("STORE C");	
}

void write(vector<string>* cmds){
	for(long long i=0; i<cmds->size(); i++) {
		code_gen(cmds->at(i));
	}
	code_gen("PUT B");
	
}


// Multiply assuming a*b: a is in B register, b is in C register, result in D register
void multiply() {
	code_gen("SUB D D");
	code_gen("JZERO C " + to_string(code_offset+8));
	code_gen("INC C");
	code_gen("JODD C " + to_string(code_offset+2));
	code_gen("ADD D B");
	code_gen("DEC C");
	code_gen("ADD B B");
	code_gen("HALF C");
	code_gen("JUMP " + to_string(code_offset-7));
	code_gen("COPY B D");
}

// DIVIDE a/b assuming a is in A, b is in B register
void divide() {
	code_gen("SUB C C");
	code_gen("JZERO B " + to_string(get_code_offset() + 20 )); // if b=0, jump over all of it
	code_gen("SUB D D");
	code_gen("INC D"); // D <- 1

	code_gen("COPY E A");
	code_gen("SUB E B"); 
	code_gen("JZERO E " + to_string(get_code_offset()+4)); 
	code_gen("ADD B B");
	code_gen("ADD D D");
	code_gen("JUMP " + to_string(get_code_offset()-5));

	code_gen("COPY E B");
	code_gen("SUB E A");
	code_gen("JZERO E " + to_string(get_code_offset()+2));
	code_gen("JUMP " + to_string(get_code_offset() +3));
	code_gen("SUB A B");
	code_gen("ADD C D");
	code_gen("HALF B");
	code_gen("HALF D");
	code_gen("JZERO D " + to_string(get_code_offset() + 2));
	code_gen("JUMP " + to_string(get_code_offset() - 9));
}

void declare_var(string var_name, long long size, long long start, bool isArray) {
	variable* v;
	v = get_var(var_name);
	if (v==0) {
		v = put_var(var_name, size, start, false, isArray, false);
	}
	else {
		ostringstream os;
		os<<"Zmienna "<< var_name <<" jest już zadeklarowana."<<endl;
		yyerror(os.str().c_str());
	}
}

FILE *read_code(char* input) {
	string input_file = input;
    FILE *fin = fopen(input_file.c_str(), "r");

    if(!fin) {
        cerr<<"Can't open file: " <<input_file<<endl;
        return nullptr;
    }

    return fin;
}

void print_code(char* output, vector<string> commands) {
	string output_file = output;
    ofstream fout(output_file);
    
    vector<string>::iterator it;
    for(it = commands.begin(); it != commands.end(); it++) {
        fout << *it << endl;
    }

    fout.close();
}


int main(int argc, char** argv){
	if (argc != 3) {
		cerr<<"Nieprawidłowe parametry uruchomienia."<<endl;
	}
	yyin = read_code(argv[1]);
	if (yyin == nullptr) {
		return -1;
	}

 	yyparse();
	print_code(argv[2], code);
}

void yyerror(char const *s){
  	cerr<<"Linia " << yylineno << ": " << s << endl;
  	exit(-1);
}
