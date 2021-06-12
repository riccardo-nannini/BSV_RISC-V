// TwoCycle.bsv
//
// This is a two cycle implementation of the RISC-V processor.

// Unlike OneCycle.bsv, this design implements a von Neumann architecture where data and instructions are not in the same memory.
// Therefore (assuming the memory cannot be accessed twice inthe same cycle) there is a structural hazard in reading from memory.
// This is solved by splitting the instruction execution in 2 cycles, fetching the istruction first and reading the data in the second cc.

import Types::*;
import ProcTypes::*;
import CMemTypes::*;
import RFile::*;
import IMemory::*;
import DMemory::*;
import Decode::*;
import Exec::*;
import CsrFile::*;
import Vector::*;
import Fifo::*;
import Ehr::*;
import GetPut::*;

typedef enum {
	Fetch,
	Execute
} State deriving(Bits, Eq, FShow);

(* synthesize *)
module mkProc(Proc);
    Reg#(Addr) pc <- mkRegU;
    RFile      rf <- mkRFile;
    DMemory  dMem <- mkDMemory;
    IMemory  iMem <- mkIMemory;
    CsrFile  csrf <- mkCsrFile;
    Reg#(State) state <- mkRegU;
    Reg#(Data) f2d <- mkRegU;

    Bool memReady = iMem.init.done() && dMem.init.done();

    rule test (!memReady);
	    let e = tagged InitDone;
	    iMem.init.request.put(e);
	    dMem.init.request.put(e);
    endrule
    
    rule doFetch(csrf.started && state == Fetch);      
	
        let inst = iMem.req(pc);
        f2d <= inst;
        state <= Execute;

    endrule

    rule doExecute(csrf.started && state == Execute);
	
	    //Execution stage
    
        let inst = f2d;

        // decode
        DecodedInst dInst = decode(inst);

        // read general purpose register values 
        Data rVal1 = rf.rd1(fromMaybe(?, dInst.src1));
        Data rVal2 = rf.rd2(fromMaybe(?, dInst.src2));

        // read CSR values (for CSRR inst)
        Data csrVal = csrf.rd(fromMaybe(?, dInst.csr));

        // execute
        ExecInst eInst = exec(dInst, rVal1, rVal2, pc, ?, csrVal);  
        // The fifth argument above is the predicted pc, to detect if it was mispredicted. 
        // Since there is no branch prediction, this field is sent with a random value

        // memory
        if(eInst.iType == Ld) begin
            eInst.data <- dMem.req(MemReq{op: Ld, addr: eInst.addr, data: ?});
        end else if(eInst.iType == St) begin
            let d <- dMem.req(MemReq{op: St, addr: eInst.addr, data: eInst.data});
        end

        // commit

        // trace - print the instruction
        $display("pc: %h inst: (%h) expanded: ", pc, inst, showInst(inst));
        $fflush(stdout);

        // check unsupported instruction at commit time. Exiting
        if(eInst.iType == Unsupported) begin
            $fwrite(stderr, "ERROR: Executing unsupported instruction at pc: %x. Exiting\n", pc);
            $finish;
        end

        // write back to reg file
        if(isValid(eInst.dst)) begin
            rf.wr(fromMaybe(?, eInst.dst), eInst.data);
        end

        // update the pc depending on whether the branch is taken or not
        pc <= eInst.brTaken ? eInst.addr : pc + 4;

        // CSR write for sending data to host & stats
        csrf.wr(eInst.iType == Csrw ? eInst.csr : Invalid, eInst.data);
        state <= Fetch;

    endrule

    method ActionValue#(CpuToHostData) cpuToHost;
        let ret <- csrf.cpuToHost;
        return ret;
    endmethod

    method Action hostToCpu(Bit#(32) startpc) if ( !csrf.started && memReady );
        csrf.start(0); // only 1 core, id = 0
        pc <= startpc;
	state <= Fetch;
    endmethod

    interface iMemInit = iMem.init;
    interface dMemInit = dMem.init;
endmodule

