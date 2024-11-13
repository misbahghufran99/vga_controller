module vga_adapter(h_sync,v_sync,VGA_R,VGA_G,VGA_B,VGA_BLANK_N,clk50,clk65,reset);

output logic h_sync;
output logic v_sync;
output logic [7:0] VGA_R;
output logic [7:0] VGA_G;
output logic [7:0] VGA_B;
output logic VGA_BLANK_N;
input reset;
input clk50;    //50Mhz system clock
output logic clk65; //65Mhz clock
logic [10:0] h_counter;     //to count till 1344 pixels per line
logic [9:0] v_counter;      // to count 806 lines per frame
logic [19:0] address;
logic [23:0] ram_data_out;
logic [10:0] pixel_x, pixel_y;


    
logic pll_locked;

    // PLL Instance (generated with 50MHz -> 65MHz)
    my_pll pll_inst (
        .refclk   (clk50),   // Reference clock (50MHz)
        .rst      (reset),       // Reset input
        .outclk_0 (clk65), // Output clock (65MHz)
        .locked   (pll_locked)   // PLL locked signal
    );

// Parameters for XGA sync timings
    parameter H_SYNC_PULSE = 136;
    parameter H_BACK_PORCH = 296;   //136+160
    parameter H_ACTIVE_TIME = 1320; //296+1024
    parameter H_FRONT_PORCH = 1344; //1320+24
    parameter V_SYNC_PULSE = 6;
    parameter V_BACK_PORCH = 35;        //6+29
    parameter V_ACTIVE_TIME = 803;  //35+768
    parameter V_FRONT_PORCH = 806;      //803+3

    // State encoding
    typedef enum logic [3:0] {
        H_SYNC_STATE,
        H_BACK_PORCH_STATE,
        H_ACTIVE_STATE,
        H_FRONT_PORCH_STATE,
        V_SYNC_STATE,
        V_BACK_PORCH_STATE,
        V_ACTIVE_STATE,
        V_FRONT_PORCH_STATE
    } state_t;
     
     state_t h_state, v_state;
     
     // Horizontal state transition logic
    always @(posedge clk65 or posedge reset) begin
        if (reset) begin
            h_state <= H_SYNC_STATE;
        end else begin
            case (h_state)
                H_SYNC_STATE: if (h_counter == H_SYNC_PULSE-1) h_state <= H_BACK_PORCH_STATE;
                H_BACK_PORCH_STATE: if (h_counter == H_BACK_PORCH-1) h_state <= H_ACTIVE_STATE;
                H_ACTIVE_STATE: if (h_counter == H_ACTIVE_TIME-1) h_state <= H_FRONT_PORCH_STATE;
                H_FRONT_PORCH_STATE: if (h_counter == H_FRONT_PORCH-1) h_state <= H_SYNC_STATE;
            endcase
        end
    end
     
         // Vertical state transition logic
    always @(posedge clk65 or posedge reset) begin
        if (reset) begin
            v_state <= V_SYNC_STATE;
        end else begin
            case (v_state)
                V_SYNC_STATE: if (v_counter == V_SYNC_PULSE-1) v_state <= V_BACK_PORCH_STATE;
                V_BACK_PORCH_STATE: if (v_counter == V_BACK_PORCH-1) v_state <= V_ACTIVE_STATE;
                V_ACTIVE_STATE: if (v_counter == V_ACTIVE_TIME-1) v_state <= V_FRONT_PORCH_STATE;
                V_FRONT_PORCH_STATE: if (v_counter == V_FRONT_PORCH-1) v_state <= V_SYNC_STATE;
            endcase
        end
    end
     
     //h_counter and v_counter
     always @(posedge clk65 or posedge reset)
     begin
     
    if (reset) begin
     
        h_counter <= 11'b0;
        v_counter <= 10'b0;
          
    end else begin
        // Horizontal counter increment
        if (h_counter == 11'd1343) begin
            h_counter <= 11'd0;
            if (v_counter == 10'd805) begin
                v_counter <= 10'd0;  // Reset vertical counter
            end else begin
                v_counter <= v_counter + 1;  // Increment vertical counter
            end
        end else begin
            h_counter <= h_counter + 1;  // Increment horizontal counter
        end
    end 
     
     end
     
// Sync Signal Generation
always @(posedge clk65) begin
    h_sync <= (h_state == H_SYNC_STATE) ? 0 : 1;
    v_sync <= (v_state == V_SYNC_STATE) ? 0 : 1;
end
     
     //address calculation
     always @(posedge clk65)
     begin
        if (h_state==H_ACTIVE_STATE && v_state==V_ACTIVE_STATE)
            begin
                pixel_x <= h_counter-296;
                pixel_y <= v_counter-35;
                address <= (pixel_x) + (pixel_y * 1024); 
            end
     end
     

always @(posedge clk65) begin
    if (h_state == H_ACTIVE_STATE && v_state == V_ACTIVE_STATE) begin
        // Assign the 24-bit RGB data from RAM to VGA color signals
        VGA_R <= ram_data_out[23:16];  // Upper 8 bits for Red
        VGA_G <= ram_data_out[15:8];   // Middle 8 bits for Green
        VGA_B <= ram_data_out[7:0];    // Lower 8 bits for Blue
          VGA_BLANK_N <= 1'b1;
    end else begin
        // When not in the active video period, output black
        VGA_R <= 8'b0;
        VGA_G <= 8'b0;
        VGA_B <= 8'b0;
          VGA_BLANK_N <= 1'b0;
    end
end


endmodule

`timescale 1ns / 1ps

module tb_vga_adapter();

    // Signals for the VGA controller instance
    logic h_sync;
    logic v_sync;
    logic [7:0] VGA_R;
    logic [7:0] VGA_G;
    logic [7:0] VGA_B;
    logic VGA_BLANK_N;
    logic reset;
    logic clk50;
    logic clk65;

    // Instantiate the VGA controller
    vga_adapter uut (
        .h_sync(h_sync),
        .v_sync(v_sync),
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B),
        .VGA_BLANK_N(VGA_BLANK_N),
        .clk50(clk50),
        .clk65(clk65),
        .reset(reset)
    );

    // Clock generation (50 MHz and 65 MHz signals)
    initial begin
        clk50 = 0;
        forever #10 clk50 = ~clk50; // 50 MHz clock with a period of 20ns
    end

    initial begin
        clk65 = 0;
        forever #7.692 clk65 = ~clk65; // 65 MHz clock with a period of ~15.384ns
    end

    // Testbench variables
    //integer pixel_count;

    // Simulation control signals
    initial begin
        reset = 1;
        #100;
        reset = 0;
    end

    // Monitor signals
    always @(posedge clk65) begin
        $display("h_counter: %d, v_counter: %d, address: %d, VGA_R: %h, VGA_G: %h, VGA_B: %h", uut.h_counter, uut.v_counter, uut.address, uut.VGA_R, uut.VGA_G, uut.VGA_B);
    end

    // Logic for RGB bar generation (dividing screen into 3 columns)
    always @(posedge clk65) begin
        if (uut.v_state == uut.V_ACTIVE_STATE) begin
            // Determine the current pixel column position
            if (uut.pixel_x < 341) begin // First 1/3 of the screen width (for red bar)
                uut.ram_data_out = 24'hFF0000; // Red color (RGB888)
            end else if (uut.pixel_x < 682) begin // Second 1/3 of the screen width (for green bar)
                uut.ram_data_out = 24'h00FF00; // Green color (RGB888)
            end else begin // Last 1/3 of the screen width (for blue bar)
                uut.ram_data_out = 24'h0000FF; // Blue color (RGB888)
            end
        end else begin
            uut.ram_data_out = 24'h000000; // Black (outside of active video period)
        end
    end

    // Stop simulation after a short period (adjust timing as needed for your testing)
    initial begin
        #5000000; // Simulate for a period of time (example: 5ms)
        $stop;
    end

endmodule
