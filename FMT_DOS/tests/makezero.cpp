#include <fstream>

char zero[8192];

int main(void)
{
	for(auto &x : zero)
	{
		x=0;
	}
	std::ofstream fp("ZEROCMOS.BIN",std::ios::binary);
	fp.write(zero,8192);
	fp.close();
	return 0;
}
