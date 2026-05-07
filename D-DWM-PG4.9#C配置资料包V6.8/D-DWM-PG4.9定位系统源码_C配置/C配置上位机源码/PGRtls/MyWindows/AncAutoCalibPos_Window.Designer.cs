namespace PGRtls.MyWindows
{
    partial class AncAutoCalibPos_Window
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
            this.groupBox1 = new System.Windows.Forms.GroupBox();
            this.Tb_log = new System.Windows.Forms.TextBox();
            this.groupBox2 = new System.Windows.Forms.GroupBox();
            this.label4 = new System.Windows.Forms.Label();
            this.Combo_MarkAxis = new System.Windows.Forms.ComboBox();
            this.label3 = new System.Windows.Forms.Label();
            this.Combo_MarkAnc = new System.Windows.Forms.ComboBox();
            this.label2 = new System.Windows.Forms.Label();
            this.Combo_ScaleOption = new System.Windows.Forms.ComboBox();
            this.label1 = new System.Windows.Forms.Label();
            this.Combo_OriginAnc = new System.Windows.Forms.ComboBox();
            this.Btn_Reset = new System.Windows.Forms.Button();
            this.Btn_Comfirm = new System.Windows.Forms.Button();
            this.Btn_Stop = new System.Windows.Forms.Button();
            this.Btn_Start = new System.Windows.Forms.Button();
            this.DataGridView_Anc = new System.Windows.Forms.DataGridView();
            this.groupBox3 = new System.Windows.Forms.GroupBox();
            this.PictureBox_draw = new System.Windows.Forms.PictureBox();
            this.Draw_timer = new System.Windows.Forms.Timer(this.components);
            this.Column_select = new System.Windows.Forms.DataGridViewCheckBoxColumn();
            this.Column_ID = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.Column_X = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.Column_y = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.groupBox1.SuspendLayout();
            this.groupBox2.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.DataGridView_Anc)).BeginInit();
            this.groupBox3.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.PictureBox_draw)).BeginInit();
            this.SuspendLayout();
            // 
            // groupBox1
            // 
            this.groupBox1.Controls.Add(this.Tb_log);
            this.groupBox1.Location = new System.Drawing.Point(12, 330);
            this.groupBox1.Name = "groupBox1";
            this.groupBox1.Size = new System.Drawing.Size(440, 241);
            this.groupBox1.TabIndex = 1;
            this.groupBox1.TabStop = false;
            this.groupBox1.Text = "Log显示";
            // 
            // Tb_log
            // 
            this.Tb_log.Location = new System.Drawing.Point(11, 20);
            this.Tb_log.Multiline = true;
            this.Tb_log.Name = "Tb_log";
            this.Tb_log.ScrollBars = System.Windows.Forms.ScrollBars.Vertical;
            this.Tb_log.Size = new System.Drawing.Size(413, 206);
            this.Tb_log.TabIndex = 0;
            this.Tb_log.TextChanged += new System.EventHandler(this.Tb_log_TextChanged);
            // 
            // groupBox2
            // 
            this.groupBox2.Controls.Add(this.label4);
            this.groupBox2.Controls.Add(this.Combo_MarkAxis);
            this.groupBox2.Controls.Add(this.label3);
            this.groupBox2.Controls.Add(this.Combo_MarkAnc);
            this.groupBox2.Controls.Add(this.label2);
            this.groupBox2.Controls.Add(this.Combo_ScaleOption);
            this.groupBox2.Controls.Add(this.label1);
            this.groupBox2.Controls.Add(this.Combo_OriginAnc);
            this.groupBox2.Controls.Add(this.Btn_Reset);
            this.groupBox2.Controls.Add(this.Btn_Comfirm);
            this.groupBox2.Controls.Add(this.Btn_Stop);
            this.groupBox2.Controls.Add(this.Btn_Start);
            this.groupBox2.Controls.Add(this.DataGridView_Anc);
            this.groupBox2.Location = new System.Drawing.Point(12, 12);
            this.groupBox2.Name = "groupBox2";
            this.groupBox2.Size = new System.Drawing.Size(440, 312);
            this.groupBox2.TabIndex = 2;
            this.groupBox2.TabStop = false;
            this.groupBox2.Text = "功能控制";
            // 
            // label4
            // 
            this.label4.AutoSize = true;
            this.label4.Location = new System.Drawing.Point(161, 107);
            this.label4.Name = "label4";
            this.label4.Size = new System.Drawing.Size(131, 12);
            this.label4.TabIndex = 12;
            this.label4.Text = "辅助点基站所在坐标轴:";
            // 
            // Combo_MarkAxis
            // 
            this.Combo_MarkAxis.FormattingEnabled = true;
            this.Combo_MarkAxis.Items.AddRange(new object[] {
            "x轴正半轴",
            "x轴负半轴",
            "y轴正半轴",
            "y轴负半轴"});
            this.Combo_MarkAxis.Location = new System.Drawing.Point(295, 103);
            this.Combo_MarkAxis.Name = "Combo_MarkAxis";
            this.Combo_MarkAxis.Size = new System.Drawing.Size(92, 20);
            this.Combo_MarkAxis.TabIndex = 11;
            this.Combo_MarkAxis.SelectedIndexChanged += new System.EventHandler(this.Combo_MarkAxis_SelectedIndexChanged);
            // 
            // label3
            // 
            this.label3.AutoSize = true;
            this.label3.Location = new System.Drawing.Point(9, 107);
            this.label3.Name = "label3";
            this.label3.Size = new System.Drawing.Size(71, 12);
            this.label3.TabIndex = 10;
            this.label3.Text = "辅助点基站:";
            // 
            // Combo_MarkAnc
            // 
            this.Combo_MarkAnc.FormattingEnabled = true;
            this.Combo_MarkAnc.Location = new System.Drawing.Point(82, 103);
            this.Combo_MarkAnc.Name = "Combo_MarkAnc";
            this.Combo_MarkAnc.Size = new System.Drawing.Size(64, 20);
            this.Combo_MarkAnc.TabIndex = 9;
            this.Combo_MarkAnc.DropDown += new System.EventHandler(this.Combo_MarkAnc_DropDown);
            this.Combo_MarkAnc.SelectedIndexChanged += new System.EventHandler(this.Combo_MarkAnc_SelectedIndexChanged);
            // 
            // label2
            // 
            this.label2.AutoSize = true;
            this.label2.Location = new System.Drawing.Point(158, 76);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(59, 12);
            this.label2.TabIndex = 8;
            this.label2.Text = "基站方向:";
            // 
            // Combo_ScaleOption
            // 
            this.Combo_ScaleOption.FormattingEnabled = true;
            this.Combo_ScaleOption.Items.AddRange(new object[] {
            "顺时针",
            "逆时针"});
            this.Combo_ScaleOption.Location = new System.Drawing.Point(218, 72);
            this.Combo_ScaleOption.Name = "Combo_ScaleOption";
            this.Combo_ScaleOption.Size = new System.Drawing.Size(92, 20);
            this.Combo_ScaleOption.TabIndex = 7;
            this.Combo_ScaleOption.SelectedIndexChanged += new System.EventHandler(this.Combo_ScaleOption_SelectedIndexChanged);
            // 
            // label1
            // 
            this.label1.AutoSize = true;
            this.label1.Location = new System.Drawing.Point(9, 76);
            this.label1.Name = "label1";
            this.label1.Size = new System.Drawing.Size(59, 12);
            this.label1.TabIndex = 6;
            this.label1.Text = "原点基站:";
            // 
            // Combo_OriginAnc
            // 
            this.Combo_OriginAnc.FormattingEnabled = true;
            this.Combo_OriginAnc.Location = new System.Drawing.Point(69, 72);
            this.Combo_OriginAnc.Name = "Combo_OriginAnc";
            this.Combo_OriginAnc.Size = new System.Drawing.Size(69, 20);
            this.Combo_OriginAnc.TabIndex = 5;
            this.Combo_OriginAnc.DropDown += new System.EventHandler(this.Combo_OriginAnc_DropDown);
            this.Combo_OriginAnc.SelectedIndexChanged += new System.EventHandler(this.Combo_OriginAnc_SelectedIndexChanged);
            // 
            // Btn_Reset
            // 
            this.Btn_Reset.Location = new System.Drawing.Point(338, 20);
            this.Btn_Reset.Name = "Btn_Reset";
            this.Btn_Reset.Size = new System.Drawing.Size(86, 36);
            this.Btn_Reset.TabIndex = 4;
            this.Btn_Reset.Text = "重置坐标";
            this.Btn_Reset.UseVisualStyleBackColor = true;
            this.Btn_Reset.Click += new System.EventHandler(this.Btn_Reset_Click);
            // 
            // Btn_Comfirm
            // 
            this.Btn_Comfirm.Location = new System.Drawing.Point(229, 20);
            this.Btn_Comfirm.Name = "Btn_Comfirm";
            this.Btn_Comfirm.Size = new System.Drawing.Size(86, 36);
            this.Btn_Comfirm.TabIndex = 3;
            this.Btn_Comfirm.Text = "确认更改";
            this.Btn_Comfirm.UseVisualStyleBackColor = true;
            this.Btn_Comfirm.Click += new System.EventHandler(this.Btn_Comfirm_Click);
            // 
            // Btn_Stop
            // 
            this.Btn_Stop.Location = new System.Drawing.Point(120, 20);
            this.Btn_Stop.Name = "Btn_Stop";
            this.Btn_Stop.Size = new System.Drawing.Size(86, 36);
            this.Btn_Stop.TabIndex = 2;
            this.Btn_Stop.Text = "停止标定";
            this.Btn_Stop.UseVisualStyleBackColor = true;
            this.Btn_Stop.Click += new System.EventHandler(this.Btn_Stop_Click);
            // 
            // Btn_Start
            // 
            this.Btn_Start.Location = new System.Drawing.Point(11, 20);
            this.Btn_Start.Name = "Btn_Start";
            this.Btn_Start.Size = new System.Drawing.Size(86, 36);
            this.Btn_Start.TabIndex = 1;
            this.Btn_Start.Text = "开始标定";
            this.Btn_Start.UseVisualStyleBackColor = true;
            this.Btn_Start.Click += new System.EventHandler(this.Btn_Start_Click);
            // 
            // DataGridView_Anc
            // 
            this.DataGridView_Anc.AllowUserToAddRows = false;
            this.DataGridView_Anc.AllowUserToResizeRows = false;
            this.DataGridView_Anc.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.DataGridView_Anc.Columns.AddRange(new System.Windows.Forms.DataGridViewColumn[] {
            this.Column_select,
            this.Column_ID,
            this.Column_X,
            this.Column_y});
            this.DataGridView_Anc.Location = new System.Drawing.Point(11, 140);
            this.DataGridView_Anc.Name = "DataGridView_Anc";
            this.DataGridView_Anc.RowHeadersVisible = false;
            this.DataGridView_Anc.RowTemplate.Height = 23;
            this.DataGridView_Anc.Size = new System.Drawing.Size(413, 166);
            this.DataGridView_Anc.TabIndex = 0;
            // 
            // groupBox3
            // 
            this.groupBox3.BackColor = System.Drawing.SystemColors.ControlLightLight;
            this.groupBox3.Controls.Add(this.PictureBox_draw);
            this.groupBox3.Location = new System.Drawing.Point(468, 12);
            this.groupBox3.Name = "groupBox3";
            this.groupBox3.Size = new System.Drawing.Size(408, 559);
            this.groupBox3.TabIndex = 3;
            this.groupBox3.TabStop = false;
            this.groupBox3.Text = "结果显示";
            // 
            // PictureBox_draw
            // 
            this.PictureBox_draw.BackColor = System.Drawing.Color.Transparent;
            this.PictureBox_draw.Location = new System.Drawing.Point(16, 20);
            this.PictureBox_draw.Name = "PictureBox_draw";
            this.PictureBox_draw.Size = new System.Drawing.Size(386, 524);
            this.PictureBox_draw.TabIndex = 1;
            this.PictureBox_draw.TabStop = false;
            this.PictureBox_draw.MouseMove += new System.Windows.Forms.MouseEventHandler(this.PictureBox_draw_MouseMove);
            this.PictureBox_draw.MouseWheel += new System.Windows.Forms.MouseEventHandler(this.PictureBox_draw_MouseWheel);
            // 
            // Draw_timer
            // 
            this.Draw_timer.Tick += new System.EventHandler(this.Draw_timer_Tick);
            // 
            // Column_select
            // 
            this.Column_select.HeaderText = "使能";
            this.Column_select.Name = "Column_select";
            this.Column_select.Width = 50;
            // 
            // Column_ID
            // 
            this.Column_ID.HeaderText = "基站ID";
            this.Column_ID.Name = "Column_ID";
            this.Column_ID.ReadOnly = true;
            this.Column_ID.Width = 75;
            // 
            // Column_X
            // 
            this.Column_X.HeaderText = "解算x(cm)";
            this.Column_X.Name = "Column_X";
            this.Column_X.ReadOnly = true;
            this.Column_X.Width = 90;
            // 
            // Column_y
            // 
            this.Column_y.HeaderText = "解算y(cm)";
            this.Column_y.Name = "Column_y";
            this.Column_y.ReadOnly = true;
            this.Column_y.Width = 90;
            // 
            // AncAutoCalibPos_Window
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 12F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(888, 583);
            this.Controls.Add(this.groupBox3);
            this.Controls.Add(this.groupBox2);
            this.Controls.Add(this.groupBox1);
            this.Name = "AncAutoCalibPos_Window";
            this.StartPosition = System.Windows.Forms.FormStartPosition.CenterScreen;
            this.Text = "基站自主标定";
            this.FormClosing += new System.Windows.Forms.FormClosingEventHandler(this.AncAutoCalibPos_Window_FormClosing);
            this.Load += new System.EventHandler(this.AncAutoCalibPos_Window_Load);
            this.groupBox1.ResumeLayout(false);
            this.groupBox1.PerformLayout();
            this.groupBox2.ResumeLayout(false);
            this.groupBox2.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)(this.DataGridView_Anc)).EndInit();
            this.groupBox3.ResumeLayout(false);
            ((System.ComponentModel.ISupportInitialize)(this.PictureBox_draw)).EndInit();
            this.ResumeLayout(false);

        }

        #endregion
        private System.Windows.Forms.GroupBox groupBox1;
        private System.Windows.Forms.TextBox Tb_log;
        private System.Windows.Forms.GroupBox groupBox2;
        private System.Windows.Forms.DataGridView DataGridView_Anc;
        private System.Windows.Forms.Button Btn_Comfirm;
        private System.Windows.Forms.Button Btn_Stop;
        private System.Windows.Forms.Button Btn_Start;
        private System.Windows.Forms.GroupBox groupBox3;
        private System.Windows.Forms.PictureBox PictureBox_draw;
        private System.Windows.Forms.Button Btn_Reset;
        private System.Windows.Forms.Label label4;
        private System.Windows.Forms.ComboBox Combo_MarkAxis;
        private System.Windows.Forms.Label label3;
        private System.Windows.Forms.ComboBox Combo_MarkAnc;
        private System.Windows.Forms.Label label2;
        private System.Windows.Forms.ComboBox Combo_ScaleOption;
        private System.Windows.Forms.Label label1;
        private System.Windows.Forms.ComboBox Combo_OriginAnc;
        private System.Windows.Forms.Timer Draw_timer;
        private System.Windows.Forms.DataGridViewCheckBoxColumn Column_select;
        private System.Windows.Forms.DataGridViewTextBoxColumn Column_ID;
        private System.Windows.Forms.DataGridViewTextBoxColumn Column_X;
        private System.Windows.Forms.DataGridViewTextBoxColumn Column_y;
    }
}