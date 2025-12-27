//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

int codeload(const char *sourcecode);
void coderun();
char* codestep();
char* codereset();
int currentAddress();
int currentAddressBus();
int currentData();
int* instructions();

// Interrupt support
void trigger_interrupt(unsigned char opcode);
int check_interrupt();
void process_interrupt();

// CP/M console I/O
void cpm_put_char(unsigned char ch);
unsigned char cpm_get_char();
int cpm_console_status();
