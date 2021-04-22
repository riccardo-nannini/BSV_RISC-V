package TbSimpleTrafficLight;

import SimpleTrafficLight::*;

interface Lamp;
   method Bool changed;
   method Action show_offs;
   method Action show_ons;
   method Action reset;
endinterface

module mkLamp#(String name, Bool lamp)(Lamp);
   Reg#(Bool) prev <- mkReg(False);

   method changed = (prev != lamp);

   method Action show_offs;
      if (prev && !lamp)
	       $write (name + " off, ");
   endmethod

   method Action show_ons;
      if (!prev && lamp)
	       $write (name + " on, ");
   endmethod

   method Action reset;
      prev <= lamp;
   endmethod
endmodule

(* synthesize *)
module mkTest();
   let dut <- sysTL;

   Reg#(UInt#(16)) ctr <- mkReg(0);

   Lamp lamps[12];

   lamps[0] <- mkLamp("NS  red  ", dut.lampRedNS);
   lamps[1] <- mkLamp("NS  amber", dut.lampAmberNS);
   lamps[2] <- mkLamp("NS  green", dut.lampGreenNS);

   lamps[3] <- mkLamp("E   red  ", dut.lampRedE);
   lamps[4] <- mkLamp("E   amber", dut.lampAmberE);
   lamps[5] <- mkLamp("E   green", dut.lampGreenE);

   lamps[6] <- mkLamp("W   red  ", dut.lampRedW);
   lamps[7] <- mkLamp("W   amber", dut.lampAmberW);
   lamps[8] <- mkLamp("W   green", dut.lampGreenW);

   lamps[9]  <- mkLamp("Ped red  ", dut.lampRedPed);
   lamps[10] <- mkLamp("Ped amber", dut.lampAmberPed);
   lamps[11] <- mkLamp("Ped green", dut.lampGreenPed);

   function do_offs(l) = l.show_offs;
   function do_ons(l) = l.show_ons;
   function do_reset(l) = l.reset;

    function check(val);
      action
        if (!val) $display("TEST FAILED");
        else $display("TEST SUCCEED");
      endaction
    endfunction

   function do_it(f);
      action
	      for (Integer i=0; i<12; i=i+1)
	        f(lamps[i]);
      endaction
   endfunction

   function any_changes();
      Bool b = False;
        for (Integer i=0; i<12; i=i+1)
	        b = b || lamps[i].changed;
        return b;
   endfunction

       
   rule show (any_changes());
      do_it(do_offs);
      do_it(do_ons);
      do_it(do_reset);
      $display("(at time %d)", ctr);
   endrule
   

   rule inc_ctr;
      ctr <= ctr + 1;
      if (ctr == 400) dut.requestPedestrian;
      if (ctr == 630) dut.requestPedestrian;
   endrule

   rule stop (ctr > 1000);
      $finish(0);
   endrule
endmodule

endpackage

     
