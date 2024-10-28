
module master_transmitter (
    input wire clk,                           // Clock signal (drives the sequential logic)
    input wire rst,                           // Reset signal (active high, resets the module)
    input wire start_tx,                      // Start transmission signal
    input wire [47:0] destination_mac,        // 48-bit destination MAC address (6 bytes)
    input wire [47:0] source_mac,             // 48-bit source MAC address (6 bytes)
    input wire [15:0] ethertype,              // 16-bit EtherType/Length field
    input wire [7:0] payload [0:1499],        // Payload data to transmit (up to 1500 bytes)
    input wire [15:0] payload_length,         // Length of the payload (in bytes)
    output reg [7:0] frame_out,               // Byte-by-byte Ethernet frame output
    output reg valid                          // Valid signal indicating valid frame data
);

    // Internal registers for CRC calculation and FSM state control
    reg [31:0] crc_calc;                      // 32-bit CRC-32 value for frame integrity
    reg crc_en;                               // CRC enable signal (active when CRC is computed)
    reg [15:0] byte_count;                    // Counter to track the number of transmitted bytes
    reg [3:0] state;                          // State register for FSM (Finite State Machine)

    // Constants used in Ethernet frame construction
    localparam PREAMBLE = 8'h55;              // Preamble byte (repeated 7 times)
    localparam SFD = 8'hD5;                   // Start Frame Delimiter (1 byte, marks frame start)

    // FSM state definitions (used to control frame transmission sequence)
    localparam S_IDLE     = 0,                // Idle state (waiting for start signal)
               S_PRE      = 1,                // Sending preamble and SFD
               S_MAC      = 2,                // Sending MAC addresses (destination + source)
               S_TYPE     = 3,                // Sending EtherType/Length field
               S_PAYLOAD  = 4,                // Sending payload data
               S_CRC      = 5;                // Sending CRC-32 checksum

    // FSM Implementation: Controls the sequence of frame transmission
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset all signals and go to idle state
            valid <= 0;                       // Invalidate the frame output
            state <= S_IDLE;                  // Set state to idle
            byte_count <= 0;                  // Reset byte counter
        end else begin
            // Main FSM state machine to transmit Ethernet frames
            case (state)
                // S_IDLE: Wait for the start transmission signal (start_tx)
                S_IDLE: begin
                    valid <= 0;               // Invalidate frame output in idle state
                    if (start_tx) begin       // If start_tx is high, begin transmission
                        state <= S_PRE;       // Move to the preamble state
                        byte_count <= 0;      // Reset byte counter
                    end
                end

                // S_PRE: Send 7 bytes of preamble (0x55) and 1 byte of SFD (0xD5)
                S_PRE: begin
                    if (byte_count < 7) begin // First 7 bytes are preamble
                        frame_out <= PREAMBLE;  // Output preamble byte
                        valid <= 1;           // Set valid to 1 indicating valid data
                        byte_count <= byte_count + 1;  // Increment byte counter
                    end else begin
                        frame_out <= SFD;     // Send Start Frame Delimiter (SFD)
                        state <= S_MAC;       // Move to MAC address transmission state
                        byte_count <= 0;      // Reset byte counter
                    end
                end

                // S_MAC: Transmit destination and source MAC addresses (12 bytes)
                S_MAC: begin
                    if (byte_count < 12) begin  // 6 bytes for destination, 6 for source MAC
                        frame_out <= (byte_count < 6) ? 
                            destination_mac[47 - (byte_count * 8) +: 8] :  // Send destination MAC
                            source_mac[47 - ((byte_count - 6) * 8) +: 8]; // Send source MAC
                        byte_count <= byte_count + 1;  // Increment byte counter
                    end else begin
                        state <= S_TYPE;       // Move to EtherType/Length field state
                        byte_count <= 0;       // Reset byte counter
                    end
                end

                // S_TYPE: Send the 16-bit EtherType/Length field (2 bytes)
                S_TYPE: begin
                    if (byte_count == 0)
                        frame_out <= ethertype[15:8];  // Send upper byte of EtherType
                    else begin
                        frame_out <= ethertype[7:0];   // Send lower byte of EtherType
                        state <= S_PAYLOAD;            // Move to payload transmission state
                    end
                    byte_count <= byte_count + 1;      // Increment byte counter
                end

                // S_PAYLOAD: Transmit the payload data (byte-by-byte)
                S_PAYLOAD: begin
                    if (byte_count < payload_length) begin  // Transmit until payload length is reached
                        frame_out <= payload[byte_count];  // Output the next payload byte
                        byte_count <= byte_count + 1;      // Increment byte counter
                        crc_en <= 1;                       // Enable CRC calculation
                    end else begin
                        state <= S_CRC;        // Move to CRC transmission state
                        crc_en <= 0;           // Disable CRC calculation
                    end
                end

                // S_CRC: Transmit the 32-bit CRC checksum (4 bytes)
                S_CRC: begin
                    case (byte_count)
                        0: frame_out <= crc_calc[31:24];  // Send highest byte of CRC
                        1: frame_out <= crc_calc[23:16];  // Send next byte of CRC
                        2: frame_out <= crc_calc[15:8];   // Send next byte of CRC
                        3: frame_out <= crc_calc[7:0];    // Send lowest byte of CRC
                    endcase
                    byte_count <= byte_count + 1;          // Increment byte counter
                    if (byte_count == 3)                   // After 4 CRC bytes are sent
                        state <= S_IDLE;                   // Go back to idle state
                end

                // Default case: Return to idle state in case of unexpected behavior
                default: state <= S_IDLE;
            endcase
        end
    end

    // Dummy CRC Calculation (Replace with proper CRC logic if needed)
    always @(posedge clk or posedge rst) begin
        if (rst)
            crc_calc <= 32'h0;               // Reset CRC value on reset
        else if (crc_en)
            crc_calc <= crc_calc ^ frame_out; // Simple XOR-based CRC logic (for demonstration)
    end
endmodule

