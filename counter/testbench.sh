#!/bin/bash

Help()
{
   # Display Help
   echo
   echo "Compile and run the simulation for your BSV testbench"
   echo "bsc REQUIRED"
   echo
   echo "Syntax: ./testbench.sh -f -m [-d]"
   echo
   echo "options:"
   
   echo "f     testbench .bsv source file"
   echo "m     testbench module name" 
   echo "d     output .vcd file name (default dump.vcd)"
   echo

}

DUMP="dump.vcd"
while getopts ":f:m:d:h" arg; do
  case $arg in
    f) FILE=$OPTARG;;  #testbench file name
    m) MODULE=$OPTARG;; #testbench module name
    d) DUMP=$OPTARG;;
    h) Help
       exit;;
   \?) # incorrect option
         echo "Error: Invalid option"
         exit;;
  esac
done



bsc -u -sim $FILE && bsc -o sim -sim -e $MODULE && ./sim -V $DUMP
