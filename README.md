# JackCompiler


ASM symbols:

| Symbol | Description |
|--------|-------------|
| SP     | Stack Pointer |
| LCL    | local |
| ARG    | argument |
| THIS   | first half of pointer |
| THAT   | second half of pointer |
| R13-R15| Guessing we can just use these puppies |
| Xxx.j  | Each static variable j in file XXX.vm is translated into the symbol Xxx.j. |
| Control symbols | |


## RAM addresses
| 0-15 | 16 virtual registers
| 16-255 | static variables
| 256-2047 | STack
| 2048-16483 | Heap
| 16384-24575 | Memory mapped I/O

3 is this
4 is that
5 - 12 are temp
pointer i should translate to 3 + i
temp i should translate to 5 + i
## Memory Segments Mapping