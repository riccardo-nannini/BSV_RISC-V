
/*
  Counter with load/increment/decrement methods
  The name Cnt is due to the fact that there is a library with name 'Counter' in the bsc compiler and I was having problem
  when running the simulation because the name was interpreted as the library file and not as my Counter.bsv file
*/


interface Cnt#(type size_t);
  method Bit#(size_t) read();
  method Action load(Bit#(size_t) newval);
  method Action increment(Bit#(size_t) newval);
  method Action decrement(Bit#(size_t) newval);
endinterface

//(* synthesize *)
module mkCnt(Cnt#(size_t));
  Reg#(Bit#(size_t)) value <- mkReg(0);

  method Bit#(size_t) read();
    return value;
  endmethod

  method Action load(Bit#(size_t) newval);
    value <= newval;
  endmethod

  method Action increment(Bit#(size_t) incr);
    value <= value + incr;
  endmethod

  method Action decrement(Bit#(size_t) incr);
    value <= value - incr;
  endmethod

endmodule