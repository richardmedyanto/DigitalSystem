-- FIR filter order 7 --
-- coefficient: 8-bits --
-- input: 8-bits --
-- output: 8-bits --
-- Made by Richard Medyanto --

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_SIGNED.all;
use IEEE.NUMERIC_STD.all;

entity digitalfilter is
port(   clk: in std_logic; -- to i_clk
		shift_en: in std_logic; -- to r_RX_DV
        input: in std_logic_vector(7 downto 0); -- o_rx_byte
        output: out std_logic_vector(7 downto 0));
end digitalfilter;

architecture Behavioral of digitalfilter is
    signal count: std_logic;
    signal reg, reg0, reg1, reg2, reg3, reg4, reg5, reg6, reg7 : signed(7 downto 0);
    signal con, con0, con1, con2, con3 : signed(7 downto 0);
    signal mul : signed(15 downto 0);
    signal acc, add, tadd: signed(7 downto 0);
	 signal sel: std_logic_vector(3 downto 0);
begin

-- DETERMINE THE CONSTANTS/COEFFICIENTS FOR MULTIPLICATION --
-- design the filter in matlab (filter designer) --
-- then find the coefficients of the designed filter --
con0 <= "11111011"; -- -0.0390625 (should be -0.04077) = con7
con1 <= "00001110"; -- 0.109375 (should be 0.1103) = con6
con2 <= "00011011"; -- 0.2109375 (should be 0.2115) = con5
con3 <= "00100101"; -- 0.2890625 (should be 0.2925) = con4
-- con4 <= "00100101"; -- 0.2890625 (should be 0.2925)
-- con5 <= "00011011"; -- 0.2109375 (should be 0.2115)
-- con6 <= "00001110"; -- 0.109375 (should be 0.1103)
-- con7 <= "11111011"; -- -0.0390625 (should be -0.04077)

process(clk)
begin
    -- SHIFT REGISTER --
    if(rising_edge(clk)) then
    reg7 <= reg6;
    reg6 <= reg5;
    reg5 <= reg4;
    reg4 <= reg3;
    reg3 <= reg2;
    reg2 <= reg1;
    reg1 <= reg0;
    reg0 <= signed(input);
    end if;

    -- controller for counter
    if shift_en = '1' then -- rx_dv
        count <= '1';
    elsif sel = "1001" then -- counter: 9
        output <= std_logic_vector(acc);
    elsif sel = "1010" then -- counter: 10
        count <= '0';
    end if;

    -- counter
    if count = '0' or shift_en = '1' then
        sel <= (others => '0');
    elsif rising_edge(clk) and count = '1' then
        sel <= sel + 1;
    end if;
    
    -- multiplexer
    case sel is
        -- when "0000" => 0, clear accumulator
        when "0001" =>
            reg <= reg0;
            con <= con0;
        when "0010" =>
            reg <= reg1;
            con <= con1;
        when "0011" =>
            reg <= reg2;
            con <= con2;
        when "0100" =>
            reg <= reg3;
            con <= con3;
        when "0101" =>
            reg <= reg4;
            con <= con3; -- con4
        when "0110" =>
            reg <= reg5;
            con <= con2; -- con5
        when "0111" =>
            reg <= reg6;
            con <= con1; -- con6
        when "1000" =>
            reg <= reg7;
            con <= con0; -- con7
        -- when "1001" => 9, add to output (line 57)
        when others =>
            reg <= (others => '0');
            con <= (others => '0');
    end case;
    
    -- accumulate
    if count = '0' or shift_en = '1' then
        acc <= (others => '0');
    elsif (rising_edge(clk) and count = '1') then
        acc <= add;
    end if;
    
    -- prevent overflow
    if (mul(14) = '0' and acc(7) = '0' and tadd(7) = '1') then
        -- if positive + positive = negative
        add <= "01111111";
    elsif (mul(14) = '1' and acc(7) = '1' and tadd(7) = '0') then 
        -- if negative + negative = positive
        add <= "10000001";
    else
        add <= tadd;
    end if;

end process;

-- (1,7) * (1,7) = (2,14)
mul <= reg * con;

-- (1,7) + (1,7) = (1,7)
tadd <= mul(14 downto 7) + acc;

end Behavioral;
