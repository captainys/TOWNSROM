#include <iostream>
#include <fstream>
#include <string>


const unsigned int NOTFOUND=~0;


void Capitalize(std::string &s)
{
	for(auto &c : s)
	{
		if('a'<=c && c<='z')
		{
			c=c+'A'-'a';
		}
	}
}

void DropComment(std::string &LINE)
{
	for(unsigned int i=0; i<LINE.size(); ++i)
	{
		if(';'==LINE[i])
		{
			LINE.resize(i);
		}
	}
}

std::string CapitalizeAndDropComment(std::string line)
{
	Capitalize(line);
	DropComment(line);
	return line;
}

unsigned int Find(std::string keyword,std::string within)
{
	for(unsigned int i=0; i+keyword.size()<=within.size(); ++i)
	{
		int j;
		for(j=0; j<keyword.size(); ++j)
		{
			if(keyword[j]!=within[i+j])
			{
				break;
			}
		}
		if(j==keyword.size())
		{
			return i;
		}
	}
	return NOTFOUND;
}

bool IsSeparator(char c)
{
	return ' '==c || '\t'==c || '('==c || ')'==c || ','==c || ';'==c;
}

unsigned int FindWord(std::string keyword,std::string within)
{
	for(unsigned int i=0; i+keyword.size()<=within.size(); ++i)
	{
		int j;
		for(j=0; j<keyword.size(); ++j)
		{
			if(keyword[j]!=within[i+j])
			{
				break;
			}
		}
		if(j==keyword.size())
		{
			if((0==i || IsSeparator(within[i-1])) && (0==within[i+j] || IsSeparator(within[i+j])))
			{
				return i;
			}
		}
	}
	return NOTFOUND;
}

std::string Replace(std::string str,unsigned int loc,unsigned int len,std::string to)
{
	std::string newStr;
	for(unsigned int i=0; i<loc; ++i)
	{
		newStr.push_back(str[i]);
	}
	newStr=newStr+to;
	for(unsigned int i=loc+len; i<str.size(); ++i)
	{
		newStr.push_back(str[i]);
	}
	return newStr;
}

std::string ReplaceWord(std::string line,std::string LINE,std::string from,std::string to)
{
	Capitalize(from);
	auto loc=FindWord(from,LINE);
	if(NOTFOUND!=loc)
	{
		return Replace(line,loc,from.size(),to);
	}
	return line;
}

int main(int ac,char *av[])
{
	if(3!=ac)
	{
		std::cout << "toNASM something.ASM something.NSM" << std::endl;
		return 1;
	}



	unsigned nLinesProcessed=0;

	std::ifstream ifp(av[1]);
	if(true!=ifp.is_open())
	{
		std::cout << "Cannot open input." << std::endl;
		return 1;
	}
	std::ofstream ofp(av[2]);
	if(true!=ofp.is_open())
	{
		std::cout << "Cannot open output." << std::endl;
		return 1;
	}

	bool inStruc=false;
	bool inMacro=false;
	while(true!=ifp.eof())
	{
		std::string line;
		std::getline(ifp,line);
		auto from=line;
		++nLinesProcessed;

		auto LINE=line;
		Capitalize(LINE);


		// Do it before dropping comment
		if(NOTFOUND!=Find("USE_IN_NASM",LINE) && ';'==LINE[0])
		{
			line.erase(line.begin());
			goto WRITE_AND_NEXT;
		}


		int firstNonSpace=0;
		for(auto c : line)
		{
			if(';'==c)
			{
				goto WRITE_AND_NEXT;
			}
			if(' '!=c && '\t'!=c)
			{
				break;
			}
			++firstNonSpace;
		}
		// Not a comment line


		// Do it before dropping comment
		if(NOTFOUND!=Find("NOT_IN_NASM",LINE))
		{
			std::cout << "Skip>>" << line << std::endl;
			goto SKIP_AND_NEXT;
		}


		DropComment(LINE);


		// Remove  SOMETHING	ENDP, and PROC to :
		if(0==firstNonSpace)
		{
			if(NOTFOUND!=FindWord("ENDP",LINE))
			{
				std::cout << "Skip>>" << line << std::endl;
				goto SKIP_AND_NEXT;
			}
			{
				auto loc=FindWord("PROC",LINE);
				if(NOTFOUND!=loc)
				{
					line.insert(line.begin()+loc,';');
					for(unsigned int i=0; i<loc; ++i)
					{
						if(' '==line[i] || '\t'==line[i])
						{
							line[i]=':';
							break;
						}
					}
				}
			}
		}

		LINE=CapitalizeAndDropComment(line);


		{
			auto loc=Find(",OFFSET ",LINE);
			if(NOTFOUND!=loc)
			{
				line=Replace(line,loc,8,",");
				LINE=CapitalizeAndDropComment(line);
			}
		}


		{
			std::string keyword="ORG";
			auto loc=FindWord(keyword,LINE);
			if(NOTFOUND!=loc)
			{
				line=Replace(line,loc,keyword.size(),"PLACE");
			}
		}

		LINE=CapitalizeAndDropComment(line);

		if(0==firstNonSpace)
		{
			std::string keyword="DD";
			auto loc=FindWord(keyword,LINE);
			if(NOTFOUND==loc)
			{
				keyword="DW";
				loc=FindWord(keyword,LINE);
			}
			if(NOTFOUND==loc)
			{
				keyword="DB";
				loc=FindWord(keyword,LINE);
			}
			if(loc!=NOTFOUND)
			{
				// Insert ':' if I didn't type after the label.
				for(unsigned int i=0; i<loc; ++i)
				{
					if(':'==line[i])
					{
						break;
					}
					else if(' '==line[i] || '\t'==line[i]) // I was sloppy.
					{
						line.insert(line.begin()+i,':');
						break;
					}
				}
			}
			LINE=CapitalizeAndDropComment(line);
		}

		line=ReplaceWord(line,LINE,"DWORD PTR","DWORD");
		line=ReplaceWord(line,LINE,"WORD PTR","WORD");
		line=ReplaceWord(line,LINE,"BYTE PTR","BYTE");

		LINE=CapitalizeAndDropComment(line);

		if(0==firstNonSpace && NOTFOUND!=FindWord("STRUC",LINE))
		{
			std::string newLine="STRUC\t\t\t\t\t";
			for(auto c : line)
			{
				if(' '==c || '\t'==c)
				{
					break;
				}
				newLine.push_back(c);
			}

			inStruc=true;
			line=newLine;
		}

		LINE=CapitalizeAndDropComment(line);

		if(true==inStruc)
		{
			if(0==firstNonSpace && NOTFOUND!=FindWord("ENDS",LINE))
			{
				line="ENDSTRUC";
				inStruc=false;
			}
			auto loc=FindWord("DD",LINE);
			unsigned int qto1=NOTFOUND;
			if(0!=loc && NOTFOUND!=loc && (LINE[loc-1]==' ' || LINE[loc-1]=='\t' || LINE[loc-1]==':'))
			{
				line=Replace(line,loc,2,"RESD");
				qto1=loc;
			}
			loc=FindWord("DW",LINE);
			if(0!=loc && NOTFOUND!=loc && (LINE[loc-1]==' ' || LINE[loc-1]=='\t' || LINE[loc-1]==':'))
			{
				qto1=loc;
				line=Replace(line,loc,2,"RESW");
			}
			loc=FindWord("DB",LINE);
			if(0!=loc && NOTFOUND!=loc && (LINE[loc-1]==' ' || LINE[loc-1]=='\t' || LINE[loc-1]==':'))
			{
				qto1=loc;
				line=Replace(line,loc,2,"RESB");
			}
			if(NOTFOUND!=qto1)
			{
				LINE=CapitalizeAndDropComment(line);

				auto dup=FindWord("DUP",LINE);
				if(qto1<dup && NOTFOUND!=dup)
				{
					line.insert(line.begin()+dup,';');
				}
				else
				{
					for(unsigned int i=qto1; i<line.size() && ';'!=line[i]; ++i)
					{
						if('?'==line[i])
						{
							line[i]='1';
						}
					}
				}
			}
		}

		LINE=CapitalizeAndDropComment(line);

		if(0==firstNonSpace && NOTFOUND!=FindWord("MACRO",LINE))
		{
			std::string newLine="%MACRO\t\t\t\t\t";
			for(auto c : line)
			{
				if(' '==c || '\t'==c)
				{
					break;
				}
				newLine.push_back(c);
			}
			newLine+="\t\t0";
			line=newLine;
			inMacro=true;
		}

		LINE=CapitalizeAndDropComment(line);

		if(true==inMacro && NOTFOUND!=FindWord("ENDM",LINE))
		{
			line="%ENDMACRO";
			inMacro=false;
		}

		LINE=CapitalizeAndDropComment(line);

		{
			auto loc=FindWord("INCLUDE",LINE);
			if(NOTFOUND!=loc)
			{
				std::string keyword=".ASM";
				auto asmLoc=Find(keyword,LINE);
				if(NOTFOUND!=asmLoc)
				{
					line=Replace(line,asmLoc,keyword.size(),".NSM");
				}

				int state=0;
				for(unsigned int i=loc+7; i<line.size(); ++i)
				{
					if(0==state && ' '!=line[i] && '\t'!=line[i])
					{
						line.insert(line.begin()+i,'\"');
						state=1;
					}
					else if(1==state && (' '==line[i] || '\t'==line[i] || ';'==line[i]))
					{
						line.insert(line.begin()+i,'\"');
						state=2;
						break;
					}
				}
				if(0!=state && 2!=state)
				{
					line.push_back('\"');
				}

				line=Replace(line,loc,7,"%INCLUDE");
			}
		}

		LINE=CapitalizeAndDropComment(line);

	WRITE_AND_NEXT:
		if(from!=line)
		{
			std::cout << "From>>" << from << std::endl;
			std::cout << "To  >>" << line << std::endl;
		}
		ofp << line << std::endl;
	SKIP_AND_NEXT:
		;
	}

	if(inMacro || inStruc)
	{
		std::cout << "Open MACRO or STRUC!!!!" << std::endl;
	}

	std::cout << nLinesProcessed << " lines." << std::endl;

	return 0;
}
