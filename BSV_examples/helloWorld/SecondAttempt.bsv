package SecondAttempt;

  //prints "Hello world" 5 times
  /*
    Unpredictable/Bad version, in the 5th cycle, all 3 rules fire: if 'stop' fires first then the result is correct,
    otherwise say_hello might fire a 6th time before stop is fired
  */
  String s = "Hello world";

  (* synthesize *)
  module mkAttempt (Empty);
    Reg#(UInt#(3)) ctr <- mkReg(0); //instantiate and initialize the counter register

    rule stop (ctr == 5);
      $finish(0);
    endrule


    rule say_hello;
      $display(ctr);
    endrule

    rule inc_ctr;
      ctr <= ctr +1;
    endrule

      
  endmodule

endpackage