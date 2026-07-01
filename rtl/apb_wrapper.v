module wrapper #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)
(
    // Inputs from TB
    input wire PCLK,
    input wire PRESETn,

    input wire [DATA_WIDTH-1:0] WDATA,
    input wire [(DATA_WIDTH/8)-1:0] WSTRB,
    input wire [ADDR_WIDTH-1:0] ADDR,
    input wire SEL, // Two Slaves 0 for Slave 1, 1 for Slave 2
    input wire WRn, // 1 for Write, 0 for Read
    input wire EN, // Enable signal for the transaction

    // Outputs to TB
    output wire [DATA_WIDTH-1:0] DATA_OUT
);

    wire [ADDR_WIDTH-1:0] PADDR;
    wire PSEL1;
    wire PSEL2;
    wire PENABLE;
    wire PWRITE;
    wire [DATA_WIDTH-1:0] PWDATA;
    wire [(DATA_WIDTH/8)-1:0] PSTRB;

    wire PREADY, PREADY1, PREADY2;
    wire [DATA_WIDTH-1:0] PRDATA, PRDATA1, PRDATA2;
    wire PSLVERR, PSLVERR1, PSLVERR2;




    apb_master #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut_master
    (
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        
        .WDATA(WDATA),
        .WSTRB(WSTRB),
        .ADDR(ADDR),
        .SEL(SEL),
        .WRn(WRn),
        .EN(EN),
        .DATA_OUT(DATA_OUT),

        .PADDR(PADDR),
        .PSEL1(PSEL1),
        .PSEL2(PSEL2),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PSTRB(PSTRB),

        .PREADY(PREADY),
        .PRDATA(PRDATA),
        .PSLVERR(PSLVERR)
    );


    apb_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut_slave1 (
        .PCLK(PCLK),
        .PRESETn(PRESETn),

        .PADDR(PADDR),
        .PSEL(PSEL1),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PSTRB(PSTRB),

        .PREADY(PREADY1),
        .PRDATA(PRDATA1),
        .PSLVERR(PSLVERR1)
    );

    apb_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut_slave2 (
        .PCLK(PCLK),
        .PRESETn(PRESETn),

        .PADDR(PADDR),
        .PSEL(PSEL2),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PSTRB(PSTRB),

        .PREADY(PREADY2),
        .PRDATA(PRDATA2),
        .PSLVERR(PSLVERR2)
    );

    assign PREADY = (PSEL1 && PREADY1) || (PSEL2 && PREADY2);
    assign PRDATA = (PSEL1) ? PRDATA1 : PRDATA2;
    assign PSLVERR = (PSEL1 && PSLVERR1) || (PSEL2 && PSLVERR2);
endmodule