module top(
    input clk,
    input raw_rst_n,

    output [31:0] inst_addr,
    input [31:0] inst,

    output uart_tx_pin,
    output axi_error_led
);
    wire rst_n;
    wire [31:0] pc;
    wire stall;
    //decoder
    wire [4:0] rs1_addr;
    wire [4:0] rs2_addr;
    wire [4:0] rd_addr;
    wire reg_we;
    wire alu_src;
    wire [3:0] alu_op;
    wire mem_we;
    wire [1:0] wb_sel;
    wire [1:0] alu_op1_sel;
    wire branch;
    wire jump;
    wire jump_reg;
    wire [1:0] mem_size;
    wire mem_ext_u;

    //RF
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;

    //Imm
    wire [31:0] imm;

    //alu
    wire [31:0] alu_result;
    wire alu_zero;
    wire [31:0] alu_operand_b;
    wire [31:0] alu_operand_a;

    wire [31:0] reg_write_data;

    //ram
    wire [31:0] mem_read_data;

    assign inst_addr = pc;

    debounce u_debounce(
        .clk(clk),
        .key_in(raw_rst_n),
        .key_out(rst_n)
    );

    pc_reg u_pc_reg(
        .clk(clk),
        .rst_n(rst_n),
        .imm(imm),
        .alu_result(alu_result),
        .branch(branch),
        .jump(jump),
        .jump_reg(jump_reg),
        .zero(alu_zero),
        .stall(stall),
        .pc(pc)
    );

    //Decode
    decoder u_decoder (
        .inst       (inst),
        .rs1_addr   (rs1_addr),
        .rs2_addr   (rs2_addr),
        .rd_addr    (rd_addr),
        .reg_we     (reg_we),
        .alu_src    (alu_src),
        .alu_op     (alu_op),
        .mem_we     (mem_we),
        .wb_sel     (wb_sel),
        .alu_op1_sel (alu_op1_sel),
        .mem_size   (mem_size),
        .mem_ext_u  (mem_ext_u),
        .branch     (branch),
        .jump       (jump), 
        .jump_reg   (jump_reg)
    );
    imm_gen u_imm_gen (
        .inst (inst),
        .imm  (imm)
    );

    wire real_reg_we = reg_we & (~stall);
    regfile u_regfile (
        .clk      (clk),
        .rst_n    (rst_n),
        .rs1_addr (rs1_addr),
        .rs1_data (rs1_data),
        .rs2_addr (rs2_addr),
        .rs2_data (rs2_data),
        .we       (real_reg_we),
        .rd_addr  (rd_addr),
        .rd_data  (reg_write_data) // 最终算出的数据写回
    );

    //EX
    assign alu_operand_a= (alu_op1_sel == 2'b01) ? pc :
                        (alu_op1_sel == 2'b10) ? 32'b0 :
                        rs1_data;
    assign alu_operand_b = (alu_src) ? imm : rs2_data;
    alu u_alu (
        .alu_op (alu_op),
        .op1    (alu_operand_a),
        .op2    (alu_operand_b),
        .result (alu_result),
        .zero   (alu_zero)
    );

    wire [1:0] addr_offset = alu_result[1:0];//计算内存访问的地址偏移量
    //LSU - store
    reg [3:0] ram_we;
    reg [31:0] ram_wdata;
    always @(*)begin
        ram_we = 4'b0000;
        ram_wdata = rs2_data;
        if (mem_we)begin
            case(mem_size)
                2'b00:begin //byte
                    ram_wdata = {4{rs2_data[7:0]}};
                    ram_we = 4'b0001 << addr_offset;
                end
                2'b01:begin //halfword
                    ram_wdata = {2{rs2_data[15:0]}};
                    ram_we = (addr_offset[1]) ? 4'b1100 : 4'b0011;
                end
                2'b10:begin //word
                    ram_wdata = rs2_data;
                    ram_we = 4'b1111;
                end
            endcase
        end
    end

    //LSU - load
    wire [31:0] raw_mem_data = is_periph ? axi_rdata_out : ram_rdata_out;
    reg [15:0] hw;
    reg  [31:0] final_mem_data;
    reg [7:0] b;
    always @(*)begin
        b = 8'b0;
        hw = 16'b0;
        final_mem_data = raw_mem_data;//default lw
        case(mem_size)
            2'b00:begin //byte
                case(addr_offset)
                    2'b00: b = raw_mem_data[7:0];
                    2'b01: b = raw_mem_data[15:8];
                    2'b10: b = raw_mem_data[23:16];
                    2'b11: b = raw_mem_data[31:24];
                endcase
                final_mem_data = (mem_ext_u) ? {24'b0, b} : {{24{b[7]}}, b};
            end
            2'b01:begin //halfword
                hw = addr_offset[1] ? raw_mem_data[31:16] : raw_mem_data[15:0];
                final_mem_data = (mem_ext_u) ? {16'b0, hw} : {{16{hw[15]}}, hw};
            end
            2'b10:begin //word
                final_mem_data = raw_mem_data;
            end
            default: final_mem_data = raw_mem_data;
        endcase
    end

    wire [31:0] pc_plus_4 = pc + 32'd4;
    assign reg_write_data = (wb_sel == 2'b10) ? pc_plus_4 :
                            (wb_sel == 2'b01) ? final_mem_data:
                            alu_result;


    // =========================================================================
    // 极简地址路由 (Interconnect)
    // =========================================================================
    wire is_periph = (alu_result[31:28] == 4'h4); // 4打头，分配给 AXI 外设
    wire is_ram    = (alu_result[31:28] == 4'h0); // 0打头，分配给内部 RAM

    // 判断当前是否是真实的访存请求（Store 或 Load）
    // wb_sel == 2'b01 是咱们之前 Decoder 里定义的 Load 指令写回标志
    wire is_load = (wb_sel == 2'b01); 
    wire is_mem_req = mem_we || is_load;

    // AXI 桥接器的请求信号：是外设地址，且有访存需求
    wire axi_req = is_periph & is_mem_req;

    // RAM 的写使能保护：除了 stall 屏蔽，还要确保地址是 RAM 区域的
    wire [3:0] real_ram_we = (stall || !is_ram) ? 4'b0000 : ram_we;

    // =========================================================================
    // Stall (暂停) 机制真正接入
    // =========================================================================
    wire axi_stall;
    assign stall = axi_stall; // 替换掉之前写死的 0 

    // =========================================================================
    // 读数据 MUX：把外设读回来的数据和 RAM 读出来的数据合并，送给 LSU 去截取
    // =========================================================================
    wire [31:0] ram_rdata_out;
    wire [31:0] axi_rdata_out;
    // LSU 之前用的 raw_mem_data，现在变成了一个选择器

    // AXI4-Lite 总线连线
    wire [31:0] awaddr;
    wire        awvalid;
    wire        awready;
    wire [31:0] wdata;
    wire [3:0]  wstrb;
    wire        wvalid;
    wire        wready;
    wire [1:0]  bresp;
    wire        bvalid;
    wire        bready;
    wire [31:0] araddr;
    wire        arvalid;
    wire        arready;
    wire [31:0] rdata;
    wire [1:0]  rresp;
    wire        rvalid;
    wire        rready;

    // 1. Data RAM 例化 (保持原样，仅改名 rdata)
    data_ram u_data_ram (
        .clk   (clk),
        .we    (real_ram_we),
        .addr  (alu_result),
        .wdata (ram_wdata),
        .rdata (ram_rdata_out)
    );

    // 2. AXI Master 桥接器
    axi_master_bridge u_axi_master (
        .clk        (clk),
        .rst_n      (rst_n),
        .axi_error  (axi_error_led),
        
        // CPU 侧
        .cpu_req    (axi_req),
        .cpu_we     (mem_we),
        .cpu_addr   (alu_result),
        .cpu_wdata  (ram_wdata),
        .cpu_wstrb  (ram_we),
        .cpu_rdata  (axi_rdata_out),
        .cpu_stall  (axi_stall),
        
        // AXI 侧 (直接怼线)
        .aw_addr    (awaddr),  .aw_valid (awvalid), .aw_ready (awready),
        .w_data     (wdata),   .w_strb   (wstrb),   .w_valid  (wvalid),  .w_ready (wready),
        .b_resp     (bresp),   .b_valid  (bvalid),  .b_ready  (bready),
        .ar_addr    (araddr),  .ar_valid (arvalid), .ar_ready (arready),
        .r_data     (rdata),   .r_resp   (rresp),   .r_valid  (rvalid),  .r_ready (rready)
    );

    // 3. 原生 UART 硬件
    wire [7:0] uart_tx_data;
    wire       uart_tx_en;
    wire       uart_tx_busy;
    
    // 没用到 tx_ack 可以悬空不接
    uart_tx #(
        .CLK_FREQ(27_000_000), 
        .BAUD_RATE(115_200)
    ) u_uart_tx (
        .clk      (clk),
        .rst_n    (rst_n),
        .tx_start (uart_tx_en),
        .tx_data  (uart_tx_data),
        .tx       (uart_tx_pin),
        .tx_busy  (uart_tx_busy),
        .tx_ack   () 
    );

    // 4. AXI UART 从机包装器
    axi_uart_slave u_axi_uart_slave (
        .aclk         (clk),
        .aresetn      (rst_n),
        
        // AXI 侧
        .aw_addr      (awaddr),  .aw_valid   (awvalid), .aw_ready (awready),
        .w_data       (wdata),   .w_strb     (wstrb),   .w_valid  (wvalid),  .w_ready (wready),
        .b_resp       (bresp),   .b_valid    (bvalid),  .b_ready  (bready),
        .ar_addr      (araddr),  .ar_valid   (arvalid), .ar_ready (arready),
        .r_data       (rdata),   .r_resp     (rresp),   .r_valid  (rvalid),  .r_ready (rready),
        
        // 硬件驱动侧
        .uart_tx_data (uart_tx_data),
        .uart_tx_en   (uart_tx_en),
        .uart_tx_busy (uart_tx_busy)
    );

endmodule