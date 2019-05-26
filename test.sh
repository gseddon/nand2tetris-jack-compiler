#! /bin/bash
#set -ue
input=$1
base=${input%.*}

mix jack_compiler ${input}
echo Compile complete.
if [[ ${input} == ${base} ]]; then
    base=${base}/$(basename ${base})
fi

python3 ~/git/hack/main.py -i ${base}.asm -l
echo listing file generated.

test=${base}.tst
~/git/nand2tetris/tools/CPUEmulator.sh ${test}
echo cmp
cat ${base}.cmp
echo out
cat ${base}.out