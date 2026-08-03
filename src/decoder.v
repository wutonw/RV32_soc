// Opcode 宏定义 (标准 RISC-V RV32I 定义)
`define OP_R_TYPE   7'b0110011  // ADD, SUB, AND, OR 等
`define OP_I_TYPE   7'b0010011  // ADDI, ANDI 等
`define OP_LOAD     7'b0000011  // LW 等
`define OP_STORE    7'b0100011  // SW 等
`define OP_BRANCH   7'b1100011  // BEQ, BNE 等
`define OP_LUI      7'b0110111  // LUI
`define OP_AUIPC    7'b0010111  // AUIPC
`define OP_JAL      7'b1101111  // JAL
`define OP_JALR     7'b1100111

module decoder(
    input [31:0] inst,//machine code instruction

    //register file interface
    output [4:0] rs1_addr,
    output [4:0] rs2_addr,
    output [4:0] rd_addr,

    //control signals
    output reg reg_we,//resgister write enable
    output reg alu_src,//0:rs2_data,1:imm
    output reg [3:0] alu_op,//ALU operation
    output reg mem_we,//memory wr_en
    output reg [1:0] wb_sel//00:alu_result, 01:mem_data, 10:PC+4

    //pc jump control signals
    output reg branch,
    output reg jump,
    output reg jump_reg
);

    wire [6:0] opcode = inst[6:0];
    wire [2:0] funct3 = inst[14:12];
    wire [6:0] funct7 = inst[31:25];

    assign rd_addr  = inst[11:7];
    assign rs1_addr = inst[19:15];
    assign rs2_addr = inst[24:20];

    always @(*)begin
        //default values
        reg_we     = 1'b0;
        alu_src    = 1'b0;  //default rs2
        alu_op     = `ALU_ADD;
        mem_we     = 1'b0;
        wb_sel     = 2'b00;
        branch     = 1'b0;
        jump       = 1'b0;
        jump_reg   = 1'b0;

        case(opcode)
            //R-Type
            `OP_R_TYPE:begin
                reg_we = 1'b1;//to regfile
                alu_src = 1'b0;//rs2
                mem_we = 1'b0;//not to memory
                wb_sel = 2'b00;//from alu

                case (funct3)
                    3'b000:  alu_op = (funct7[5]) ? `ALU_SUB : `ALU_ADD; // funct7[5]==1 -> SUB
                    3'b111:  alu_op = `ALU_AND;
                    3'b110:  alu_op = `ALU_OR;
                    3'b010:  alu_op = `ALU_SLT;
                    default: alu_op = `ALU_ADD;
                endcase
            end

            //I-Type
            `OP_I_TYPE:begin
                reg_we =1'b1;
                alu_src = 1'b1;//imm
                mem_we =1'b0;
                wb_sel =2'b00;

                case (funct3)
                    3'b000: alu_op = `ALU_ADD; // ADDI
                    3'b111: alu_op = `ALU_AND; // ANDI
                    3'b110: alu_op = `ALU_OR;  // ORI
                    default: alu_op = `ALU_ADD;
                endcase
            end

            //Load
            `OP_LOAD:begin
                reg_we =1'b1;
                alu_src = 1'b1;//add+imm_offest
                alu_op = `ALU_ADD;
                mem_we =1'b0;
                wb_sel =2'b01;//from memory
            end

            //Store
            `OP_STORE:begin
                reg_we =1'b0;
                alu_src = 1'b1;//add+imm_offest
                alu_op = `ALU_ADD;
                mem_we =1'b1;//to memory
                wb_sel =2'b00;
            end

            //Branch(BEQ)
            `OP_BRANCH:begin
                reg_we =1'b0;
                alu_src = 1'b0;//rs2
                alu_op = `ALU_SUB;//compare rs1 and rs2 (zero flag)
                mem_we =1'b0;
                wb_sel =2'b00;
                branch = 1'b1;
            end

            //JAL
            `OP_JAL:begin
                reg_we =1'b1;//pc=pc+4 保存返回地址
                alu_src = 1'b0;
                alu_op = `ALU_ADD;
                mem_we =1'b0;
                wb_sel =2'b10;//pc+4
                jump = 1'b1;
            end

            //JALR
            `OP_JALR:begin
                reg_we =1'b1;//pc=pc+4 保存返回地址
                alu_src = 1'b1;//rs1+imm
                alu_op = `ALU_ADD;
                mem_we =1'b0;
                wb_sel =2'b10;//pc+4
                jump_reg = 1'b1;
            end

            default: ;
        endcase

    end

endmodule