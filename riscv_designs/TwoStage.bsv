// TwoStage.bsv
//
// This is a two stage pipelined implementation of the RISC-V processor.

import Types::*;
import ProcTypes::*;
import CMemTypes::*;
import MemInit::*;
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

typedef struct {
	DecodedInst dInst;
	Addr pc;
	Addr predPc;
} Dec2Ex deriving (Bits, Eq);

(* synthesize *)
module mkProc(Proc);
    Ehr#(2, Addr) pc <- mkEhrU;
    RFile      rf <- mkRFile;
    IMemory  iMem <- mkIMemory;
    DMemory  dMem <- mkDMemory;
    CsrFile  csrf <- mkCsrFile;
    Fifo#(2, Dec2Ex) d2e <- mkCFFifo;


    Bool memReady = iMem.init.done() && dMem.init.done();
    
    rule test (!memReady);
	let e = tagged InitDone;
	iMem.init.request.put(e);
	dMem.init.request.put(e);
    endrule


    rule doFetch(csrf.started);

        Data inst = iMem.req(pc[0]);
        
        Dec2Ex dec2exe;
        dec2exe.pc = pc[0];
        dec2exe.predPc = pc[0] + 4;
        dec2exe.dInst = decode(inst);

        d2e.enq(dec2exe);
        pc[0] <= pc[0] + 4;

    endrule

    rule doExecute(csrf.started);
        

        Dec2Ex dec2exe = d2e.first;
        d2e.deq();
    

        // trace - print the instruction
        $display("pc: %h", dec2exe.pc);
	    $fflush(stdout);

        // read general purpose register values 
        Data rVal1 = rf.rd1(fromMaybe(?, dec2exe.dInst.src1));
        Data rVal2 = rf.rd2(fromMaybe(?, dec2exe.dInst.src2));

        // read CSR values (for CSRR inst)
        Data csrVal = csrf.rd(fromMaybe(?, dec2exe.dInst.csr));

        // execute
        ExecInst eInst = exec(dec2exe.dInst, rVal1, rVal2, dec2exe.pc, dec2exe.predPc, csrVal);  
        
        // memory
        if(eInst.iType == Ld) begin
            eInst.data <- dMem.req(MemReq{op: Ld, addr: eInst.addr, data: ?});
        end else if(eInst.iType == St) begin
            let d <- dMem.req(MemReq{op: St, addr: eInst.addr, data: eInst.data});
        end

        // write back to reg file
        if(isValid(eInst.dst)) begin
            rf.wr(fromMaybe(?, eInst.dst), eInst.data);
        end

        // CSR write for sending data to host & stats
        csrf.wr(eInst.iType == Csrw ? eInst.csr : Invalid, eInst.data);

        // Control hazard handling
        if (eInst.mispredict) 
        begin
            $display("Mispredict!");
            $fflush(stdout);
            d2e.clear();
            if (eInst.brTaken) 
            begin
                pc[1] <= eInst.addr;
            end
        end
        
        
    endrule


    method ActionValue#(CpuToHostData) cpuToHost;
        let ret <- csrf.cpuToHost;
        return ret;
    endmethod

    method Action hostToCpu(Bit#(32) startpc) if ( !csrf.started && memReady );
        csrf.start(0); // only 1 core, id = 0
        $display("STARTING AT PC: %h", startpc);
	    $fflush(stdout);
        pc[0] <= startpc;
    endmethod

	interface iMemInit = iMem.init;
    interface dMemInit = dMem.init;
endmodule

