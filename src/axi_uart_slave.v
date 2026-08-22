module axi_uart_slave(
    input aclk,
    input aresetn,

    //AW
    input [31:0] aw_addr,
    input aw_valid,
    output aw_ready,

    //W
    input [31:0] w_data,
    input [3:0] w_strb,
    input w_valid,
    output w_ready,

    //B
    output [1:0] b_resp,
    output reg b_valid,
    input b_ready,

    //AR & R
    input [31:0] ar_addr,
    input ar_valid,
    output ar_ready,
    output [31:0] r_data,
    output [1:0] r_resp,
    output r_valid,
    input r_ready,

    output reg [7:0] uart_tx_data,
    output reg uart_tx_en,
    input uart_tx_busy
);
    localparam UART_BASE_ADDR = 32'h4000_0000;

    wire write_req = aw_valid && w_valid;

    wire aw_ready = write_req&&(!uart_tx_busy)&&(!b_valid);
    wire w_ready = write_req&&(!uart_tx_busy)&&(!b_valid);

    wire write_fire = aw_ready && w_ready && aw_valid && w_valid;

    always @(posedge aclk or negedge aresetn)begin
        if(!aresetn)begin
            uart_tx_data <= 0;
            uart_tx_en <= 0;
            b_valid <= 0;
        end else begin
            uart_tx_en <= 1'b0;
            if(write_fire)begin
                if(aw_addr == UART_BASE_ADDR)begin
                    uart_tx_data <= w_data [7:0];
                    uart_tx_en <= 1;
                end
                b_valid <= 1;
            end
            if(b_valid&&b_ready)begin
                b_valid <= 0;
            end
        end
    end

    assign b_resp = (aw_addr == UART_BASE_ADDR) ? 2'b00 : 2'b10;
    //R channel
    assign ar_ready = 1'b0;
    assign r_valid  = 1'b0;
    assign r_data   = 32'b0;
    assign r_resp   = 2'b00;
endmodule