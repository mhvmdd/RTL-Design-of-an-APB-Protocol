// `timescale 1ns/1ps

module tb_slave();

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    parameter STROBE_WIDTH = DATA_WIDTH / 8;

    // Clock and Reset
    logic PCLK;
    logic PRESETn;

    // APB Master Signals
    logic [ADDR_WIDTH-1:0]   PADDR;
    logic                    PSEL;
    logic                    PENABLE;
    logic                    PWRITE;
    logic [DATA_WIDTH-1:0]   PWDATA;
    logic [STROBE_WIDTH-1:0] PSTRB;

    // APB Slave Outputs
    logic                    PREADY;
    logic [DATA_WIDTH-1:0]   PRDATA;
    logic                    PSLVERR;

    logic [DATA_WIDTH-1:0] data;
    // ---------------------------------------------------------
    // Instantiate APB Slave
    // ---------------------------------------------------------
    apb_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut_apb (
        .PCLK(PCLK),
        .PRESETn(PRESETn),

        .PADDR(PADDR),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PSTRB(PSTRB),

        .PREADY(PREADY),
        .PRDATA(PRDATA),
        .PSLVERR(PSLVERR)
    );

    // ---------------------------------------------------------
    // Clock Generation (10ns period -> 100MHz)
    // ---------------------------------------------------------
    initial begin
        PCLK = 0;
        forever #5 PCLK = ~PCLK;
    end

    clocking cb_apb @(posedge PCLK);
        default input #1ns output #0;
        input PRESETn;
        input PREADY;
        input PSLVERR;
        input PRDATA;
        output PADDR;
        output PSEL;
        output PENABLE;
        output PWRITE;
        output PWDATA;
        output PSTRB;
    endclocking
    // ---------------------------------------------------------
    // APB Tasks for Simulation
    // ---------------------------------------------------------
    
    // Task: APB Write Transaction
    task apb_write(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data, input [STROBE_WIDTH-1:0] strb);
        begin
             @(cb_apb);
            // SETUP Phase
            PSEL    <= 1'b1;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b1;
            PADDR   <= addr;
            PWDATA  <= data;
            PSTRB   <= strb;
            
            @(cb_apb);
            // ACCESS Phase
            PENABLE <= 1'b1;
            
            do begin
                @(cb_apb);
            end while(!PREADY);

            // Back to IDLE
            PSEL    <= 1'b0;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b0;
            PSTRB   <= '0;
        end
    endtask

    // Task: APB Read Transaction
    task apb_read(input [ADDR_WIDTH-1:0] addr);
        begin
            @(cb_apb);
            // SETUP Phase
            PSEL    <= 1'b1;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b0;
            PADDR   <= addr;
            
            @(cb_apb);
            // ACCESS Phase
            PENABLE <= 1'b1;
            

            // Wait for PREADY
            do begin
                @(cb_apb);
            end while(!PREADY);
            
            data = PRDATA;
            $display("Read Data at Addr 0x%0h: 0x%0h (Err: %0b) at %t", addr, data, PSLVERR, $time);

            // Back to IDLE
            PSEL    <= 1'b0; // back to back transactions
            PENABLE <= 1'b0;
        end
    endtask

    // ---------------------------------------------------------
    // Main Test Sequence
    // ---------------------------------------------------------
    initial begin
        // 1. Initialize Inputs
        PRESETn = 0;
        PADDR   = 0;
        PSEL    = 0;
        PENABLE = 0;
        PWRITE  = 0;
        PWDATA  = 0;
        PSTRB   = 0;

        // 2. Assert Reset
        $display("--- Starting Reset ---");
        #30;
        PRESETn = 1;
        #10;
        $display("--- Reset Complete ---");

        // 3. Test Read-Only Status Register (Expected: 0x12)
        $display("\n[TEST 1] Reading Status Register (Expected 0x12)");
        apb_read(32'h0000_0004);

        // 4. Test Valid Write to Data Register
        $display("\n[TEST 2] Writing 0xDEADBEEF to Data Register");
        apb_write(32'h0000_0000, 32'hDEADBEEF, 4'b1111); // Full word write
        
        $display("[TEST 2] Reading Data Register to Verify Write");
        apb_read(32'h0000_0000); // Should read back DEADBEEF

        // 5. Test Valid Write to Control Register
        $display("\n[TEST 3] Writing 0x12345678 to Control Register");
        apb_write(32'h0000_0008, 32'h12345678, 4'b1111);
        apb_read(32'h0000_0008); 

        // 6. Test Error Handling (Writing to an invalid address)
        $display("\n[TEST 4] Intentional Error: Writing to Invalid Address 0x0000_0010");
        apb_write(32'h0000_0010, 32'hFFFFFFFF, 4'b1111);
        if (PSLVERR) $display("-> SUCCESS: PSLVERR was asserted correctly!");
        else $display("-> FAIL: PSLVERR was not asserted!");

        // 7. Finish Simulation
        $display("\n--- Simulation Complete ---");
        #20;
        $finish;
    end

    // Optional: Dump waveforms for GTKWave or ModelSim/Questa
    initial begin
        $dumpfile("dump.vcd");
        // $dumpvars(0, tb_apb_slave);
    end

endmodule