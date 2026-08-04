module pc_reg(
    input clk,
    input rst_n,
    input [31:0] imm,
    input [31:0] alu_result,
    input branch,
    input jump,
    input jump_reg,
    input zero,
    output reg [31:0] pc
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'b0;
        end else begin
            if(branch == 1 && zero ==1 || jump == 1)begin
                pc <= pc + imm;
            end else if (jump_reg == 1) begin
                pc <= {alu_result[31:1], 1'b0};
            end else begin
                pc <= pc + 32'd4;
            end
        end
    end
endmodule