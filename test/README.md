# Running the tests

This library defines a number of tests for the individual packages. In order to
be able to run these tests, one can execute `./alltests.tcl`. This will execute 
all tests through the `tclsh` interpreter, which is the fastest. Vivado-specific
tests are automatically skipped. Sourcing a specific test file will also work,
for example: `tclsh json.test`. 

## Vivado
Packages and tests that require to be executed within Vivado however, need to
be executed in a different way. First, one needs to ensure that the `vivado`
command is available from the current PATH. If this is the case, 
a helper script can be used to source the test suite through execution of 
`./vivado-source.sh alltests.tcl`. Again, specific tests scripts can be executed
through the execution of `./vivado-source.sh vivado.test`, for example. The 
initialization of a new Vivado Tcl interpreter does however take some time. 
Since a new interpreter is spawned for every individual test script, the execution
of the entire test suite takes some minutes.

## Hardware-specific Tests
Some tests require a specific hardware setup in order not to be skipped. At this
moment, some tests require a Digilent Nexys 4 board to be connected as the only
device in order for these tests to be executed. 
