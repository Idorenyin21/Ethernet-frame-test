`timescale 1ns / 1ps

module tb_master_slave_ethernet;

    // Clock and reset signals
    reg clk;
    reg rst;

    // Signals for the master transmitter
    reg start_tx;
    reg [7:0] destination_mac [5:0];    // Destination MAC address (6 bytes)
    reg [7:0] source_mac [5:0];         // Source MAC address (6 bytes)
    reg [15:0] ethertype;               // EtherType/Length field
    reg [7:0] payload [1499:0];         // Payload (1500 bytes max)
    reg [15:0] payload_length;          // Length of the payload
    wire [7:0] frame_out;               // Frame output from master transmitter
    wire valid;                         // Valid signal for frame output

    // Signals for the slave receiver
    reg [7:0] frame_in;                 // Frame input to slave receiver
    reg valid_in;                       // Valid signal for frame input
    wire [7:0] payload_out [1499:0];    // Extracted payload from slave receiver
    wire error_flag;                    // Error flag for CRC check

    // Instantiate the master transmitter
    master_transmitter master_inst (
        .clk(clk),
        .rst(rst),
        .start_tx(start_tx),
        .destination_mac(destination_mac),
        .source_mac(source_mac),
        .ethertype(ethertype),
        .payload(payload),
        .payload_length(payload_length),
        .frame_out(frame_out),
        .valid(valid)
    );

    // Instantiate the slave receiver
    slave_receiver slave_inst (
        .clk(clk),
        .rst(rst),
        .frame_in(frame_in),
        .valid(valid_in),
        .payload_out(payload_out),
        .error_flag(error_flag)
    );

    // Clock generation: 10ns period (100MHz)
    always #5 clk = ~clk;

    // Testbench initialization
    initial begin
        // Initialize clock and reset
        clk = 0;
        rst = 1;
        start_tx = 0;
        valid_in = 0;
        #20 rst = 0;  // Deassert reset after 20ns

        // Initialize MAC addresses
        destination_mac[0] = 8'hAA; destination_mac[1] = 8'hBB;
        destination_mac[2] = 8'hCC; destination_mac[3] = 8'hDD;
        destination_mac[4] = 8'hEE; destination_mac[5] = 8'hFF;

        source_mac[0] = 8'h11; source_mac[1] = 8'h22;
        source_mac[2] = 8'h33; source_mac[3] = 8'h44;
        source_mac[4] = 8'h55; source_mac[5] = 8'h66;

        // Initialize EtherType field
        ethertype = 16'h0800;  // Example: IPv4 EtherType

        // Initialize payload
        payload_length = 16'd10;  // Set payload length to 10 bytes
        payload[0] = 8'hDE; payload[1] = 8'hAD;
        payload[2] = 8'hBE; payload[3] = 8'hEF;
        payload[4] = 8'h12; payload[5] = 8'h34;
        payload[6] = 8'h56; payload[7] = 8'h78;
        payload[8] = 8'h9A; payload[9] = 8'hBC;

        // Start transmission from master transmitter
        #30 start_tx = 1;
        #10 start_tx = 0;  // Deassert start_tx after 10ns

        // Wait for the master to generate the frame
        #100;

        // Send the generated frame to the slave receiver
        for (integer i = 0; i < (12 + 2 + payload_length); i = i + 1) begin
            frame_in = frame_out;  // Transmit frame data byte-by-byte
            valid_in = valid;      // Set valid signal
            #10;                   // Wait 10ns for each byte
        end

        // Check for CRC error
        if (error_flag) 
            $display("Test failed: CRC error detected.");
        else
            $display("Test passed: Frame received successfully.");

        // End simulation
        #50 $stop;
    end
endmodule

