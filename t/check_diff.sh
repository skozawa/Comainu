#!/bin/bash

files=(
    "sample.KC.bout"
    "sample.KC.lout"
    "sample_mid.KC.mout"
    "sample.bccwj.txt.bout"
    "sample.bccwj.txt.lbout"
    "sample.bccwj.txt.lout"
    "sample.bccwj.txt.mbout"
    "sample.bccwj.txt.mout"
    "sample.txt.bout"
    "sample.txt.lbout"
    "sample.txt.lout"
    "sample.txt.mbout"
    "sample.txt.mout"
)

for file in "${files[@]}"; do
    echo $file
    diff $1/$file $2/$file
done
