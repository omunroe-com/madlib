/* -----------------------------------------------------------------------------
 * sql.yy
 * 
 * A simple context-free grammar to parse SQL files and translating
 * CREATE FUNCTION statements into C++ function declarations.
 * This allows .sql files to be documented by documentation tools like Doxygen.
 *
 * Revision History:
 * 0.2: Florian Schoppmann, 16 Jan 2011, Converted to C++
 * 0.1:          "        , 10 Jan 2011, Initial version.
 * -----------------------------------------------------------------------------
 */

/* The %code directive needs bison >= 2.4 */
%require "2.4"

%code requires {
//	#include <stdio.h>
	#include <map>
	#include <fstream>
	#include <string>
	
	/* FIXME: We should not disable warning. Problem, however: asprintf */
	#pragma GCC diagnostic ignored "-Wwrite-strings"
	
	#ifdef COMPILING_SCANNER
		/* Flex expects the signature of yylex to be defined in the macro
		 * YY_DECL. */
		#define YY_DECL										\
			int												\
			bison::SQLScanner::lex(							\
				bison::SQLParser::semantic_type *yylval,	\
				bison::SQLParser::location_type *yylloc,	\
				bison::SQLDriver *driver					\
			)
	#else
		/* In the parser, we need to call the lexer and therefore need the
		 * lexer class declaration. */
		#define yyFlexLexer SQLFlexLexer
		#undef yylex
		#include "FlexLexer.h"
		#undef yyFlexLexer
	#endif
	
	/* Data type of semantic values */
	#define YYSTYPE char *
	
	namespace bison {

	/* Forward declaration because referenced by generated class declaration
	 * SQLParser */
	class SQLDriver;
	
	}
}

%code provides {
	namespace bison {

	class SQLScanner;

	class SQLDriver
	{
	public:
		SQLDriver();
		virtual ~SQLDriver();
		void error(const SQLParser::location_type &l, const std::string &m);
		void error(const std::string &m);

		
		std::map<std::string, int>	declToLineNo;
		SQLScanner					*scanner;
	};
	
	/* We need to subclass because SQLFlexLexer's yylex function does not have
	 * the proper signature */
	class SQLScanner : public SQLFlexLexer
	{
	public:
		SQLScanner(std::istream *arg_yyin = 0, std::ostream* arg_yyout = 0);
		virtual ~SQLScanner();
		virtual int lex(SQLParser::semantic_type *yylval,
			SQLParser::location_type *yylloc, SQLDriver *driver);
		virtual void preScannerAction(SQLParser::semantic_type *yylval,
			SQLParser::location_type *yylloc, SQLDriver *driver);
	};
	
	} // namespace bison

	/* "Connect" the bison parser in the driver to the flex scanner class
	 * object. The C++ scanner generated by flex is a bit ugly, therefore
	 * this sort of hack here.
	 */
	#undef yylex
	#define yylex driver->scanner->lex
}

/* write out a header file containing the token defines */
%defines

/* use C++ and its skeleton file */
%skeleton "lalr1.cc"

/* keep track of the current position within the input */
%locations

/* The name of the parser class. */
%define "parser_class_name" "SQLParser"

/* Declare that an argument declared by the braced-code `argument-declaration'
 * is an additional yyparse argument. The `argument-declaration' is used when
 * declaring functions or prototypes. The last identifier in
 * `argument-declaration' must be the argument name. */
%parse-param { SQLDriver *driver }

/* Declare that the braced-code argument-declaration is an additional yylex
 * argument declaration. */
%lex-param   { SQLDriver *driver }

/* namespace to enclose parser in */
%name-prefix="bison"


%token IDENTIFIER

%token COMMENT

%token CREATE_FUNCTION

%token IN
%token OUT
%token INOUT

%token RETURNS
%token SETOF

%token AS
%token LANGUAGE
%token IMMUTABLE
%token STABLE
%token VOLATILE
%token CALLED_ON_NULL_INPUT
%token RETURNS_NULL_ON_NULL_INPUT
%token SECURITY_INVOKER
%token SECURITY_DEFINER

/* types with more than 1 word */
%token BIT
%token CHARACTER
%token DOUBLE
%token PRECISION
%token TIME
%token VARYING 
%token VOID
%token WITH
%token WITHOUT 
%token ZONE

%token INTEGER_LITERAL
%token STRING_LITERAL

%% /* Grammar rules and actions follow. */

input:
	| input stmt
	| input COMMENT { std::cout << "//" << $2 << '\n'; }
	| input '\n' { std::cout << '\n'; }
;

stmt:
	  ';'
	| createFnStmt ';' { std::cout << ";\n\n"; }
;

createFnStmt:
	  CREATE_FUNCTION qualifiedIdent '(' optArgList ')' returnDecl fnOptions {
		std::cout << $6 << ' ' << $2 << '(' << $4 << ") { }";
		driver->declToLineNo.insert(std::pair<std::string,int>($2, @2.begin.line));
	}
;

qualifiedIdent:
	  IDENTIFIER
	| IDENTIFIER '.' IDENTIFIER {
		$$ = $3;
		/* asprintf(&($$), "%s::%s", $1, $3); */
	}
;

optArgList:
	| argList
;

argList:
	  argument
	| argList ',' argument {
		asprintf(&($$), "%s, %s", $1, $3);
	}
;

argument:
	  type
	| argname type {
		asprintf(&($$), "%s %s", $2, $1);
	}
	| argmode argname type {
		asprintf(&($$), "%s %s", $3, $2);
	}
;

argmode:
	  IN
	| OUT
	| INOUT
;

argname:
	IDENTIFIER
;

type:
	  baseType optArray {
		asprintf(&($$), "%s%s", $1, $2);
	}
;

baseType:
	  qualifiedIdent
	| BIT VARYING optLength {
		asprintf(&($$), "varbit%s", $3);
	}
	| CHARACTER VARYING optLength {
		asprintf(&($$), "varchar%s", $3);
	}
	| DOUBLE PRECISION { $$ = "float8"; }
	| VOID { $$ = "void"; }
;

optArray: { $$ = ""; }
	| array;

optLength:
	| '(' INTEGER_LITERAL ')' {
		asprintf(&($$), "(%s)", $2);
	}
;

array:
	  '[' ']' { $$ = "[]"; }
	| '[' INTEGER_LITERAL ']' {
		asprintf(&($$), "[%s]", $2);
	}
	| array '[' ']' {
		asprintf(&($$), "%s[]", $1);
	}
	| array '[' INTEGER_LITERAL ']' {
		asprintf(&($$), "%s[%s]", $1, $2);
	}
;

returnDecl: { $$ = "void"; }
	| RETURNS retType { $$ = $2; }
;

retType:
	  type
	| SETOF type {
		asprintf(&($$), "set<%s>", $2);
	}
;

fnOptions:
	| fnOptions fnOption;

fnOption:
	  AS STRING_LITERAL
	| AS STRING_LITERAL ',' STRING_LITERAL
	| LANGUAGE STRING_LITERAL
	| LANGUAGE IDENTIFIER
	| IMMUTABLE
	| STABLE
	| VOLATILE
	| CALLED_ON_NULL_INPUT
	| RETURNS_NULL_ON_NULL_INPUT
	| SECURITY_INVOKER
	| SECURITY_DEFINER
;

%%

namespace bison{

SQLDriver::SQLDriver() {
}

SQLDriver::~SQLDriver() {
}

void SQLDriver::error(const SQLParser::location_type &l, const std::string &m) {
	std::cerr << l << ": " << m << std::endl;
}

void SQLDriver::error(const std::string &m) {
	std::cerr << m << std::endl;
}

void SQLParser::error(const SQLParser::location_type &l,
	const std::string &m) {
	
	driver->error(l, m);
}

} // namespace bison

/* This implementation of SQLFlexLexer::yylex() is required because it is
 * declared in FlexLexer.h. The scanner's "real" yylex function is generated by
 * flex and "connected" via YY_DECL. */
#ifdef yylex
	#undef yylex
#endif
int SQLFlexLexer::yylex()
{
	std::cerr <<
		"Error: SQLFlexLexer::yylex() was called. Use SQLScanner::lex() instead"
		<< std::endl;
	return 0;
}

int	main(int argc, char **argv)
{
	std::ifstream		inStream(argv[1]);
	bison::SQLDriver	driver;
	bison::SQLScanner	scanner(&inStream); driver.scanner = &scanner;
	bison::SQLParser	parser(&driver);

	int result = parser.parse();

	if (result != 0)
		return result;
	
	std::cout << "// List of functions:\n";
	for (std::map<std::string,int>::iterator it = driver.declToLineNo.begin();
		it != driver.declToLineNo.end(); it++)
		std::cout << "// " << (*it).first << ": line " << (*it).second << std::endl;
	
	return 0;
}
