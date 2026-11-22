module testbench;
  timeunit 1ns;
  timeprecision 1ps;

  logic clk, reset;
  logic [31:0] writedata, dataadr;
  logic memwrite;

  logic [31:0] machine_code_list [0:63];  // depth must match dut.imem.RAM

  string  prog_file, trace_file;
  integer trace_fd;
  integer i;
  integer cycles;
  bit     done;

  top dut (
    .clk(clk),
    .reset(reset),
    .writedata(writedata),
    .dataadr(dataadr),
    .memwrite(memwrite)
  );

  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100MHz clock
  end

  initial begin
    done = 0;
    if (!$value$plusargs("PROG=%s", prog_file))
      $fatal(1, "Missing +PROG=<binary machine code file>");
    if (!$value$plusargs("TRACE=%s", trace_file))
      trace_file = "rtl.trace";
    trace_fd = $fopen(trace_file, "w");
    if (trace_fd == 0)
      $fatal(1, "Could not open trace file %s", trace_file);

    reset = 1;

    // Wait for imem's own initialization to finish, clear it, then load program
    // through memfile.dat, the same flow as instr_gen.sv
    #1;
    for (i = 0; i < 64; i++) machine_code_list[i] = 32'h0;
    $readmemb(prog_file, machine_code_list);
    $writememh("rtl/memfile.dat", machine_code_list);
    $readmemh("rtl/memfile.dat", dut.imem.RAM);

    $fdisplay(trace_fd, "Translation complete. Binary instructions written to traces/prog1.bin.");

    repeat (2) @(posedge clk);
    reset = 0;

    // Run until the trickbox store (0xDED to byte address 0x40) or a timeout
    cycles = 0;
    while (dut.dmem.RAM[16'h0040 >> 2] !== 32'h0000_0DED && cycles < 5000) begin
      @(posedge clk);
      cycles++;
    end
    if (cycles >= 5000)
      $display("TIMEOUT: trickbox value never written");
    else
      $display("Trickbox written. Simulation ending after %0d cycles.", cycles);

    repeat (5) @(posedge clk); // let the last instructions finish
    done = 1;
    $fclose(trace_fd);
    $finish;
  end

  // Trace logger. Sampling at posedge sees the values from the previous cycle
  // (the instruction that was in WB / MEM), before this edge updates the pipeline.
  always @(posedge clk) begin
    if (!reset && !done) begin
      if (dut.mips.dp.rf.we3 === 1'b1 && dut.mips.dp.rf.wa3 != 5'd0)
        $fdisplay(trace_fd, "R %0d %08h", dut.mips.dp.rf.wa3, dut.mips.dp.rf.wd3);
      if (memwrite === 1'b1)
        $fdisplay(trace_fd, "M %08h %08h", dataadr, writedata);
    end
  end

  always @(negedge clk) begin
    if (dut.mips.dp.validW === 1'b1) begin
      $fdisplay(trace_fd, "Executing at 0x%h: %h", dut.mips.dp.pc, dut.mips.dp.instrW);
    end
  end

  initial begin
    $fsdbDumpfile("novas.fsdb");
    $fsdbDumpvars(0, testbench);
    $fsdbDumpMDA(testbench.dut.dmem.RAM);
    $fsdbDumpMDA(testbench.dut.mips.dp.rf);
  end
endmodule
