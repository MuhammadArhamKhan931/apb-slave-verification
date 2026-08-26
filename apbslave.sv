module apb_slave_dut_cov (
    input  wire        PCLK,
    input  wire        PRESETn,
    input  wire        PSEL,
    input  wire        PENABLE,
    input  wire        PWRITE,
    input  wire [7:0]  PADDR,
    input  wire [31:0] PWDATA,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    output logic        PSLVERR
);
 
    logic [31:0] mem [0:255];
    integer idx;
 
    localparam [7:0] RESERVED_ADDR = 8'hFF;
 
    typedef enum logic [1:0] {IDLE, SETUP, ACCESS} state_t;
    state_t state;
 
    logic [3:0] wait_cnt;
 
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            for (idx = 0; idx < 256; idx = idx + 1)
                mem[idx] <= 32'h0;
            state    <= IDLE;
            PRDATA   <= 32'h0;
            PREADY   <= 1'b0;
            PSLVERR  <= 1'b0;
            wait_cnt <= 4'h0;
        end else begin
            case (state)
                IDLE: begin
                    PREADY  <= 1'b0;
                    PSLVERR <= 1'b0;
                    if (PSEL && !PENABLE) begin
                        wait_cnt <= $urandom_range(0, 3);
                        state    <= SETUP;
                    end
                end
 
                SETUP: begin
                    if (PSEL && PENABLE)
                        state <= ACCESS;
                    else
                        state <= IDLE;
                end
 
                ACCESS: begin
                    if (wait_cnt != 0) begin
                        PREADY   <= 1'b0;
                        wait_cnt <= wait_cnt - 1'b1;
                    end else begin
                        PREADY <= 1'b1;
                        if (PADDR == RESERVED_ADDR) begin
                            PSLVERR <= 1'b1;
                            PRDATA  <= 32'h0;
                        end else begin
                            PSLVERR <= 1'b0;
                            if (PWRITE)
                                mem[PADDR] <= PWDATA;
                            else
                                PRDATA <= mem[PADDR];
                        end
 
                        if (PSEL && !PENABLE)
                            state <= SETUP;
                        else
                            state <= IDLE;
                    end
                end
 
                default: state <= IDLE;
            endcase
        end
    end
 
endmodule