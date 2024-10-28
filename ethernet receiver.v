module slave_receiver (
    input wire clk,               // Clock signal
    input wire rst,               // Reset signal (active high)
    input wire [7:0] frame_in,    // Incoming Ethernet frame data
    input wire valid,             // Frame validity signal
//    output reg [7:0] payload_out [1499:0], // Extracted payload data
   output reg [11999:0] payload_out , // Extracted payload data
    output reg error_flag         // Error flag for CRC check
);

    reg [15:0] byte_count;    // Counter for received bytes
    reg crc_en;               // Enable CRC checking
    reg [31:0] crc_incoming;  // CRC received with the frame
    reg [31:0] crc_calc;      // CRC computed from the data
    reg [3:0] state;          // FSM state register

    // FSM states
    localparam S_IDLE = 0, S_RECEIVE = 1, S_CRC = 2;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            error_flag <= 0;      // Clear error flag on reset
            state <= S_IDLE;      // Move to idle state
            byte_count <= 0;      // Reset byte counter
        end else begin
            case (state)
                S_IDLE: begin
                    if (valid) begin  // If a frame is valid, start receiving
                        state <= S_RECEIVE;
                        crc_en <= 1;  // Enable CRC calculation
                        byte_count <= 0;
                    end
                end

                S_RECEIVE: begin
                    if (byte_count < 1500) begin  // Receive payload
                        payload_out[byte_count] <= frame_in;
                        byte_count <= byte_count + 1;
                    end else begin
                        state <= S_CRC;  // Move to CRC check state
                        crc_en <= 0;     // Stop CRC calculation
                    end
                end

                S_CRC: begin
                    // Compare computed CRC with received CRC
                    if (crc_calc != crc_incoming)
                        error_flag <= 1;  // Set error flag if CRC mismatch
                    state <= S_IDLE;  // Return to idle state
                end
            endcase
        end
    end

    // CRC-32 module for computing CRC of the received frame
    crc32 crc_check (
        .clk(clk),
        .rst(rst),
        .data_in(frame_in),
        .crc_en(crc_en),
        .crc_out(crc_calc)
    );
endmodule
