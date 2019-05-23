#! /bin/bash
#set -ue
input=$1
base=${input%.*}
mix jack_compiler ${input}
echo Compile complete.

test=${base}.tst
~/git/nand2tetris/tools/CPUEmulator.sh ${test}
echo cmp
cat ${base}.cmp
echo out
cat ${base}.out