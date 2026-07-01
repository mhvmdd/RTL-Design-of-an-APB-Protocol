
module tb_wrapper();

    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    parameter STROBE_WIDTH = DATA_WIDTH / 8;

    // Clock and Reset
    logic PCLK;
    logic PRESETn;

    // Master Control Signals (TB -> Master)
    logic [DATA_WIDTH-1:0]   WDATA;
    logic [STROBE_WIDTH-1:0] WSTRB;
    logic [ADDR_WIDTH-1:0]   ADDR;
    logic                    SEL;
    logic                    WRn;
    logic                    EN;

    // Output from Master (Master -> TB)
    logic [DATA_WIDTH-1:0]   DATA_OUT;

    // ---------------------------------------------------------
    // Instantiate Wrapper
    // ---------------------------------------------------------
    wrapper #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .WDATA(WDATA),
        .WSTRB(WSTRB),
        .ADDR(ADDR),
        .SEL(SEL),
        .WRn(WRn),
        .EN(EN),
        .DATA_OUT(DATA_OUT)
    );

    // ---------------------------------------------------------
    // Clock Generation
    // ---------------------------------------------------------
    initial begin
        PCLK = 0;
        forever #5 PCLK = ~PCLK;
    end

    // ---------------------------------------------------------
    // Clocking Block for Race-Free Driving
    // ---------------------------------------------------------
    clocking cb @(posedge PCLK);
        default input #1step output #0;
        output WDATA, WSTRB, ADDR, SEL, WRn, EN;
        input  DATA_OUT;
    endclocking

    // ---------------------------------------------------------
    // BFM Tasks for the TB-to-Master Interface
    // ---------------------------------------------------------
    
    // Write Task
    task master_tb_write(input logic sel_in, input [ADDR_WIDTH-1:0] addr_in, input [DATA_WIDTH-1:0] data_in);
        begin
            // @(cb);
            cb.EN    <= 1'b1;
            cb.WRn   <= 1'b1;
            cb.SEL   <= sel_in;
            cb.ADDR  <= addr_in;
            cb.WDATA <= data_in;
            cb.WSTRB <= 4'b1111;

            // Pulse EN for 1 cycle to kick off the FSM
            @(cb);
            cb.EN    <= 1'b0;

            // Wait 2 more cycles for SETUP and ACCESS phases to complete
            // (Assuming zero-wait-state slaves)
            @(cb); 
            @(cb);
        end
    endtask

    // Read Task
    task master_tb_read(input logic sel_in, input [ADDR_WIDTH-1:0] addr_in);
        begin
            // @(cb);
            cb.EN    <= 1'b1;
            cb.WRn   <= 1'b0;
            cb.SEL   <= sel_in;
            cb.ADDR  <= addr_in;
            cb.WDATA <= '0;
            cb.WSTRB <= '0;

            // Pulse EN for 1 cycle
            @(cb);
            cb.EN   <= 1'b0;

            // Wait out SETUP and ACCESS phases
            @(cb);
            @(cb);

            $display("Read Data from Slave %0d at Addr 0x%0h: 0x%0h at %t", sel_in+1, addr_in, cb.DATA_OUT, $time);
        end
    endtask

    // ---------------------------------------------------------
    // Main Test Sequence
    // ---------------------------------------------------------
    initial begin
        // 1. Initialize Inputs
        PRESETn = 0;
        EN      = 0;
        WRn     = 0;
        SEL     = 0;
        ADDR    = 0;
        WDATA   = 0;
        WSTRB   = 0;

        // 2. Assert Reset
        $display("--- Starting Reset ---");
        repeat (3) @(cb);
        PRESETn = 1;
        repeat (1) @(cb);
        $display("--- Reset Complete ---");

        // ---------------------------------------------------------
        // TEST 1: Basic Write and Read (Slave 1)
        // ---------------------------------------------------------
        $display("\n[TEST 1] Basic I/O on Slave 1");
        master_tb_write(1'b0, 32'h0000_0000, 32'hAAAA_BBBB);
        master_tb_read (1'b0, 32'h0000_0000);

        // ---------------------------------------------------------
        // TEST 2: Data Isolation (Cross-Slave Pollution Check)
        // ---------------------------------------------------------
        // Objective: Ensure writing to Address 0x8 on Slave 2 
        // does not overwrite Address 0x8 on Slave 1.
        $display("\n[TEST 2] Verifying Cross-Slave Isolation");
        master_tb_write(1'b0, 32'h0000_0008, 32'h1111_1111); // Slave 1
        master_tb_write(1'b1, 32'h0000_0008, 32'h2222_2222); // Slave 2
        
        $display("-> Reading Slave 1 (Expect 0x11111111)");
        master_tb_read (1'b0, 32'h0000_0008); 
        $display("-> Reading Slave 2 (Expect 0x22222222)");
        master_tb_read (1'b1, 32'h0000_0008);

        // ---------------------------------------------------------
        // TEST 3: Back-to-Back Interleaved Transactions
        // ---------------------------------------------------------
        // Objective: Stress the FSM by immediately switching SEL 
        // without dead cycles between enables.
        $display("\n[TEST 3] Back-to-Back Interleaved Routing");
        master_tb_write(1'b0, 32'h0000_0004, 32'hBEEF_0001); // Slave 1
        master_tb_write(1'b1, 32'h0000_0004, 32'hCAFE_0002); // Slave 2
        master_tb_write(1'b0, 32'h0000_0000, 32'h0000_FFFF); // Slave 1
        
        master_tb_read(1'b0, 32'h0000_0004);
        master_tb_read(1'b1, 32'h0000_0004);

        // ---------------------------------------------------------
        // TEST 4: Error Handling (PSLVERR Assertion)
        // ---------------------------------------------------------
        // Objective: Hit the invalid address threshold (> 0x0C) 
        // that we defined in the slave module.
        $display("\n[TEST 4] Error Generation (Invalid Address)");
        // Write to address 0x10 on Slave 1 (Should trigger PSLVERR internally)
        master_tb_write(1'b0, 32'h0000_0010, 32'hDEAD_DEAD);
         $display("Write Data from Slave %0d at Addr 0x%0h: 0x%0h at %t", 1, 32'h0000_0010, 32'hDEAD_DEAD, $time);
        if (dut.PSLVERR)
            $display ("-> Successful Error Raised");
        else 
            $display ("-> Failed Error Raised");
        
        // Read from address 0x14 on Slave 2
        master_tb_read (1'b1, 32'h0000_0014);
        if (dut.PSLVERR)
            $display ("-> Successful Error Raised");
        else 
            $display ("-> Failed Error Raised");

        // 5. End Simulation
        #40;
        $display("\n--- Simulation Complete ---");
        $finish;
    end

    initial begin
        $dumpfile("wrapper.vcd");
        $dumpvars(0, tb_wrapper);
    end

endmodule