FLAGS = -std=c++17

build: lex parse
	g++ parser.cpp $(FLAGS) lex.cpp -o kompilator -lm -ll

parse:
	bison -d parser.y -o parser.cpp
lex:
	flex -o lex.cpp scanner.l

clean:
	rm -f *.o *~ *.c *.cpp *.hpp
	rm -f kompilator