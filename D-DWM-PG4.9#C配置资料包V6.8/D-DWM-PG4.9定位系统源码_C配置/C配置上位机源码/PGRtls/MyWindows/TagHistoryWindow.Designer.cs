namespace PGRtls.MyWindows
{
    partial class TagHistoryWindow
    {
        /// <summary>
        /// Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form Designer generated code

        /// <summary>
        /// Required method for Designer support - do not modify
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            this.components = new System.ComponentModel.Container();
            this.numericUpDown_TagSize = new System.Windows.Forms.NumericUpDown();
            this.label11 = new System.Windows.Forms.Label();
            this.checkBox_name = new System.Windows.Forms.CheckBox();
            this.checkBox_draw_distcircle = new System.Windows.Forms.CheckBox();
            this.checkBox_axis = new System.Windows.Forms.CheckBox();
            this.checkBox_taginfo = new System.Windows.Forms.CheckBox();
            this.Draw_timer = new System.Windows.Forms.Timer(this.components);
            this.CheckBox_map = new System.Windows.Forms.CheckBox();
            this.Text_time_now = new System.Windows.Forms.Label();
            this.label1 = new System.Windows.Forms.Label();
            this.Text_time_total = new System.Windows.Forms.Label();
            this.Btn_stop = new System.Windows.Forms.Button();
            this.Btn_pause = new System.Windows.Forms.Button();
            this.Btn_start = new System.Windows.Forms.Button();
            this.PictureBox_draw = new System.Windows.Forms.PictureBox();
            this.Text_status = new System.Windows.Forms.Label();
            this.custom_trackbar1 = new PGRtls.CustomControls.Custom_trackbar();
            ((System.ComponentModel.ISupportInitialize)(this.numericUpDown_TagSize)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.PictureBox_draw)).BeginInit();
            this.SuspendLayout();
            // 
            // numericUpDown_TagSize
            // 
            this.numericUpDown_TagSize.Location = new System.Drawing.Point(654, 9);
            this.numericUpDown_TagSize.Maximum = new decimal(new int[] {
            20,
            0,
            0,
            0});
            this.numericUpDown_TagSize.Name = "numericUpDown_TagSize";
            this.numericUpDown_TagSize.Size = new System.Drawing.Size(44, 21);
            this.numericUpDown_TagSize.TabIndex = 100;
            this.numericUpDown_TagSize.Value = new decimal(new int[] {
            8,
            0,
            0,
            0});
            this.numericUpDown_TagSize.ValueChanged += new System.EventHandler(this.numericUpDown_TagSize_ValueChanged);
            // 
            // label11
            // 
            this.label11.AutoSize = true;
            this.label11.Location = new System.Drawing.Point(589, 13);
            this.label11.Name = "label11";
            this.label11.Size = new System.Drawing.Size(59, 12);
            this.label11.TabIndex = 99;
            this.label11.Text = "标签大小:";
            // 
            // checkBox_name
            // 
            this.checkBox_name.AutoSize = true;
            this.checkBox_name.Checked = true;
            this.checkBox_name.CheckState = System.Windows.Forms.CheckState.Checked;
            this.checkBox_name.Location = new System.Drawing.Point(368, 11);
            this.checkBox_name.Name = "checkBox_name";
            this.checkBox_name.RightToLeft = System.Windows.Forms.RightToLeft.Yes;
            this.checkBox_name.Size = new System.Drawing.Size(108, 16);
            this.checkBox_name.TabIndex = 93;
            this.checkBox_name.Text = ":设备名称-显示";
            this.checkBox_name.UseVisualStyleBackColor = true;
            // 
            // checkBox_draw_distcircle
            // 
            this.checkBox_draw_distcircle.AutoSize = true;
            this.checkBox_draw_distcircle.Location = new System.Drawing.Point(120, 10);
            this.checkBox_draw_distcircle.Name = "checkBox_draw_distcircle";
            this.checkBox_draw_distcircle.RightToLeft = System.Windows.Forms.RightToLeft.Yes;
            this.checkBox_draw_distcircle.Size = new System.Drawing.Size(96, 16);
            this.checkBox_draw_distcircle.TabIndex = 90;
            this.checkBox_draw_distcircle.Text = ":测距圆-显示";
            this.checkBox_draw_distcircle.UseVisualStyleBackColor = true;
            // 
            // checkBox_axis
            // 
            this.checkBox_axis.AutoSize = true;
            this.checkBox_axis.Checked = true;
            this.checkBox_axis.CheckState = System.Windows.Forms.CheckState.Checked;
            this.checkBox_axis.Location = new System.Drawing.Point(12, 10);
            this.checkBox_axis.Name = "checkBox_axis";
            this.checkBox_axis.RightToLeft = System.Windows.Forms.RightToLeft.Yes;
            this.checkBox_axis.Size = new System.Drawing.Size(96, 16);
            this.checkBox_axis.TabIndex = 91;
            this.checkBox_axis.Text = ":坐标轴-显示";
            this.checkBox_axis.UseVisualStyleBackColor = true;
            // 
            // checkBox_taginfo
            // 
            this.checkBox_taginfo.AutoSize = true;
            this.checkBox_taginfo.Location = new System.Drawing.Point(222, 10);
            this.checkBox_taginfo.Name = "checkBox_taginfo";
            this.checkBox_taginfo.RightToLeft = System.Windows.Forms.RightToLeft.Yes;
            this.checkBox_taginfo.Size = new System.Drawing.Size(132, 16);
            this.checkBox_taginfo.TabIndex = 92;
            this.checkBox_taginfo.Text = ":标签名称坐标-显示";
            this.checkBox_taginfo.UseVisualStyleBackColor = true;
            // 
            // Draw_timer
            // 
            this.Draw_timer.Tick += new System.EventHandler(this.Draw_timer_Tick);
            // 
            // CheckBox_map
            // 
            this.CheckBox_map.AutoSize = true;
            this.CheckBox_map.Location = new System.Drawing.Point(489, 11);
            this.CheckBox_map.Name = "CheckBox_map";
            this.CheckBox_map.RightToLeft = System.Windows.Forms.RightToLeft.Yes;
            this.CheckBox_map.Size = new System.Drawing.Size(78, 16);
            this.CheckBox_map.TabIndex = 102;
            this.CheckBox_map.Text = "地图-显示";
            this.CheckBox_map.UseVisualStyleBackColor = true;
            // 
            // Text_time_now
            // 
            this.Text_time_now.AutoSize = true;
            this.Text_time_now.Location = new System.Drawing.Point(526, 459);
            this.Text_time_now.Name = "Text_time_now";
            this.Text_time_now.Size = new System.Drawing.Size(143, 12);
            this.Text_time_now.TabIndex = 103;
            this.Text_time_now.Text = "2024/10/10 10:10:10 100";
            // 
            // label1
            // 
            this.label1.AutoSize = true;
            this.label1.Location = new System.Drawing.Point(675, 459);
            this.label1.Name = "label1";
            this.label1.Size = new System.Drawing.Size(23, 12);
            this.label1.TabIndex = 104;
            this.label1.Text = " / ";
            // 
            // Text_time_total
            // 
            this.Text_time_total.AutoSize = true;
            this.Text_time_total.Location = new System.Drawing.Point(704, 459);
            this.Text_time_total.Name = "Text_time_total";
            this.Text_time_total.Size = new System.Drawing.Size(143, 12);
            this.Text_time_total.TabIndex = 105;
            this.Text_time_total.Text = "2024/10/10 10:10:10 100";
            // 
            // Btn_stop
            // 
            this.Btn_stop.BackColor = System.Drawing.Color.Transparent;
            this.Btn_stop.BackgroundImage = global::PGRtls.Properties.Resources._24gl_stop;
            this.Btn_stop.BackgroundImageLayout = System.Windows.Forms.ImageLayout.Stretch;
            this.Btn_stop.Location = new System.Drawing.Point(105, 449);
            this.Btn_stop.Name = "Btn_stop";
            this.Btn_stop.Size = new System.Drawing.Size(35, 32);
            this.Btn_stop.TabIndex = 108;
            this.Btn_stop.UseVisualStyleBackColor = false;
            this.Btn_stop.Click += new System.EventHandler(this.Btn_stop_Click);
            // 
            // Btn_pause
            // 
            this.Btn_pause.BackColor = System.Drawing.Color.Transparent;
            this.Btn_pause.BackgroundImage = global::PGRtls.Properties.Resources._24gl_pause2;
            this.Btn_pause.BackgroundImageLayout = System.Windows.Forms.ImageLayout.Stretch;
            this.Btn_pause.Location = new System.Drawing.Point(62, 449);
            this.Btn_pause.Name = "Btn_pause";
            this.Btn_pause.Size = new System.Drawing.Size(35, 32);
            this.Btn_pause.TabIndex = 107;
            this.Btn_pause.UseVisualStyleBackColor = false;
            this.Btn_pause.Click += new System.EventHandler(this.Btn_pause_Click);
            // 
            // Btn_start
            // 
            this.Btn_start.BackColor = System.Drawing.Color.Transparent;
            this.Btn_start.BackgroundImage = global::PGRtls.Properties.Resources._24gl_start;
            this.Btn_start.BackgroundImageLayout = System.Windows.Forms.ImageLayout.Stretch;
            this.Btn_start.Location = new System.Drawing.Point(21, 449);
            this.Btn_start.Name = "Btn_start";
            this.Btn_start.Size = new System.Drawing.Size(35, 32);
            this.Btn_start.TabIndex = 106;
            this.Btn_start.UseVisualStyleBackColor = false;
            this.Btn_start.Click += new System.EventHandler(this.Btn_start_Click);
            // 
            // PictureBox_draw
            // 
            this.PictureBox_draw.BackColor = System.Drawing.Color.White;
            this.PictureBox_draw.Location = new System.Drawing.Point(6, 45);
            this.PictureBox_draw.Name = "PictureBox_draw";
            this.PictureBox_draw.Size = new System.Drawing.Size(848, 400);
            this.PictureBox_draw.TabIndex = 83;
            this.PictureBox_draw.TabStop = false;
            this.PictureBox_draw.MouseMove += new System.Windows.Forms.MouseEventHandler(this.PictureBox_draw_MouseMove);
            // 
            // Text_status
            // 
            this.Text_status.AutoSize = true;
            this.Text_status.Font = new System.Drawing.Font("宋体", 10.5F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, ((byte)(134)));
            this.Text_status.Location = new System.Drawing.Point(740, 490);
            this.Text_status.Name = "Text_status";
            this.Text_status.Size = new System.Drawing.Size(76, 14);
            this.Text_status.TabIndex = 109;
            this.Text_status.Text = "空闲中...";
            // 
            // custom_trackbar1
            // 
            this.custom_trackbar1.C_BarColor = System.Drawing.SystemColors.GradientInactiveCaption;
            this.custom_trackbar1.C_BarSize = 10;
            this.custom_trackbar1.C_IsRound = true;
            this.custom_trackbar1.C_Maximum = 100;
            this.custom_trackbar1.C_Minimum = 0;
            this.custom_trackbar1.C_Orientation = PGRtls.CustomControls.C_Trackbar_Orientation.Horizontal_LR;
            this.custom_trackbar1.C_SliderColor = System.Drawing.SystemColors.Highlight;
            this.custom_trackbar1.C_Value = 0;
            this.custom_trackbar1.Location = new System.Drawing.Point(157, 459);
            this.custom_trackbar1.Name = "custom_trackbar1";
            this.custom_trackbar1.Size = new System.Drawing.Size(363, 10);
            this.custom_trackbar1.TabIndex = 101;
            this.custom_trackbar1.Text = "custom_trackbar1";
            this.custom_trackbar1.CValueChanged += new PGRtls.CustomControls.Custom_trackbar.CValueChangedEventHandler(this.custom_trackbar1_CValueChanged);
            // 
            // TagHistoryWindow
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 12F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(862, 513);
            this.Controls.Add(this.Text_status);
            this.Controls.Add(this.Btn_stop);
            this.Controls.Add(this.Btn_pause);
            this.Controls.Add(this.Btn_start);
            this.Controls.Add(this.Text_time_total);
            this.Controls.Add(this.label1);
            this.Controls.Add(this.Text_time_now);
            this.Controls.Add(this.CheckBox_map);
            this.Controls.Add(this.custom_trackbar1);
            this.Controls.Add(this.numericUpDown_TagSize);
            this.Controls.Add(this.label11);
            this.Controls.Add(this.checkBox_name);
            this.Controls.Add(this.checkBox_taginfo);
            this.Controls.Add(this.checkBox_draw_distcircle);
            this.Controls.Add(this.checkBox_axis);
            this.Controls.Add(this.PictureBox_draw);
            this.MaximizeBox = false;
            this.Name = "TagHistoryWindow";
            this.ShowIcon = false;
            this.StartPosition = System.Windows.Forms.FormStartPosition.CenterScreen;
            this.Text = "二维轨迹回放";
            this.Load += new System.EventHandler(this.TagHistoryWindow_Load);
            ((System.ComponentModel.ISupportInitialize)(this.numericUpDown_TagSize)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.PictureBox_draw)).EndInit();
            this.ResumeLayout(false);
            this.PerformLayout();

        }

        #endregion

        private System.Windows.Forms.NumericUpDown numericUpDown_TagSize;
        private System.Windows.Forms.Label label11;
        private System.Windows.Forms.CheckBox checkBox_name;
        private System.Windows.Forms.CheckBox checkBox_draw_distcircle;
        private System.Windows.Forms.CheckBox checkBox_axis;
        private System.Windows.Forms.PictureBox PictureBox_draw;
        private System.Windows.Forms.CheckBox checkBox_taginfo;
        private CustomControls.Custom_trackbar custom_trackbar1;
        private System.Windows.Forms.Timer Draw_timer;
        private System.Windows.Forms.CheckBox CheckBox_map;
        private System.Windows.Forms.Label Text_time_now;
        private System.Windows.Forms.Label label1;
        private System.Windows.Forms.Label Text_time_total;
        private System.Windows.Forms.Button Btn_start;
        private System.Windows.Forms.Button Btn_pause;
        private System.Windows.Forms.Button Btn_stop;
        private System.Windows.Forms.Label Text_status;
    }
}