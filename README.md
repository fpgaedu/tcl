# FPGAedu Tcl Library

This library contains a number of packages that collectively contribute to the 
development of a server application that is to be run inside a Vivado instance, 
allowing for interprocess communication between a client and Vivado features.

## Packages
 - `fpgaedu::json`
 - `fpgaedu::jsonrpc`
 - `fpgaedu::vivado`
 - `fpgaedu::vivadoserver`

## Requirements
- Vivado >= 2016.3, implying:
    - Tcl >= 8.5
    - Tcllib >= 1.11.1
- `vivado` command available from `PATH`.

This library was developed using an installation of Vivado 2016.3, so that's the
reason for the version requirement. A lower version may be compatible, but this 
is not tested.

## Synopsis
To start the server on port 3742 (=FPGA):
```
vivado -mode batch -nolog -nojournal -notrace -source start.tcl
```

## Server 
The server application exposes a remote procedure call (RPC) interface to allow
for interaction with Vivado functionality through a remote client. 

As described in [this](https://www.simple-is-better.org/json-rpc/transport_sockets.html#shutdown-close-after-every-request-response)
page, the server uses the simplest transport mechanism possible, in which a 
new socket connection is created for every request. Socket enpoints are 
closed to signal the end of a request and a response. Procedure calls are 
encoded in JSON-RPC 2.0 format. The current JSON-RPC implementation does not 
allow for batch processing.

The server currently exposes a single method `program` for single device 
programming. 

Example request:
```json
{
    "jsonrpc": "2.0",
    "method": "program",
    "id": 1,
    "params": {
        "target": "localhost:3121/xilinx_tcf/Digilent/210274673876A",
        "device": "xc7a100t_0",
        "bitstream": "SEVMTE8gV09TEQgSEVMTE8gV09STEQgSEVMTE8gV09STEQgSEVMTE8...

                               Base64 encoded binary bitstream data 
        
                      ...ASDADASDSTEQgSEVMTE8gV09STEQgDQo=SEVMTE8gV 09STEQNCg=="
    }
}
```
Example response:
```json
{
    "jsonrpc": "2.0",
    "id": 1,
    "result": null
}
```