--------------------------------------------------------------------------------
-- Authors:
-- 		Spyridon Poursalidis <s.poursalidis@gmail.com>
-- 
-- Description: 
-- 		A 3x3 Sobel Edge Detection HDL IP core featuring an AXI4-Stream video 
--    interface for real-time image processing in Xilinx FPGAs
--
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

entity sobel_3x3_core_axis is
generic(
  FIFO_DEPTH    : Integer := 2048;
  FIFO_MEM_TYPE : string  := "auto";
	PIXEL_WIDTH   : Integer := 8;
	FRAME_WIDTH	  : integer range 0 to 4095 := 1280;
	FRAME_HEIGHT  : integer range 0 to 2047 := 720
);
port (
	aclk 		      : in std_logic;
	aresetn 	    : in std_logic;
	enable		    : in std_logic;

	s_axis_tdata  : in std_logic_vector(PIXEL_WIDTH-1 downto 0);
	s_axis_tvalid : in std_logic;
	s_axis_tlast  : in std_logic;
	s_axis_tuser  : in std_logic;
	s_axis_tready : out std_logic;

	m_axis_tdata  : out std_logic_vector(PIXEL_WIDTH-1 downto 0);
	m_axis_tvalid : out std_logic;
	m_axis_tlast  : out std_logic;
	m_axis_tuser  : out std_logic;
	m_axis_tready : in  std_logic
);
end sobel_3x3_core_axis;

architecture rtl of sobel_3x3_core_axis is

function select_min2 (A0,A1: signed)
	return signed is
begin
	if A0 < A1 then return A0; else return A1; end if;
end select_min2;

function select_max2 (A0,A1: signed)
	return signed is
begin
	if A0 < A1 then return A1; else return A0; end if;
end select_max2;

type pixel_matrix    is array(1 to 9)            of signed(s_axis_tdata'length+2 downto 0);
type fifo_data_type  is array (natural range <>) of std_logic_vector;
type fifo_level_type is array (natural range <>) of Integer range 0 to 4095;

signal out_row_cnt  : integer range 0 to 2047 := 0;
signal out_col_cnt 	: integer range 0 to 4095 := 0;
signal column_edge  : std_logic;
signal first_row    : std_logic;
signal last_row     : std_logic;

signal fifo_wen    : std_logic_vector(1 downto 0);
signal fifo_rden   : std_logic_vector(1 downto 0);
signal fifo_full   : std_logic_vector(1 downto 0);
signal fifo_afull  : std_logic_vector(1 downto 0);
signal fifo_empty  : std_logic_vector(1 downto 0);
signal fifo_din    : fifo_data_type(1 downto 0) (s_axis_tdata'length-1 downto 0);
signal fifo_dout   : fifo_data_type(1 downto 0) (s_axis_tdata'length-1 downto 0);
signal fifo_level  : fifo_level_type(1 downto 0);

signal low_c       : fifo_data_type(0 to 2) (s_axis_tdata'length-1 downto 0);
signal mid_c       : fifo_data_type(0 to 2) (s_axis_tdata'length-1 downto 0);
signal top_c       : fifo_data_type(0 to 2) (s_axis_tdata'length-1 downto 0);
signal Magnitude   : signed(s_axis_tdata'length+2 downto 0);
signal tvalid      : std_logic_vector(3 downto 0);
signal sobel_pixel : std_logic_vector(m_axis_tdata'length-1 downto 0);

type state_type is (STORE_LINE_0_S, STORE_LINE_1_S, GEN_FRAME_OUT_S);
signal fsm_state : state_type := STORE_LINE_0_S;

signal sobel_en     : std_logic;

begin

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
-- Enable Logic
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
process(aclk)
begin
  if rising_edge(aclk) then
    if (aresetn = '0') then
      sobel_en <= enable;
    elsif (last_row = '1' and m_axis_tlast = '1' and m_axis_tvalid = '1' and m_axis_tready = '1') then
      sobel_en <= enable;
    end if;
  end if;
end process;

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
-- Row/Column counters
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
process(aclk)
begin
  if rising_edge(aclk) then

    if (aresetn = '0') then
      out_row_cnt <= 0;
      out_col_cnt <= 0;
    else

      if (m_axis_tvalid = '1' and m_axis_tready = '1') then
        if (m_axis_tlast = '1') then
          out_col_cnt <= 0;
        else
          out_col_cnt <= out_col_cnt + 1;
        end if;
      end if;

      if (m_axis_tvalid = '1' and m_axis_tready = '1' and m_axis_tlast = '1') then
        if (last_row = '1') then
          out_row_cnt <= 0;
        else
          out_row_cnt <= out_row_cnt + 1;
        end if;
      end if;

    end if;
  end if;
end process;

column_edge <= '1' when (out_col_cnt = 0 or out_col_cnt = FRAME_WIDTH-1) else '0';
first_row   <= '1' when (out_row_cnt = 0) else '0';
last_row    <= '1' when (out_row_cnt = FRAME_HEIGHT-1) else '0';

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
-- FIFO Logic
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
fifo_inst: FOR i in 0 to 1 generate
  xpm_fifo_inst: xpm_fifo_sync
    generic map(
      ECC_MODE            => "no_ecc",
      FIFO_MEMORY_TYPE    => FIFO_MEM_TYPE,
      USE_ADV_FEATURES    => "1000",
      DOUT_RESET_VALUE    => "0",
      FULL_RESET_VALUE    => 0,
      READ_MODE           => "fwft",
      FIFO_READ_LATENCY   => 0,
      WRITE_DATA_WIDTH    => PIXEL_WIDTH,
      FIFO_WRITE_DEPTH    => FIFO_DEPTH,
      READ_DATA_WIDTH     => PIXEL_WIDTH
    )
    port map (
      wr_clk              => aclk,
      rst                 => not(aresetn),
      wr_en               => fifo_wen(i),
      din                 => fifo_din(i),
      full                => fifo_full(i),
      rd_en               => fifo_rden(i),
      dout                => fifo_dout(i),
      empty               => fifo_empty(i),
      data_valid          => open,
      almost_empty        => open,
      almost_full         => open,
      dbiterr             => open,
      overflow            => open,
      prog_empty          => open,
      prog_full           => open,
      rd_data_count       => open,
      rd_rst_busy         => open,
      sbiterr             => open,
      underflow           => open,
      wr_ack              => open,
      wr_data_count       => open,
      wr_rst_busy         => open,
      injectdbiterr       => '0',
      injectsbiterr       => '0',
      sleep               => '0'
    );
end generate fifo_inst;

s_axis_tready <= m_axis_tready when (sobel_en = '0') else
                 not(fifo_afull(1)) when (fsm_state = STORE_LINE_0_S) else 
                 not(fifo_afull(0)) when (fsm_state = STORE_LINE_1_S) else
                 '0' when (s_axis_tuser = '1' and m_axis_tuser = '0') else 
                 not(fifo_full(0)) and m_axis_tready;

-- Write into FIFO 0
fifo_din(0)  <= s_axis_tdata;

fifo_wen(0)  <= '0' when (sobel_en = '0' or fsm_state = STORE_LINE_0_S) else 
                s_axis_tvalid and s_axis_tready;

-- Write into FIFO 1
fifo_din(1)  <= s_axis_tdata when (fsm_state = STORE_LINE_0_S) else 
                fifo_dout(0);

fifo_wen(1) <= '0' when (last_row = '1' or sobel_en = '0') else
               s_axis_tvalid and s_axis_tready when (fsm_state = STORE_LINE_0_S) else
               fifo_rden(0);

-- Calculate FIFO fill level
-- We calculate it ourselves, because the FIFOs internal counters
-- have a delay of 2cc
process(aclk)
begin
  if rising_edge(aclk) then
    if (aresetn = '0') then
      fifo_level  <= (others => 0);
    else 
      for i in 0 to 1 loop

        if (fifo_wen(i) = '1' and fifo_rden(i) = '0') then
          -- Increase FIFO level counter
          fifo_level(i) <= fifo_level(i) + 1;
        elsif (fifo_wen(i) = '0' and fifo_rden(i) = '1') then
          -- Decrease FIFO level counter
          fifo_level(i) <= fifo_level(i) - 1;
        end if;

      end loop;
    end if;
  end if;
end process;

-- Set FIFO almost full flag
-- We don't use the FIFOs prog full signal, because it doesn't
-- work as expected
tt: for i in 0 to 1 generate
	fifo_afull(i) <= '1' when (fifo_level(i) = FRAME_WIDTH) else '0';
end generate tt;

fifo_rden(0) <= m_axis_tready when (fifo_empty = "00" and fsm_state = GEN_FRAME_OUT_S) else 
                '0';

fifo_rden(1) <= not(fifo_empty(1)) when (last_row = '1') else 
                fifo_rden(0);

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
-- Control FSM and perform sobel calculations
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
process(aclk)
  variable P     : pixel_matrix := (others => (others => '0'));
  variable G_x   : signed(s_axis_tdata'length+2 downto 0);
  variable G_y   : signed(s_axis_tdata'length+2 downto 0);
  variable max_G : signed(s_axis_tdata'length+2 downto 0);
  variable min_G : signed(s_axis_tdata'length+2 downto 0);
  variable mult  : signed(2*s_axis_tdata'length+5 downto 0);
  variable div   : signed(2*s_axis_tdata'length+5 downto 0);
begin

  if rising_edge(aclk) then

    if (aresetn = '0') then

      fsm_state   <= STORE_LINE_0_S;
      tvalid      <= (others => '0');
      low_c       <= (others => (others => '0'));
      mid_c       <= (others => (others => '0'));
      top_c       <= (others => (others => '0'));
      Magnitude   <= (others => '0');
      sobel_pixel <= (others => '0');

    else

      case (fsm_state) is

        when STORE_LINE_0_S =>

          tvalid      <= (others => '0');
          low_c       <= (others => (others => '0'));
          mid_c       <= (others => (others => '0'));
          top_c       <= (others => (others => '0'));
          Magnitude   <= (others => '0');
          sobel_pixel <= (others => '0');

          -- Line 0 is stored within FIFO 1
          if (sobel_en = '1' and fifo_afull(1) = '1') then
            fsm_state <= STORE_LINE_1_S;
          end if;

        when STORE_LINE_1_S =>

          tvalid      <= (others => '0');
          low_c       <= (others => (others => '0'));
          mid_c       <= (others => (others => '0'));
          top_c       <= (others => (others => '0'));
          Magnitude   <= (others => '0');
          sobel_pixel <= (others => '0');

          -- Line 1 is stored within FIFO 0
          if (fifo_afull(0) = '1') then
            fsm_state <= GEN_FRAME_OUT_S;
          end if;

        when GEN_FRAME_OUT_S =>

          if (last_row = '1' and m_axis_tlast = '1' and m_axis_tvalid = '1' and m_axis_tready = '1') then
            fsm_state  <= STORE_LINE_0_S;
          end if;

          if (m_axis_tready = '1' and last_row = '0') then

            -------------------------------------------------------------------------------
            --                               Stage 0
            -------------------------------------------------------------------------------
            -- The data is stored within our module the following way:
            --
            --	  Lower Line  	         Middle Line              Top Line
            --      		  		            ________                ________ 
            --                           |	      |              |        |
            --   s_axis_tdata ----+----> | FIFO 0 | -----+-----> | FIFO 1 |------+
            --                    |      |________| 	   |	   	 |________|      |
            --                    |                      |                       |
            --                    v                      v                       v
            --                  [2-cc]                 [2-cc]                  [2-cc]
            --                    |                      |                       |
            --                 low (0-2)              mid (0-2)               top (0-2)
            --
            -------------------------------------------------------------------------------
            tvalid(0) <= fifo_rden(0);

            if (fifo_rden(0) = '1') then
              low_c(0) <= fifo_din(0);
              mid_c(0) <= fifo_dout(0);
              top_c(0) <= fifo_dout(1);
            end if;

            -------------------------------------------------------------------------------
            --                              Stage 1
            -------------------------------------------------------------------------------
            tvalid(1) <= tvalid(0);
            low_c(1)  <= low_c(0);
            mid_c(1)  <= mid_c(0);
            top_c(1)  <= top_c(0);

            -------------------------------------------------------------------------------
            --                              Stage 2
            -------------------------------------------------------------------------------
            tvalid(2) <= tvalid(1);
            low_c(2)  <= low_c(1);
            mid_c(2)  <= mid_c(1);
            top_c(2)  <= top_c(1);

            -------------------------------------------------------------------------------
            --                              Stage 3
            -------------------------------------------------------------------------------
            -- We have the following pixel configration:
            --
            --	            Index:     2    1    0
            --                      | P1 | P4 | P7 | --> Upper  Line
            --                      | P2 | P5 | P8 | --> Middle Line
            --                      | P3 | P6 | P9 | --> Lower  Line
            --
            -- In this design we will use the Alpha Max Linear approximation:
            --
            --          |G| = max(|G_x|,|G_y|) + 0,375 x min(|G_x|,|G_y|)
            --              = max(|G_x|,|G_y|) + (384 x min(|G_x|,|G_y|) / 1024)
            --              = max(|G_x|,|G_y|) + (384 x min(|G_x|,|G_y|)) >> 10
            --
            -- where:
            --
            --            G_x = P(3) - P(1) + 2 * (P(6) - P(4)) + P(9) - P(7)
            --            G_y = P(9) + P(7) + 2 * (P(8) - P(2)) - P(3) - P(1)
            -------------------------------------------------------------------------------
            P(1) := "000" & signed(top_c(2));
            P(2) := "000" & signed(mid_c(2));
            P(3) := "000" & signed(low_c(2));

            P(4) := "000" & signed(top_c(1));
            P(5) := "000" & signed(mid_c(1));
            P(6) := "000" & signed(low_c(1));

            P(7) := "000" & signed(top_c(0));
            P(8) := "000" & signed(mid_c(0));
            P(9) := "000" & signed(low_c(0));

            tvalid(3) <= tvalid(2);
            G_x       := P(3) - P(1) + shift_left(P(6)-P(4), 1) + P(9) - P(7);
            G_y       := P(9) + P(7) + shift_left(P(8)-P(2), 1) - P(3) - P(1);
            max_G     := select_max2(abs(G_x),abs(G_y));
            min_G     := select_min2(abs(G_x),abs(G_y));	
            mult      := 384*min_G;
            div		    := shift_right(mult,10);
            Magnitude <= max_G + div(10 downto 0);

            -------------------------------------------------------------------------------
            --                              Stage 4
            -------------------------------------------------------------------------------
            sobel_pixel <= (others => '0') when (Magnitude < 0) else
                           (others => '1') when (Magnitude > 255) else
                           std_logic_vector(Magnitude(m_axis_tdata'length-1 downto 0));

          end if;

        when others =>
          fsm_state   <= STORE_LINE_0_S;
          tvalid      <= (others => '0');
          low_c       <= (others => (others => '0'));
          mid_c       <= (others => (others => '0'));
          top_c       <= (others => (others => '0'));
          Magnitude   <= (others => '0');
          sobel_pixel <= (others => '0');

      end case;

    end if;

  end if;
end process;

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
-- Output Signals
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
m_axis_tdata <= s_axis_tdata when (sobel_en = '0') else
                (others => '0') when (column_edge = '1' or first_row = '1' or last_row = '1') else 
                sobel_pixel;

m_axis_tvalid <= s_axis_tvalid when (sobel_en = '0') else
                 '0' when (fsm_state = STORE_LINE_1_S) else
                 '1' when (aresetn = '1' and (first_row = '1' or last_row = '1')) else
                 tvalid(3);

m_axis_tuser  <= '1' when (out_col_cnt = 0 and out_row_cnt = 0) else '0';
m_axis_tlast  <= '1' when (out_col_cnt = FRAME_WIDTH-1) else '0';

end rtl;