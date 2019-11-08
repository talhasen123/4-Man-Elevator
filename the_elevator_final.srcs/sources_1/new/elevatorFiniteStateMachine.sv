`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.12.2018 22:41:34
// Design Name: 
// Module Name: elevatorFiniteStateMachine
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module elevatorFiniteStateMachine( input logic resetTimer, systemReset, executeScenario, clk_in,
                                   output logic [3:0] an,
                                   output logic a, b, c, d, e, f, g, dp, scenarioRunning,
                                   // FPGA pins for 8x8 display
                                   output reset_out, //shift register's reset
                                   output OE,     //output enable, active low 
                                   output SH_CP,  //pulse to the shift register
                                   output ST_CP,  //pulse to store shift register
                                   output DS,     //shift register's serial input data
                                   output [7:0] col_select, // active column, active high
                                   output [3:0] keyb_row,
                                   input  [3:0] keyb_col
                                  );
   logic [2:0] elevator;
   logic [3:0] floor1Passengers;
   logic [3:0] floor2Passengers;
   logic [3:0] floor3Passengers;
   logic [3:0] currentTimeState;
   logic floor1HasPassengers, floor2HasPassengers, floor3HasPassengers;
   logic [2:0] col_num;
   logic [0:7] [7:0] image_red;
   logic [0:7] [7:0]  image_green = 
   {8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000};
   logic [0:7] [7:0]  image_blue;
   logic [3:0] key_value;
   logic key_valid;
    logic [3:0] segment1Number;
    logic [3:0] segment2Number;
    logic [3:0] segment3Number;
    logic [3:0] segmentShifted = {4'b1010};
    logic [3:0] newSegmentShifted;
    logic [1:0] direction;
    logic clk_timer, clk_shift;
    
    ClockDivider1Second counterTimeDivider(clk_in, clk_timer);
    ClockDividerQuarterSecond shiftClock(clk_in, clk_shift);
    scenario scene(systemReset, executeScenario, clk_in, key_valid, key_value,
                   elevator, floor1Passengers, floor2Passengers, floor3Passengers, currentTimeState, direction, scenarioRunning, floor1HasPassengers, floor2HasPassengers, floor3HasPassengers);    
    timerCounter timeCount( segment1Number, segment2Number, segment3Number, resetTimer, systemReset, scenarioRunning, clk_timer);
    SevSeg_4digit mySevSeg( clk_in, segment3Number, segment2Number, segment1Number, segmentShifted, a, b, c, d, e, f, g, dp, an);
    directionDisplay( segmentShifted, direction, resetTimer, systemReset, scenarioRunning, clk_shift, newSegmentShifted);
    redAndBlueLights lightController( elevator, floor1Passengers, floor2Passengers, floor3Passengers, currentTimeState, image_red, image_blue);
    keypad4X4 keypad4X4_inst0(
        .clk(clk_in),
        .keyb_row(keyb_row), // just connect them to FPGA pins, row scanner
        .keyb_col(keyb_col), // just connect them to FPGA pins, column scanner
        .key_value(key_value), //user's output code for detected pressed key: row[1:0]_col[1:0]
        .key_valid(key_valid)  // user's output valid: if the key is pressed long enough (more than 20~40 ms), key_valid becomes '1' for just one clock cycle.
    );
    display_8x8 display_8x8_0(
        .clk(clk_in),
        
        // RGB data for display current column
        .red_vect_in(image_red[col_num]),
        .green_vect_in(image_green[col_num]),
        .blue_vect_in(image_blue[col_num]),
        
        .col_data_capture(), // unused
        .col_num(col_num),
        
        // FPGA pins for display
        .reset_out(reset_out),
        .OE(OE),
        .SH_CP(SH_CP),
        .ST_CP(ST_CP),
        .DS(DS),
        .col_select(col_select)   
    ); 
    
    always_ff @(posedge clk_shift)
        segmentShifted <= newSegmentShifted;
    
endmodule


module directionDisplay( input logic [3:0] segmentShifted,
                         input logic [1:0] direction, 
                         input logic resetTimer, systemReset, scenarioRunning, clk_shift,
                         output logic [3:0] newSegmentShifted
                        );
    always_ff @(posedge clk_shift)
        if ( systemReset == 1 | resetTimer == 1) newSegmentShifted <= 4'b1010;
        else if ( scenarioRunning == 0 ) newSegmentShifted <= segmentShifted;
        else
        begin
            if ( direction == 2'b00) 
            begin
                if ( segmentShifted < 4'b1111) newSegmentShifted <= segmentShifted + 1;
                else newSegmentShifted <= 4'b1010;
            end
            else if ( direction == 2'b01) newSegmentShifted <= segmentShifted;
            else if ( direction == 2'b10)
            begin
                if ( segmentShifted > 4'b1010) newSegmentShifted <= segmentShifted - 1;
                else newSegmentShifted <= 4'b1111;
            end
        end
endmodule

module timerCounter(input reg [3:0] segment3Number,
                    input reg [3:0] segment2Number,
                    input reg [3:0] segment1Number,
                    input logic resetTimer, systemReset, scenarioRunning, clk_timer
                    );

    always_ff @( posedge clk_timer)
        if ( systemReset == 1 || resetTimer == 1)
            begin
                segment1Number <= 4'b0000;
                segment2Number <= 4'b0000;
                segment3Number <= 4'b0000;
            end
        else if ( scenarioRunning == 1)
            begin
                segment1Number <= segment1Number + 4'b0001;
                if ( segment1Number == 4'b1001)
                    begin
                        segment2Number <= segment2Number + 4'b0001;
                        segment1Number <= 4'b0000;
                    end   
                if ( segment1Number == 4'b1001 & segment2Number == 4'b1001)
                    begin
                        segment3Number <= segment3Number + 4'b0001;
                        segment2Number <= 4'b0000;
                    end
            end
        else
            begin
                segment1Number <= segment1Number;
                segment2Number <= segment2Number;
                segment3Number <= segment3Number;
            end
endmodule



module scenario(input logic systemReset, start, clk_in, key_valid, 
                input logic [3:0] key_value,
                output logic [2:0] elevator,
                output logic [3:0] floor1Passengers,
                output logic [3:0] floor2Passengers,
                output logic [3:0] floor3Passengers,
                output logic [3:0] currentTimeState,
                output logic [1:0] direction,
                output logic scenarioRunning, floor1HasPassengers, floor2HasPassengers, floor3HasPassengers
                );
    logic[3:0] newFloor1Passengers;
    logic[3:0] newFloor2Passengers;
    logic[3:0] newFloor3Passengers;
    logic[2:0] newElevator1;
    logic[2:0] newElevator2;
    logic[2:0] newElevator3;
    logic[3:0] nextTimeState;
    logic increment1, decrement1, increment2, decrement2, increment3, decrement3;
    logic newIncrement1, newDecrement1, newIncrement2, newDecrement2, newIncrement3, newDecrement3;
    logic clk_out, travelling;
    logic finish;
    
    isScenarioStillRunning isScenarioRunning( systemReset, start, finish, clk_in, scenarioRunning);
    assign finish = (~floor1HasPassengers&~floor2HasPassengers&~floor3HasPassengers)&(currentTimeState == 4'b0000);
    
    floor1 floor1Controller(elevator, floor1Passengers, currentTimeState, key_value, scenarioRunning, clk_in, key_valid, newElevator1, newFloor1Passengers, floor1HasPassengers);
    floor2 floor2Controller(elevator, floor2Passengers, currentTimeState, key_value, scenarioRunning, clk_in, key_valid, newElevator2, newFloor2Passengers, floor2HasPassengers);
    floor3 floor3Controller(elevator, floor3Passengers, currentTimeState, key_value, scenarioRunning, clk_in, key_valid, newElevator3, newFloor3Passengers, floor3HasPassengers);
      
    timingDecoder timeDecoder( floor3HasPassengers, floor2HasPassengers, floor1HasPassengers, elevator[2], currentTimeState, nextTimeState, direction, travelling);    
    ClockDivider2Or3 clockDivider( clk_in, travelling, scenarioRunning, clk_out);
    
    always_ff @(posedge clk_out)
    begin
         if ( systemReset == 1)
            begin
                elevator <= 3'b000;
                floor1Passengers <= 4'b0000;
                floor2Passengers <= 4'b0000;
                floor3Passengers <= 4'b0000;
                currentTimeState <= 4'b0000;
            end          
        else
        begin    
            if ( currentTimeState == 4'b1001) 
                elevator <= 3'b000;       
            else if ( currentTimeState == 4'b0001) 
                elevator <= newElevator1;
            else if ( currentTimeState == 4'b0011) 
                elevator <= newElevator2;
            else if ( currentTimeState == 4'b0101)
                elevator <= newElevator3;      
            
            floor1Passengers <= newFloor1Passengers;
            floor2Passengers <= newFloor2Passengers;
            floor3Passengers <= newFloor3Passengers;
            currentTimeState <= nextTimeState;
        end
    end        
endmodule        


module isScenarioStillRunning(input logic systemReset, start, finish, clk_in,
                              output logic scenarioRunning);

    always @(*)
        if ( systemReset == 1) scenarioRunning <= 0;
        else if ( scenarioRunning == 1 & finish == 1) scenarioRunning <= 0;
        else if ( start == 1 || (start == 0 & finish == 0) ) scenarioRunning <= 1;      
endmodule 


                   

module floor1(input logic [2:0] elevator,
             input logic [3:0] floorPassengers,
             input logic [3:0] currentState,
             input logic [3:0] key_value,
             input logic  scenarioRunning, clk_in, key_valid,
             output logic [2:0] newElevator,
             output logic [3:0] newFloorPassengers,
             output logic floorHasPassengers
             );
    logic [3:0] newFloorPassengersIncremented;
    logic [3:0] newFloorPassengersDecremented;
    logic [3:0] newFloorPassengersChanged;
    
    passengerIncrementer incrementer(floorPassengers, scenarioRunning, clk_in, newFloorPassengersIncremented);
    passengerDecrementer decrementer(floorPassengers, scenarioRunning, clk_in, newFloorPassengersDecremented);
    floor1PassengersChanger change(elevator, floorPassengers, currentState, scenarioRunning, clk_in, newElevator, newFloorPassengersChanged, floorHasPassengers);    
    
    always @(*)       
       if ( scenarioRunning == 0 & key_valid == 1'b1 & key_value == 4'b0100)
           newFloorPassengers <= newFloorPassengersIncremented;
       else if ( scenarioRunning == 0 & key_valid == 1'b1 & key_value == 4'b0101)
          newFloorPassengers <= newFloorPassengersDecremented;
       else newFloorPassengers <= newFloorPassengersChanged;   
           
endmodule



module floor2(input logic [2:0] elevator,
             input logic [3:0] floorPassengers,
             input logic [3:0] currentState,
             input logic [3:0] key_value,
             input logic  scenarioRunning, clk_in, key_valid,
             output logic [2:0] newElevator,
             output logic [3:0] newFloorPassengers,
             output logic floorHasPassengers
             );
    
   logic [3:0] newFloorPassengersIncremented;
   logic [3:0] newFloorPassengersDecremented;
    logic [3:0] newFloorPassengersChanged;
                 
   passengerIncrementer incrementer(floorPassengers, scenarioRunning, clk_in, newFloorPassengersIncremented);
   passengerDecrementer decrementer(floorPassengers, scenarioRunning, clk_in, newFloorPassengersDecremented);
    floor2PassengersChanger change(elevator, floorPassengers, currentState, scenarioRunning, clk_in, newElevator, newFloorPassengersChanged, floorHasPassengers);    
                 
    always @(*)       
      if ( scenarioRunning == 0 & key_valid == 1'b1 & key_value == 4'b1000)
          newFloorPassengers <= newFloorPassengersIncremented;
      else if ( scenarioRunning == 0 & key_valid == 1'b1 & key_value == 4'b1001)
          newFloorPassengers <= newFloorPassengersDecremented;
      else  newFloorPassengers <= newFloorPassengersChanged;   
    
endmodule

module floor3(input logic [2:0] elevator,
             input logic [3:0] floorPassengers,
             input logic [3:0] currentState,
             input logic [3:0] key_value,
             input logic  scenarioRunning, clk_in, key_valid,
             output logic [2:0] newElevator,
             output logic [3:0] newFloorPassengers,
             output logic floorHasPassengers
             );
    
    logic [3:0] newFloorPassengersIncremented;
    logic [3:0] newFloorPassengersDecremented;
    logic [3:0] newFloorPassengersChanged;
                 
    passengerIncrementer incrementer(floorPassengers, scenarioRunning, clk_in, newFloorPassengersIncremented);
    passengerDecrementer decrementer(floorPassengers, scenarioRunning, clk_in, newFloorPassengersDecremented);
    floor3PassengersChanger change(elevator, floorPassengers, currentState, scenarioRunning, clk_in, newElevator, newFloorPassengersChanged, floorHasPassengers);          
    
    always @(*)       
      if ( scenarioRunning == 0 & key_valid == 1'b1 & key_value == 4'b1100)
          newFloorPassengers <= newFloorPassengersIncremented;
      else if ( scenarioRunning == 0 & key_valid == 1'b1 & key_value == 4'b1101)
          newFloorPassengers <= newFloorPassengersDecremented;
      else newFloorPassengers <= newFloorPassengersChanged;   
endmodule


module floor1PassengersChanger(input logic [2:0] elevator,
                              input logic [3:0] floorPassengers,
                              input logic [3:0] currentState,
                              input logic scenarioRunning, clk_in,
                              output logic [2:0] newElevator,
                              output logic [3:0] newFloorPassengers,
                              output logic floorHasPassengers
                              );

    logic [2:0] noOfSpaceInElevator;
    assign noOfSpaceInElevator = 3'b100 - elevator;
    always @(*)
        if ( scenarioRunning == 1)
        begin
            if ( currentState == 4'b0001)
            begin
                if ( floorPassengers >= 4'b0100)
                begin
                    newFloorPassengers <= floorPassengers - noOfSpaceInElevator;
                    newElevator <= 3'b100;
                end    
                else
                begin
                    if ( noOfSpaceInElevator < floorPassengers)
                    begin
                        newElevator <= 3'b100;
                        newFloorPassengers <= floorPassengers - noOfSpaceInElevator;
                    end
                    else
                    begin
                        newElevator <= elevator + floorPassengers;
                        newFloorPassengers <= 4'b0000;
                    end
                end
            end
            
            else
            begin
                newElevator <= elevator;
                newFloorPassengers <= floorPassengers;
            end
            
            if ( floorPassengers > 0) floorHasPassengers <= 1'b1;
            else floorHasPassengers <= 1'b0;
            
        end   
        
        else
        begin
            newElevator <= 3'b000;
            newFloorPassengers <= floorPassengers;
            floorHasPassengers <= 1'b0;
        end         
endmodule

module floor2PassengersChanger(input logic [2:0] elevator,
                              input logic [3:0] floorPassengers,
                              input logic [3:0] currentState,
                              input logic scenarioRunning, clk_in,
                              output logic [2:0] newElevator,
                              output logic [3:0] newFloorPassengers,
                              output logic floorHasPassengers
                              );

    logic [2:0] noOfSpaceInElevator;
    assign noOfSpaceInElevator = 3'b100 - elevator;
     always @(*)
           if ( scenarioRunning == 1)
           begin               
               if ( currentState == 4'b0011)
               begin
                   if ( floorPassengers >= 4'b0100)
                   begin
                       newFloorPassengers <= floorPassengers - noOfSpaceInElevator;
                       newElevator <= 3'b100;
                       floorHasPassengers <= 1'b1;
                   end    
                   else
                   begin
                       if ( noOfSpaceInElevator < floorPassengers)
                       begin
                           newElevator <= 3'b100;
                           newFloorPassengers <= floorPassengers - noOfSpaceInElevator;
                           floorHasPassengers <= 1'b1;
                       end
                       else
                       begin
                           newElevator <= elevator + floorPassengers;
                           newFloorPassengers <= 4'b0000;
                           floorHasPassengers <= 1'b0;
                       end
                   end
               end
               
               else
               begin
                   newElevator <= elevator;
                   newFloorPassengers <= floorPassengers;
               end
               
               if ( floorPassengers > 0) floorHasPassengers <= 1'b1;
               else floorHasPassengers <= 1'b0;
               
           end   
           
           else
           begin
               newElevator <= 3'b000;
               newFloorPassengers <= floorPassengers;
               floorHasPassengers <= 1'b0;
           end  
endmodule


module floor3PassengersChanger(input logic [2:0] elevator,
                              input logic [3:0] floorPassengers,
                              input logic [3:0] currentState,
                              input logic  scenarioRunning, clk_in,
                              output logic [2:0] newElevator,
                              output logic [3:0] newFloorPassengers,
                              output logic floorHasPassengers
                              );

    logic [2:0] noOfSpaceInElevator;
    assign noOfSpaceInElevator = 3'b100 - elevator;
     always @(*)
           if ( scenarioRunning == 1)
           begin               
               if ( currentState == 4'b0101)
               begin
                   if ( floorPassengers >= 4'b0100)
                   begin
                       newFloorPassengers <= floorPassengers - noOfSpaceInElevator;
                       newElevator <= 3'b100;
                       floorHasPassengers <= 1'b1;
                   end    
                   else
                   begin
                       if ( noOfSpaceInElevator < floorPassengers)
                       begin
                           newElevator <= 3'b100;
                           newFloorPassengers <= floorPassengers - noOfSpaceInElevator;
                           floorHasPassengers <= 1'b1;
                       end
                       else
                       begin
                           newElevator <= elevator + floorPassengers;
                           newFloorPassengers <= 4'b0000;
                           floorHasPassengers <= 1'b0;
                       end
                   end
               end
               
               else
               begin
                   newElevator <= elevator;
                   newFloorPassengers <= floorPassengers;
               end
               
               if ( floorPassengers > 0) floorHasPassengers <= 1'b1;
               else floorHasPassengers <= 1'b0;
               
           end   
           
           else
           begin
               newElevator <= 3'b000;
               newFloorPassengers <= floorPassengers;
               floorHasPassengers <= 1'b0;
           end  
endmodule




module timingDecoder(input logic f3, f2, f1, elHead,
                     input logic [3:0] currentState,
                     output logic [3:0] nextState,
                     output logic [1:0] direction,
                     output logic travelling
                     );
    always_comb
        casez( { currentState, elHead, f3, f2, f1} )
            8'b0000?000: nextState <= 4'b0000;
            8'b0000???1: nextState <= 4'b0001;
            8'b0000??1?: nextState <= 4'b0001;
            8'b0000?1??: nextState <= 4'b0001;
            8'b0001???1: nextState <= 4'b0010;
            8'b0001?1?0: nextState <= 4'b0011;
            8'b0001??10: nextState <= 4'b0011;
            8'b00101???: nextState <= 4'b1001;
            8'b0010?00?: nextState <= 4'b1001;
            8'b001001??: nextState <= 4'b0011;
            8'b00100?1?: nextState <= 4'b0011;
            8'b0011??1?: nextState <= 4'b0100;
            8'b0011?10?: nextState <= 4'b0101;
            8'b01001???: nextState <= 4'b1000;
            8'b0100?0??: nextState <= 4'b1000;
            8'b010001??: nextState <= 4'b0101;
            8'b0101????: nextState <= 4'b0110;
            8'b0110????: nextState <= 4'b0111;
            8'b0111????: nextState <= 4'b1000;
            8'b1000????: nextState <= 4'b1001;
            8'b1001????: nextState <= 4'b0000;
            default: nextState <= 4'b0000;
        endcase
    
    assign travelling = currentState[3] | currentState[0];
    assign direction[0] = (~currentState[3] & ~currentState[0]) | (~currentState[3] & currentState[2] & currentState[1]) | (currentState[3] & currentState[2] & currentState[1]);
    assign direction[1] = (currentState[3] & ~currentState[2] & ~currentState[1]) | (~currentState[3] & currentState[2] & currentState[1] & currentState[0]);
endmodule





module passengerIncrementer(input logic [3:0] floorPassenger, 
                            input logic scenarioRunning, clk_in,
                            output logic [3:0] newFloorPassenger
                            );
    always @(*)
        if ( scenarioRunning == 0 & floorPassenger < 4'b1011) newFloorPassenger <= floorPassenger + 4'b0001;
endmodule







module passengerDecrementer(input logic [3:0] floorPassenger, 
                          input logic scenarioRunning, clk_in,
                          output logic [3:0] newFloorPassenger
                          );
    always @(*)
        if ( scenarioRunning == 0 & floorPassenger > 4'b0000) newFloorPassenger <= floorPassenger - 4'b0001;
endmodule



module ClockDivider2Or3(
 input logic clk_in, travelling, scenarioRunning,
 output logic clk_out
 );

logic [28:0] count1 = {29{1'b0}};
logic [28:0] count2 = {29{1'b0}};
logic [1:0] count3 = {2{1'b0}};
always @(posedge clk_in)
    if ( scenarioRunning == 1)
    begin
        if (travelling == 1)
            begin
                if ( count1 < 29'b10001111000011010001100000000) count1 <= count1 + 1;
                else count1 <= 0;
                clk_out <= ( count1 == 29'b10001111000011010001100000000);
            end
        else
            begin
                if ( count2 < 29'b01011111010111100001000000000) count2 <= count2 + 1;
                else count2 <= 0;
                clk_out <= ( count2 == 29'b01011111010111100001000000000);
            end
    end
    else
       begin
            if ( count3 < 2'b11) count3 <= count3 + 1;
            else count3 <= 0;
            clk_out <= (count3 == 2'b11);
        end 
       
endmodule

module ClockDivider1Second(
 input logic clk_in,
 output logic clk_out
 );

logic [28:0] count = {29{1'b0}};
always @(posedge clk_in)
    begin
        if (count < 29'b00101111101011110000100000000) count <= count + 1;
        else count <= 0;
    end
    assign clk_out = ( count == 29'b00101111101011110000100000000);
       
endmodule


module ClockDividerQuarterSecond(
 input logic clk_in,
 output logic clk_out
 );

logic [24:0] count = {25{1'b0}};
always @(posedge clk_in)
    begin
        if (count < 25'b1011111010111100001000000) count <= count + 1;
        else count <= 0;
    end
    assign clk_out = ( count == 25'b1011111010111100001000000);
       
endmodule



module redAndBlueLights( input logic [2:0] elevator,
                         input logic [3:0] floor1Passengers,
                         input logic [3:0] floor2Passengers,
                         input logic [3:0] floor3Passengers,
                         input logic [3:0] currentState,
                         output logic [0:7] [7:0] redLights,
                         output logic [0:7] [7:0] blueLights
                         );
    always_comb
    begin
        blueLights = {8'b0, 8'b0, 8'b0, 8'b0, 8'b0, 8'b0, 8'b0, 8'b0};
        redLights = {8'b0, 8'b0, 8'b0, 8'b0, 8'b0, 8'b0, 8'b0, 8'b0};
        
        if ( currentState == 4'b1001)
        begin
             if ( elevator == 3'b000) begin
                 blueLights[0][0] = 1; blueLights[0][1] = 1; blueLights[1][0] = 1; blueLights[1][1] = 1;  
             end
             else if ( elevator == 3'b001) begin
                 blueLights[0][0] = 1; redLights[0][1] = 1; blueLights[1][0] = 1; blueLights[1][1] = 1;
             end
             else if ( elevator == 3'b010) begin
                 blueLights[0][0] = 1; redLights[0][1] = 1; blueLights[1][0] = 1; redLights[1][1] = 1;
             end
             else if ( elevator == 3'b011) begin
                 redLights[0][0] = 1; redLights[0][1] = 1; blueLights[1][0] = 1; redLights[1][1] = 1;
             end
             else begin
                 redLights[0][0] = 1; redLights[0][1] = 1; redLights[1][0] = 1; redLights[1][1] = 1;
             end
        end
        else if ( currentState == 4'b0000)
        begin
             if ( elevator == 3'b000) begin
                 blueLights[0][0] = 1; blueLights[0][1] = 1; blueLights[1][0] = 1; blueLights[1][1] = 1;  
             end
             else if ( elevator == 3'b001) begin
                 blueLights[0][0] = 1; redLights[0][1] = 1; blueLights[1][0] = 1; blueLights[1][1] = 1;
             end
             else if ( elevator == 3'b010) begin
                 blueLights[0][0] = 1; redLights[0][1] = 1; blueLights[1][0] = 1; redLights[1][1] = 1;
             end
             else if ( elevator == 3'b011) begin
                 redLights[0][0] = 1; redLights[0][1] = 1; blueLights[1][0] = 1; redLights[1][1] = 1;
             end
             else begin
                 redLights[0][0] = 1; redLights[0][1] = 1; redLights[1][0] = 1; redLights[1][1] = 1;
             end
        end 
        else if ( currentState == 4'b0001)
        begin
             if ( elevator == 3'b000) begin
                 blueLights[0][2] = 1; blueLights[0][3] = 1; blueLights[1][2] = 1; blueLights[1][3] = 1;  
             end
             else if ( elevator == 3'b001) begin
                 blueLights[0][2] = 1; redLights[0][3] = 1; blueLights[1][2] = 1; blueLights[1][3] = 1;
             end
             else if ( elevator == 3'b010) begin
                 blueLights[0][2] = 1; redLights[0][3] = 1; blueLights[1][2] = 1; redLights[1][3] = 1;
             end
             else if ( elevator == 3'b011) begin
                 redLights[0][2] = 1; redLights[0][3] = 1; blueLights[1][2] = 1; redLights[1][3] = 1;
             end
             else begin
                 redLights[0][2] = 1; redLights[0][3] = 1; redLights[1][2] = 1; redLights[1][3] = 1;
             end
        end
        else if ( currentState == 4'b0010 | currentState == 4'b1000)
        begin
            if ( elevator == 3'b000) begin
                blueLights[0][2] = 1; blueLights[0][3] = 1; blueLights[1][2] = 1; blueLights[1][3] = 1;  
            end
            else if ( elevator == 3'b001) begin
                blueLights[0][2] = 1; redLights[0][3] = 1; blueLights[1][2] = 1; blueLights[1][3] = 1;
            end
            else if ( elevator == 3'b010) begin
                blueLights[0][2] = 1; redLights[0][3] = 1; blueLights[1][2] = 1; redLights[1][3] = 1;
            end
            else if ( elevator == 3'b011) begin
                redLights[0][2] = 1; redLights[0][3] = 1; blueLights[1][2] = 1; redLights[1][3] = 1;
            end
            else begin
                redLights[0][2] = 1; redLights[0][3] = 1; redLights[1][2] = 1; redLights[1][3] = 1;
            end
        end
        else if ( currentState == 4'b0011 | currentState == 4'b0111)
        begin
             if ( elevator == 3'b000) begin
                 blueLights[0][4] = 1; blueLights[0][5] = 1; blueLights[1][4] = 1; blueLights[1][5] = 1;  
             end
             else if ( elevator == 3'b001) begin
                 blueLights[0][4] = 1; redLights[0][5] = 1; blueLights[1][4] = 1; blueLights[1][5] = 1;
             end
             else if ( elevator == 3'b010) begin
                 blueLights[0][4] = 1; redLights[0][5] = 1; blueLights[1][4] = 1; redLights[1][5] = 1;
             end
             else if ( elevator == 3'b011) begin
                 redLights[0][4] = 1; redLights[0][5] = 1; blueLights[1][4] = 1; redLights[1][5] = 1;
             end
             else begin
                 redLights[0][4] = 1; redLights[0][5] = 1; redLights[1][4] = 1; redLights[1][5] = 1;
             end
        end
        else if ( currentState == 4'b0100)
        begin
             if ( elevator == 3'b000) begin
                 blueLights[0][4] = 1; blueLights[0][5] = 1; blueLights[1][4] = 1; blueLights[1][5] = 1;  
             end
             else if ( elevator == 3'b001) begin
                 blueLights[0][4] = 1; redLights[0][5] = 1; blueLights[1][4] = 1; blueLights[1][5] = 1;
             end
             else if ( elevator == 3'b010) begin
                 blueLights[0][4] = 1; redLights[0][5] = 1; blueLights[1][4] = 1; redLights[1][5] = 1;
             end
             else if ( elevator == 3'b011) begin
                 redLights[0][4] = 1; redLights[0][5] = 1; blueLights[1][4] = 1; redLights[1][5] = 1;
             end
             else begin
                 redLights[0][4] = 1; redLights[0][5] = 1; redLights[1][4] = 1; redLights[1][5] = 1;
             end
        end
        else if ( currentState == 4'b0101)
        begin
             if ( elevator == 3'b000) begin
                 blueLights[0][6] = 1; blueLights[0][7] = 1; blueLights[1][6] = 1; blueLights[1][7] = 1;  
             end
             else if ( elevator == 3'b001) begin
                 blueLights[0][6] = 1; redLights[0][7] = 1; blueLights[1][6] = 1; blueLights[1][7] = 1;
             end
             else if ( elevator == 3'b010) begin
                 blueLights[0][6] = 1; redLights[0][7] = 1; blueLights[1][6] = 1; redLights[1][7] = 1;
             end
             else if ( elevator == 3'b011) begin
                 redLights[0][6] = 1; redLights[0][7] = 1; blueLights[1][6] = 1; redLights[1][7] = 1;
             end
             else begin
                 redLights[0][6] = 1; redLights[0][7] = 1; redLights[1][6] = 1; redLights[1][7] = 1;
             end
        end
        else if ( currentState == 4'b0110)
        begin
             if ( elevator == 3'b000) begin
                 blueLights[0][6] = 1; blueLights[0][7] = 1; blueLights[1][6] = 1; blueLights[1][7] = 1;  
             end
             else if ( elevator == 3'b001) begin
                 blueLights[0][6] = 1; redLights[0][7] = 1; blueLights[1][6] = 1; blueLights[1][7] = 1;
             end
             else if ( elevator == 3'b010) begin
                 blueLights[0][6] = 1; redLights[0][7] = 1; blueLights[1][6] = 1; redLights[1][7] = 1;
             end
             else if ( elevator == 3'b011) begin
                 redLights[0][6] = 1; redLights[0][7] = 1; blueLights[1][6] = 1; redLights[1][7] = 1;
             end
             else begin
                 redLights[0][6] = 1; redLights[0][7] = 1; redLights[1][6] = 1; redLights[1][7] = 1;
             end
        end
        
        
        
        if ( floor1Passengers == 4'b0001)
        begin
            redLights[2][3] = 1;
        end
        else if ( floor1Passengers == 4'b0010)
        begin
            redLights[2][3] = 1; redLights[2][2] = 1;   
        end
        else if ( floor1Passengers == 4'b0011)
        begin
            redLights[2][3] = 1; redLights[2][2] = 1; redLights[3][3] = 1; 
        end
        else if ( floor1Passengers == 4'b0100)
        begin
            redLights[2][3] = 1; redLights[2][2] = 1; redLights[3][3] = 1; redLights[3][2] = 1; 
        end
        else if ( floor1Passengers == 4'b0101)
        begin
            redLights[2][3] = 1; redLights[2][2] = 1; redLights[3][3] = 1; redLights[3][2] = 1; redLights[4][3] = 1; 
        end
        else if ( floor1Passengers == 4'b0110)
        begin
            redLights[2][3] = 1; redLights[2][2] = 1; redLights[3][3] = 1; redLights[3][2] = 1; redLights[4][3] = 1; redLights[4][2] = 1; 
        end
        else if ( floor1Passengers == 4'b0111)
        begin
            redLights[2][3] = 1; redLights[2][2] = 1; redLights[3][3] = 1; redLights[3][2] = 1; redLights[4][3] = 1; redLights[4][2] = 1; 
            redLights[5][3] = 1; 
        end
        else if ( floor1Passengers == 4'b1000)
        begin
            redLights[2][3] = 1; redLights[2][2] = 1; redLights[3][3] = 1; redLights[3][2] = 1; redLights[4][3] = 1; redLights[4][2] = 1; 
            redLights[5][3] = 1; redLights[5][2] = 1;
        end
        else if ( floor1Passengers == 4'b1001)
        begin
            redLights[2][3] = 1; redLights[2][2] = 1; redLights[3][3] = 1; redLights[3][2] = 1; redLights[4][3] = 1; redLights[4][2] = 1; 
            redLights[5][3] = 1; redLights[5][2] = 1; redLights[6][3] = 1;
        end
        else if ( floor1Passengers == 4'b1010)
        begin
            redLights[2][3] = 1; redLights[2][2] = 1; redLights[3][3] = 1; redLights[3][2] = 1; redLights[4][3] = 1; redLights[4][2] = 1; 
            redLights[5][3] = 1; redLights[5][2] = 1; redLights[6][3] = 1; redLights[6][2] = 1;
        end
        else if ( floor1Passengers == 4'b1011)
        begin
            redLights[2][3] = 1; redLights[2][2] = 1; redLights[3][3] = 1; redLights[3][2] = 1; redLights[4][3] = 1; redLights[4][2] = 1; 
            redLights[5][3] = 1; redLights[5][2] = 1; redLights[6][3] = 1; redLights[6][2] = 1; redLights[7][3] = 1;
        end
        else if ( floor1Passengers == 4'b1100)
        begin
            redLights[2][3] = 1; redLights[2][2] = 1; redLights[3][3] = 1; redLights[3][2] = 1; redLights[4][3] = 1; redLights[4][2] = 1; 
            redLights[5][3] = 1; redLights[5][2] = 1; redLights[6][3] = 1; redLights[6][2] = 1; redLights[7][3] = 1; redLights[7][2] = 1;
        end
        ////////////////////////////////////////////////
        ////////////////////////////////////////////////
        if ( floor2Passengers == 4'b0001)
        begin
            redLights[2][5] = 1;
        end
        else if ( floor2Passengers == 4'b0010)
        begin
            redLights[2][5] = 1; redLights[2][4] = 1;    
        end
        else if ( floor2Passengers == 4'b0011)
        begin
            redLights[2][5] = 1; redLights[2][4] = 1; redLights[3][5] = 1;    
        end
        else if ( floor2Passengers == 4'b0100)
        begin
            redLights[2][5] = 1; redLights[2][4] = 1; redLights[3][5] = 1; redLights[3][4] = 1;
        end
        else if ( floor2Passengers == 4'b0101)
        begin
            redLights[2][5] = 1; redLights[2][4] = 1; redLights[3][5] = 1; redLights[3][4] = 1; redLights[4][5] = 1;
        end
        else if ( floor2Passengers == 4'b0110)
        begin
            redLights[2][5] = 1; redLights[2][4] = 1; redLights[3][5] = 1; redLights[3][4] = 1; redLights[4][5] = 1; redLights[4][4] = 1; 
        end
        else if ( floor2Passengers == 4'b0111)
        begin
            redLights[2][5] = 1; redLights[2][4] = 1; redLights[3][5] = 1; redLights[3][4] = 1; redLights[4][5] = 1; redLights[4][4] = 1; 
            redLights[5][5] = 1;
        end
        else if ( floor2Passengers == 4'b1000)
        begin
            redLights[2][5] = 1; redLights[2][4] = 1; redLights[3][5] = 1; redLights[3][4] = 1; redLights[4][5] = 1; redLights[4][4] = 1; 
            redLights[5][5] = 1; redLights[5][4] = 1;
        end
        else if ( floor2Passengers == 4'b1001)
        begin
            redLights[2][5] = 1; redLights[2][4] = 1; redLights[3][5] = 1; redLights[3][4] = 1; redLights[4][5] = 1; redLights[4][4] = 1; 
            redLights[5][5] = 1; redLights[5][4] = 1; redLights[6][5] = 1;
        end
        else if ( floor2Passengers == 4'b1010)
        begin
            redLights[2][5] = 1; redLights[2][4] = 1; redLights[3][5] = 1; redLights[3][4] = 1; redLights[4][5] = 1; redLights[4][4] = 1; 
            redLights[5][5] = 1; redLights[5][4] = 1; redLights[6][5] = 1; redLights[6][4] = 1;
        end
        else if ( floor2Passengers == 4'b1011)
        begin
            redLights[2][5] = 1; redLights[2][4] = 1; redLights[3][5] = 1; redLights[3][4] = 1; redLights[4][5] = 1; redLights[4][4] = 1; 
            redLights[5][5] = 1; redLights[5][4] = 1; redLights[6][5] = 1; redLights[6][4] = 1; redLights[7][5] = 1;
        end
        else if ( floor2Passengers == 4'b1100)
        begin
            redLights[2][5] = 1; redLights[2][4] = 1; redLights[3][5] = 1; redLights[3][4] = 1; redLights[4][5] = 1; redLights[4][4] = 1; 
            redLights[5][5] = 1; redLights[5][4] = 1; redLights[6][5] = 1; redLights[6][4] = 1; redLights[7][5] = 1; redLights[7][4] = 1;
        end
        //////////////////////////////////////////
        //////////////////////////////////////////   
        if ( floor3Passengers == 4'b0001)
        begin
            redLights[2][7] = 1;
        end
        else if ( floor3Passengers == 4'b0010)
        begin
            redLights[2][7] = 1; redLights[2][6] = 1;    
        end
        else if ( floor3Passengers == 4'b0011)
        begin
            redLights[2][7] = 1; redLights[2][6] = 1; redLights[3][7] = 1;   
        end
        else if ( floor3Passengers == 4'b0100)
        begin
            redLights[2][7] = 1; redLights[2][6] = 1; redLights[3][7] = 1; redLights[3][6] = 1;
        end
        else if ( floor3Passengers == 4'b0101)
        begin
            redLights[2][7] = 1; redLights[2][6] = 1; redLights[3][7] = 1; redLights[3][6] = 1; redLights[4][7] = 1; 
        end
        else if ( floor3Passengers == 4'b0110)
        begin
            redLights[2][7] = 1; redLights[2][6] = 1; redLights[3][7] = 1; redLights[3][6] = 1; redLights[4][7] = 1; redLights[4][6] = 1; 
        end
        else if ( floor3Passengers == 4'b0111)
        begin
            redLights[2][7] = 1; redLights[2][6] = 1; redLights[3][7] = 1; redLights[3][6] = 1; redLights[4][7] = 1; redLights[4][6] = 1; 
            redLights[5][7] = 1;
        end
        else if ( floor3Passengers == 4'b1000)
        begin
            redLights[2][7] = 1; redLights[2][6] = 1; redLights[3][7] = 1; redLights[3][6] = 1; redLights[4][7] = 1; redLights[4][6] = 1; 
            redLights[5][7] = 1; redLights[5][6] = 1; 
        end
        else if ( floor3Passengers == 4'b1001)
        begin
            redLights[2][7] = 1; redLights[2][6] = 1; redLights[3][7] = 1; redLights[3][6] = 1; redLights[4][7] = 1; redLights[4][6] = 1; 
            redLights[5][7] = 1; redLights[5][6] = 1; redLights[6][7] = 1;  
        end
        else if ( floor3Passengers == 4'b1010)
        begin
            redLights[2][7] = 1; redLights[2][6] = 1; redLights[3][7] = 1; redLights[3][6] = 1; redLights[4][7] = 1; redLights[4][6] = 1; 
            redLights[5][7] = 1; redLights[5][6] = 1; redLights[6][7] = 1; redLights[6][6] = 1;
        end
        else if ( floor3Passengers == 4'b1011)
        begin
            redLights[2][7] = 1; redLights[2][6] = 1; redLights[3][7] = 1; redLights[3][6] = 1; redLights[4][7] = 1; redLights[4][6] = 1; 
            redLights[5][7] = 1; redLights[5][6] = 1; redLights[6][7] = 1; redLights[6][6] = 1; redLights[7][7] = 1; 
        end
        else if ( floor3Passengers == 4'b1100)
        begin
            redLights[2][7] = 1; redLights[2][6] = 1; redLights[3][7] = 1; redLights[3][6] = 1; redLights[4][7] = 1; redLights[4][6] = 1; 
            redLights[5][7] = 1; redLights[5][6] = 1; redLights[6][7] = 1; redLights[6][6] = 1; redLights[7][7] = 1; redLights[7][6] = 1;
        end     
    end                            
endmodule
