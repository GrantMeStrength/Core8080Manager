//I figured a table would be easier and faster than an actual algorithm for
//computing the parity bit since we're always limited to 8 bits
char par_tab[256] =
{1,0,0,1,0,1,1,0,0,1,1,0,1,0,0,1,0,1,1,0,1,0,0,1,1,0,0,1,0,1,1,0,
 0,1,1,0,1,0,0,1,1,0,0,1,0,1,1,0,1,0,0,1,0,1,1,0,0,1,1,0,1,0,0,1,
 0,1,1,0,1,0,0,1,1,0,0,1,0,1,1,0,1,0,0,1,0,1,1,0,0,1,1,0,1,0,0,1,
 1,0,0,1,0,1,1,0,0,1,1,0,1,0,0,1,0,1,1,0,1,0,0,1,1,0,0,1,0,1,1,0,
 0,1,1,0,1,0,0,1,1,0,0,1,0,1,1,0,1,0,0,1,0,1,1,0,0,1,1,0,1,0,0,1,
 1,0,0,1,0,1,1,0,0,1,1,0,1,0,0,1,0,1,1,0,1,0,0,1,1,0,0,1,0,1,1,0,
 1,0,0,1,0,1,1,0,0,1,1,0,1,0,0,1,0,1,1,0,1,0,0,1,1,0,0,1,0,1,1,0,
 0,1,1,0,1,0,0,1,1,0,0,1,0,1,1,0,1,0,0,1,0,1,1,0,0,1,1,0,1,0,0,1};

enum regs {
  B, C, D, E, H, L, PSW, A, SP
};

struct i8080 {
//Registers. reg[6] not used by convention. IRL this is the PSW
  unsigned char reg[9]; // was 8
  unsigned int stack_ptr;
  unsigned int prog_ctr;
//Flags
  char carry;
  char aux_carry;
  char iszero;
  char parity;
  char sign;
//Interrupt support
  char interrupt_enable;
  char interrupt_pending;
  unsigned char interrupt_opcode;
};

//Update zero, sign, parity flags based on argument byte
void zsp_flags(unsigned char byte, struct i8080* p) {
  if (byte == 0)
    {p->iszero = 1; p->sign = 0;}
  else if (byte >= 0x80)
    {p->iszero = 0; p->sign = 1;}
  else
    {p->iszero = 0; p->sign = 0;}
  p->parity = par_tab[byte];
  return;
}

unsigned char increment(unsigned char regm, struct i8080* cpu) {
  // Auxiliary carry: set if low nibble overflows
  cpu->aux_carry = ((regm & 0x0F) == 0x0F) ? 1 : 0;
  regm += 1;
  zsp_flags(regm, cpu);
  return regm;
}

unsigned char decrement(unsigned char regm, struct i8080* cpu) {
  // Auxiliary carry: set if no borrow from bit 4
  cpu->aux_carry = ((regm & 0x0F) != 0) ? 1 : 0;
  regm -= 1;
  zsp_flags(regm, cpu);
  return regm;
}

void rotate(char left, char throughcarry, struct i8080* cpu) {
  char tempcarry = cpu->carry;
  if (left) {
    cpu->carry = (cpu->reg)[A] / 0x80;
    (cpu->reg)[A] <<= 1; (cpu->reg)[A] %= 0x100;
    if (throughcarry) (cpu->reg)[A] += tempcarry;
    else (cpu->reg)[A] += cpu->carry;
  }
  else {//right
    cpu->carry = (cpu->reg)[A] % 2;
    (cpu->reg)[A] >>= 1;
    if (throughcarry) (cpu->reg)[A] += 0x80 * tempcarry;
    else (cpu->reg)[A] += 0x80 * cpu->carry;
  }
  return;
}

void add(unsigned char regm, struct i8080* cpu, char shouldicarry) {
  unsigned int res = (cpu->reg)[A] + regm;
  if (shouldicarry) res += cpu->carry;

  // Auxiliary carry: carry from bit 3 to bit 4
  unsigned int low_nibble = ((cpu->reg)[A] & 0x0F) + (regm & 0x0F);
  if (shouldicarry) low_nibble += cpu->carry;
  cpu->aux_carry = (low_nibble > 0x0F) ? 1 : 0;

  if (res > 0xFF) cpu->carry = 1;
  else cpu->carry = 0;
  res %= 0x100;
  zsp_flags((unsigned char)res, cpu);
  (cpu->reg)[A] = (unsigned char)res;
  return;
}

void sub(unsigned char regm, struct i8080* cpu, char shouldiborrow) {
  unsigned char original_regm = regm;
  if (shouldiborrow) {regm +=1; regm %= 0x100;}

  // Auxiliary carry: borrow from bit 4 (inverted logic for subtraction)
  int low_nibble = ((cpu->reg)[A] & 0x0F) - (original_regm & 0x0F);
  if (shouldiborrow) low_nibble -= cpu->carry;
  cpu->aux_carry = (low_nibble >= 0) ? 1 : 0;

  if ((cpu->reg)[A] < regm) cpu->carry = 1;
  else cpu->carry = 0;
  unsigned char res = 0x100 - regm;
  res += (cpu->reg)[A]; res %= 0x100;
  zsp_flags(res, cpu);
  (cpu->reg)[A] = res;
  return;
}

enum log_op {bw_and, bw_xor, bw_or};
void logic(enum log_op sw, unsigned char regm, struct i8080* cpu) {
  switch (sw) {
    case bw_and: (cpu->reg)[A] &= regm; break;
    case bw_xor: (cpu->reg)[A] ^= regm; break;
    case bw_or: (cpu->reg)[A] |= regm; break;
  }
  cpu->carry = 0;
  zsp_flags((cpu->reg)[A], cpu);
  return;
}

void cmp(unsigned char regm, struct i8080* cpu) {
  // Auxiliary carry: borrow from bit 4
  int low_nibble = ((cpu->reg)[A] & 0x0F) - (regm & 0x0F);
  cpu->aux_carry = (low_nibble >= 0) ? 1 : 0;

  if ((cpu->reg)[A] < regm) cpu->carry = 1;
  else cpu->carry = 0;
  unsigned char res = 0x100 - regm;
  res += (cpu->reg)[A]; res %= 0x100;
  zsp_flags(res, cpu);
  return;
}

void daa(struct i8080* cpu) {
  // Decimal Adjust Accumulator - adjusts result of BCD addition
  unsigned char correction = 0;
  unsigned char carry = cpu->carry;

  // Check low nibble (bits 0-3)
  if (((cpu->reg)[A] & 0x0F) > 9 || cpu->aux_carry) {
    correction = 0x06;
  }

  // Check high nibble (bits 4-7)
  if ((((cpu->reg)[A] & 0xF0) >> 4) > 9 || cpu->carry ||
      ((((cpu->reg)[A] & 0xF0) >> 4) >= 9 && ((cpu->reg)[A] & 0x0F) > 9)) {
    correction |= 0x60;
    carry = 1;
  }

  // Apply correction
  unsigned int result = (cpu->reg)[A] + correction;

  // Set auxiliary carry if there was a carry from bit 3
  cpu->aux_carry = (((cpu->reg)[A] & 0x0F) + (correction & 0x0F)) > 0x0F ? 1 : 0;

  (cpu->reg)[A] = (unsigned char)(result & 0xFF);
  cpu->carry = carry;
  zsp_flags((cpu->reg)[A], cpu);
  return;
}

void doubleinr(enum regs R, struct i8080* cpu) {
  if (R == SP) {
    if (cpu->stack_ptr == 0xFFFF) {cpu->stack_ptr = 0; return;}
    ++cpu->stack_ptr; return;
  }
  else if (R == B || R == D || R == H) {
    if ((cpu->reg)[R+1] == 0xFF) {
      cpu->reg[R+1] = 0;
      if ((cpu->reg)[R] == 0xFF) {cpu->reg[R] = 0; return;}
      ++cpu->reg[R]; return;
    }
    ++(cpu->reg)[R+1]; return;
  }
}

void doubledcr(enum regs R, struct i8080* cpu) {
  if (R == SP) {
    if (cpu->stack_ptr == 0) {cpu->stack_ptr = 0xFFFF; return;}
    --cpu->stack_ptr; return;
  }
  else if (R == B || R == D || R == H) {
    if ((cpu->reg)[R+1] == 0) {
      cpu->reg[R+1] = 0xFF;
      if ((cpu->reg)[R] == 0) {cpu->reg[R] = 0xFF; return;}
      --cpu->reg[R]; return;
    }
    --(cpu->reg)[R+1]; return;
  }
}

void xthl(struct i8080* cpu, unsigned char* mem) {
  unsigned char temp = (cpu->reg)[H];
    (cpu->reg)[H] = MemRead((cpu->stack_ptr)+1); // mem[(cpu->stack_ptr)+1];
    MemWrite((cpu->stack_ptr)+1, temp);
   //mem[(cpu->stack_ptr)+1] = temp;
  temp = (cpu->reg)[L];
    (cpu->reg)[L] = MemRead(cpu->stack_ptr); //mem[cpu->stack_ptr];
//  mem[cpu->stack_ptr] = temp;
     MemWrite((cpu->stack_ptr), temp);
  return;
}

void xchg(struct i8080* cpu) {
  unsigned char temp = (cpu->reg)[H];
  (cpu->reg)[H] = (cpu->reg)[D];
  (cpu->reg)[D] = temp;
  temp = (cpu->reg)[L];
  (cpu->reg)[L] = (cpu->reg)[E];
  (cpu->reg)[E] = temp;
  return;
}

void doubleadd(enum regs R, struct i8080* cpu) {
  unsigned int targ = 0x100*(cpu->reg)[H] + (cpu->reg)[L];
  unsigned int summand = 0;
  if (R == SP)
    summand = cpu->stack_ptr;
  else if (R == B || R == D || R == H)
    summand = 0x100*(cpu->reg)[R] + (cpu->reg)[R+1];
  targ += summand;
  cpu->carry = targ / 0x10000; targ %= 0x10000;
  (cpu->reg)[H] = targ / 0x100; (cpu->reg)[L] = targ % 0x100;
  return;
}

unsigned int call(unsigned int ret, unsigned int jmp,
                  struct i8080* cpu, unsigned char* mem) {
 // mem[(cpu->stack_ptr) - 1] = ret/0x100;
 // mem[(cpu->stack_ptr) - 2] = ret%0x100;
    
    MemWrite((cpu->stack_ptr) - 1, ret/0x100);
    MemWrite((cpu->stack_ptr) - 2, ret%0x100);
    
  cpu->stack_ptr -= 2;
  return jmp;
}

unsigned int ret(struct i8080* cpu, unsigned char* mem) {
  cpu->stack_ptr += 2;
    return 0x100*MemRead((cpu->stack_ptr)-1) + MemRead(cpu->stack_ptr-2);
//  return 0x100*mem[(cpu->stack_ptr)-1] + mem[cpu->stack_ptr-2];
}

void push(enum regs R, struct i8080* cpu, unsigned char* mem) {
  //mem[(cpu->stack_ptr) - 1] = (cpu->reg)[R];
    MemWrite(((cpu->stack_ptr) - 1),(cpu->reg)[R]);
  if (R == A) {
      
    MemWrite((cpu->stack_ptr) - 2,
      
   // mem[(cpu->stack_ptr) - 2] =
       (cpu->carry)//Least signif. bit of PSW is carry
       + 0x02//2nd bit is always on
       + 0x04 * (cpu->parity)//3rd bit parity, 4th always off
       + 0x10 * (cpu->aux_carry)//5th aux_carry, 6th always off
       + 0x40 * (cpu->iszero)//7th bit is zero bit
       + 0x80 * (cpu->sign));//8th (most signif.) bit is sign
  }
  else if (R == B || R == D || R == H)
   // mem[(cpu->stack_ptr) - 2] = (cpu->reg)[R+1];
     MemWrite(((cpu->stack_ptr) - 2),(cpu->reg)[R+1]);
  cpu->stack_ptr -= 2;
  return;
}

void pop(enum regs R, struct i8080* cpu, unsigned char* mem) {
    (cpu->reg)[R] = MemRead((cpu->stack_ptr)+1);
  if (R == A) {
    unsigned char psw = MemRead(cpu->stack_ptr);
    cpu->carry = psw%2;
    psw >>= 2; cpu->parity    = psw%2;
    psw >>= 2; cpu->aux_carry = psw%2;
    psw >>= 2; cpu->iszero    = psw%2;
    psw >>= 1; cpu->sign      = psw%2;
  }
  else if (R == B || R == D || R == H)
     (cpu->reg)[R+1] = MemRead(cpu->stack_ptr);
  cpu->stack_ptr += 2;
  return;
}
