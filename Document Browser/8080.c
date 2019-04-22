#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "8080.h"

short int exec_inst(struct i8080* cpu, unsigned char* mem) {
    unsigned int p = cpu->prog_ctr;
    unsigned char opcode = mem[p];
    unsigned int dest = 0x100 * (cpu->reg)[H] + (cpu->reg)[L];
    unsigned int d8 = mem[p+1];//8-bit data or least sig. part of 16-bit data
    unsigned int d16 = mem[p+2];//Most sig. part of 16-bit data
    unsigned int da = 0x100 * d16 + d8;//Use if 16 bit data refers to an address
    switch (opcode) {
            //LXI(dest, d16)
        case 0x01: (cpu->reg)[B] = d16; (cpu->reg)[C] = d8; return p+3;
        case 0x11: (cpu->reg)[D] = d16; (cpu->reg)[E] = d8; return p+3;
        case 0x21: (cpu->reg)[H] = d16; (cpu->reg)[L] = d8; return p+3;
        case 0x31: cpu->stack_ptr = 0x100*d16 + d8; return p+3;
            //Direct addressing: STA, LDA, SHLD, LHLD
        case 0x32: mem[da] = (cpu->reg)[A]; return p+3;
        case 0x3a: (cpu->reg)[A] = mem[da]; return p+3;
        case 0x22: mem[da] = (cpu->reg)[L]; mem[da+1] = (cpu->reg)[H]; return p+3;
        case 0x2a: (cpu->reg)[L] = mem[da]; (cpu->reg)[H] = mem[da+1]; return p+3;
            //STAX, LDAX
        case 0x02: mem[0x100*(cpu->reg)[B]+(cpu->reg)[C]]=(cpu->reg)[A]; return p+1;
        case 0x12: mem[0x100*(cpu->reg)[D]+(cpu->reg)[E]]=(cpu->reg)[A]; return p+1;
        case 0x0a: (cpu->reg)[A]=mem[0x100*(cpu->reg)[B]+(cpu->reg)[C]]; return p+1;
        case 0x1a: (cpu->reg)[A]=mem[0x100*(cpu->reg)[D]+(cpu->reg)[E]]; return p+1;
            //MVI(dest, d8)
        case 0x06: (cpu->reg)[B] = d8; return p+2;
        case 0x16: (cpu->reg)[D] = d8; return p+2;
        case 0x26: (cpu->reg)[H] = d8; return p+2;
        case 0x36: mem[dest] = d8; return p+2;
        case 0x0e: (cpu->reg)[C] = d8; return p+2;
        case 0x1e: (cpu->reg)[E] = d8; return p+2;
        case 0x2e: (cpu->reg)[L] = d8; return p+2;
        case 0x3e: (cpu->reg)[A] = d8; return p+2;
            //MOV(dest, src)
        case 0x40: return p+1;
        case 0x41: (cpu->reg)[B] = (cpu->reg)[C]; return p+1;
        case 0x42: (cpu->reg)[B] = (cpu->reg)[D]; return p+1;
        case 0x43: (cpu->reg)[B] = (cpu->reg)[E]; return p+1;
        case 0x44: (cpu->reg)[B] = (cpu->reg)[H]; return p+1;
        case 0x45: (cpu->reg)[B] = (cpu->reg)[L]; return p+1;
        case 0x46: (cpu->reg)[B] = mem[dest]; return p+1;
        case 0x47: (cpu->reg)[B] = (cpu->reg)[A]; return p+1;
        case 0x48: (cpu->reg)[C] = (cpu->reg)[B]; return p+1;
        case 0x49: return p+1;
        case 0x4a: (cpu->reg)[C] = (cpu->reg)[D]; return p+1;
        case 0x4b: (cpu->reg)[C] = (cpu->reg)[E]; return p+1;
        case 0x4c: (cpu->reg)[C] = (cpu->reg)[H]; return p+1;
        case 0x4d: (cpu->reg)[C] = (cpu->reg)[L]; return p+1;
        case 0x4e: (cpu->reg)[C] = mem[dest]; return p+1;
        case 0x4f: (cpu->reg)[C] = (cpu->reg)[A]; return p+1;
        case 0x50: (cpu->reg)[D] = (cpu->reg)[B]; return p+1;
        case 0x51: (cpu->reg)[D] = (cpu->reg)[C]; return p+1;
        case 0x52: return p+1;
        case 0x53: (cpu->reg)[D] = (cpu->reg)[E]; return p+1;
        case 0x54: (cpu->reg)[D] = (cpu->reg)[H]; return p+1;
        case 0x55: (cpu->reg)[D] = (cpu->reg)[L]; return p+1;
        case 0x56: (cpu->reg)[D] = mem[dest]; return p+1;
        case 0x57: (cpu->reg)[D] = (cpu->reg)[A]; return p+1;
        case 0x58: (cpu->reg)[E] = (cpu->reg)[B]; return p+1;
        case 0x59: (cpu->reg)[E] = (cpu->reg)[C]; return p+1;
        case 0x5a: (cpu->reg)[E] = (cpu->reg)[D]; return p+1;
        case 0x5b: return p+1;
        case 0x5c: (cpu->reg)[E] = (cpu->reg)[H]; return p+1;
        case 0x5d: (cpu->reg)[E] = (cpu->reg)[L]; return p+1;
        case 0x5e: (cpu->reg)[E] = mem[dest]; return p+1;
        case 0x5f: (cpu->reg)[E] = (cpu->reg)[A]; return p+1;
        case 0x60: (cpu->reg)[H] = (cpu->reg)[B]; return p+1;
        case 0x61: (cpu->reg)[H] = (cpu->reg)[C]; return p+1;
        case 0x62: (cpu->reg)[H] = (cpu->reg)[D]; return p+1;
        case 0x63: (cpu->reg)[H] = (cpu->reg)[E]; return p+1;
        case 0x64: return p+1;
        case 0x65: (cpu->reg)[H] = (cpu->reg)[L]; return p+1;
        case 0x66: (cpu->reg)[H] = mem[dest]; return p+1;
        case 0x67: (cpu->reg)[H] = (cpu->reg)[A]; return p+1;
        case 0x68: (cpu->reg)[L] = (cpu->reg)[B]; return p+1;
        case 0x69: (cpu->reg)[L] = (cpu->reg)[C]; return p+1;
        case 0x6a: (cpu->reg)[L] = (cpu->reg)[D]; return p+1;
        case 0x6b: (cpu->reg)[L] = (cpu->reg)[E]; return p+1;
        case 0x6c: (cpu->reg)[L] = (cpu->reg)[H]; return p+1;
        case 0x6d: return p+1;
        case 0x6e: (cpu->reg)[L] = mem[dest]; return p+1;
        case 0x6f: (cpu->reg)[L] = (cpu->reg)[A]; return p+1;
        case 0x70: mem[dest] = (cpu->reg)[B]; return p+1;
        case 0x71: mem[dest] = (cpu->reg)[C]; return p+1;
        case 0x72: mem[dest] = (cpu->reg)[D]; return p+1;
        case 0x73: mem[dest] = (cpu->reg)[E]; return p+1;
        case 0x74: mem[dest] = (cpu->reg)[H]; return p+1;
        case 0x75: mem[dest] = (cpu->reg)[L]; return p+1;
        case 0x76: return p;//halt
        case 0x77: mem[dest] = (cpu->reg)[A]; return p+1;
        case 0x78: (cpu->reg)[A] = (cpu->reg)[B]; return p+1;
        case 0x79: (cpu->reg)[A] = (cpu->reg)[C]; return p+1;
        case 0x7a: (cpu->reg)[A] = (cpu->reg)[D]; return p+1;
        case 0x7b: (cpu->reg)[A] = (cpu->reg)[E]; return p+1;
        case 0x7c: (cpu->reg)[A] = (cpu->reg)[H]; return p+1;
        case 0x7d: (cpu->reg)[A] = (cpu->reg)[L]; return p+1;
        case 0x7e: (cpu->reg)[A] = mem[dest]; return p+1;
        case 0x7f: return p+1;
            //Increment/decrement
        case 0x04: increment((cpu->reg)[B], cpu); return p+1;
        case 0x0c: increment((cpu->reg)[C], cpu); return p+1;
        case 0x14: increment((cpu->reg)[D], cpu); return p+1;
        case 0x1c: increment((cpu->reg)[E], cpu); return p+1;
        case 0x24: increment((cpu->reg)[H], cpu); return p+1;
        case 0x2c: increment((cpu->reg)[L], cpu); return p+1;
        case 0x34: increment(mem[dest], cpu); return p+1;
        case 0x3c: increment((cpu->reg)[A], cpu); return p+1;
        case 0x05: decrement((cpu->reg)[B], cpu); return p+1;
        case 0x0d: decrement((cpu->reg)[C], cpu); return p+1;
        case 0x15: decrement((cpu->reg)[D], cpu); return p+1;
        case 0x1d: decrement((cpu->reg)[E], cpu); return p+1;
        case 0x25: decrement((cpu->reg)[H], cpu); return p+1;
        case 0x2d: decrement((cpu->reg)[L], cpu); return p+1;
        case 0x35: decrement(mem[dest], cpu); return p+1;
        case 0x3d: decrement((cpu->reg)[A], cpu); return p+1;
            //Rotate
        case 0x07: rotate(1, 0, cpu); return p+1;
        case 0x17: rotate(1, 1, cpu); return p+1;
        case 0x0f: rotate(0, 0, cpu); return p+1;
        case 0x1f: rotate(0, 1, cpu); return p+1;
        case 0x27: return p+1;//Here be dragons
        case 0x2f: (cpu->reg)[A] = ~(cpu->reg)[A]; return p+1;
        case 0x37: cpu->carry = 1; return p+1;
        case 0x3f: cpu->carry = !(cpu->carry); return p+1;
            //16-bit inc/dec
        case 0x03: doubleinr(B, cpu); return p+1;
        case 0x13: doubleinr(D, cpu); return p+1;
        case 0x23: doubleinr(H, cpu); return p+1;
        case 0x33: doubleinr(SP, cpu); return p+1;
        case 0x0b: doubledcr(B, cpu); return p+1;
        case 0x1b: doubledcr(D, cpu); return p+1;
        case 0x2b: doubledcr(H, cpu); return p+1;
        case 0x3b: doubledcr(SP, cpu); return p+1;
            //XTHL, XCHG, SPHL
        case 0xe3: xthl(cpu, mem); return p+1;
        case 0xeb: xchg(cpu); return p+1;
        case 0xf9: cpu->stack_ptr = 0x100*(cpu->reg)[H]+(cpu->reg)[L]; return p+1;
            //Arith/logic
        case 0x80: add((cpu->reg)[B], cpu, 0); return p+1;
        case 0x81: add((cpu->reg)[C], cpu, 0); return p+1;
        case 0x82: add((cpu->reg)[D], cpu, 0); return p+1;
        case 0x83: add((cpu->reg)[E], cpu, 0); return p+1;
        case 0x84: add((cpu->reg)[H], cpu, 0); return p+1;
        case 0x85: add((cpu->reg)[L], cpu, 0); return p+1;
        case 0x86: add(mem[dest], cpu, 0); return p+1;
        case 0x87: add((cpu->reg)[A], cpu, 0); return p+1;
        case 0x88: add((cpu->reg)[B], cpu, 1); return p+1;
        case 0x89: add((cpu->reg)[C], cpu, 1); return p+1;
        case 0x8a: add((cpu->reg)[D], cpu, 1); return p+1;
        case 0x8b: add((cpu->reg)[E], cpu, 1); return p+1;
        case 0x8c: add((cpu->reg)[H], cpu, 1); return p+1;
        case 0x8d: add((cpu->reg)[L], cpu, 1); return p+1;
        case 0x8e: add(mem[dest], cpu, 1); return p+1;
        case 0x8f: add((cpu->reg)[A], cpu, 1); return p+1;
        case 0x90: sub((cpu->reg)[B], cpu, 0); return p+1;
        case 0x91: sub((cpu->reg)[C], cpu, 0); return p+1;
        case 0x92: sub((cpu->reg)[D], cpu, 0); return p+1;
        case 0x93: sub((cpu->reg)[E], cpu, 0); return p+1;
        case 0x94: sub((cpu->reg)[H], cpu, 0); return p+1;
        case 0x95: sub((cpu->reg)[L], cpu, 0); return p+1;
        case 0x96: sub(mem[dest], cpu, 0); return p+1;
        case 0x97: sub((cpu->reg)[A], cpu, 0); return p+1;
        case 0x98: sub((cpu->reg)[B], cpu, 1); return p+1;
        case 0x99: sub((cpu->reg)[C], cpu, 1); return p+1;
        case 0x9a: sub((cpu->reg)[D], cpu, 1); return p+1;
        case 0x9b: sub((cpu->reg)[E], cpu, 1); return p+1;
        case 0x9c: sub((cpu->reg)[H], cpu, 1); return p+1;
        case 0x9d: sub((cpu->reg)[L], cpu, 1); return p+1;
        case 0x9e: sub(mem[dest], cpu, 1); return p+1;
        case 0x9f: sub((cpu->reg)[A], cpu, 1); return p+1;
        case 0xa0: logic(bw_and, (cpu->reg)[B], cpu); return p+1;
        case 0xa1: logic(bw_and, (cpu->reg)[C], cpu); return p+1;
        case 0xa2: logic(bw_and, (cpu->reg)[D], cpu); return p+1;
        case 0xa3: logic(bw_and, (cpu->reg)[E], cpu); return p+1;
        case 0xa4: logic(bw_and, (cpu->reg)[H], cpu); return p+1;
        case 0xa5: logic(bw_and, (cpu->reg)[L], cpu); return p+1;
        case 0xa6: logic(bw_and, mem[dest], cpu); return p+1;
        case 0xa7: logic(bw_and, (cpu->reg)[A], cpu); return p+1;
        case 0xa8: logic(bw_xor, (cpu->reg)[B], cpu); return p+1;
        case 0xa9: logic(bw_xor, (cpu->reg)[C], cpu); return p+1;
        case 0xaa: logic(bw_xor, (cpu->reg)[D], cpu); return p+1;
        case 0xab: logic(bw_xor, (cpu->reg)[E], cpu); return p+1;
        case 0xac: logic(bw_xor, (cpu->reg)[H], cpu); return p+1;
        case 0xad: logic(bw_xor, (cpu->reg)[L], cpu); return p+1;
        case 0xae: logic(bw_xor, mem[dest], cpu); return p+1;
        case 0xaf: logic(bw_xor, (cpu->reg)[A], cpu); return p+1;
        case 0xb0: logic(bw_or, (cpu->reg)[B], cpu); return p+1;
        case 0xb1: logic(bw_or, (cpu->reg)[C], cpu); return p+1;
        case 0xb2: logic(bw_or, (cpu->reg)[D], cpu); return p+1;
        case 0xb3: logic(bw_or, (cpu->reg)[E], cpu); return p+1;
        case 0xb4: logic(bw_or, (cpu->reg)[H], cpu); return p+1;
        case 0xb5: logic(bw_or, (cpu->reg)[L], cpu); return p+1;
        case 0xb6: logic(bw_or, mem[dest], cpu); return p+1;
        case 0xb7: logic(bw_or, (cpu->reg)[A], cpu); return p+1;
        case 0xb8: cmp((cpu->reg)[B], cpu); return p+1;
        case 0xb9: cmp((cpu->reg)[C], cpu); return p+1;
        case 0xba: cmp((cpu->reg)[D], cpu); return p+1;
        case 0xbb: cmp((cpu->reg)[E], cpu); return p+1;
        case 0xbc: cmp((cpu->reg)[H], cpu); return p+1;
        case 0xbd: cmp((cpu->reg)[L], cpu); return p+1;
        case 0xbe: cmp(mem[dest], cpu); return p+1;
        case 0xbf: cmp((cpu->reg)[A], cpu); return p+1;
            //ADI, ADC, SUI, SBI, ANI, XRI, ORI, CPI
        case 0xc6: add(d8, cpu, 0); return p+2;
        case 0xce: add(d8, cpu, 1); return p+2;
        case 0xd6: sub(d8, cpu, 0); return p+2;
        case 0xde: sub(d8, cpu, 1); return p+2;
        case 0xe6: logic(bw_and, d8, cpu); return p+2;
        case 0xee: logic(bw_xor, d8, cpu); return p+2;
        case 0xf6: logic(bw_or, d8, cpu); return p+2;
        case 0xfe: cmp(d8, cpu); return p+2;
            //16bit A/L
        case 0x09: doubleadd(B, cpu); return p+1;
        case 0x19: doubleadd(D, cpu); return p+1;
        case 0x29: doubleadd(H, cpu); return p+1;
        case 0x39: doubleadd(SP, cpu); return p+1;
            //Push/pop using stack pointer
        case 0xc1: pop(B, cpu, mem); return p+1;
        case 0xd1: pop(D, cpu, mem); return p+1;
        case 0xe1: pop(H, cpu, mem); return p+1;
        case 0xf1: pop(A, cpu, mem); return p+1;
        case 0xc5: push(B, cpu, mem); return p+1;
        case 0xd5: push(D, cpu, mem); return p+1;
        case 0xe5: push(H, cpu, mem); return p+1;
        case 0xf5: push(A, cpu, mem); return p+1;
            //Jumps
        case 0xcb:
        case 0xc3: return da;//JMP
        case 0xc2: return !(cpu->iszero) ? da : p+3;//JNZ
        case 0xd2: return !(cpu->carry)  ? da : p+3;//JNC
        case 0xe2: return !(cpu->parity) ? da : p+3;//JPO
        case 0xf2: return !(cpu->sign)   ? da : p+3;//JP
        case 0xca: return  (cpu->iszero) ? da : p+3;//JZ
        case 0xda: return  (cpu->carry)  ? da : p+3;//JC
        case 0xea: return  (cpu->parity) ? da : p+3;//JPE
        case 0xfa: return  (cpu->sign)   ? da : p+3;//JM
        case 0xe9: return 0x100*(cpu->reg)[H]+(cpu->reg)[L];//PCHL
            //Calls
        case 0xcd:
        case 0xdd:
        case 0xed:
        case 0xfd: return call(p+3, da, cpu, mem);//CALL
        case 0xc4: return !(cpu->iszero) ? call(p+3, da, cpu, mem) : p+3;//CNZ
        case 0xd4: return !(cpu->carry)  ? call(p+3, da, cpu, mem) : p+3;//CNC
        case 0xe4: return !(cpu->parity) ? call(p+3, da, cpu, mem) : p+3;//CPO
        case 0xf4: return !(cpu->sign)   ? call(p+3, da, cpu, mem) : p+3;//CP
        case 0xcc: return  (cpu->iszero) ? call(p+3, da, cpu, mem) : p+3;//CZ
        case 0xdc: return  (cpu->carry)  ? call(p+3, da, cpu, mem) : p+3;//CC
        case 0xec: return  (cpu->parity) ? call(p+3, da, cpu, mem) : p+3;//CPE
        case 0xfc: return  (cpu->sign)   ? call(p+3, da, cpu, mem) : p+3;//CM
            //Returns
        case 0xc9:
        case 0xd9: return ret(cpu, mem);//RET
        case 0xc0: return !(cpu->iszero) ? ret(cpu, mem) : p+1;//RNZ
        case 0xd0: return !(cpu->carry)  ? ret(cpu, mem) : p+1;//RNC
        case 0xe0: return !(cpu->parity) ? ret(cpu, mem) : p+1;//RPO
        case 0xf0: return !(cpu->sign)   ? ret(cpu, mem) : p+1;//RP
        case 0xc8: return  (cpu->iszero) ? ret(cpu, mem) : p+1;//RZ
        case 0xd8: return  (cpu->carry)  ? ret(cpu, mem) : p+1;//RC
        case 0xe8: return  (cpu->parity) ? ret(cpu, mem) : p+1;//RPE
        case 0xf8: return  (cpu->sign)   ? ret(cpu, mem) : p+1;//RM
            //Restarts
        case 0xc7: return call(p+1, 0x00, cpu, mem);//RST 0
        case 0xcf: return call(p+1, 0x08, cpu, mem);//RST 1
        case 0xd7: return call(p+1, 0x10, cpu, mem);//RST 2
        case 0xdf: return call(p+1, 0x18, cpu, mem);//RST 3
        case 0xe7: return call(p+1, 0x20, cpu, mem);//RST 4
        case 0xef: return call(p+1, 0x28, cpu, mem);//RST 5
        case 0xf7: return call(p+1, 0x30, cpu, mem);//RST 6
        case 0xff: return call(p+1, 0x38, cpu, mem);//RST 7
            //NOP
        case 0x00:
        case 0x10:
        case 0x20:
        case 0x30:
        case 0x08:
        case 0x18:
        case 0x28:
        case 0x38: return p+1;
        default: perror("Unrecognized instruction");
    }
    
    return 0;
}

unsigned char mem[0xFFFF] = { 0 };
struct i8080 cpu;
struct i8080* p = &cpu;
char buffer[80]; // for displaying reg dump
int currentAndNext[6]; // store the just executed and next to be executed instructions for display

char * dumpRegs(struct i8080* p)
{
    
    sprintf(buffer, "PC:%04X\tA:%02X B:%02X C:%02X D:%02X E:%02X H:%02X L:%02X SP:%04X\n",
            (p->prog_ctr),
            (p->reg)[A], (p->reg)[B], (p->reg)[C], (p->reg)[D],
            (p->reg)[E], (p->reg)[H], (p->reg)[L], (p->stack_ptr));
    
    return buffer;
}



int currentAddress()
{
    return cpu.prog_ctr;
}

int currentData()
{
    return mem[cpu.prog_ctr];
}

int* instructions()
{
    return currentAndNext;
}


char* codestep()
{
    currentAndNext[0] = mem[cpu.prog_ctr];
    currentAndNext[1] = mem[cpu.prog_ctr+1];
    currentAndNext[2] = mem[cpu.prog_ctr+2];
    cpu.prog_ctr = exec_inst(&cpu, mem);
    currentAndNext[3] = mem[cpu.prog_ctr];
    currentAndNext[4] = mem[cpu.prog_ctr+1];
    currentAndNext[5] = mem[cpu.prog_ctr+2];
    return dumpRegs(&cpu);
}

char* codereset()
{
    // reset all registers
    
    cpu.prog_ctr = 0;
    cpu.stack_ptr = 0;
    
    cpu.reg[A] = 0;
    cpu.reg[H] = 0;
    cpu.reg[L] = 0;
    cpu.reg[B] = 0;
    cpu.reg[C] = 0;
    cpu.reg[D] = 0;
    cpu.reg[E] = 0;
    cpu.reg[SP] = 0;
    
    currentAndNext[0] = mem[cpu.prog_ctr];
    currentAndNext[1] = mem[cpu.prog_ctr+1];
    currentAndNext[2] = mem[cpu.prog_ctr+2];
    currentAndNext[3] = mem[cpu.prog_ctr+3];
    currentAndNext[4] = mem[cpu.prog_ctr+4];
    currentAndNext[5] = mem[cpu.prog_ctr+5];
    
    return dumpRegs(&cpu);
}

void coderun()
{
    codestep();
    cpu.prog_ctr = exec_inst(&cpu, mem);
    dumpRegs(&cpu);
    
  //  unsigned int temp;
  //  do {
  //      temp = cpu.prog_ctr;
  //      cpu.prog_ctr = exec_inst(&cpu, mem);
  //      dumpRegs(&cpu);
  //  } while (temp != cpu.prog_ctr && cpu.prog_ctr < 65535);
}

void codeload(const char *sourcecode)
{
    unsigned long length = strlen(sourcecode);
    
    const char *pos = sourcecode;
    for (size_t count = 0; count < length / 2; count++)
    {
        sscanf(pos, "%2hhx",&mem[count]);
        pos += 2;
    }
}

/*
 int execute8080code(const char *sourcecode) {
 
 //    unsigned char mem[0xFFFF] = { 0 };
 //    unsigned long length = strlen(sourcecode);
 //
 //    struct i8080 cpu;
 //    struct i8080* p = &cpu;
 
 unsigned long length = strlen(sourcecode);
 
 
 // Copy the code into "memory" of our 8080VM
 const char *pos = sourcecode;
 for (size_t count = 0; count < length / 2; count++)
 {
 sscanf(pos, "%2hhx",&mem[count]);
 pos += 2;
 }
 
 // reset all registers
 cpu.reg[A] = 0;
 cpu.reg[H] = 0;
 cpu.reg[L] = 0;
 cpu.reg[B] = 0;
 cpu.reg[C] = 0;
 cpu.reg[D] = 0;
 cpu.reg[E] = 0;
 cpu.reg[SP] = 0;
 
 // Run the code
 runcode(0, p, mem);
 
 return 0;
 }
 */
