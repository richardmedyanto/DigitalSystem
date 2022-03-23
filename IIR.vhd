-- IIR filter order 6 --
-- coefficient: 16-bits --
-- input: 8-bits --
-- output: 8-bits --
-- Made by Richard Medyanto --

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_SIGNED.all;
use IEEE.NUMERIC_STD.all;

entity digitalfilteriir is
    generic(
		x : INTEGER := 8;
		y : INTEGER := 8
	);
    port(   RST: in std_logic;
            clk: in std_logic; -- i_clk
            shift_en: in std_logic; -- r_RX_DV
            input: in std_logic_vector(x-1 downto 0); -- o_rx_byte
            output: out std_logic_vector(x-1 downto 0));
end digitalfilteriir;

architecture Behavioral of digitalfilteriir is
    signal p5_en, p10_en, p15_en, ACC_CLR, count: std_logic;
    signal sel: std_logic_vector(4 downto 0);
    signal p1, p2, p3, p4, p5, p8, p9, p10, p13, p14, p15, mx: signed(x-1 downto 0);
    signal acc, add, tadd, coeff: signed(y-1 downto 0);
    signal mult: signed((x+y)-1 downto 0);
    signal tmult: std_logic_vector((x+y)-1 downto 0);
	signal cdiv: std_logic_vector(4 downto 0);
	signal cclk: std_logic;
    signal a : unsigned(x-1 downto 0);
    signal b : unsigned(y-1 downto 0);
    signal s : unsigned(x+y downto 0);
    signal incre : integer:= (x+y)/2; 
    signal run : std_logic := '0';
	signal valid, start : std_logic;
begin

process(clk)
begin
    -- shift register --
    if (shift_en  = '1' and rising_edge(clk)) then
        p1 <= signed(input);
        p2 <= p1;
        -- p3 = p6
        -- p4 = p7
        p3 <= p5;
        p4 <= p3;
        -- p8 = p11
        -- p9 = p12
        p8 <= p10;
        p9 <= p8;
        p13 <= p15;
        p14 <= p13;
    end if;

    -- p5 register
    if (falling_edge(clk) and p5_en = '1') then
        p5 <= acc((x+y)-1 downto x);
    end if;

    -- p10 register
    if (falling_edge(clk) and p10_en = '1') then
        p10 <= acc((x+y)-1 downto x);
    end if;

    -- p15 register
    if (falling_edge(clk) and p15_en = '1') then
        p15 <= acc((x+y)-1 downto x); 
    end if;
    
    -- accumulator:
    if ACC_CLR = '1' then
        acc <= (others => '0');
    elsif (rising_edge(clk) and count = '1' and valid = '1') then
        acc <= add;
    end if;
    
    -- prevent overflow for adder:
    if (mult((x+y)-2) = '0' and acc(y-1) = '0' and tadd(y-1) = '1') then
        -- if positive + positive = negative
        add <= "01111111";
    elsif (mult((x+y)-2) = '1' and acc(y-1) = '1' and tadd(y-1) = '0') then 
        -- if negative + negative = positive
        add <= "10000001";
    else
        add <= tadd;
    end if;
    
    -- controller for counter
    if shift_en = '1' then -- rx_dv
        count <= '1';
        start <= '1';
    elsif sel = "10110" then -- clock 22
        count <= '0';
        start <= '0';
    end if;

	 if rst='1' then
		cdiv <= (others => '0');
	 elsif rising_edge(clk) then
		cdiv <= cdiv + 1;
		if cdiv > "0111" then
			cclk <= not cclk;
		end if;
	 end if;
	 
    -- counter
    if count = '0' then
        sel <= (others => '0');
    elsif rising_edge(cclk) and count = '1' then
        sel <= sel + 1;
    end if;

    -- comparator
    if sel = "00000" or sel = "00111" or sel = "01110" or sel = "10101" then
        -- clear accumulator
        ACC_CLR <= '1';
    elsif sel = "00110" then -- 6
        p5_en <= '1';
    elsif sel = "01101" then -- 13
        p10_en <= '1';
    elsif sel = "10100" then -- 20
        p15_en <= '1';
    else
        ACC_CLR <= '0';
        p5_en <= '0';
        p10_en <= '0';
        p15_en <= '0';
    end if;

    -- multiplexer
    case sel is
        -- when "00000" => 0, clear accumulator
        when "00001" => -- 1
            mx <= signed(input); -- p0
            coeff <= "10100110"; -- b00
        when "00010" => -- 2
            mx <= p1;
            coeff <= "00011101"; -- b01
        when "00011" => -- 3
            mx <= p2;
            coeff <= "10100110"; -- b02
        when "00100" => -- 4
            mx <= p3;
            coeff <= "00011101"; -- -a01
        when "00101" => -- 5
            mx <= p4;
            coeff <= "00011101"; -- -a02
        -- when "00110" => 6, add 1st section accumulator to p5
        -- when "00111" => 7, clear accumulator
        when "01000" => -- 8
            mx <= p5;
            coeff <= "10100110"; -- b10
        when "01001" => -- 9
            mx <= p3;
            coeff <= "00011101"; -- b11
        when "01010" => -- 10
            mx <= p4;
            coeff <= "10100110"; -- b12
        when "01011" => -- 11
            mx <= p8;
            coeff <= "00011101"; -- -a11
        when "01100" => -- 12
            mx <= p9;
            coeff <= "10100110"; -- -a12
        -- when "01101" => 13, add 2nd section accumulator to p10
        -- when "01110" => 14, clear accumulator
        when "01111" => -- 15
            mx <= p10;
            coeff <= "00011101"; -- b20
        when "10000" => -- 16
            mx <= p8;
            coeff <= "10100110"; -- b21
        when "10001" => -- 17
            mx <= p9;
            coeff <= "00011101"; -- b22
        when "10010" => -- 18
            mx <= p13;
            coeff <= "00011101"; -- -a21
        when "10011" => -- 19
            mx <= p14;
            coeff <= "10100110"; -- -a22
        -- when "10100" => 20, add 3rd section accumulator to p15
        -- when "10101" => 21, clear accumulator
        when others =>
            -- clear accumulator
            mx <= (others => '0');
            coeff <= (others => '0');
    end case;

end process;

-- (1,7) * (1,15) = (2,22)
-- mult <= x * coeff;

process(CLK)
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                a <= (others => '0');
                b <= (others => '0');
                s <= (others => '0');
                incre <= 0;
                run <= '0';
                valid <= '0';
                tmult <= (others => '0');
            else
                if run = '1' then
                    if incre = 0 then
                        tmult(x+y-1 downto 0) <= std_logic_vector(s(x+y downto 1));
                        run <= '0';
                        valid <= '1';
                    else 
                        if(s(1) = '1' and s(0) = '0') then
                            b <= s(x+y downto (x+y)/2+1); -- 16 downto 9
                            s(x+y downto (x+y)/2+1) <= (b(y-1 downto 0) - a(x-1 downto 0));
                        elsif (s(1) = '0' and s(0) = '1') then
                            b <= (s(x+y downto (x+y)/2+1));
                            s(x+y downto (x+y)/2+1) <= (b(y-1 downto 0) + a(x-1 downto 0));
                        end if;
                        s(x+y-1 downto 0) <= s(x+y downto 1);
                        incre <= incre - 1; -- counting down can save logic
                    end if;
                elsif start = '1' then
                    a <= unsigned(mx);
                    s <= (others => '0');
                    s((x+y)/2 downto 1) <= unsigned(coeff);
                    incre <= (x+y)/2;
                    run <= '1';
                    valid <= '0';
                    tmult <= (others => '0');
                end if;
            end if;
        end if;
		  
		  if(rising_edge(clk) and valid = '1') then
				mult <= signed(tmult);
		  end if;
		  
    end process;


-- temporary add: to prevent overflow
-- x=8, y=16
-- (22 - (15)=7)
tadd <= mult((x+y)-2 downto x-1) + acc;

output <= std_logic_vector(p15);

end Behavioral;
