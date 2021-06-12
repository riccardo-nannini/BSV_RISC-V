// Six stage

import Types::*;
import ProcTypes::*;
import MemTypes::*;
import MemInit::*;
import RFile::*;
import IMemory::*;
import DMemory::*;
import Decode::*;
import Exec::*;
import CsrFile::*;
import Fifo::*;
import Ehr::*;
import Btb::*;
import Scoreboard::*;
import FPGAMemory::*;
import Bht::*;


// Data structure for Instruction Fetch to Decode stage
typedef struct {
    Addr pc;
    Addr predPc;
    Bool exeEpoch;
    Bool decEpoch;
} Fetch2Decode deriving (Bits, Eq);

// Data structure for Decode to Register Fetch stage
typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Bool exeEpoch;
} Decode2Register deriving (Bits, Eq);

// Data structure for Register Fetch to Execute stage
typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Data rVal1;
    Data rVal2;
    Data csrVal;
    Bool exeEpoch;
} Register2Execute deriving (Bits, Eq);

// Data structure for Execute to Memory stage
typedef struct {
    Addr pc;
    Maybe#(ExecInst) eInst;
} Execute2Memory deriving (Bits, Eq);

// Data structure for Memory to Write Back stage
typedef struct {
    Addr pc;
    Maybe#(ExecInst) eInst;
} Memory2WriteBack deriving (Bits, Eq);

// redirect msg from Execute stage
typedef struct {
    Addr pc;
    Addr nextPc;
} ExeRedirect deriving (Bits, Eq);

// redirect msg from Execute stage
typedef struct {
    Addr nextPc;
} DecRedirect deriving (Bits, Eq);




(* synthesize *)
module mkProc(Proc);
    Ehr#(2, Addr) pcReg <- mkEhr(?);
    RFile            rf <- mkRFile;
    Scoreboard#(10)   sb <- mkCFScoreboard;
    FPGAMemory       iMem <- mkFPGAMemory;
    FPGAMemory       dMem <- mkFPGAMemory;
    CsrFile          csrf <- mkCsrFile;
    Btb#(6)          btb <- mkBtb; // 64-entry BTB
    Bht#(8)	         bht <- mkBht; // 256-entry 2bit-BHT

    Bool memReady = iMem.init.done && dMem.init.done;

    // global epoch for redirection from Execute stage
    Reg#(Bool) exeEpoch <- mkReg(False);
    // global epoch for redirection from Decode stage
    Reg#(Bool) decEpoch <- mkReg(False);

   // EHRs for redirection
   Ehr#(2, Maybe#(ExeRedirect)) exeRedirect <- mkEhr(Invalid);
   Ehr#(2, Maybe#(DecRedirect)) decRedirect <- mkEhr(Invalid);

   //Intermidiate registers
   Fifo#(2, Fetch2Decode)     f2dFifo <- mkCFFifo;
   Fifo#(2, Decode2Register)  d2rFifo <- mkCFFifo;
   Fifo#(2, Register2Execute) r2eFifo <- mkCFFifo;
   Fifo#(2, Execute2Memory)   e2mFifo <- mkCFFifo;
   Fifo#(2, Memory2WriteBack) m2wbFifo <- mkCFFifo;



   	// fetch, decode, reg read stage
	rule doFetch(csrf.started);

		// request instruction from memory & update pc
		iMem.req(MemReq{op: ?, addr: pcReg[0], data: ?});
        Addr predPc = btb.predPc(pcReg[0]);

        Fetch2Decode f2d = Fetch2Decode {
            pc: pcReg[0],
            predPc : predPc,
            exeEpoch: exeEpoch,
            decEpoch: decEpoch
        };

        $display("Fetching instruction: PC = %x, next PC: %x", pcReg[0], predPc);
        
        f2dFifo.enq(f2d);
        pcReg[0] <= predPc;

    endrule

    //---------------------------------------------------------------------

    rule doDecode(csrf.started);

        let f2d = f2dFifo.first;
        f2dFifo.deq;

        Data inst <- iMem.resp();

        if (f2d.decEpoch == decEpoch && f2d.exeEpoch == exeEpoch)
        begin

            DecodedInst dInst = decode(inst);

            if (dInst.iType == J || dInst.iType == Br)
            begin
                let bthPrevision = bht.predPc(f2d.pc, f2d.predPc);

                if (bthPrevision != f2d.predPc)
                begin

                    $display("Redirect by BHT: PC = %x, old ppc = %x, new ppc = %x", f2d.pc, f2d.predPc, bthPrevision);

                    decRedirect[0] <= Valid(DecRedirect {
                        nextPc: bthPrevision
                    });            
                    
                    f2d.predPc = bthPrevision;

                end
            end
            

            Decode2Register d2r = Decode2Register {
                pc: f2d.pc,
                predPc : f2d.predPc,
                dInst: dInst,
                exeEpoch: f2d.exeEpoch
            };

            $display("Decode: PC = %x, inst = %x, expanded = ", f2d.pc, inst, showInst(inst));

            d2rFifo.enq(d2r);
        end
        else
        begin
            $display("Killing wrong path in Decode");
        end
        

    endrule

    //---------------------------------------------------------------------

    rule doRegister(csrf.started);

        let d2r = d2rFifo.first;
        let dInst = d2r.dInst;

        // reg read
		Data rVal1 = rf.rd1(fromMaybe(?, dInst.src1));
		Data rVal2 = rf.rd2(fromMaybe(?, dInst.src2));
		Data csrVal = csrf.rd(fromMaybe(?, dInst.csr));


        if(!sb.search1(dInst.src1) && !sb.search2(dInst.src2))
        begin
			// enq & update PC, sb
			sb.insert(dInst.dst);

            $display("Read registers: PC = %x", d2r.pc);

            Register2Execute r2e = Register2Execute {
            pc: d2r.pc,
            predPc: d2r.predPc,
            dInst: d2r.dInst,
            rVal1: rVal1,
            rVal2: rVal2,
            csrVal: csrVal,
            exeEpoch: d2r.exeEpoch
            };
            d2rFifo.deq;

            r2eFifo.enq(r2e);
        end
		else 
        begin
			$display("######### REGISTER READ STALLED: PC = %x ##########", d2r.pc);
		end
        

    endrule

    //---------------------------------------------------------------------

    rule doExecute(csrf.started);

        let r2e = r2eFifo.first;
        r2eFifo.deq;

        Maybe#(ExecInst) eInst;

        if (r2e.exeEpoch != exeEpoch)
        begin   
            // kill wrong-path inst, just deq sb
			$display("Execute: Kill instruction");
            eInst = Invalid;
		end    
        else
        begin
            // execute
		    ExecInst exeInst = exec(r2e.dInst, r2e.rVal1, r2e.rVal2, r2e.pc, r2e.predPc, r2e.csrVal);  
            eInst = Valid(exeInst);

            // check unsupported instruction at commit time. Exiting
            if(exeInst.iType == Unsupported)
            begin
                $fwrite(stderr, "ERROR: Executing unsupported instruction at pc: %x. Exiting\n", r2e.pc);
                $finish;
            end

		    // check mispred: with proper BTB, it is only possible for branch/jump inst
		    if(exeInst.mispredict) 
		    begin
		    $display("Execute finds misprediction: PC = %x", r2e.pc);
		      let realNextPc = exeInst.iType == J || exeInst.iType == Jr || exeInst.iType == Br ? exeInst.addr : r2e.pc + 4;
		    	exeRedirect[0] <= Valid (ExeRedirect {
		    		pc: r2e.pc,
		    		nextPc: realNextPc
		    	});
		    end
		    else
            begin
		    	$display("Execute: PC = %x", r2e.pc);
            end
            if (exeInst.iType == Br)
            begin
                bht.update(r2e.pc, exeInst.brTaken);
            end

        end

        Execute2Memory e2m = Execute2Memory {
            pc: r2e.pc,
            eInst: eInst
        };
        e2mFifo.enq(e2m);

        

    endrule

    //---------------------------------------------------------------------

    rule doMemory(csrf.started);

        let e2m = e2mFifo.first;
        e2mFifo.deq;

        if (isValid(e2m.eInst))
        begin

            //recover the executed instruction
            let eInst = fromMaybe(?, e2m.eInst);

            // memory
            if(eInst.iType == Ld) 
            begin
                dMem.req(MemReq{op: Ld, addr: eInst.addr, data: ?});
                $display("Memory: LOAD instruction: PC = %x", e2m.pc);
            end 
            else if(eInst.iType == St)
            begin
                let dummy <- dMem.req(MemReq{op: St, addr: eInst.addr, data: eInst.data});
                $display("Memory: STORE instruction: PC = %x", e2m.pc);
            end
            else
            begin
                $display("Memory stage of instruction: PC = %x", e2m.pc);
            end
        end
        else
        begin
            $display("Memory stage of invalid instruction");
        end

        Memory2WriteBack m2wb = Memory2WriteBack {
            pc: e2m.pc,
            eInst: e2m.eInst
        };

        m2wbFifo.enq(m2wb);

    endrule
        
    //---------------------------------------------------------------------

    rule doWriteBack(csrf.started);

        m2wbFifo.deq;
        let m2wb = m2wbFifo.first;

        if (isValid(m2wb.eInst))
        begin

            //recover the executed instruction
            let eInst = fromMaybe(?, m2wb.eInst);

            if (eInst.iType == Ld)
            begin
                eInst.data <- dMem.resp();
            end


            // write back to reg file
		    if(isValid(eInst.dst))
            begin
                rf.wr(fromMaybe(?, eInst.dst), eInst.data);
            end

            csrf.wr(eInst.iType == Csrw ? eInst.csr : Invalid, eInst.data);
            $display("Write back stage of instruction: PC = %x", m2wb.pc);
        end
        else
        begin
            $display("Write back stage of invalid instruction");
        end

        // remove from scoreboard
        sb.remove;

    endrule

    //---------------------------------------------------------------------

	(* fire_when_enabled *)
	(* no_implicit_conditions *)
	rule cononicalizeRedirect(csrf.started);
		if(exeRedirect[1] matches tagged Valid .r) 
        begin
			// fix mispred
			pcReg[1] <= r.nextPc;
			exeEpoch <= !exeEpoch; // flip epoch
			btb.update(r.pc, r.nextPc); // train BTB
			$display("Fetch: Mispredict, redirected by Execute");
		end
        else if (decRedirect[1] matches tagged Valid .r)
        begin
            // fix mispred
            pcReg[1] <= r.nextPc;
            decEpoch <= !decEpoch;
            $display("Fetch: Mispredict, redirected by Decode");
        end
		// reset EHRs
		exeRedirect[1] <= Invalid;
        decRedirect[1] <= Invalid;
	endrule

    //---------------------------------------------------------------------


    method ActionValue#(CpuToHostData) cpuToHost if(csrf.started);
        let ret <- csrf.cpuToHost;
        return ret;
    endmethod

    method Action hostToCpu(Bit#(32) startpc) if ( !csrf.started && memReady );
	$display("Start cpu");
        csrf.start(0); // only 1 core, id = 0
        pcReg[0] <= startpc;
    endmethod

	interface iMemInit = iMem.init;
    interface dMemInit = dMem.init;
endmodule

