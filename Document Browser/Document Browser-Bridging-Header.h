//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

void codeload(const char *sourcecode, unsigned int org);
void coderun();
char* codestep();
char* codereset();
void cpu_set_pc(unsigned short addr);
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
int cpm_is_waiting_for_input();
void cpm_clear_waiting();
void cpm_set_echo(int enable);
