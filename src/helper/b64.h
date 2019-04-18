#ifndef _B64
#define _B64
#include <stdlib.h>
size_t b64_encoded_size(size_t inlen);
char *b64_encode(const unsigned char *in, size_t len);
#endif
