#!/bin/bash
# 
# прилуда для запуска шептача
# 
## скомпилить и запустить
#/home/user/src/n2o/samples/mad deps compile plan repl
maker="mad"
opts="deps compile plan repl"
fullpath=$(pwd)
#echo "fullpath: $fullpath"
cc="$fullpath/$maker $opts"
echo "================================="
echo "*** compile & run scheptoush! ***"
echo "================================="
#echo "$cc"
$cc
exit 0
