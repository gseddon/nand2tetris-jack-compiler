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
argument
Stores the function’s arguments.
Allocated dynamically by the VM implementation when the function is entered.

local
Stores the function’s local variables.
Allocated dynamically by the VM implementation and initialized to 0’s when the function is entered.

static
Stores static variables shared by all functions in the same .vm ﬁle.
Allocated by the VM imp. for each .vm ﬁle; shared by all functions in the .vm ﬁle.

constant
Pseudo-segment that holds all the constants in the range 0 . . . 32767.
Emulated by the VM implementation; Seen by all the functions in the program.

this that
Any VM function can use these segments to manipulate selected areas on the heap.
General-purpose segments. Can be made to correspond to different areas in the heap. Serve various programming needs.

pointer
A two-entry segment that holds the base addresses of the this and that segments.
Any VM function can set pointer 0 (or 1) to some address; this has the effect of aligning the this (or that) segment to the heap area beginning in that address.

temp
Fixed eight-entry segment that holds temporary variables for general use.
May be used by any VM function for any purpose. Shared by all functions in the program.