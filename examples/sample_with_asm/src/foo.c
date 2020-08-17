#include "mylib.h"
#include <stdio.h>

extern const char* message();

void foo()
{
    printf("Hello, I'm a library function 'foo'!\n");
    printf("Here is a message: %s\n", message());
}
