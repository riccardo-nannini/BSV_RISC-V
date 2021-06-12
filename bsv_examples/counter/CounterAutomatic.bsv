interface CounterAutomatic#(type size_t);
  method Bit#(size_t) read();
  method Action load(Bit#(size_t) newval);
endinterface

//(* synthesize *)
module mkCounterAutomatic(CounterAutomatic#(size_t));

  Reg#(Bit#(size_t)) value <- mkReg(0);

  //the Counter automatically increments are every clock cycle as soon as his value is !=0
  rule increment (value != 0);
    value <= value+1;
  endrule

  method Bit#(size_t) read();
    return value;
  endmethod

  method Action load(Bit#(size_t) newval);
    value <= newval;
  endmethod


endmodule