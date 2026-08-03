module pc_reg(
    input clk,
    input rst_n,
    output reg [31:0] pc
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'b0;
        end else begin
            pc <= pc + 4;
        end
    end
endmodule