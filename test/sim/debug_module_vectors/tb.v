// This is not really a "testbench", just an integration of CPU + DM for a
// CXXRTL test to poke at

module tb #(
	parameter W_DATA = 32,
	parameter W_ADDR = 32,
	parameter NUM_IRQ = 16
) (
	// Global signals
	input wire               clk,
	input wire               rst_n,

	// Instruction fetch port
	output wire [W_ADDR-1:0] i_haddr,
	output wire              i_hwrite,
	output wire [1:0]        i_htrans,
	output wire [2:0]        i_hsize,
	output wire [2:0]        i_hburst,
	output wire [3:0]        i_hprot,
	output wire              i_hmastlock,
	input  wire              i_hready,
	input  wire              i_hresp,
	output wire [W_DATA-1:0] i_hwdata,
	input  wire [W_DATA-1:0] i_hrdata,

	// Load/store port
	output wire [W_ADDR-1:0] d_haddr,
	output wire              d_hwrite,
	output wire [1:0]        d_htrans,
	output wire [2:0]        d_hsize,
	output wire [2:0]        d_hburst,
	output wire [3:0]        d_hprot,
	output wire              d_hmastlock,
	input  wire              d_hready,
	input  wire              d_hresp,
	output wire [W_DATA-1:0] d_hwdata,
	input  wire [W_DATA-1:0] d_hrdata,

	// Debug module interface
	input  wire              dmi_psel,
	input  wire              dmi_penable,
	input  wire              dmi_pwrite,
	input  wire [7:0]        dmi_paddr,
	input  wire [31:0]       dmi_pwdata,
	output reg  [31:0]       dmi_prdata,
	output wire              dmi_pready,
	output wire              dmi_pslverr,

	// Level-sensitive interrupt sources
	input wire [NUM_IRQ-1:0] irq,       // -> mip.meip
	input wire               soft_irq,  // -> mip.msip
	input wire               timer_irq  // -> mip.mtip
);

localparam N_HARTS = 1;
localparam XLEN = 32;

wire                      sys_reset_req;
wire                      sys_reset_done;
wire [N_HARTS-1:0]        hart_reset_req;
wire [N_HARTS-1:0]        hart_reset_done;

wire [N_HARTS-1:0]        hart_req_halt;
wire [N_HARTS-1:0]        hart_req_halt_on_reset;
wire [N_HARTS-1:0]        hart_req_resume;
wire [N_HARTS-1:0]        hart_halted;
wire [N_HARTS-1:0]        hart_running;

wire [N_HARTS*XLEN-1:0]   hart_data0_rdata;
wire [N_HARTS*XLEN-1:0]   hart_data0_wdata;
wire [N_HARTS-1:0]        hart_data0_wen;

wire [N_HARTS*XLEN-1:0]   hart_instr_data;
wire [N_HARTS-1:0]        hart_instr_data_vld;
wire [N_HARTS-1:0]        hart_instr_data_rdy;
wire [N_HARTS-1:0]        hart_instr_caught_exception;
wire [N_HARTS-1:0]        hart_instr_caught_ebreak;

hazard3_dm #(
	.N_HARTS      (N_HARTS),
	.NEXT_DM_ADDR (0)
) dm (
	.clk                         (clk),
	.rst_n                       (rst_n),

	.dmi_psel                    (dmi_psel),
	.dmi_penable                 (dmi_penable),
	.dmi_pwrite                  (dmi_pwrite),
	.dmi_paddr                   (dmi_paddr),
	.dmi_pwdata                  (dmi_pwdata),
	.dmi_prdata                  (dmi_prdata),
	.dmi_pready                  (dmi_pready),
	.dmi_pslverr                 (dmi_pslverr),

	.sys_reset_req               (sys_reset_req),
	.sys_reset_done              (sys_reset_done),
	.hart_reset_req              (hart_reset_req),
	.hart_reset_done             (hart_reset_done),

	.hart_req_halt               (hart_req_halt),
	.hart_req_halt_on_reset      (hart_req_halt_on_reset),
	.hart_req_resume             (hart_req_resume),
	.hart_halted                 (hart_halted),
	.hart_running                (hart_running),

	.hart_data0_rdata            (hart_data0_rdata),
	.hart_data0_wdata            (hart_data0_wdata),
	.hart_data0_wen              (hart_data0_wen),

	.hart_instr_data             (hart_instr_data),
	.hart_instr_data_vld         (hart_instr_data_vld),
	.hart_instr_data_rdy         (hart_instr_data_rdy),
	.hart_instr_caught_exception (hart_instr_caught_exception),
	.hart_instr_caught_ebreak    (hart_instr_caught_ebreak)
);


// Generate resynchronised reset for CPU based on upstream reset and
// on reset requests from DM.

wire assert_cpu_reset = !rst_n || sys_reset_req || hart_reset_req[0];

reg [1:0] cpu_reset_sync;
wire rst_n_cpu = cpu_reset_sync[1];

always @ (posedge clk or posedge assert_cpu_reset)
	if (assert_cpu_reset)
		cpu_reset_sync <= 2'b00;
	else
		cpu_reset_sync <= (cpu_reset_sync << 1) | 2'b01;

// Still some work to be done on the reset handshake -- this ought to be
// resynchronised to DM's reset domain here, and the DM should wait for a
// rising edge after it has asserted the reset pulse, to make sure the tail
// of the previous "done" is not passed on.
assign sys_reset_done = rst_n_cpu;
assign hart_reset_done = rst_n_cpu;


hazard3_cpu_2port #(
	.RESET_VECTOR    (32'hc0),
	.MTVEC_INIT      (32'h00),
	.EXTENSION_C     (1),
	.EXTENSION_M     (1),
	.CSR_M_MANDATORY (1),
	.CSR_M_TRAP      (1),
	.CSR_COUNTER     (1),
	.DEBUG_SUPPORT   (1),
	.NUM_IRQ         (NUM_IRQ),
	.MVENDORID_VAL   (32'hdeadbeef),
	.MARCHID_VAL     (32'hfeedf00d),
	.MIMPID_VAL      (32'h12345678),
	.MHARTID_VAL     (32'h0),
	.REDUCED_BYPASS  (0),
	.MULDIV_UNROLL   (2),
	.MUL_FAST        (1),
) cpu (
	.clk                        (clk),
	.rst_n                      (rst_n_cpu),

	.i_haddr                    (i_haddr),
	.i_hwrite                   (i_hwrite),
	.i_htrans                   (i_htrans),
	.i_hsize                    (i_hsize),
	.i_hburst                   (i_hburst),
	.i_hprot                    (i_hprot),
	.i_hmastlock                (i_hmastlock),
	.i_hready                   (i_hready),
	.i_hresp                    (i_hresp),
	.i_hwdata                   (i_hwdata),
	.i_hrdata                   (i_hrdata),

	.d_haddr                    (d_haddr),
	.d_hwrite                   (d_hwrite),
	.d_htrans                   (d_htrans),
	.d_hsize                    (d_hsize),
	.d_hburst                   (d_hburst),
	.d_hprot                    (d_hprot),
	.d_hmastlock                (d_hmastlock),
	.d_hready                   (d_hready),
	.d_hresp                    (d_hresp),
	.d_hwdata                   (d_hwdata),
	.d_hrdata                   (d_hrdata),

	.dbg_req_halt               (hart_req_halt),
	.dbg_req_halt_on_reset      (hart_req_halt_on_reset),
	.dbg_req_resume             (hart_req_resume),
	.dbg_halted                 (hart_halted),
	.dbg_running                (hart_running),

	.dbg_data0_rdata            (hart_data0_rdata),
	.dbg_data0_wdata            (hart_data0_wdata),
	.dbg_data0_wen              (hart_data0_wen),

	.dbg_instr_data             (hart_instr_data),
	.dbg_instr_data_vld         (hart_instr_data_vld),
	.dbg_instr_data_rdy         (hart_instr_data_rdy),
	.dbg_instr_caught_exception (hart_instr_caught_exception),
	.dbg_instr_caught_ebreak    (hart_instr_caught_ebreak),

	.irq                        (irq),
	.soft_irq                   (soft_irq),
	.timer_irq                  (timer_irq)
);

endmodule
