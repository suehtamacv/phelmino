#!/bin/bash

> phelmino_rom.txt

if [[ $# -lt 2 ]]; then
   echo "Usage: phelmino_compiler.sh [option] [file]";
   echo "  Compile Assembly or C code into hex file for ROM memory intialization";
   echo "  The options are:";
   echo "  -s   when input file is of extension .S (assembly code)";
   echo "  -c   when input file is of extension .c (C code)";
else
   case $1 in
           "-s") riscv32-unknown-elf-as -o riscv_raw_elf $2 ;;
           "-c") riscv32-unknown-elf-gcc -o riscv_raw_elf $2 -static
   esac

   #riscv32-unknown-elf-strip riscv_raw_elf 
   riscv32-unknown-elf-objcopy -I elf32-littleriscv -O binary riscv_raw_elf riscv_section_elf
   xxd -c 4 -e riscv_section_elf > riscv_hex_instructions.txt
   ./generate_rom.pl

fi;