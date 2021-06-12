import StmtFSM::*;
import Cnt::*;

(* synthesize *)
module mkTbCounter();

  Cnt#(8) counter <- mkCnt();
  Reg#(Bit#(16)) state <- mkReg(0);

  // check that the counter matches an expected value
  function check(expected_val);
    action
      if (counter.read() != expected_val)
        $display("FAIL: counter != %0d", expected_val);
    endaction
  endfunction
  
  //creates a FSM that executes the tests
  Stmt test_seq = seq
    counter.load(16);
    check(16);
    counter.increment(1);
    counter.increment(3);
    check(20);
    counter.decrement(4);
    check(16);
    $display("TESTS FINISHED");
  endseq;

  mkAutoFSM(test_seq);

endmodule