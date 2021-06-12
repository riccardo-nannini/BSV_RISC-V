package TbTrafficLightCarSensors;

import TrafficLightCarSensors::*;

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

   Reg#(UInt#(32)) ctr <- mkReg(0);

   Reg#(Bool) carN <- mkReg(False);
   Reg#(Bool) carS <- mkReg(False);
   Reg#(Bool) carE <- mkReg(False);
   Reg#(Bool) carW <- mkReg(False);

   rule detect_cars;
      dut.set_car_state_N(carN);
      dut.set_car_state_S(carS);
      dut.set_car_state_E(carE);
      dut.set_car_state_W(carW);
   endrule
   
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

      if (ctr == 5000) carN <= True;
      if (ctr == 6500) carN <= False;
      if (ctr == 7000) carW <= True;
      if (ctr == 7250) carS <= True;
      if (ctr == 7300) dut.requestPedestrian;
      if (ctr == 7500) carW <= False;
      if (ctr == 7500) carS <= False;
      if (ctr == 12000) dut.requestPedestrian;
   endrule

   rule stop (ctr > 30000);
      $finish(0);
   endrule
endmodule

endpackage

     
