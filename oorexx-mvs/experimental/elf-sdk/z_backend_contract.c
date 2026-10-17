/* ooRexx MVS / z/OS ELF SDK early ABI sanity probe.
 * Host packaging proves only build and format. The guest MUST run this and
 * record return 42 before ABI behaviour is accepted. No file services here.
 * Both TSO24 and TSO31 use ILP32 but have different runtime service contracts.
 */
#include <limits.h>

static int bits_and_endian(void)
{
    unsigned long pattern = 0x01020304UL;
    const unsigned char *p = (const unsigned char *)&pattern;
    if (CHAR_BIT != 8 || sizeof(char) != 1 || sizeof(short) != 2 ||
        sizeof(int) != 4 || sizeof(long) != 4 || sizeof(void *) != 4)
        return 21;
    if (p[0] != 1 || p[1] != 2 || p[2] != 3 || p[3] != 4)
        return 22;
    return 42;
}

int main(void)
{
    return bits_and_endian();
}
