#ifndef __LOC_H
#define __LOC_H

#include "stdint.h"
#include "common_config.h"




// uint8_t PersonPosition_xy(double A_x,double A_y,double A_r,u16 A_en,
//														double B_x,double B_y,double B_r,u16 B_en,
//														double C_x,double C_y,double C_r,u16 C_en,
//														double D_x,double D_y,double D_r,u16 D_en,
//														double E_x,double E_y,double E_r,u16 E_en,
//														double F_x,double F_y,double F_r,u16 F_en,
//														double G_x,double G_y,double G_r,u16 G_en,
//														double H_x,double H_y,double H_r,u16 H_en,double *point_out);
														
uint8_t Rtls_Cal_2D(Anchor_t *anc_list ,uint32_t Calculate_FLAG, float *point_out);
														
//uint8_t PersonPosition_xyz(double A_x,double A_y,double A_z,double A_r,u16 A_en,
//														double B_x,double B_y,double B_z,double B_r,u16 B_en,
//														double C_x,double C_y,double C_z,double C_r,u16 C_en,
//														double D_x,double D_y,double D_z,double D_r,u16 D_en,
//														double E_x,double E_y,double E_z,double E_r,u16 E_en,
//														double F_x,double F_y,double F_z,double F_r,u16 F_en,
//														double G_x,double G_y,double G_z,double G_r,u16 G_en,
//														double H_x,double H_y,double H_z,double H_r,u16 H_en,double *point_out_xyz);

uint8_t Rtls_Cal_3D(Anchor_t *anc_list ,uint32_t Calculate_FLAG ,float *point_out);														
														
uint8_t Get_three_BS_Out_XYZ(double x1, double y1, double z1, double r1,
                           double x2, double y2, double z2, double r2,
                           double x3, double y3, double z3, double r3,
                           double x4, double y4, double z4, double r4,double *Point_xyz);//三维坐标求解


uint8_t Get_three_BS_Out_XY(double A_x,double A_y,double A_r, 
												 double B_x,double B_y,double B_r,
												 double C_x,double C_y,double C_r,double *PP_point_out);
												 
uint8_t Get_three_BS_Out_XYZ_New(double x1, double y1, double z1, double r1,
								 double x2, double y2, double z2, double r2,
								 double x3, double y3, double z3, double r3,
								 double x4, double y4, double z4, double r4,float *Point_xyz);
								 
uint8_t Judge(double x1, double y1,
         double x2, double y2,
         double x3, double y3);
													 
#endif
