`default_nettype none


module tt_um_trivium_stream_processor (
    // Dedicated inputs/outputs
    input  wire [7:0] ui_in,
    output reg  [7:0] uo_out,
    
    // Bidirectional IOs
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    
    // System signals
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // ====================================
    // Constants and Parameters
    // ====================================
    localparam IDLE  = 2'd0;
    localparam RUN   = 2'd1;
    localparam RESET = 2'd2;
    
    localparam INIT_S1 = 64'h23A2B;
    localparam INIT_S2 = 64'h2A892;
    localparam INIT_S3 = 64'hF4511;
    
    localparam CMD_NORMAL = 8'h00;
    localparam CMD_RESET  = 8'hFF;
    
    // ====================================
    // Internal Registers
    // ====================================
    reg [63:0] s1, s2, s3;
    reg [7:0] temp_keystream;
    reg [2:0] step;
    reg [1:0] state;
    
    // ====================================
    // Output Assignments
    // ====================================
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;
    
    // ====================================
    // Main State Machine
    // ====================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1             <= INIT_S1;
            s2             <= INIT_S2;
            s3             <= INIT_S3;
            temp_keystream <= 8'b0;
            uo_out         <= 8'b0;
            step           <= 3'd0;
            state          <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    step           <= 3'd0;
                    temp_keystream <= 8'b0;
                    uo_out         <= 8'b0;

                    if (uio_in != CMD_NORMAL && uio_in != CMD_RESET) begin
                        s1    <= {48'd0, uio_in, uio_in};
                        s2    <= {48'd0, uio_in, ~uio_in[3:0], uio_in[7:4]};
                        s3    <= {48'd0, uio_in, (uio_in ^ 8'hA5)};
                        state <= RUN;
                    end
                end

                RUN: begin
                    uo_out <= uo_out;  // Hold last value by default

                    if (uio_in == CMD_RESET) begin
                        state <= RESET;
                    end else begin
                        if (step == 3'd0) begin
                            temp_keystream <= 8'b0;
                        end
                        
                        // Update LFSRs
                        s1 <= {s1[62:0], s2[0] ^ s3[1] ^ s1[5] ^ s2[7] ^ s3[13] ^ s1[31] ^ s2[47] ^ s3[60]};
                        s2 <= {s2[62:0], s3[3] ^ s1[1] ^ s2[2] ^ s3[19] ^ s1[23]};
                        s3 <= {s3[62:0], s1[5] ^ s2[2] ^ s3[4] ^ s1[17] ^ s2[29] ^ s3[63] ^ s1[10] ^ s2[40]};
                        
                        // Accumulate keystream
                        temp_keystream <= {temp_keystream[6:0], s1[0] ^ s2[0] ^ s3[0]};
                        
                        step <= step + 1;

                        if (step == 3'd7) begin
                            uo_out <= ui_in ^ temp_keystream;
                            step   <= 3'd0;
                        end
                    end
                end

                RESET: begin
                    s1             <= INIT_S1;
                    s2             <= INIT_S2;
                    s3             <= INIT_S3;
                    temp_keystream <= 8'b0;
                    uo_out         <= 8'b0;
                    step           <= 3'd0;
                    state          <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
