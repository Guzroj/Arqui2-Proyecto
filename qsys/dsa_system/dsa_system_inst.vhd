	component dsa_system is
		port (
			clk_clk                             : in  std_logic                    := 'X'; -- clk
			pio_leds_external_connection_export : out std_logic_vector(9 downto 0);        -- export
			reset_reset                         : in  std_logic                    := 'X'  -- reset
		);
	end component dsa_system;

	u0 : component dsa_system
		port map (
			clk_clk                             => CONNECTED_TO_clk_clk,                             --                          clk.clk
			pio_leds_external_connection_export => CONNECTED_TO_pio_leds_external_connection_export, -- pio_leds_external_connection.export
			reset_reset                         => CONNECTED_TO_reset_reset                          --                        reset.reset
		);

