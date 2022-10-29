#!/bin/bash

# bccwj2*out
for method in bccwj2bnstout bccwj2longout bccwj2longbnstout bccwj2midout bccwj2midbnstout bccwjlong2midout
do
    echo $method
    ./script/comainu.pl $method --input sample/sample.bccwj.txt --output-dir sample_out
done

# kc2*out
for method in kc2bnstout kc2longout
do
    echo $method
    ./script/comainu.pl $method --input sample/sample.KC --output-dir sample_out
done
echo "kclong2midout"
./script/comainu.pl kclong2midout --input sample/sample_mid.KC --output-dir sample_out

# plain2*out
for method in plain2bnstout plain2longbnstout plain2longout plain2midbnstout plain2midout
do
    echo $method
    ./script/comainu.pl $method --input sample/plain/sample.txt --output-dir sample_out
done

# train
echo "train long model"
./script/comainu.pl kc2longmodel sample/sample.KC sample_train
echo "train mid model"
./script/comainu.pl kclong2midmodel sample/sample_mid.KC sample_train
echo "train bnst model"
./script/comainu.pl kc2bnstmodel sample/sample.KC sample_train

# eval
echo "eval train model"
./script/comainu.pl kc2longeval sample/sample.KC sample_out/sample.KC.lout sample_out
echo "eval mid model"
./script/comainu.pl kclong2mideval sample/sample_mid.KC sample_out/sample_mid.KC.mout sample_out
echo "eval bnst model"
./script/comainu.pl kc2bnsteval sample/sample.KC sample_out/sample.KC.bout sample_out
