#define UART (*(volatile unsigned char *)0x10000000UL)

static void puts_(const char *s) { while (*s) UART = *s++; }

static unsigned long fib(unsigned n) {
    unsigned long a = 0, b = 1;
    while (n--) { unsigned long t = a + b; a = b; b = t; }
    return a;
}

int main(void) {
    puts_("Hello RISC-V 64!\n");
    unsigned long f = fib(50);               // 12586269025 (usa 64 bits)
    long d = (long)f / 7 + (long)f % 7;      // exercita M
    return (f == 12586269025UL && d == 1798039860L + 5) ? 0 : 1;
}