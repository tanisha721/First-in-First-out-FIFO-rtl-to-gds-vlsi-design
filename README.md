# First-in-First-out-FIFO-rtl-to-gds-vlsi-design
This project is a deep dive into the world of Digital VLSI Design. Instead of just writing code that stays on a computer, I’ve taken a FIFO (First-In-First-Out) buffer through the entire industrial pipeline to create a layout ready for a chip factory (GDSII).
## Tools used 
cadance stimulator [waveform generation]
cadance genus [gate level netlist generation]
cadance innovus [physical design]
verilog code [programming language]

## Working and Verilog Code
This code creates a digital waiting room for data. It uses a memory array to store bits until they are ready to be read.

Think of it like a circular pipe:

Pointers: It uses a "Write" and "Read" pointer to track where data goes in and comes out.

Flags: It automatically signals if the pipe is full (stop sending!) or empty (nothing to read).

The Logic: It prevents crashes by ensuring you can't write to a full buffer or read from an empty one.

## Verilog Code 
module fifo #(
    parameter data_width = 8,    // Width of each data word
    parameter data_length = 16   // Number of slots in the FIFO
)
(
    input clk,                   // Global clock
    input rst_n,                 // Active-low asynchronous reset
    input wr_en,                 // Write enable signal
    input rd_en,                 // Read enable signal
    input [data_width-1:0] din,  // Data input bus
    output reg [data_width-1:0] dout, // Data output bus
    output wire empty,           // High when FIFO has no data
    output wire full             // High when FIFO is at max capacity
);

    // Calculate address width based on depth (e.g., 16 slots needs 4 bits)
    localparam ADD_WIDTH = $clog2(data_length);

    // Pointers are 1-bit wider than the address to distinguish between Full and Empty
    reg [ADD_WIDTH:0] wr_ptr; 
    reg [ADD_WIDTH:0] rd_ptr;
    
    // Memory array (Internal Buffer)
    reg [data_width-1:0] mem [0:data_length-1];

    // EMPTY Logic: If pointers are identical, the FIFO is empty
    assign empty = (wr_ptr == rd_ptr);

    // FULL Logic: 
    // Fix: The MSB must be different, but the remaining address bits must be the same.
    assign full = (wr_ptr[ADD_WIDTH] != rd_ptr[ADD_WIDTH]) && 
                  (wr_ptr[ADD_WIDTH-1:0] == rd_ptr[ADD_WIDTH-1:0]);

    // WRITE Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0; // Reset write pointer to start
        end
        else if (wr_en && !full) begin
            // Write data to memory using only the address bits (ignoring the MSB)
            mem[wr_ptr[ADD_WIDTH-1:0]] <= din;
            wr_ptr <= wr_ptr + 1'b1; // Increment pointer
        end
    end

    // READ Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= 0; // Reset read pointer to start
            dout   <= 0;
        end
        else if (rd_en && !empty) begin
            // Fetch data from memory using only the address bits
            dout   <= mem[rd_ptr[ADD_WIDTH-1:0]];
            rd_ptr <= rd_ptr + 1'b1; // Increment pointer
        end 
    end

endmodule

## Verilog Testbench
This testbench acts as a virtual controller that talks to your FIFO module to verify its behavior. I have added comments to explain the clock generation, the reset sequence, and the "for-loops" used to stress-test the memory.
module fifo_tb();

// Parameters: Matching the design settings
localparam data_width = 8;
localparam data_length = 16;

// Signals to drive the FIFO inputs
reg clk;
reg rst_n;
reg wr_en;
reg rd_en;
reg [data_width-1:0] din;

// Wires to observe the FIFO outputs
wire [data_width-1:0] dout;
wire empty;
wire full;

// Instantiate the Device Under Test (DUT)
fifo #(
    .data_width(data_width),
    .data_length(data_length)
) dut (
    .clk(clk), 
    .rst_n(rst_n), 
    .wr_en(wr_en), 
    .rd_en(rd_en), 
    .din(din), 
    .dout(dout), 
    .empty(empty), 
    .full(full)
);

// 1. Clock Generation: Creates a constant heart-beat for the logic
initial begin
    clk = 0;
    forever #5 clk = ~clk; // Toggles every 5 units to create a period of 10
end

integer i;

// 2. Main Stimulus: The step-by-step testing plan
initial begin
    // Initialize everything to zero/inactive
    rst_n = 0;
    wr_en = 0;
    rd_en = 0;
    din = 0;

    // Hold reset for 20ns, then release it
    #20;
    rst_n = 1;
    #10;

    // --- TEST 1: WRITING ---
    $display("Writing to FIFO");
    for(i=0; i<10; i=i+1) begin
        @(posedge clk);        // Wait for the rising edge of the clock
        if(!full) begin        // Logic check: Only send data if FIFO isn't full
            wr_en <= 1;
            din <= i;          // Feed the loop index as data
            $display("%0t ns: WRITE din=%0d, full=%b, empty=%b", $time, i, full, empty);
        end 
        else begin
            wr_en <= 0;
            $display("%0t ns: fifo full cannot write", $time);
        end
    end

    // Turn off write enable after the loop
    @(posedge clk);
    wr_en <= 0;
    din   <= 0;
    #20;

    // --- TEST 2: READING ---
    $display("reading from FIFO");
    for(i=1; i<10; i=i+1) begin
        @(posedge clk);        // Synchronize with the clock
        if(!empty) begin       // Logic check: Only pull data if FIFO has something
            rd_en <= 1;
            // The data 'dout' will appear on the bus after the clock edge
            $display("%0t ns: READ dout=%0d, full=%b, empty=%b", $time, dout, full, empty);
        end
        else begin
            rd_en <= 0;
            $display("%0t ns: fifo is empty cannot read it!", $time);
        end
    end

    // Clean up and finish
    @(posedge clk);
    rd_en <= 0;
    #50;
    $display("simulation ends");
    $stop; // Pauses the simulation for waveform inspection
end

endmodule

## Cadance sdc file 
1. Clock Definition
Defines a 100MHz clock (10ns period) with a 50% duty cycle (rises at 0ns, falls at 5ns)
create_clock -name clk -period 10.0 -waveform {0 5} [get_ports clk]

2. Clock Jitter/Reliability
Accounts for 0.2ns of "uncertainty" (jitter or skew) to give the design some safety margin
set_clock_uncertainty 0.2 [get_clocks clk]

3. Input Delays (Arrival Times)
Tells the tool that data for control and data signals arrives 2ns after the clock edge
This ensures the chip has enough time to "catch" the data before the next beat
set_input_delay 2.0 -clock clk [get_ports {wr_en rd_en}]
set_input_delay 2.0 -clock clk [get_ports din*]

4. Output Delays (Required Times)
Sets a 2ns requirement for data to be ready at the pins before the next clock cycle
set_output_delay 2.0 -clock clk [get_ports dout*]
set_output_delay 2.0 -clock clk [get_ports {empty full}]

5. Electrical Characteristics (Drive Strength)
The clock has "infinite" drive (0 resistance) to prevent the tool from buffering it prematurely
set_drive 0 [get_ports clk]
Standard drive strength for input pins to model real-world signal behavior
set_drive 1 [get_ports {wr_en rd_en}]
set_drive 1 [get_ports din*]

6. Electrical Characteristics (Capacitive Load)
Models the "weight" (capacitance) that the output pins have to push against
set_load 0.1 [get_ports dout*]
set_load 0.05 [get_ports {empty full}]

7. Exceptions
Tells the tool NOT to worry about timing the Reset signal. 
Since reset is asynchronous, it doesn't need to meet a specific 10ns clock deadline.
set_false_path -from [get_ports rst_n]

## Author 
Tanisha Singh
B.tech Electronics and Communication Engineering
