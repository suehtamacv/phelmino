#include <math.h>
#include "lib_phelmino.h"

int main(void) {
    int a = get();
    int b = get();

    print(a + b);
    print(a * b);
    print(a - b);
    print(b - a);
    print(a % b);
    print(b % a);
    print(pow(a, b));
    
    return 0;
}
