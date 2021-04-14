import StmtFSM::*;
import CounterAutomatic::*;

(* synthesize *)
module mkTbCounterAutomatic();

  CounterAutomatic#(8) counter <- mkCounterAutomatic();
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
    counter.load(1);
    check(1); //checks if the load is correct
    check(2); //check if after 1cc the value is incremented by 1
    check(3); //check if after 1cc the value is incremented by 2
    $display("TESTS FINISHED");
  endseq;

  mkAutoFSM(test_seq);

endmodule