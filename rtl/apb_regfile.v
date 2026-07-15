module apb_slave #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)
(
    // Inputs from Master
    input wire PCLK,
    input wire PRESETn,
    input wire [ADDR_WIDTH-1:0] PADDR,
    input wire PSEL,
    input wire PENABLE,
    input wire PWRITE,
    input wire [DATA_WIDTH-1:0] PWDATA,
    input wire [(DATA_WIDTH/8)-1:0] PSTRB,

    // Outputs to Master
    output reg PREADY,
    output reg [DATA_WIDTH-1:0] PRDATA,
    output reg PSLVERR
);  

    localparam STROBE_WIDTH = (DATA_WIDTH/8);

    // Register addresses
    localparam integer DATA_REGISTER = 32'h0000_0000;
    localparam integer STATUS_REGISTER = 32'h0000_0004; // RO
    localparam integer CONTROL_REGISTER = 32'h0000_0008;
    localparam integer CONFIG_REGISTER = 32'h0000_000C;

    //logic for registers
    wire [DATA_WIDTH-1:0] status_reg;
    reg [DATA_WIDTH-1:0] data_reg;
    reg [DATA_WIDTH-1:0] control_reg;
    reg [DATA_WIDTH-1:0] config_reg;

    assign status_reg = 32'h0000_0012; // Ex


// Write Logic (Clocked)
    integer i;
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            data_reg <= 'd0;
            control_reg <= 'd0;
            config_reg <= 'd0;
        end
        else begin
            if (PSEL) begin
                if (PWRITE && PENABLE) begin
                    for (i = 0; i < STROBE_WIDTH; i = i + 1) begin
                        if (PSTRB[i]) begin
                            case (PADDR)
                                DATA_REGISTER:
                                    data_reg[(i*8)+:8] <= PWDATA[(i*8)+:8];

                                CONTROL_REGISTER: 
                                    control_reg[(i*8)+:8] <= PWDATA[(i*8)+:8];

                                CONFIG_REGISTER:
                                    config_reg[(i*8)+:8] <= PWDATA[(i*8)+:8];

                                default:; 
                            endcase
                        end
                    end
                end
            end
        end
    end
// READ Logic (Non-Clocked)
    always @(*) begin
        PRDATA = {DATA_WIDTH{1'b0}}; // Default value
        if (PSEL) begin
            if (!PWRITE && PENABLE) begin
                case (PADDR)
                    DATA_REGISTER: begin 
                        PRDATA = data_reg;
                    end
                    STATUS_REGISTER: begin
                        PRDATA = status_reg;
                    end
                    CONTROL_REGISTER: begin
                        PRDATA = control_reg;
                    end
                    CONFIG_REGISTER: begin
                        PRDATA = config_reg;
                    end
                    default: PRDATA = {DATA_WIDTH{1'b0}};
                endcase
            end 
        end
    end

    // Slave Error Logic
    always @(*) begin
        PSLVERR = 1'b0; // Default to no error
        if (PSEL && (((PADDR > CONFIG_REGISTER) && !PWRITE) || 
        ((PADDR != DATA_REGISTER && PADDR != CONTROL_REGISTER && PADDR != CONFIG_REGISTER) && PWRITE) ||
        PADDR[1:0] != 2'b00)) begin
            PSLVERR = 1'b1; // Error for invalid address
        end 
    end

    // READY Logic
    always @(*) begin
        PREADY = 1'b0; // Default to ready
        if (PSEL && PENABLE) begin
            PREADY = 1'b1; // Ready when selected and enabled
        end
    end


endmodule