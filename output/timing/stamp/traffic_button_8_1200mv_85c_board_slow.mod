/*
 Copyright (C) 2020  Intel Corporation. All rights reserved.
 Your use of Intel Corporation's design tools, logic functions 
 and other software and tools, and any partner logic 
 functions, and any output files from any of the foregoing 
 (including device programming or simulation files), and any 
 associated documentation or information are expressly subject 
 to the terms and conditions of the Intel Program License 
 Subscription Agreement, the Intel Quartus Prime License Agreement,
 the Intel FPGA IP License Agreement, or other applicable license
 agreement, including, without limitation, that your use is for
 the sole purpose of programming logic devices manufactured by
 Intel and sold by Intel or its authorized distributors.  Please
 refer to the applicable agreement for further details, at
 https://fpgasoftware.intel.com/eula.
*/
MODEL
/*MODEL HEADER*/
/*
 This file contains Slow Corner delays for the design using part EP4CE6E22C8
 with speed grade 8, core voltage 1.2V, and temperature 85 Celsius

*/
MODEL_VERSION "1.0";
DESIGN "traffic_button";
DATE "04/10/2026 04:15:34";
PROGRAM "Quartus Prime";



INPUT rst_n;
INPUT clk;
INPUT cfg_addr[2];
INPUT cfg_addr[0];
INPUT cfg_we;
INPUT cfg_addr[3];
INPUT cfg_addr[1];
INPUT cfg_data[0];
INPUT cfg_data[1];
INOUT dig_dip[0];
INPUT io_mode;
INOUT dig_dip[1];
INOUT dig_dip[3];
INOUT dig_dip[2];
INPUT cfg_data[2];
INPUT cfg_data[3];
INPUT cfg_data[4];
INPUT cfg_data[5];
INPUT cfg_data[6];
INPUT cfg_data[7];
OUTPUT SVNSEG_SEG[0];
OUTPUT SVNSEG_SEG[1];
OUTPUT SVNSEG_SEG[2];
OUTPUT SVNSEG_SEG[3];
OUTPUT SVNSEG_SEG[4];
OUTPUT SVNSEG_SEG[5];
OUTPUT SVNSEG_SEG[6];
OUTPUT SVNSEG_SEG[7];
OUTPUT n_r_left;
OUTPUT n_y_left;
OUTPUT n_g_left;
OUTPUT n_r_ped;
OUTPUT n_g_ped;
OUTPUT n_r_stra;
OUTPUT n_y_stra;
OUTPUT n_g_stra;
OUTPUT s_r_left;
OUTPUT s_y_left;
OUTPUT s_g_left;
OUTPUT s_r_ped;
OUTPUT s_g_ped;
OUTPUT s_r_stra;
OUTPUT s_y_stra;
OUTPUT s_g_stra;
OUTPUT e_r_left;
OUTPUT e_y_left;
OUTPUT e_g_left;
OUTPUT e_r_ped;
OUTPUT e_g_ped;
OUTPUT e_r_stra;
OUTPUT e_y_stra;
OUTPUT e_g_stra;
OUTPUT w_r_left;
OUTPUT w_y_left;
OUTPUT w_g_left;
OUTPUT w_r_ped;
OUTPUT w_g_ped;
OUTPUT w_r_stra;
OUTPUT w_y_stra;
OUTPUT w_g_stra;
OUTPUT system_fault_led;

/*Arc definitions start here*/
pos_cfg_addr[0]__clk__setup:		SETUP (POSEDGE) cfg_addr[0] clk ;
pos_cfg_addr[1]__clk__setup:		SETUP (POSEDGE) cfg_addr[1] clk ;
pos_cfg_addr[2]__clk__setup:		SETUP (POSEDGE) cfg_addr[2] clk ;
pos_cfg_addr[3]__clk__setup:		SETUP (POSEDGE) cfg_addr[3] clk ;
pos_cfg_data[0]__clk__setup:		SETUP (POSEDGE) cfg_data[0] clk ;
pos_cfg_data[1]__clk__setup:		SETUP (POSEDGE) cfg_data[1] clk ;
pos_cfg_data[2]__clk__setup:		SETUP (POSEDGE) cfg_data[2] clk ;
pos_cfg_data[3]__clk__setup:		SETUP (POSEDGE) cfg_data[3] clk ;
pos_cfg_data[4]__clk__setup:		SETUP (POSEDGE) cfg_data[4] clk ;
pos_cfg_data[5]__clk__setup:		SETUP (POSEDGE) cfg_data[5] clk ;
pos_cfg_data[6]__clk__setup:		SETUP (POSEDGE) cfg_data[6] clk ;
pos_cfg_data[7]__clk__setup:		SETUP (POSEDGE) cfg_data[7] clk ;
pos_cfg_we__clk__setup:		SETUP (POSEDGE) cfg_we clk ;
pos_dig_dip[0]__clk__setup:		SETUP (POSEDGE) dig_dip[0] clk ;
pos_dig_dip[1]__clk__setup:		SETUP (POSEDGE) dig_dip[1] clk ;
pos_dig_dip[2]__clk__setup:		SETUP (POSEDGE) dig_dip[2] clk ;
pos_dig_dip[3]__clk__setup:		SETUP (POSEDGE) dig_dip[3] clk ;
pos_io_mode__clk__setup:		SETUP (POSEDGE) io_mode clk ;
pos_cfg_addr[0]__clk__hold:		HOLD (POSEDGE) cfg_addr[0] clk ;
pos_cfg_addr[1]__clk__hold:		HOLD (POSEDGE) cfg_addr[1] clk ;
pos_cfg_addr[2]__clk__hold:		HOLD (POSEDGE) cfg_addr[2] clk ;
pos_cfg_addr[3]__clk__hold:		HOLD (POSEDGE) cfg_addr[3] clk ;
pos_cfg_data[0]__clk__hold:		HOLD (POSEDGE) cfg_data[0] clk ;
pos_cfg_data[1]__clk__hold:		HOLD (POSEDGE) cfg_data[1] clk ;
pos_cfg_data[2]__clk__hold:		HOLD (POSEDGE) cfg_data[2] clk ;
pos_cfg_data[3]__clk__hold:		HOLD (POSEDGE) cfg_data[3] clk ;
pos_cfg_data[4]__clk__hold:		HOLD (POSEDGE) cfg_data[4] clk ;
pos_cfg_data[5]__clk__hold:		HOLD (POSEDGE) cfg_data[5] clk ;
pos_cfg_data[6]__clk__hold:		HOLD (POSEDGE) cfg_data[6] clk ;
pos_cfg_data[7]__clk__hold:		HOLD (POSEDGE) cfg_data[7] clk ;
pos_cfg_we__clk__hold:		HOLD (POSEDGE) cfg_we clk ;
pos_dig_dip[0]__clk__hold:		HOLD (POSEDGE) dig_dip[0] clk ;
pos_dig_dip[1]__clk__hold:		HOLD (POSEDGE) dig_dip[1] clk ;
pos_dig_dip[2]__clk__hold:		HOLD (POSEDGE) dig_dip[2] clk ;
pos_dig_dip[3]__clk__hold:		HOLD (POSEDGE) dig_dip[3] clk ;
pos_io_mode__clk__hold:		HOLD (POSEDGE) io_mode clk ;
pos_clk__SVNSEG_SEG[0]__delay:		DELAY (POSEDGE) clk SVNSEG_SEG[0] ;
pos_clk__SVNSEG_SEG[1]__delay:		DELAY (POSEDGE) clk SVNSEG_SEG[1] ;
pos_clk__SVNSEG_SEG[2]__delay:		DELAY (POSEDGE) clk SVNSEG_SEG[2] ;
pos_clk__SVNSEG_SEG[3]__delay:		DELAY (POSEDGE) clk SVNSEG_SEG[3] ;
pos_clk__SVNSEG_SEG[4]__delay:		DELAY (POSEDGE) clk SVNSEG_SEG[4] ;
pos_clk__SVNSEG_SEG[5]__delay:		DELAY (POSEDGE) clk SVNSEG_SEG[5] ;
pos_clk__SVNSEG_SEG[6]__delay:		DELAY (POSEDGE) clk SVNSEG_SEG[6] ;
pos_clk__dig_dip[0]__delay:		DELAY (POSEDGE) clk dig_dip[0] ;
pos_clk__dig_dip[1]__delay:		DELAY (POSEDGE) clk dig_dip[1] ;
pos_clk__dig_dip[2]__delay:		DELAY (POSEDGE) clk dig_dip[2] ;
pos_clk__dig_dip[3]__delay:		DELAY (POSEDGE) clk dig_dip[3] ;
pos_clk__e_g_left__delay:		DELAY (POSEDGE) clk e_g_left ;
pos_clk__e_g_ped__delay:		DELAY (POSEDGE) clk e_g_ped ;
pos_clk__e_g_stra__delay:		DELAY (POSEDGE) clk e_g_stra ;
pos_clk__e_r_left__delay:		DELAY (POSEDGE) clk e_r_left ;
pos_clk__e_r_ped__delay:		DELAY (POSEDGE) clk e_r_ped ;
pos_clk__e_r_stra__delay:		DELAY (POSEDGE) clk e_r_stra ;
pos_clk__e_y_left__delay:		DELAY (POSEDGE) clk e_y_left ;
pos_clk__e_y_stra__delay:		DELAY (POSEDGE) clk e_y_stra ;
pos_clk__n_g_left__delay:		DELAY (POSEDGE) clk n_g_left ;
pos_clk__n_g_ped__delay:		DELAY (POSEDGE) clk n_g_ped ;
pos_clk__n_g_stra__delay:		DELAY (POSEDGE) clk n_g_stra ;
pos_clk__n_r_left__delay:		DELAY (POSEDGE) clk n_r_left ;
pos_clk__n_r_ped__delay:		DELAY (POSEDGE) clk n_r_ped ;
pos_clk__n_r_stra__delay:		DELAY (POSEDGE) clk n_r_stra ;
pos_clk__n_y_left__delay:		DELAY (POSEDGE) clk n_y_left ;
pos_clk__n_y_stra__delay:		DELAY (POSEDGE) clk n_y_stra ;
pos_clk__s_g_left__delay:		DELAY (POSEDGE) clk s_g_left ;
pos_clk__s_g_ped__delay:		DELAY (POSEDGE) clk s_g_ped ;
pos_clk__s_g_stra__delay:		DELAY (POSEDGE) clk s_g_stra ;
pos_clk__s_r_left__delay:		DELAY (POSEDGE) clk s_r_left ;
pos_clk__s_r_ped__delay:		DELAY (POSEDGE) clk s_r_ped ;
pos_clk__s_r_stra__delay:		DELAY (POSEDGE) clk s_r_stra ;
pos_clk__s_y_left__delay:		DELAY (POSEDGE) clk s_y_left ;
pos_clk__s_y_stra__delay:		DELAY (POSEDGE) clk s_y_stra ;
pos_clk__system_fault_led__delay:		DELAY (POSEDGE) clk system_fault_led ;
pos_clk__w_g_left__delay:		DELAY (POSEDGE) clk w_g_left ;
pos_clk__w_g_ped__delay:		DELAY (POSEDGE) clk w_g_ped ;
pos_clk__w_g_stra__delay:		DELAY (POSEDGE) clk w_g_stra ;
pos_clk__w_r_left__delay:		DELAY (POSEDGE) clk w_r_left ;
pos_clk__w_r_ped__delay:		DELAY (POSEDGE) clk w_r_ped ;
pos_clk__w_r_stra__delay:		DELAY (POSEDGE) clk w_r_stra ;
pos_clk__w_y_left__delay:		DELAY (POSEDGE) clk w_y_left ;
pos_clk__w_y_stra__delay:		DELAY (POSEDGE) clk w_y_stra ;
_8.325__8.155__delay:		DELAY 8.325 8.155 ;
_8.034__7.864__delay:		DELAY 8.034 7.864 ;
_10.256__9.717__delay:		DELAY 10.256 9.717 ;
_7.931__7.761__delay:		DELAY 7.931 7.761 ;

ENDMODEL
