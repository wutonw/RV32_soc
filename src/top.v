module top(
    input clk,
    input rst_n,

    output [31:0] inst_addr,
    input [31:0] inst
);

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
    assign stall = 1'b0;//暂时不暂停

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
                3'b10:begin //word
                    ram_wdata = rs2_data;
                    ram_we = 4'b1111;
                end
            endcase
        end
    end

    //LSU - load
    wire [31:0] raw_mem_data;
    reg  [31:0] final_mem_data;
    reg [7:0] b;
    always @(*)begin
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
                wire [15:0] hw = addr_offset[1] ? raw_mem_data[31:16] : raw_mem_data[15:0];
                final_mem_data = (mem_ext_u) ? {16'b0, hw} : {{16{hw[15]}}, hw};
            end
            2'b10:begin //word
                final_mem_data = raw_mem_data;
            end
            default: final_mem_data = raw_mem_data;
        endcase
    end

    wire [3:0] real_ram_we = stall ? 4'b0000 : ram_we;
    data_ram u_data_ram (
        .clk   (clk),
        .we    (real_ram_we),
        .addr  (alu_result),
        .wdata (ram_wdata),
        .rdata (raw_mem_data)
    );

    wire [31:0] pc_plus_4 = pc + 32'd4;
    assign reg_write_data = (wb_sel == 2'b10) ? pc_plus_4 :
                            (wb_sel == 2'b01) ? final_mem_data:
                            alu_result;
endmodule