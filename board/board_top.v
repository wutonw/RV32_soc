module board_top (
    input  wire clk,
    input  wire raw_rst_n,
    output wire uart_tx_pin,
    output wire axi_error_led
);
    wire [31:0] inst_addr;
    wire [31:0] inst;

    top u_cpu (
        .clk           (clk),
        .raw_rst_n     (raw_rst_n),
        .inst_addr     (inst_addr),
        .inst          (inst),
        .uart_tx_pin   (uart_tx_pin),
        .axi_error_led (axi_error_led)
    );

    fpga_inst_rom u_inst_rom (
        .addr (inst_addr),
        .inst (inst)
    );
endmodule
