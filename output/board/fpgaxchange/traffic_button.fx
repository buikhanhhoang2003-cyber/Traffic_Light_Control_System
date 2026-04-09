###############################################################################
# Copyright (C) 1991-2026 Altera Corporation. All rights reserved.
# Any  megafunction  design,  and related netlist (encrypted  or  decrypted),
# support information,  device programming or simulation file,  and any other
# associated  documentation or information  provided by  Intel  or a partner
# under  Intel's   Megafunction   Partnership   Program  may  be  used  only
# to program  PLD  devices (but not masked  PLD  devices) from  Intel.   Any
# other  use  of such  megafunction  design,  netlist,  support  information,
# device programming or simulation file,  or any other  related documentation
# or information  is prohibited  for  any  other purpose,  including, but not
# limited to  modification,  reverse engineering,  de-compiling, or use  with
# any other  silicon devices,  unless such use is  explicitly  licensed under
# a separate agreement with  Intel  or a megafunction partner.  Title to the
# intellectual property,  including patents,  copyrights,  trademarks,  trade
# secrets,  or maskworks,  embodied in any such megafunction design, netlist,
# support  information,  device programming or simulation file,  or any other
# related documentation or information provided by  Intel  or a megafunction
# partner, remains with Intel, the megafunction partner, or their respective
# licensors. No other licenses, including any licenses needed under any third
# party's intellectual property, are provided herein.
#
###############################################################################


# FPGA Xchange file generated using Quartus Prime Version 20.1.0 Build 711 06/05/2020 SJ Lite Edition

# DESIGN=traffic_button
# REVISION=traffic_button
# DEVICE=EP4CE6
# PACKAGE=TQFP
# SPEEDGRADE=8

Signal Name,Pin Number,Direction,IO Standard,Drive (mA),Termination,Slew Rate,Swap Group,Diff Type

SVNSEG_SEG[0],128,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
SVNSEG_SEG[1],121,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
SVNSEG_SEG[2],125,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
SVNSEG_SEG[3],129,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
SVNSEG_SEG[4],132,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
SVNSEG_SEG[5],126,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
SVNSEG_SEG[6],124,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
SVNSEG_SEG[7],127,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
n_r_left,34,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
n_y_left,32,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
n_g_left,30,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
n_r_ped,52,output,2.5 V,Default,Series 50 Ohm without Calibration,FAST,swap_1,--
n_g_ped,84,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
n_r_stra,33,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
n_y_stra,31,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
n_g_stra,28,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
s_r_left,112,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
s_y_left,113,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
s_g_left,141,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
s_r_ped,100,output,2.5 V,Default,Series 50 Ohm without Calibration,FAST,swap_1,--
s_g_ped,85,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
s_r_stra,119,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
s_y_stra,120,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
s_g_stra,55,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
e_r_left,60,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
e_y_left,65,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
e_g_left,111,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
e_r_ped,53,output,2.5 V,Default,Series 50 Ohm without Calibration,FAST,swap_1,--
e_g_ped,86,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
e_r_stra,64,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
e_y_stra,59,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
e_g_stra,80,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
w_r_left,73,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
w_y_left,71,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
w_g_left,69,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
w_r_ped,99,output,2.5 V,Default,Series 50 Ohm without Calibration,FAST,swap_1,--
w_g_ped,87,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
w_r_stra,72,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
w_y_stra,70,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
w_g_stra,68,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
system_fault_led,144,output,3.3-V LVTTL,8,Off,FAST,swap_0,--
dig_dip[0],133,bidir,3.3-V LVTTL,,Off,--,swap_2,--
dig_dip[1],135,bidir,3.3-V LVTTL,,Off,--,swap_2,--
dig_dip[2],136,bidir,3.3-V LVTTL,,Off,--,swap_2,--
dig_dip[3],137,bidir,3.3-V LVTTL,,Off,--,swap_2,--
clk,23,input,3.3-V LVTTL,,Off,--,swap_3,--
rst_n,24,input,3.3-V LVTTL,,Off,--,swap_3,--
io_mode,138,input,3.3-V LVTTL,,Off,--,swap_3,--
cfg_data[0],103,input,3.3-V LVTTL,,Off,--,swap_3,--
cfg_addr[3],106,input,3.3-V LVTTL,,Off,--,swap_3,--
cfg_we,110,input,3.3-V LVTTL,,Off,--,swap_3,--
cfg_addr[1],83,input,3.3-V LVTTL,,Off,--,swap_3,--
cfg_addr[2],88,input,3.3-V LVTTL,,Off,--,swap_3,--
cfg_addr[0],89,input,3.3-V LVTTL,,Off,--,swap_3,--
cfg_data[7],105,input,3.3-V LVTTL,,Off,--,swap_3,--
cfg_data[6],90,input,3.3-V LVTTL,,Off,--,swap_3,--
cfg_data[5],91,input,3.3-V LVTTL,,Off,--,swap_3,--
cfg_data[4],114,input,3.3-V LVTTL,,Off,--,swap_3,--
cfg_data[3],115,input,3.3-V LVTTL,,Off,--,swap_3,--
cfg_data[2],104,input,3.3-V LVTTL,,Off,--,swap_3,--
cfg_data[1],98,input,3.3-V LVTTL,,Off,--,swap_3,--
~ALTERA_ASDO_DATA1~,6,input,3.3-V LVTTL,,Off,--,NOSWAP,--
~ALTERA_FLASH_nCE_nCSO~,8,input,3.3-V LVTTL,,Off,--,NOSWAP,--
~ALTERA_DCLK~,12,output,3.3-V LVTTL,Default,Off,FAST,NOSWAP,--
~ALTERA_DATA0~,13,input,3.3-V LVTTL,,Off,--,NOSWAP,--
~ALTERA_nCEO~,101,output,2.5 V,8,Off,FAST,NOSWAP,--
