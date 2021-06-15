# High Performance Processors and Systems Project 

## Bluespec RISC-V processors<br/>
Abstract:
Bluespec System Verilog (**BSV**) is a state-of-the-art Hardware Description Language (HDL).<br/>
Bluespec compilation toolchain (**BSC**) has been recently released as open source. <br/>
The purpose of this project is to investigate the potentiality of its toolchain implementing a multi-stage **RISC-V processor**.<br/>

Keyword: Bluespec, RISC-V, Computer Architectures

**Final report of the project** [here](https://github.com/riccardo-nannini/BSV_RISC-V/blob/main/report/report.pdf)

---

### Requirements to run the examples: 

- [bsc](https://github.com/B-Lang-org/bsc)

---


### How to run the examples:
#### Compile into Verilog RTL

	$ bsc -verilog filename.bsv
where **_filename.bsv_** is your BSV file

#### Simulate your design from Verilog RTL

	$ bsc -o sim -e moduleName moduleName.v
	$ ./sim
where **_sim_** is the desired output executable name, **_moduleName_** is the top-level module in the design and **_moduleName.v_** is the output of the previous step.

#### Test your design with a testbench

In order to use Bluespec's native simulator **Bluesim** to simulate the design and generate the VCD we compile the sources to Bluesim objects:

	$ bsc -u -sim testbench.bsv
where **_testbench.bsv_** is your source testbench file, and create the executable with:

	$ bsc -o sim -sim -e moduleName
where **_sim_** is the desired output executable name and **_moduleName_** is the top-level module in the testbench source.<br/><br/>
We can then execute the executable and dump the waveforms in a .vcd file

	$ ./sim -V dump.vcd
where **_sim_** is the output of the previous step and **_dump.vcd_** is the desired .vcd output file. <br/> <br/>

This 3 steps are automated in a really simple bash script [testbench.sh](https://github.com/riccardo-nannini/BSV_RISC-V/blob/main/examples/counter/testbench.sh), more info on the use of the script are avaiable through

	$ ./testbench.sh -h
