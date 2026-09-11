library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vhdl_tb_lib;
use vhdl_tb_lib.vhdl_tb_pkg.all;

entity tb_sobel_3x3_core_axis is
end entity tb_sobel_3x3_core_axis;

architecture rtl of tb_sobel_3x3_core_axis is
 
 signal aclk : std_logic := '0';
 signal aresetn : std_logic := '0';
 signal enable : std_logic := '0';
 signal s_axis_video_tdata : std_logic_vector(7 downto 0);
 signal s_axis_video_tvalid : std_logic;
 signal s_axis_video_tready : std_logic := '1';
 signal s_axis_video_tlast : std_logic;
 signal s_axis_video_tuser : std_logic;
 signal m_axis_video_tdata : std_logic_vector(7 downto 0) := (others => '0');
 signal m_axis_video_tvalid : std_logic := '0';
 signal m_axis_video_tready : std_logic := '1';
 signal m_axis_video_tlast : std_logic := '0';
 signal m_axis_video_tuser : std_logic  := '0';

 signal in_frame_done : std_logic  := '0';

begin

    --------------------------------------------------
    -- generate clock
    --------------------------------------------------
    process begin gen_clock(aclk, 3.33 ns); end process;

    --------------------------------------------------
    -- generate reset
    --------------------------------------------------
    process begin gen_resetn(aclk, aresetn); end process;
        
    --------------------------------------------------
    -- main
    --------------------------------------------------
    stimulus: process is
    begin
        -- wait until reset cleared
        wait until aresetn = '1';

        -- wait 10 clock cycles
        wait_n_cycles(aclk, 10);

        -- write your test here
        --
        --
        loop
            wait for 3 ms;
            enable <= not(enable);
            -- wait for 1 ms;
            -- m_axis_video_tready <= '0';
            -- wait_n_cycles(aclk, 5);
            -- m_axis_video_tready <= '1';
        end loop;

        wait;
    end process;

    --------------------------------------------------
    -- device-under-test (DuT)
    --------------------------------------------------
    dut: entity work.sobel_3x3_core_axis
    generic map (
        FRAME_WIDTH	 => 1280,
        FRAME_HEIGHT => 1024
    )
    port map ( 
        aclk          => aclk,
        aresetn       => aresetn,
        enable        => enable,
        s_axis_tdata  => s_axis_video_tdata,
        s_axis_tvalid => s_axis_video_tvalid,
        s_axis_tready => s_axis_video_tready,
        s_axis_tlast  => s_axis_video_tlast,
        s_axis_tuser  => s_axis_video_tuser,

        m_axis_tdata  => m_axis_video_tdata,
        m_axis_tvalid => m_axis_video_tvalid,
        m_axis_tready => m_axis_video_tready,
        m_axis_tlast  => m_axis_video_tlast,
        m_axis_tuser  => m_axis_video_tuser
    );

    --------------------------------------------------
    -- Read OSD frame
    --------------------------------------------------
    rd_osd: entity vhdl_tb_lib.read_file_axis
    generic map ( 
        input_file      => "input_frame.hex",
        FRAME_WIDTH     => 1280,
        FRAME_HEIGHT    => 1024,
        PIXEL_PER_WORD  => 1
    )
    port map (
        clk     => aclk,
        resetn  => aresetn,
        done    => in_frame_done,
        tdata   => s_axis_video_tdata,
        tvalid  => s_axis_video_tvalid,
        tready  => s_axis_video_tready,
        tuser   => s_axis_video_tuser,
        tlast   => s_axis_video_tlast
    );

    --------------------------------------------------
    -- Write output frame
    --------------------------------------------------
    wr_file: entity vhdl_tb_lib.write_file_axis
    generic map ( 
        output_file  => "output_frame",
        FRAME_HEIGHT => 1024
    )
    port map (
        clk     => aclk,
        tdata   => m_axis_video_tdata,
        tvalid  => m_axis_video_tvalid,
        tready  => m_axis_video_tready,
        tuser   => m_axis_video_tuser,
        tlast   => m_axis_video_tlast
    );

end rtl;