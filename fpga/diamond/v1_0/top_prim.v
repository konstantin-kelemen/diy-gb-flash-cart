// Verilog netlist produced by program LSE :  version Diamond (64-bit) 3.14.0.75.2
// Netlist written on Wed Sep 02 21:50:52 2026
//
// Verilog Description of module top
//

module top (gb_a, gb_d, gb_rd_n, data_oe_n, data_dir) /* synthesis syn_module_defined=1 */ ;   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(1[8:11])
    input [15:0]gb_a;   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    output [7:0]gb_d;   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(3[24:28])
    input gb_rd_n;   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(5[24:31])
    output data_oe_n;   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(12[24:33])
    output data_dir;   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(13[21:29])
    
    
    wire VCC_net, gb_a_c_15, gb_a_c_14, gb_a_c_13, gb_a_c_12, gb_a_c_11, 
        gb_a_c_10, gb_a_c_9, gb_a_c_8, gb_a_c_7, gb_a_c_6, gb_a_c_5, 
        gb_a_c_4, gb_a_c_3, gb_a_c_2, gb_a_c_1, gb_a_c_0, gb_d_c_7, 
        gb_d_c_6, gb_d_c_5, gb_d_c_4, gb_d_c_3, gb_d_c_2, gb_d_c_1, 
        gb_d_c_0, gb_rd_n_c, data_oe_n_c, n1143, n938, n269, n270, 
        n285, n286, n936, n301, n316, n317, n349, n380, n934, 
        n1142, n1139, n933, n926, n931, n356, n930, n380_adj_1, 
        n270_adj_2, n900, n286_adj_3, n1170, n928, n14, n13, n929, 
        n932, n347, n349_adj_4, n356_adj_5, n927, n380_adj_6, n935, 
        n301_adj_7, n1172, n1171, n1015, n364, n914, n918, n1169, 
        n1168, n916, n915, n944, n903, n1014, n348, n1013, n1153, 
        n1012, n380_adj_8, n1011, n917, n1167, n1010, n1009, n912, 
        n1008, n1165, n947, n641, n772, n950, n1151, n1003, 
        n1002, n1001, n920, n1163, n953, n301_adj_9, n316_adj_10, 
        n317_adj_11, n1162, n1160, n1159, n1147, n1146, n1145, 
        n1133, n1164, n1158, n954, n952, n951, n949, n948, n909, 
        n946, n911, n1125, n1124, n945, n989, n906, n1161, n1123, 
        n905, n940, n1144, n939, n937, GND_net;
    
    VLO i1264 (.Z(GND_net));
    LUT4 i733_2_lut_3_lut (.A(gb_a_c_2), .B(gb_a_c_3), .C(gb_a_c_1), .Z(n316)) /* synthesis lut_function=(!(A+(B+(C)))) */ ;
    defparam i733_2_lut_3_lut.init = 16'h0101;
    PFUMX i1077 (.BLUT(n938), .ALUT(n939), .C0(gb_a_c_4), .Z(n940));
    PFUMX i1249 (.BLUT(n1164), .ALUT(n1165), .C0(gb_a_c_3), .Z(n380_adj_8));
    OB gb_d_pad_7 (.I(gb_d_c_7), .O(gb_d[7]));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(3[24:28])
    LUT4 mux_226_Mux_7_i301_3_lut_3_lut_4_lut_3_lut (.A(gb_a_c_1), .B(gb_a_c_2), 
         .C(gb_a_c_3), .Z(n301)) /* synthesis lut_function=(A ((C)+!B)+!A (B+!(C))) */ ;
    defparam mux_226_Mux_7_i301_3_lut_3_lut_4_lut_3_lut.init = 16'he7e7;
    LUT4 i1066_3_lut_3_lut_3_lut (.A(gb_a_c_1), .B(gb_a_c_2), .C(gb_a_c_3), 
         .Z(n929)) /* synthesis lut_function=(A (B (C)+!B !(C))+!A (B+!(C))) */ ;
    defparam i1066_3_lut_3_lut_3_lut.init = 16'hc7c7;
    LUT4 i691_2_lut_rep_25_2_lut (.A(gb_a_c_1), .B(gb_a_c_0), .Z(n1146)) /* synthesis lut_function=((B)+!A) */ ;
    defparam i691_2_lut_rep_25_2_lut.init = 16'hdddd;
    LUT4 n1132_bdd_3_lut (.A(n1163), .B(n1125), .C(gb_a_c_4), .Z(n1133)) /* synthesis lut_function=(A (B+!(C))+!A (B (C))) */ ;
    defparam n1132_bdd_3_lut.init = 16'hcaca;
    PFUMX i1083 (.BLUT(n944), .ALUT(n945), .C0(gb_a_c_4), .Z(n946));
    LUT4 gb_a_c_5_bdd_4_lut_1233 (.A(gb_a_c_2), .B(gb_a_c_3), .C(gb_a_c_0), 
         .D(gb_a_c_1), .Z(n1123)) /* synthesis lut_function=(!(A (B (C+(D)))+!A !(B (C+(D))))) */ ;
    defparam gb_a_c_5_bdd_4_lut_1233.init = 16'h666a;
    PFUMX i1086 (.BLUT(n947), .ALUT(n948), .C0(gb_a_c_4), .Z(n949));
    PFUMX i1089 (.BLUT(n950), .ALUT(n951), .C0(gb_a_c_4), .Z(n952));
    LUT4 i688_4_lut_4_lut (.A(gb_a_c_4), .B(gb_a_c_3), .C(n1144), .D(n356_adj_5), 
         .Z(n380_adj_6)) /* synthesis lut_function=(!(A+!(B (C)+!B (D)))) */ ;   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    defparam i688_4_lut_4_lut.init = 16'h5140;
    LUT4 mux_226_Mux_5_i349_3_lut_4_lut_then_4_lut (.A(gb_a_c_4), .B(gb_a_c_3), 
         .C(gb_a_c_1), .D(gb_a_c_0), .Z(n1168)) /* synthesis lut_function=(A (B (C+(D))+!B !(C+(D)))+!A !((C+!(D))+!B)) */ ;
    defparam mux_226_Mux_5_i349_3_lut_4_lut_then_4_lut.init = 16'h8c82;
    LUT4 i699_4_lut_4_lut_then_4_lut (.A(gb_a_c_4), .B(gb_a_c_2), .C(gb_a_c_1), 
         .D(gb_a_c_0), .Z(n1165)) /* synthesis lut_function=(!(A+(B+((D)+!C)))) */ ;   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    defparam i699_4_lut_4_lut_then_4_lut.init = 16'h0010;
    LUT4 i747_2_lut_2_lut_3_lut (.A(gb_a_c_1), .B(gb_a_c_2), .C(gb_a_c_3), 
         .Z(n301_adj_7)) /* synthesis lut_function=(((C)+!B)+!A) */ ;
    defparam i747_2_lut_2_lut_3_lut.init = 16'hf7f7;
    PFUMX mux_226_Mux_0_i317 (.BLUT(n301_adj_9), .ALUT(n316_adj_10), .C0(gb_a_c_4), 
          .Z(n317_adj_11));
    LUT4 i687_2_lut_rep_23_2_lut_3_lut (.A(gb_a_c_0), .B(gb_a_c_1), .C(gb_a_c_2), 
         .Z(n1144)) /* synthesis lut_function=(!(A (B+(C))+!A ((C)+!B))) */ ;
    defparam i687_2_lut_rep_23_2_lut_3_lut.init = 16'h0606;
    LUT4 mux_226_Mux_7_i269_3_lut_4_lut_3_lut (.A(gb_a_c_0), .B(gb_a_c_1), 
         .C(gb_a_c_2), .Z(n269)) /* synthesis lut_function=(A (B (C))+!A !(B+(C))) */ ;
    defparam mux_226_Mux_7_i269_3_lut_4_lut_3_lut.init = 16'h8181;
    LUT4 i685_2_lut_3_lut (.A(gb_a_c_0), .B(gb_a_c_1), .C(gb_a_c_2), .Z(n347)) /* synthesis lut_function=(!(A (B+!(C))+!A !(C))) */ ;
    defparam i685_2_lut_3_lut.init = 16'h7070;
    LUT4 i1_2_lut_3_lut (.A(gb_a_c_1), .B(gb_a_c_2), .C(gb_a_c_3), .Z(n900)) /* synthesis lut_function=(A (B (C))) */ ;
    defparam i1_2_lut_3_lut.init = 16'h8080;
    PFUMX i1065 (.BLUT(n926), .ALUT(n927), .C0(gb_a_c_4), .Z(n928));
    LUT4 mux_226_Mux_0_i316_3_lut_4_lut_4_lut (.A(gb_a_c_0), .B(gb_a_c_1), 
         .C(gb_a_c_2), .D(gb_a_c_3), .Z(n316_adj_10)) /* synthesis lut_function=(!(A (B (C (D)+!C !(D))+!B (C+(D)))+!A (B (C (D))+!B (C+(D))))) */ ;
    defparam mux_226_Mux_0_i316_3_lut_4_lut_4_lut.init = 16'h0cc7;
    LUT4 mux_226_Mux_4_i356_3_lut_4_lut_3_lut (.A(gb_a_c_0), .B(gb_a_c_1), 
         .C(gb_a_c_2), .Z(n356_adj_5)) /* synthesis lut_function=(!(A (B)+!A !(B+!(C)))) */ ;
    defparam mux_226_Mux_4_i356_3_lut_4_lut_3_lut.init = 16'h6767;
    LUT4 i665_4_lut_4_lut (.A(gb_a_c_1), .B(gb_a_c_0), .C(gb_a_c_3), .D(gb_a_c_2), 
         .Z(n285)) /* synthesis lut_function=(A (B (C (D)))+!A (C)) */ ;
    defparam i665_4_lut_4_lut.init = 16'hd050;
    PFUMX i1068 (.BLUT(n929), .ALUT(n930), .C0(gb_a_c_4), .Z(n931));
    LUT4 gb_a_c_0_bdd_4_lut (.A(gb_a_c_0), .B(gb_a_c_3), .C(gb_a_c_2), 
         .D(gb_a_c_1), .Z(n989)) /* synthesis lut_function=(!(A (B)+!A (B (C+!(D))+!B (C)))) */ ;
    defparam gb_a_c_0_bdd_4_lut.init = 16'h2723;
    LUT4 i743_2_lut_2_lut_3_lut (.A(gb_a_c_0), .B(gb_a_c_2), .C(gb_a_c_1), 
         .Z(n641)) /* synthesis lut_function=(A (C)+!A ((C)+!B)) */ ;
    defparam i743_2_lut_2_lut_3_lut.init = 16'hf1f1;
    LUT4 i1069_4_lut_4_lut_4_lut_4_lut (.A(gb_a_c_1), .B(gb_a_c_2), .C(gb_a_c_3), 
         .D(gb_a_c_0), .Z(n932)) /* synthesis lut_function=(!(A (B+!(C (D)))+!A (B (C)+!B !(C)))) */ ;
    defparam i1069_4_lut_4_lut_4_lut_4_lut.init = 16'h3414;
    LUT4 mux_226_Mux_6_i356_3_lut_4_lut_4_lut_3_lut (.A(gb_a_c_0), .B(gb_a_c_1), 
         .C(gb_a_c_2), .Z(n356)) /* synthesis lut_function=(A (B)+!A !(B (C))) */ ;
    defparam mux_226_Mux_6_i356_3_lut_4_lut_4_lut_3_lut.init = 16'h9d9d;
    PFUMX i1247 (.BLUT(n1161), .ALUT(n1162), .C0(gb_a_c_2), .Z(n1163));
    LUT4 i744_2_lut_rep_30 (.A(gb_a_c_0), .B(gb_a_c_2), .Z(n1151)) /* synthesis lut_function=(A+(B)) */ ;
    defparam i744_2_lut_rep_30.init = 16'heeee;
    VHI i2 (.Z(VCC_net));
    TSALL TSALL_INST (.TSALL(GND_net));
    LUT4 gb_a_c_5_bdd_2_lut (.A(gb_a_c_2), .B(gb_a_c_3), .Z(n1124)) /* synthesis lut_function=(A (B)) */ ;
    defparam gb_a_c_5_bdd_2_lut.init = 16'h8888;
    PFUMX i1231 (.BLUT(n1124), .ALUT(n1123), .C0(gb_a_c_5), .Z(n1125));
    LUT4 gb_a_c_1_bdd_4_lut_1154_4_lut (.A(gb_a_c_4), .B(gb_a_c_0), .C(gb_a_c_2), 
         .D(gb_a_c_1), .Z(n1009)) /* synthesis lut_function=(!(A (B+!(C+(D)))+!A (((D)+!C)+!B))) */ ;   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    defparam gb_a_c_1_bdd_4_lut_1154_4_lut.init = 16'h2260;
    PFUMX mux_226_Mux_5_i286 (.BLUT(n270_adj_2), .ALUT(n900), .C0(gb_a_c_4), 
          .Z(n286_adj_3));
    LUT4 i1075_3_lut_3_lut_3_lut (.A(gb_a_c_1), .B(gb_a_c_2), .C(gb_a_c_3), 
         .Z(n938)) /* synthesis lut_function=(!(A ((C)+!B)+!A (B (C)+!B !(C)))) */ ;
    defparam i1075_3_lut_3_lut_3_lut.init = 16'h1c1c;
    LUT4 gb_a_c_1_bdd_4_lut_1155_3_lut (.A(gb_a_c_1), .B(gb_a_c_0), .C(gb_a_c_2), 
         .Z(n1010)) /* synthesis lut_function=(A (B (C))+!A !(B (C))) */ ;
    defparam gb_a_c_1_bdd_4_lut_1155_3_lut.init = 16'h9595;
    PFUMX i1253 (.BLUT(n1170), .ALUT(n1171), .C0(gb_a_c_1), .Z(n1172));
    PFUMX i1071 (.BLUT(n932), .ALUT(n933), .C0(gb_a_c_4), .Z(n934));
    PFUMX mux_226_Mux_7_i286 (.BLUT(n270), .ALUT(n285), .C0(gb_a_c_4), 
          .Z(n286));
    LUT4 i1070_4_lut_4_lut (.A(gb_a_c_1), .B(gb_a_c_3), .C(gb_a_c_2), 
         .D(gb_a_c_0), .Z(n933)) /* synthesis lut_function=(!(A (B (C (D)+!C !(D))+!B !(D))+!A !(B+(D)))) */ ;
    defparam i1070_4_lut_4_lut.init = 16'h7fc4;
    LUT4 i677_4_lut_4_lut_4_lut (.A(gb_a_c_4), .B(n356), .C(gb_a_c_3), 
         .D(n1151), .Z(n380_adj_1)) /* synthesis lut_function=(!(A+(B (C (D))+!B ((D)+!C)))) */ ;   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    defparam i677_4_lut_4_lut_4_lut.init = 16'h0454;
    PFUMX i1158 (.BLUT(n1013), .ALUT(n1008), .C0(gb_a_c_5), .Z(n1014));
    PFUMX i1245 (.BLUT(n1158), .ALUT(n1159), .C0(gb_a_c_1), .Z(n1160));
    LUT4 gb_a_c_1_bdd_4_lut_1160_4_lut (.A(gb_a_c_4), .B(gb_a_c_0), .C(gb_a_c_2), 
         .D(gb_a_c_1), .Z(n1011)) /* synthesis lut_function=(!((B+!(C+(D)))+!A)) */ ;   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    defparam gb_a_c_1_bdd_4_lut_1160_4_lut.init = 16'h2220;
    LUT4 i699_4_lut_4_lut_else_4_lut (.A(gb_a_c_4), .B(gb_a_c_2), .C(gb_a_c_1), 
         .D(gb_a_c_0), .Z(n1164)) /* synthesis lut_function=(!(A+(B (C)+!B (C (D)+!C !(D))))) */ ;   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    defparam i699_4_lut_4_lut_else_4_lut.init = 16'h0514;
    PFUMX i1156 (.BLUT(n1011), .ALUT(n1010), .C0(gb_a_c_4), .Z(n1012));
    LUT4 mux_226_Mux_3_i364_3_lut_4_lut_4_lut_4_lut (.A(gb_a_c_2), .B(gb_a_c_0), 
         .C(gb_a_c_1), .D(gb_a_c_3), .Z(n364)) /* synthesis lut_function=(!(A ((C+(D))+!B)+!A (B (C)+!B !(C+!(D))))) */ ;
    defparam mux_226_Mux_3_i364_3_lut_4_lut_4_lut_4_lut.init = 16'h141d;
    LUT4 i1084_4_lut_4_lut_4_lut (.A(gb_a_c_1), .B(gb_a_c_0), .C(gb_a_c_3), 
         .D(gb_a_c_2), .Z(n947)) /* synthesis lut_function=(A (B (D)+!B !(C+!(D)))+!A !(C (D)+!C !(D))) */ ;
    defparam i1084_4_lut_4_lut_4_lut.init = 16'h8f50;
    LUT4 i2_2_lut_rep_21_3_lut (.A(gb_a_c_0), .B(gb_a_c_1), .C(gb_a_c_3), 
         .Z(n1142)) /* synthesis lut_function=(!((B+!(C))+!A)) */ ;
    defparam i2_2_lut_rep_21_3_lut.init = 16'h2020;
    LUT4 mux_226_Mux_5_i349_3_lut_4_lut_else_4_lut (.A(gb_a_c_4), .B(gb_a_c_3), 
         .C(gb_a_c_1), .D(gb_a_c_0), .Z(n1167)) /* synthesis lut_function=(A (B (C+(D))+!B !(C (D)))) */ ;
    defparam mux_226_Mux_5_i349_3_lut_4_lut_else_4_lut.init = 16'h8aa2;
    LUT4 i1115_3_lut_4_lut_4_lut (.A(gb_a_c_0), .B(gb_a_c_1), .C(gb_a_c_2), 
         .D(gb_a_c_3), .Z(n939)) /* synthesis lut_function=(A (B+(C (D)+!C !(D)))+!A (C (D))) */ ;
    defparam i1115_3_lut_4_lut_4_lut.init = 16'hf88a;
    LUT4 mux_226_Mux_7_i270_4_lut_4_lut_4_lut (.A(gb_a_c_1), .B(gb_a_c_3), 
         .C(gb_a_c_0), .D(gb_a_c_2), .Z(n270)) /* synthesis lut_function=(A (B (C (D)))+!A !(B (C+(D))+!B !(C+(D)))) */ ;
    defparam mux_226_Mux_7_i270_4_lut_4_lut_4_lut.init = 16'h9114;
    LUT4 i1064_4_lut_4_lut (.A(gb_a_c_1), .B(gb_a_c_2), .C(gb_a_c_0), 
         .D(gb_a_c_3), .Z(n927)) /* synthesis lut_function=(!(A ((D)+!B)+!A ((C+!(D))+!B))) */ ;
    defparam i1064_4_lut_4_lut.init = 16'h0488;
    LUT4 i1087_4_lut_4_lut_4_lut_4_lut (.A(gb_a_c_1), .B(gb_a_c_2), .C(gb_a_c_0), 
         .D(gb_a_c_3), .Z(n950)) /* synthesis lut_function=(A (B (C (D))+!B (C))+!A (B (C+(D))+!B (C))) */ ;
    defparam i1087_4_lut_4_lut_4_lut_4_lut.init = 16'hf470;
    LUT4 n304_bdd_4_lut (.A(n1146), .B(n1153), .C(n301_adj_7), .D(gb_a_c_4), 
         .Z(n1139)) /* synthesis lut_function=(!(A (B ((D)+!C)+!B !(C+(D)))+!A ((D)+!C))) */ ;
    defparam n304_bdd_4_lut.init = 16'h22f0;
    LUT4 mux_226_Mux_5_i270_4_lut_4_lut (.A(gb_a_c_0), .B(gb_a_c_1), .C(gb_a_c_2), 
         .D(gb_a_c_3), .Z(n270_adj_2)) /* synthesis lut_function=(!(A (B ((D)+!C)+!B !(C))+!A (((D)+!C)+!B))) */ ;
    defparam mux_226_Mux_5_i270_4_lut_4_lut.init = 16'h20e0;
    PFUMX i1251 (.BLUT(n1167), .ALUT(n1168), .C0(gb_a_c_2), .Z(n1169));
    LUT4 i1080_then_4_lut (.A(gb_a_c_4), .B(gb_a_c_3), .C(gb_a_c_2), .D(gb_a_c_0), 
         .Z(n1159)) /* synthesis lut_function=(!(A (B (C+(D))+!B (C (D)+!C !(D)))+!A !(B ((D)+!C)+!B !((D)+!C)))) */ ;
    defparam i1080_then_4_lut.init = 16'h463c;
    LUT4 i1085_4_lut_3_lut_4_lut (.A(gb_a_c_0), .B(gb_a_c_1), .C(gb_a_c_2), 
         .D(gb_a_c_3), .Z(n948)) /* synthesis lut_function=(!(A ((C)+!B)+!A (D))) */ ;
    defparam i1085_4_lut_3_lut_4_lut.init = 16'h085d;
    LUT4 i1105_3_lut_4_lut_4_lut_4_lut (.A(gb_a_c_2), .B(gb_a_c_0), .C(gb_a_c_1), 
         .D(gb_a_c_3), .Z(n930)) /* synthesis lut_function=(!(A (B (C+(D))+!B (C+!(D)))+!A !(B+!(D)))) */ ;
    defparam i1105_3_lut_4_lut_4_lut_4_lut.init = 16'h465d;
    LUT4 i1082_4_lut_4_lut (.A(gb_a_c_0), .B(gb_a_c_2), .C(gb_a_c_1), 
         .D(gb_a_c_3), .Z(n945)) /* synthesis lut_function=(A (B (C)+!B (C (D)))+!A (B (C (D)))) */ ;
    defparam i1082_4_lut_4_lut.init = 16'he080;
    LUT4 i1_3_lut_rep_24 (.A(gb_a_c_15), .B(n13), .C(n14), .Z(n1145)) /* synthesis lut_function=(A+(B+(C))) */ ;
    defparam i1_3_lut_rep_24.init = 16'hfefe;
    LUT4 i1_2_lut_4_lut (.A(gb_a_c_15), .B(n13), .C(n14), .D(n937), 
         .Z(gb_d_c_5)) /* synthesis lut_function=(!(A+(B+(C+!(D))))) */ ;
    defparam i1_2_lut_4_lut.init = 16'h0100;
    LUT4 mux_226_Mux_2_i348_3_lut_4_lut_4_lut_4_lut_4_lut (.A(gb_a_c_0), .B(gb_a_c_1), 
         .C(gb_a_c_2), .D(gb_a_c_3), .Z(n348)) /* synthesis lut_function=(!(A (B+(C+(D)))+!A ((C+!(D))+!B))) */ ;
    defparam mux_226_Mux_2_i348_3_lut_4_lut_4_lut_4_lut_4_lut.init = 16'h0402;
    LUT4 i1_2_lut_4_lut_adj_1 (.A(gb_a_c_15), .B(n13), .C(n14), .D(n916), 
         .Z(gb_d_c_2)) /* synthesis lut_function=(!(A+(B+(C+!(D))))) */ ;
    defparam i1_2_lut_4_lut_adj_1.init = 16'h0100;
    LUT4 i1063_3_lut_4_lut_4_lut_4_lut_4_lut (.A(gb_a_c_0), .B(gb_a_c_1), 
         .C(gb_a_c_2), .D(gb_a_c_3), .Z(n926)) /* synthesis lut_function=(!(A (B+!(C (D)))+!A ((C+(D))+!B))) */ ;
    defparam i1063_3_lut_4_lut_4_lut_4_lut_4_lut.init = 16'h2004;
    LUT4 i1088_3_lut_4_lut_4_lut_4_lut (.A(gb_a_c_1), .B(gb_a_c_2), .C(gb_a_c_0), 
         .D(gb_a_c_3), .Z(n951)) /* synthesis lut_function=(!(A (B (D)+!B ((D)+!C))+!A (B+!(C (D))))) */ ;
    defparam i1088_3_lut_4_lut_4_lut_4_lut.init = 16'h10a8;
    PFUMX i1074 (.BLUT(n935), .ALUT(n936), .C0(gb_a_c_6), .Z(n937));
    LUT4 i1112_3_lut_4_lut_4_lut (.A(gb_a_c_0), .B(gb_a_c_1), .C(gb_a_c_2), 
         .D(gb_a_c_3), .Z(n944)) /* synthesis lut_function=(A (B (C+(D))+!B (C (D)+!C !(D)))+!A !(B ((D)+!C)+!B !(C))) */ ;
    defparam i1112_3_lut_4_lut_4_lut.init = 16'hb8d2;
    LUT4 i22_4_lut (.A(n1143), .B(n1142), .C(gb_a_c_2), .D(n903), .Z(n772)) /* synthesis lut_function=(A (B (C+(D))+!B !(C+!(D)))+!A (B (C))) */ ;
    defparam i22_4_lut.init = 16'hcac0;
    LUT4 gb_a_c_4_bdd_4_lut_1256 (.A(gb_a_c_4), .B(gb_a_c_0), .C(gb_a_c_3), 
         .D(gb_a_c_1), .Z(n1002)) /* synthesis lut_function=(!(A (B (C)+!B (C (D)))+!A (B+!(C)))) */ ;
    defparam gb_a_c_4_bdd_4_lut_1256.init = 16'h1a3a;
    PFUMX i1053 (.BLUT(n914), .ALUT(n915), .C0(gb_a_c_6), .Z(n916));
    LUT4 i669_4_lut (.A(n1153), .B(gb_a_c_4), .C(gb_a_c_0), .D(gb_a_c_1), 
         .Z(n349)) /* synthesis lut_function=(!(A ((C+!(D))+!B)+!A ((C (D))+!B))) */ ;
    defparam i669_4_lut.init = 16'h0c44;
    LUT4 gb_a_c_4_bdd_2_lut (.A(gb_a_c_4), .B(gb_a_c_3), .Z(n1001)) /* synthesis lut_function=(!(A+(B))) */ ;
    defparam gb_a_c_4_bdd_2_lut.init = 16'h1111;
    LUT4 i1_4_lut (.A(n1145), .B(n905), .C(n906), .D(gb_a_c_6), .Z(gb_d_c_7)) /* synthesis lut_function=(!(A+!(B (C+!(D))+!B (C (D))))) */ ;
    defparam i1_4_lut.init = 16'h5044;
    PFUMX mux_226_Mux_7_i317 (.BLUT(n301), .ALUT(n316), .C0(gb_a_c_4), 
          .Z(n317));
    LUT4 i686_4_lut (.A(n269), .B(gb_a_c_4), .C(n347), .D(gb_a_c_3), 
         .Z(n349_adj_4)) /* synthesis lut_function=(A (B (C+!(D)))+!A (B (C (D)))) */ ;
    defparam i686_4_lut.init = 16'hc088;
    L6MUX21 i1042 (.D0(n286), .D1(n317), .SD(gb_a_c_5), .Z(n905));
    LUT4 i1052_4_lut (.A(n348), .B(n380_adj_8), .C(gb_a_c_5), .D(gb_a_c_4), 
         .Z(n915)) /* synthesis lut_function=(A (B (C+(D))+!B !(C+!(D)))+!A (B (C))) */ ;
    defparam i1052_4_lut.init = 16'hcac0;
    PFUMX i1091 (.BLUT(n349_adj_4), .ALUT(n380_adj_6), .C0(gb_a_c_5), 
          .Z(n954));
    LUT4 i1051_3_lut (.A(n940), .B(n1160), .C(gb_a_c_5), .Z(n914)) /* synthesis lut_function=(A (B+!(C))+!A (B (C))) */ ;
    defparam i1051_3_lut.init = 16'hcaca;
    LUT4 i1131_3_lut_4_lut_4_lut (.A(gb_a_c_4), .B(n1169), .C(gb_a_c_5), 
         .D(n989), .Z(n936)) /* synthesis lut_function=(!(A ((C)+!B)+!A !(B ((D)+!C)+!B (C (D))))) */ ;   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    defparam i1131_3_lut_4_lut_4_lut.init = 16'h5c0c;
    LUT4 i5_4_lut (.A(gb_a_c_7), .B(gb_a_c_8), .C(gb_a_c_12), .D(gb_a_c_13), 
         .Z(n13)) /* synthesis lut_function=(A+((C+(D))+!B)) */ ;
    defparam i5_4_lut.init = 16'hfffb;
    LUT4 i1072_3_lut (.A(n286_adj_3), .B(n1003), .C(gb_a_c_5), .Z(n935)) /* synthesis lut_function=(A (B+!(C))+!A (B (C))) */ ;
    defparam i1072_3_lut.init = 16'hcaca;
    LUT4 gb_a_c_1_bdd_3_lut_1173 (.A(gb_a_c_4), .B(gb_a_c_0), .C(gb_a_c_3), 
         .Z(n1008)) /* synthesis lut_function=(!(A+(B+(C)))) */ ;
    defparam gb_a_c_1_bdd_3_lut_1173.init = 16'h0101;
    LUT4 mux_226_Mux_3_i349_then_4_lut (.A(gb_a_c_3), .B(gb_a_c_4), .C(gb_a_c_2), 
         .D(gb_a_c_0), .Z(n1171)) /* synthesis lut_function=(!(((C+(D))+!B)+!A)) */ ;
    defparam mux_226_Mux_3_i349_then_4_lut.init = 16'h0008;
    PFUMX i1043 (.BLUT(n349), .ALUT(n380), .C0(gb_a_c_5), .Z(n906));
    LUT4 i6_4_lut (.A(gb_a_c_14), .B(gb_a_c_9), .C(gb_a_c_11), .D(gb_a_c_10), 
         .Z(n14)) /* synthesis lut_function=(A+(B+(C+(D)))) */ ;
    defparam i6_4_lut.init = 16'hfffe;
    LUT4 i1_4_lut_adj_2 (.A(n1145), .B(n1133), .C(n909), .D(gb_a_c_6), 
         .Z(gb_d_c_6)) /* synthesis lut_function=(!(A+!(B (C+!(D))+!B (C (D))))) */ ;
    defparam i1_4_lut_adj_2.init = 16'h5044;
    LUT4 n1012_bdd_3_lut (.A(n1012), .B(n1009), .C(gb_a_c_3), .Z(n1013)) /* synthesis lut_function=(A (B+!(C))+!A (B (C))) */ ;
    defparam n1012_bdd_3_lut.init = 16'hcaca;
    LUT4 i1080_else_4_lut (.A(gb_a_c_4), .B(gb_a_c_3), .C(gb_a_c_2), .D(gb_a_c_0), 
         .Z(n1158)) /* synthesis lut_function=(!(A (B (C (D)+!C !(D))+!B ((D)+!C))+!A !(B+!(C)))) */ ;
    defparam i1080_else_4_lut.init = 16'h4de5;
    PFUMX i1046 (.BLUT(n772), .ALUT(n380_adj_1), .C0(gb_a_c_5), .Z(n909));
    LUT4 i1_4_lut_adj_3 (.A(n1145), .B(n953), .C(n954), .D(gb_a_c_6), 
         .Z(gb_d_c_4)) /* synthesis lut_function=(!(A+!(B (C+!(D))+!B (C (D))))) */ ;
    defparam i1_4_lut_adj_3.init = 16'h5044;
    LUT4 i1040_2_lut_2_lut (.A(gb_a_c_3), .B(gb_a_c_4), .Z(n903)) /* synthesis lut_function=(!(A+!(B))) */ ;   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    defparam i1040_2_lut_2_lut.init = 16'h4444;
    LUT4 mux_226_Mux_3_i349_else_4_lut (.A(gb_a_c_3), .B(gb_a_c_4), .C(gb_a_c_2), 
         .D(gb_a_c_0), .Z(n1170)) /* synthesis lut_function=(A (B (C)+!B (C (D)))+!A !((C+!(D))+!B)) */ ;
    defparam mux_226_Mux_3_i349_else_4_lut.init = 16'ha480;
    LUT4 i1_4_lut_adj_4 (.A(n1145), .B(n911), .C(n912), .D(gb_a_c_6), 
         .Z(gb_d_c_3)) /* synthesis lut_function=(!(A+!(B (C+!(D))+!B (C (D))))) */ ;
    defparam i1_4_lut_adj_4.init = 16'h5044;
    LUT4 i1240_then_4_lut (.A(gb_a_c_3), .B(gb_a_c_5), .C(gb_a_c_0), .D(gb_a_c_1), 
         .Z(n1162)) /* synthesis lut_function=(!(A (B (D)+!B ((D)+!C))+!A !((D)+!B))) */ ;
    defparam i1240_then_4_lut.init = 16'h55b9;
    LUT4 i706_2_lut_rep_26_3_lut (.A(gb_a_c_1), .B(gb_a_c_2), .C(gb_a_c_0), 
         .Z(n1147)) /* synthesis lut_function=(!((B+(C))+!A)) */ ;
    defparam i706_2_lut_rep_26_3_lut.init = 16'h0202;
    LUT4 i1_4_lut_adj_5 (.A(n1145), .B(n917), .C(n918), .D(gb_a_c_6), 
         .Z(gb_d_c_1)) /* synthesis lut_function=(!(A+!(B (C+!(D))+!B (C (D))))) */ ;
    defparam i1_4_lut_adj_5.init = 16'h5044;
    LUT4 i704_3_lut_4_lut_4_lut_4_lut (.A(gb_a_c_0), .B(gb_a_c_1), .C(gb_a_c_2), 
         .D(gb_a_c_3), .Z(n301_adj_9)) /* synthesis lut_function=(A (B (C+!(D))+!B !(D))+!A (C+!(D))) */ ;
    defparam i704_3_lut_4_lut_4_lut_4_lut.init = 16'hd0ff;
    LUT4 i1055_4_lut (.A(n1015), .B(n380_adj_8), .C(gb_a_c_5), .D(gb_a_c_4), 
         .Z(n918)) /* synthesis lut_function=(A (B (C+(D))+!B !(C+!(D)))+!A (B (C))) */ ;
    defparam i1055_4_lut.init = 16'hcac0;
    LUT4 i1_4_lut_adj_6 (.A(n1145), .B(n920), .C(n1014), .D(gb_a_c_6), 
         .Z(gb_d_c_0)) /* synthesis lut_function=(!(A+!(B (C+!(D))+!B (C (D))))) */ ;
    defparam i1_4_lut_adj_6.init = 16'h5044;
    LUT4 i674_2_lut_rep_22_2_lut (.A(gb_a_c_0), .B(gb_a_c_1), .Z(n1143)) /* synthesis lut_function=((B)+!A) */ ;
    defparam i674_2_lut_rep_22_2_lut.init = 16'hdddd;
    LUT4 i1049_4_lut_4_lut (.A(gb_a_c_4), .B(gb_a_c_5), .C(n364), .D(n1172), 
         .Z(n912)) /* synthesis lut_function=(!(A (B+!(D))+!A !(B (C)+!B (D)))) */ ;   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    defparam i1049_4_lut_4_lut.init = 16'h7340;
    LUT4 i1_2_lut (.A(gb_a_c_15), .B(gb_rd_n_c), .Z(data_oe_n_c)) /* synthesis lut_function=(A+(B)) */ ;   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    defparam i1_2_lut.init = 16'heeee;
    GSR GSR_INST (.GSR(VCC_net));
    LUT4 i316_2_lut_rep_32 (.A(gb_a_c_2), .B(gb_a_c_3), .Z(n1153)) /* synthesis lut_function=(A+(B)) */ ;
    defparam i316_2_lut_rep_32.init = 16'heeee;
    LUT4 i1240_else_4_lut (.A(gb_a_c_3), .B(gb_a_c_5), .C(gb_a_c_0), .D(gb_a_c_1), 
         .Z(n1161)) /* synthesis lut_function=(A (B ((D)+!C)+!B !(C+(D)))+!A !(B (C (D))+!B (C (D)+!C !(D)))) */ ;
    defparam i1240_else_4_lut.init = 16'h8d5e;
    LUT4 gb_a_c_1_bdd_4_lut_1168_4_lut (.A(gb_a_c_0), .B(gb_a_c_1), .C(gb_a_c_2), 
         .D(gb_a_c_3), .Z(n1015)) /* synthesis lut_function=(!(A (B (C+!(D))+!B !(C (D)+!C !(D)))+!A !(B (D)+!B (C (D)+!C !(D))))) */ ;
    defparam gb_a_c_1_bdd_4_lut_1168_4_lut.init = 16'h7c03;
    L6MUX21 i1090 (.D0(n928), .D1(n931), .SD(gb_a_c_5), .Z(n953));
    PFUMX i1149 (.BLUT(n1002), .ALUT(n1001), .C0(gb_a_c_2), .Z(n1003));
    PUR PUR_INST (.PUR(VCC_net));
    defparam PUR_INST.RST_PULSE = 1;
    L6MUX21 i1057 (.D0(n952), .D1(n317_adj_11), .SD(gb_a_c_5), .Z(n920));
    L6MUX21 i1054 (.D0(n946), .D1(n949), .SD(gb_a_c_5), .Z(n917));
    L6MUX21 i1048 (.D0(n934), .D1(n1139), .SD(gb_a_c_5), .Z(n911));
    LUT4 i671_4_lut_4_lut (.A(gb_a_c_4), .B(gb_a_c_3), .C(n1147), .D(n641), 
         .Z(n380)) /* synthesis lut_function=(!(A+!(B (C)+!B (D)))) */ ;   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    defparam i671_4_lut_4_lut.init = 16'h5140;
    OB gb_d_pad_6 (.I(gb_d_c_6), .O(gb_d[6]));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(3[24:28])
    OB gb_d_pad_5 (.I(gb_d_c_5), .O(gb_d[5]));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(3[24:28])
    OB gb_d_pad_4 (.I(gb_d_c_4), .O(gb_d[4]));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(3[24:28])
    OB gb_d_pad_3 (.I(gb_d_c_3), .O(gb_d[3]));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(3[24:28])
    OB gb_d_pad_2 (.I(gb_d_c_2), .O(gb_d[2]));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(3[24:28])
    OB gb_d_pad_1 (.I(gb_d_c_1), .O(gb_d[1]));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(3[24:28])
    OB gb_d_pad_0 (.I(gb_d_c_0), .O(gb_d[0]));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(3[24:28])
    OB data_oe_n_pad (.I(data_oe_n_c), .O(data_oe_n));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(12[24:33])
    OB data_dir_pad (.I(VCC_net), .O(data_dir));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(13[21:29])
    IB gb_a_pad_15 (.I(gb_a[15]), .O(gb_a_c_15));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    IB gb_a_pad_14 (.I(gb_a[14]), .O(gb_a_c_14));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    IB gb_a_pad_13 (.I(gb_a[13]), .O(gb_a_c_13));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    IB gb_a_pad_12 (.I(gb_a[12]), .O(gb_a_c_12));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    IB gb_a_pad_11 (.I(gb_a[11]), .O(gb_a_c_11));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    IB gb_a_pad_10 (.I(gb_a[10]), .O(gb_a_c_10));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    IB gb_a_pad_9 (.I(gb_a[9]), .O(gb_a_c_9));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    IB gb_a_pad_8 (.I(gb_a[8]), .O(gb_a_c_8));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    IB gb_a_pad_7 (.I(gb_a[7]), .O(gb_a_c_7));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    IB gb_a_pad_6 (.I(gb_a[6]), .O(gb_a_c_6));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    IB gb_a_pad_5 (.I(gb_a[5]), .O(gb_a_c_5));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    IB gb_a_pad_4 (.I(gb_a[4]), .O(gb_a_c_4));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    IB gb_a_pad_3 (.I(gb_a[3]), .O(gb_a_c_3));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    IB gb_a_pad_2 (.I(gb_a[2]), .O(gb_a_c_2));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    IB gb_a_pad_1 (.I(gb_a[1]), .O(gb_a_c_1));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    IB gb_a_pad_0 (.I(gb_a[0]), .O(gb_a_c_0));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(2[24:28])
    IB gb_rd_n_pad (.I(gb_rd_n), .O(gb_rd_n_c));   // c:/users/admin/documents/fpga/projects/rom_emu/top.v(5[24:31])
    
endmodule
//
// Verilog Description of module TSALL
// module not written out since it is a black-box. 
//

//
// Verilog Description of module PUR
// module not written out since it is a black-box. 
//

