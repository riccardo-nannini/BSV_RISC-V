package FirstAttempt;

  //prints "Hello world" 5 times

  String s = "Hello world";

  (* synthesize *)
  module mkAttempt (Empty);
    Reg#(UInt#(3)) ctr <- mkReg(0); //instantiate and initialize the counter register

    rule stop (ctr == 5);
      $finish(0);
    endrule


    rule say_hello (ctr < 5);
      ctr <= ctr + 1;
      $display(s);
      
    endrule
  endmodule

endpackage