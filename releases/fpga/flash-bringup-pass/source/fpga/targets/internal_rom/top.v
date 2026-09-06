module top (
    input  wire [15:0] gb_a,      // Game Boy address bus A0..A15
    output wire [7:0]  gb_d,      // FPGA -> level shifter -> Game Boy D0..D7
    // input  wire        gb_wr_n, // /WR from Game Boy
    input  wire        gb_rd_n,    // /RD from Game Boy
    // input  wire        gb_cs_n, // /CS from Game Boy
    // input  wire        gb_res_n,// /RES from Game Boy

    // /OE data-bus level shifter (SN74LVC8T245)
    // 0 = shifter enabled
    // 1 = outputs disconnected / Hi-Z
    output wire        data_oe_n,
    output wire        data_dir
);

    reg [7:0] rom_data;

    // ------------------------------------------------------------
    // The Game Boy is reading the ROM cartridge address space.
    //
    // ROM cartridge space:
    // $0000-$7FFF
    //
    // /RD active LOW.
    // ------------------------------------------------------------

    wire rom_read;

    assign rom_read =
        (!gb_rd_n) &&
        (gb_a < 16'h8000);


    // During ROM reads, the data bus direction is:
    // FPGA -> Game Boy

    assign data_dir = 1'b1;

    // ------------------------------------------------------------
    // The FPGA continuously presents rom_data to the SN74LVC8T245 input.
    //
    // The level shifter drives the Game Boy bus only while data_oe_n is low.
    // ------------------------------------------------------------

    assign gb_d = rom_data;


    // ------------------------------------------------------------
    // SN74LVC8T245 /OE control.
    //
    // During a ROM read:
    //     rom_read   = 1
    //     data_oe_n  = 0
    //
    // At all other times:
    //     data_oe_n  = 1
    //
    // The level shifter releases Game Boy D0..D7.
    // ------------------------------------------------------------

    assign data_oe_n = !rom_read;


    // ------------------------------------------------------------
    // Minimal Game Boy ROM
    // ------------------------------------------------------------

    always @(*) begin

        // Unspecified ROM addresses return $00.
        rom_data = 8'h00;

        case (gb_a)

            // ====================================================
            // $0100-$0103
            //
            // Entry point:
            //
            //   $0100: NOP
            //   $0101: JP $0150
            // ====================================================

            16'h0100: rom_data = 8'h00; // NOP
            16'h0101: rom_data = 8'hC3; // JP nn
            16'h0102: rom_data = 8'h50; // low byte
            16'h0103: rom_data = 8'h01; // high byte


            // ====================================================
            // $0104-$0133
            //
            // Nintendo logo required by the DMG boot ROM
            // ====================================================

            16'h0104: rom_data = 8'hCE;
            16'h0105: rom_data = 8'hED;
            16'h0106: rom_data = 8'h66;
            16'h0107: rom_data = 8'h66;
            16'h0108: rom_data = 8'hCC;
            16'h0109: rom_data = 8'h0D;
            16'h010A: rom_data = 8'h00;
            16'h010B: rom_data = 8'h0B;
            16'h010C: rom_data = 8'h03;
            16'h010D: rom_data = 8'h73;
            16'h010E: rom_data = 8'h00;
            16'h010F: rom_data = 8'h83;

            16'h0110: rom_data = 8'h00;
            16'h0111: rom_data = 8'h0C;
            16'h0112: rom_data = 8'h00;
            16'h0113: rom_data = 8'h0D;
            16'h0114: rom_data = 8'h00;
            16'h0115: rom_data = 8'h08;
            16'h0116: rom_data = 8'h11;
            16'h0117: rom_data = 8'h1F;
            16'h0118: rom_data = 8'h88;
            16'h0119: rom_data = 8'h89;
            16'h011A: rom_data = 8'h00;
            16'h011B: rom_data = 8'h0E;

            16'h011C: rom_data = 8'hDC;
            16'h011D: rom_data = 8'hCC;
            16'h011E: rom_data = 8'h6E;
            16'h011F: rom_data = 8'hE6;
            16'h0120: rom_data = 8'hDD;
            16'h0121: rom_data = 8'hDD;
            16'h0122: rom_data = 8'hD9;
            16'h0123: rom_data = 8'h99;
            16'h0124: rom_data = 8'hBB;
            16'h0125: rom_data = 8'hBB;
            16'h0126: rom_data = 8'h67;
            16'h0127: rom_data = 8'h63;

            16'h0128: rom_data = 8'h6E;
            16'h0129: rom_data = 8'h0E;
            16'h012A: rom_data = 8'hEC;
            16'h012B: rom_data = 8'hCC;
            16'h012C: rom_data = 8'hDD;
            16'h012D: rom_data = 8'hDC;
            16'h012E: rom_data = 8'h99;
            16'h012F: rom_data = 8'h9F;
            16'h0130: rom_data = 8'hBB;
            16'h0131: rom_data = 8'hB9;
            16'h0132: rom_data = 8'h33;
            16'h0133: rom_data = 8'h3E;


            // ====================================================
            // $0134-$0143
            //
            // Game title: "FPGA TEST"
            // ====================================================

            16'h0134: rom_data = 8'h46; // F
            16'h0135: rom_data = 8'h50; // P
            16'h0136: rom_data = 8'h47; // G
            16'h0137: rom_data = 8'h41; // A
            16'h0138: rom_data = 8'h20; // space
            16'h0139: rom_data = 8'h54; // T
            16'h013A: rom_data = 8'h45; // E
            16'h013B: rom_data = 8'h53; // S
            16'h013C: rom_data = 8'h54; // T

            16'h013D: rom_data = 8'h00;
            16'h013E: rom_data = 8'h00;
            16'h013F: rom_data = 8'h00;

            16'h0140: rom_data = 8'h00;
            16'h0141: rom_data = 8'h00;
            16'h0142: rom_data = 8'h00;

            // CGB flag
            16'h0143: rom_data = 8'h00;


            // ====================================================
            // Cartridge header
            // ====================================================

            // New licensee code
            16'h0144: rom_data = 8'h00;
            16'h0145: rom_data = 8'h00;

            // SGB flag
            16'h0146: rom_data = 8'h00;

            // Cartridge type: ROM ONLY
            16'h0147: rom_data = 8'h00;

            // ROM size: nominally 32 KiB
            16'h0148: rom_data = 8'h00;

            // External RAM: none
            16'h0149: rom_data = 8'h00;

            // Destination
            16'h014A: rom_data = 8'h00;

            // Old licensee
            16'h014B: rom_data = 8'h00;

            // ROM version
            16'h014C: rom_data = 8'h00;


            // ====================================================
            // Header checksum
            // ====================================================

            16'h014D: rom_data = 8'h69;


            // ====================================================
            // Global checksum
            //
            // The DMG boot ROM does not check the global checksum.
            // ====================================================

            16'h014E: rom_data = 8'h00;
            16'h014F: rom_data = 8'h00;


            // ====================================================
            // Test program begins at $0150
            // ====================================================


            // DI
            16'h0150: rom_data = 8'hF3;


            // XOR A
            // A = 0
            16'h0151: rom_data = 8'hAF;


            // LDH ($40),A
            // FF40 = LCDC
            // LCD OFF
            16'h0152: rom_data = 8'hE0;
            16'h0153: rom_data = 8'h40;


            // LD HL,$8000
            // Start of VRAM
            16'h0154: rom_data = 8'h21;
            16'h0155: rom_data = 8'h00;
            16'h0156: rom_data = 8'h80;


            // LD DE,$2000
            // 8192 bytes
            16'h0157: rom_data = 8'h11;
            16'h0158: rom_data = 8'h00;
            16'h0159: rom_data = 8'h20;


            // ====================================================
            // clear_loop: $015A
            // ====================================================

            // XOR A
            16'h015A: rom_data = 8'hAF;


            // LD (HL+),A
            16'h015B: rom_data = 8'h22;


            // DEC DE
            16'h015C: rom_data = 8'h1B;


            // LD A,D
            16'h015D: rom_data = 8'h7A;


            // OR E
            16'h015E: rom_data = 8'hB3;


            // JR NZ,$015A
            //
            // PC after the displacement byte is $0161
            // $0161 - 7 = $015A
            16'h015F: rom_data = 8'h20;
            16'h0160: rom_data = 8'hF9;


            // ====================================================
            // BGP = $FF
            //
            // Color 0 -> shade 3
            // ====================================================

            // LD A,$FF
            16'h0161: rom_data = 8'h3E;
            16'h0162: rom_data = 8'hFF;


            // LDH ($47),A
            // FF47 = BGP
            16'h0163: rom_data = 8'hE0;
            16'h0164: rom_data = 8'h47;


            // ====================================================
            // LCDC = $91
            //
            // bit 7 = LCD ON
            // bit 4 = tile data $8000
            // bit 0 = background ON
            // ====================================================

            // LD A,$91
            16'h0165: rom_data = 8'h3E;
            16'h0166: rom_data = 8'h91;


            // LDH ($40),A
            // FF40 = LCDC
            16'h0167: rom_data = 8'hE0;
            16'h0168: rom_data = 8'h40;


            // ====================================================
            // forever:
            //
            // JR forever
            // ====================================================

            16'h0169: rom_data = 8'h18;
            16'h016A: rom_data = 8'hFE;


            default:
                rom_data = 8'h00;

        endcase
    end

endmodule
