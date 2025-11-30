	dsa_system u0 (
		.clk_clk                             (<connected-to-clk_clk>),                             //                          clk.clk
		.pio_leds_external_connection_export (<connected-to-pio_leds_external_connection_export>), // pio_leds_external_connection.export
		.reset_reset                         (<connected-to-reset_reset>),                         //                        reset.reset
		.sdram_addr                          (<connected-to-sdram_addr>),                          //                        sdram.addr
		.sdram_ba                            (<connected-to-sdram_ba>),                            //                             .ba
		.sdram_cas_n                         (<connected-to-sdram_cas_n>),                         //                             .cas_n
		.sdram_cke                           (<connected-to-sdram_cke>),                           //                             .cke
		.sdram_cs_n                          (<connected-to-sdram_cs_n>),                          //                             .cs_n
		.sdram_dq                            (<connected-to-sdram_dq>),                            //                             .dq
		.sdram_dqm                           (<connected-to-sdram_dqm>),                           //                             .dqm
		.sdram_ras_n                         (<connected-to-sdram_ras_n>),                         //                             .ras_n
		.sdram_we_n                          (<connected-to-sdram_we_n>)                           //                             .we_n
	);

