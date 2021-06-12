
package TrafficLightCarSensors;


(* always_ready *)
interface TL;

   (* always_enabled *) //this annotations eliminate the enable wire, making so that the value is sampled every cc
   method Action set_car_state_N(Bool state);

   (* always_enabled *)
   method Action set_car_state_S(Bool state);

   (* always_enabled *)
   method Action set_car_state_E(Bool state);
      
   (* always_enabled *)
   method Action set_car_state_W(Bool state);

   method Bool lampRedNS();
   method Bool lampAmberNS();
   method Bool lampGreenNS();
      
   method Bool lampRedE();
   method Bool lampAmberE();
   method Bool lampGreenE();
      
   method Bool lampRedW();
   method Bool lampAmberW();
   method Bool lampGreenW();

   method Bool lampRedPed();
   method Bool lampAmberPed();
   method Bool lampGreenPed();

   method Action requestPedestrian();

endinterface: TL

typedef enum { //Semaphor states
   AllRed, 
   GreenNS, AmberNS, 
   GreenE, AmberE, 
   GreenW, AmberW} TLstates deriving (Eq, Bits);

typedef enum { //Pedonal semaphor states
   RedPed, RedIntermediatePed,
   AmberPed, GreenPed} PLstates deriving (Eq, Bits);

typedef UInt#(5) Time32;

(* synthesize *)
module sysTL(TL); //main module

   Reg#(TLstates) state <- mkReg(AllRed); //semaphor
   Reg#(TLstates) next_green <- mkReg(GreenNS); //next semaphor to become green
   Reg#(Time32) secs <- mkReg(0); //counter
   Reg#(PLstates) ped <- mkReg(RedPed);   //pedonal semaphor
   Reg#(Bool) ped_request <- mkReg(False);   //input from pedonal button
   Reg#(Bool) car_sensorS <- mkReg(True); 
   Reg#(Bool) car_sensorN <- mkReg(True);   
   Reg#(Bool) car_sensorE <- mkReg(True);  
   Reg#(Bool) car_sensorW <- mkReg(True);  
  
   Time32 allRedDelay = 2;
   Time32 amberDelay = 4;
   Time32 ns_green_delay = 20;
   Time32 ew_green_delay = 10;
   Time32 ped_green_delay = 10;
   Time32 ped_amber_delay = 6;

   function Action next_state(TLstates st);
      action
         state <= st;
         secs <= 0;
      endaction
   endfunction

   function TLstates green_seq(TLstates x);
      case(x)
         GreenNS: return (GreenE);
         GreenE:  return (GreenW);
         GreenW:  return (GreenNS);
      endcase
   endfunction

   function Bool car_present(TLstates x);
      case (x)
         GreenNS: return (car_sensorN || car_sensorS);
         GreenE: return (car_sensorE);
         GreenW: return (car_sensorW);
      endcase
      endfunction
 

   // The default rule, which fires (every second) only if no other can:
   rule inc_sec;
      secs <= secs + 1;
   endrule: inc_sec
   
//-------------------------------------------------------------------------------------
//-------------------------------PEDON LIGHT STATES------------------------------------
//-------------------------------------------------------------------------------------
   
   (* preempts = "fromGreenPed, inc_sec" *)
   rule fromGreenPed (state == AllRed && ped == GreenPed && secs + 1 >= ped_green_delay);
   
      ped <= AmberPed;
      secs <= 0;

   endrule: fromGreenPed


   (* preempts = "fromAmberPed, inc_sec" *)
   rule fromAmberPed (state == AllRed && ped == AmberPed && secs + 1 >= ped_amber_delay);
   
      ped <= RedPed;
      next_state(AllRed);

   
   endrule: fromAmberPed

   
   (* preempts = "fromRedPed, inc_sec" *)
   rule fromRedPed (state == AllRed && ped == RedIntermediatePed && secs + 1 >= allRedDelay);
   
      next_state(next_green);
      ped <= RedPed;
      
   endrule: fromRedPed

//-------------------------------------------------------------------------------------
//----------------------------CAR LIGHT STATES-----------------------------------------
//-------------------------------------------------------------------------------------

   //Rule handling the Red state
   (* preempts = "fromAllRed, inc_sec" *)
   rule fromAllRed (state == AllRed && ped == RedPed && secs + 1 >= allRedDelay);

      if (ped_request)
         action
            ped_request <= False;
            ped <= GreenPed;
            next_state(AllRed);
         endaction
      else if (car_present(next_green))
         next_state(next_green);
      else if (car_present(green_seq(next_green)))
         next_state(green_seq(next_green));
      else if (car_present(green_seq(green_seq(next_green))))
         next_state(green_seq(green_seq(next_green)));
      else
         noAction;
   endrule: fromAllRed
   
   (* preempts = "fromGreenNS, inc_sec" *)
   rule fromGreenNS (state == GreenNS && secs + 1 >= ns_green_delay);
      next_state(AmberNS);
   endrule: fromGreenNS

   (* preempts = "fromAmberNS, inc_sec" *)
   rule fromAmberNS (state == AmberNS && secs + 1 >= amberDelay);
      next_state(AllRed);
      next_green <= GreenE;
   endrule: fromAmberNS

   (* preempts = "fromGreenE, inc_sec" *)
   rule fromGreenE (state == GreenE && secs + 1 >= ew_green_delay);
      next_state(AmberE);
   endrule: fromGreenE

   (* preempts = "fromAmberE, inc_sec" *)
   rule fromAmberE (state == AmberE && secs + 1 >= amberDelay);
      next_state(AllRed);
      next_green <= GreenW;
   endrule: fromAmberE

   (* preempts = "fromGreenW, inc_sec" *)
   rule fromGreenW (state == GreenW && secs + 1 >= ew_green_delay);
      next_state(AmberW);
   endrule: fromGreenW

   (* preempts = "fromAmberW, inc_sec" *)
   rule fromAmberW (state == AmberW && secs + 1 >= amberDelay);
      next_state(AllRed);
      next_green <= GreenNS;
   endrule: fromAmberW

   method lampRedNS() = (!(state == GreenNS || state == AmberNS));
   method lampAmberNS() = (state == AmberNS);
   method lampGreenNS() = (state == GreenNS);
   method lampRedE() = (!(state == GreenE || state == AmberE));
   method lampAmberE() = (state == AmberE);
   method lampGreenE() = (state == GreenE);
   method lampRedW() = (!(state == GreenW || state == AmberW));
   method lampAmberW() = (state == AmberW);
   method lampGreenW() = (state == GreenW);
   method lampRedPed() = (ped == RedPed || ped == RedIntermediatePed);
   method lampAmberPed() = (ped == AmberPed);
   method lampGreenPed() = (ped == GreenPed);

   method Action set_car_state_N(value); car_sensorN <= value; endmethod
   method Action set_car_state_S(value); car_sensorS <= value; endmethod
   method Action set_car_state_W(value); car_sensorE <= value; endmethod
   method Action set_car_state_E(value); car_sensorW <= value; endmethod


   method Action requestPedestrian();
      ped_request <= True; 
   endmethod

endmodule: sysTL

endpackage
