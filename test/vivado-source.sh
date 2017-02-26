#!/usr/bin/env bash
vivado -mode batch -nolog -nojournal -notrace -source $@
# Clean up webtalk log and journal. The generation of these files is 
# unaffected by the -nolog and -nojournal command line arguments.
rm -f webtalk*.log
rm -f webtalk*.jou
rm -rf .Xil/
