module data_ram(
    input clk,
    input we,//from mem_we(decoder)
    input [31:0] addr,
    input [31:0] wdata,
    output reg [31:0] rdata
);
    //1KB RAM
    reg [31:0] ram [0:255];
    //word address , addr / 4
    wire [7:0] word_index = addr[9:2];

    always @(posedge clk) begin
        if (we) begin
            ram[word_index] <= wdata;
        end
    end
    assign rdata = ram[word_index];
endmodule