
namespace PGRtls.MyWindows
{
    partial class NavigationWindow
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
            this.DataGridView_Tag = new System.Windows.Forms.DataGridView();
            this.Column_ID = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.Column_x = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.Column_y = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.Column_z = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.Column_status = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.Column_angle = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.Column_magn = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.Btn_Search_naviTag = new System.Windows.Forms.Button();
            this.groupBox1 = new System.Windows.Forms.GroupBox();
            this.groupBox2 = new System.Windows.Forms.GroupBox();
            this.Btn_GetSpeed = new System.Windows.Forms.Button();
            this.label4 = new System.Windows.Forms.Label();
            this.Btn_changespeed = new System.Windows.Forms.Button();
            this.comboBox_ChangeSpeed = new System.Windows.Forms.ComboBox();
            this.Text_Tag_id = new System.Windows.Forms.Label();
            this.label7 = new System.Windows.Forms.Label();
            this.Text_status = new System.Windows.Forms.Label();
            this.groupBox_auto = new System.Windows.Forms.GroupBox();
            this.Btn_cursorSelect = new System.Windows.Forms.Button();
            this.Btn_StartMove = new System.Windows.Forms.Button();
            this.numericUpDown_dest_y = new System.Windows.Forms.NumericUpDown();
            this.numericUpDown_dest_x = new System.Windows.Forms.NumericUpDown();
            this.label6 = new System.Windows.Forms.Label();
            this.label5 = new System.Windows.Forms.Label();
            this.Btn_Stop = new System.Windows.Forms.Button();
            this.groupBox_mannual = new System.Windows.Forms.GroupBox();
            this.Btn_Back = new System.Windows.Forms.Button();
            this.Btn_Back_Right = new System.Windows.Forms.Button();
            this.Btn_Back_Left = new System.Windows.Forms.Button();
            this.Brn_Front = new System.Windows.Forms.Button();
            this.Btn_Front_Right = new System.Windows.Forms.Button();
            this.Btn_Front_left = new System.Windows.Forms.Button();
            this.numericUpDown_moveduetime = new System.Windows.Forms.NumericUpDown();
            this.label3 = new System.Windows.Forms.Label();
            this.Combo_ControlMode = new System.Windows.Forms.ComboBox();
            this.label2 = new System.Windows.Forms.Label();
            ((System.ComponentModel.ISupportInitialize)(this.DataGridView_Tag)).BeginInit();
            this.groupBox1.SuspendLayout();
            this.groupBox2.SuspendLayout();
            this.groupBox_auto.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.numericUpDown_dest_y)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.numericUpDown_dest_x)).BeginInit();
            this.groupBox_mannual.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.numericUpDown_moveduetime)).BeginInit();
            this.SuspendLayout();
            // 
            // DataGridView_Tag
            // 
            this.DataGridView_Tag.AllowUserToAddRows = false;
            this.DataGridView_Tag.AllowUserToDeleteRows = false;
            this.DataGridView_Tag.AllowUserToResizeColumns = false;
            this.DataGridView_Tag.AllowUserToResizeRows = false;
            this.DataGridView_Tag.AutoSizeColumnsMode = System.Windows.Forms.DataGridViewAutoSizeColumnsMode.Fill;
            this.DataGridView_Tag.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.DataGridView_Tag.Columns.AddRange(new System.Windows.Forms.DataGridViewColumn[] {
            this.Column_ID,
            this.Column_x,
            this.Column_y,
            this.Column_z,
            this.Column_status,
            this.Column_angle,
            this.Column_magn});
            this.DataGridView_Tag.Location = new System.Drawing.Point(12, 52);
            this.DataGridView_Tag.Name = "DataGridView_Tag";
            this.DataGridView_Tag.RowHeadersVisible = false;
            this.DataGridView_Tag.RowTemplate.Height = 23;
            this.DataGridView_Tag.SelectionMode = System.Windows.Forms.DataGridViewSelectionMode.FullRowSelect;
            this.DataGridView_Tag.Size = new System.Drawing.Size(525, 187);
            this.DataGridView_Tag.TabIndex = 0;
            this.DataGridView_Tag.SelectionChanged += new System.EventHandler(this.DataGridView_Tag_SelectionChanged);
            // 
            // Column_ID
            // 
            this.Column_ID.HeaderText = "标签ID";
            this.Column_ID.Name = "Column_ID";
            // 
            // Column_x
            // 
            this.Column_x.HeaderText = "x(cm)";
            this.Column_x.Name = "Column_x";
            // 
            // Column_y
            // 
            this.Column_y.HeaderText = "y(cm)";
            this.Column_y.Name = "Column_y";
            // 
            // Column_z
            // 
            this.Column_z.HeaderText = "z(cm)";
            this.Column_z.Name = "Column_z";
            // 
            // Column_status
            // 
            this.Column_status.HeaderText = "状态";
            this.Column_status.Name = "Column_status";
            // 
            // Column_angle
            // 
            this.Column_angle.HeaderText = "角度";
            this.Column_angle.Name = "Column_angle";
            // 
            // Column_magn
            // 
            this.Column_magn.HeaderText = "磁场强度(uT)";
            this.Column_magn.Name = "Column_magn";
            // 
            // Btn_Search_naviTag
            // 
            this.Btn_Search_naviTag.Location = new System.Drawing.Point(12, 12);
            this.Btn_Search_naviTag.Name = "Btn_Search_naviTag";
            this.Btn_Search_naviTag.Size = new System.Drawing.Size(85, 34);
            this.Btn_Search_naviTag.TabIndex = 1;
            this.Btn_Search_naviTag.Text = "搜索标签";
            this.Btn_Search_naviTag.UseVisualStyleBackColor = true;
            this.Btn_Search_naviTag.Click += new System.EventHandler(this.Btn_Search_naviTag_Click);
            // 
            // groupBox1
            // 
            this.groupBox1.Controls.Add(this.groupBox2);
            this.groupBox1.Controls.Add(this.Text_Tag_id);
            this.groupBox1.Controls.Add(this.label7);
            this.groupBox1.Controls.Add(this.Text_status);
            this.groupBox1.Controls.Add(this.groupBox_auto);
            this.groupBox1.Controls.Add(this.Btn_Stop);
            this.groupBox1.Controls.Add(this.groupBox_mannual);
            this.groupBox1.Controls.Add(this.Combo_ControlMode);
            this.groupBox1.Controls.Add(this.label2);
            this.groupBox1.Location = new System.Drawing.Point(12, 245);
            this.groupBox1.Name = "groupBox1";
            this.groupBox1.Size = new System.Drawing.Size(525, 426);
            this.groupBox1.TabIndex = 2;
            this.groupBox1.TabStop = false;
            this.groupBox1.Text = "导航控制";
            // 
            // groupBox2
            // 
            this.groupBox2.Controls.Add(this.Btn_GetSpeed);
            this.groupBox2.Controls.Add(this.label4);
            this.groupBox2.Controls.Add(this.Btn_changespeed);
            this.groupBox2.Controls.Add(this.comboBox_ChangeSpeed);
            this.groupBox2.Location = new System.Drawing.Point(8, 69);
            this.groupBox2.Name = "groupBox2";
            this.groupBox2.Size = new System.Drawing.Size(219, 176);
            this.groupBox2.TabIndex = 12;
            this.groupBox2.TabStop = false;
            this.groupBox2.Text = "导航配置";
            // 
            // Btn_GetSpeed
            // 
            this.Btn_GetSpeed.Location = new System.Drawing.Point(19, 80);
            this.Btn_GetSpeed.Name = "Btn_GetSpeed";
            this.Btn_GetSpeed.Size = new System.Drawing.Size(77, 40);
            this.Btn_GetSpeed.TabIndex = 12;
            this.Btn_GetSpeed.Text = "读取速度";
            this.Btn_GetSpeed.UseVisualStyleBackColor = true;
            this.Btn_GetSpeed.Click += new System.EventHandler(this.Btn_GetSpeed_Click);
            // 
            // label4
            // 
            this.label4.AutoSize = true;
            this.label4.Location = new System.Drawing.Point(17, 43);
            this.label4.Name = "label4";
            this.label4.Size = new System.Drawing.Size(53, 12);
            this.label4.TabIndex = 9;
            this.label4.Text = "速度挡位";
            // 
            // Btn_changespeed
            // 
            this.Btn_changespeed.Location = new System.Drawing.Point(115, 80);
            this.Btn_changespeed.Name = "Btn_changespeed";
            this.Btn_changespeed.Size = new System.Drawing.Size(77, 40);
            this.Btn_changespeed.TabIndex = 11;
            this.Btn_changespeed.Text = "更改速度";
            this.Btn_changespeed.UseVisualStyleBackColor = true;
            this.Btn_changespeed.Click += new System.EventHandler(this.Btn_changespeed_Click);
            // 
            // comboBox_ChangeSpeed
            // 
            this.comboBox_ChangeSpeed.FormattingEnabled = true;
            this.comboBox_ChangeSpeed.Items.AddRange(new object[] {
            "1",
            "2",
            "3"});
            this.comboBox_ChangeSpeed.Location = new System.Drawing.Point(76, 40);
            this.comboBox_ChangeSpeed.Name = "comboBox_ChangeSpeed";
            this.comboBox_ChangeSpeed.Size = new System.Drawing.Size(73, 20);
            this.comboBox_ChangeSpeed.TabIndex = 10;
            // 
            // Text_Tag_id
            // 
            this.Text_Tag_id.AutoSize = true;
            this.Text_Tag_id.Location = new System.Drawing.Point(68, 27);
            this.Text_Tag_id.Name = "Text_Tag_id";
            this.Text_Tag_id.Size = new System.Drawing.Size(17, 12);
            this.Text_Tag_id.TabIndex = 8;
            this.Text_Tag_id.Text = "ID";
            // 
            // label7
            // 
            this.label7.AutoSize = true;
            this.label7.Location = new System.Drawing.Point(18, 27);
            this.label7.Name = "label7";
            this.label7.Size = new System.Drawing.Size(41, 12);
            this.label7.TabIndex = 7;
            this.label7.Text = "标签ID";
            // 
            // Text_status
            // 
            this.Text_status.AutoSize = true;
            this.Text_status.Location = new System.Drawing.Point(6, 400);
            this.Text_status.Name = "Text_status";
            this.Text_status.Size = new System.Drawing.Size(83, 12);
            this.Text_status.TabIndex = 6;
            this.Text_status.Text = "系统运行中...";
            // 
            // groupBox_auto
            // 
            this.groupBox_auto.Controls.Add(this.Btn_cursorSelect);
            this.groupBox_auto.Controls.Add(this.Btn_StartMove);
            this.groupBox_auto.Controls.Add(this.numericUpDown_dest_y);
            this.groupBox_auto.Controls.Add(this.numericUpDown_dest_x);
            this.groupBox_auto.Controls.Add(this.label6);
            this.groupBox_auto.Controls.Add(this.label5);
            this.groupBox_auto.Enabled = false;
            this.groupBox_auto.Location = new System.Drawing.Point(8, 266);
            this.groupBox_auto.Name = "groupBox_auto";
            this.groupBox_auto.Size = new System.Drawing.Size(488, 120);
            this.groupBox_auto.TabIndex = 5;
            this.groupBox_auto.TabStop = false;
            this.groupBox_auto.Text = "自动导航";
            // 
            // Btn_cursorSelect
            // 
            this.Btn_cursorSelect.Font = new System.Drawing.Font("宋体", 10.5F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(134)));
            this.Btn_cursorSelect.Location = new System.Drawing.Point(315, 31);
            this.Btn_cursorSelect.Name = "Btn_cursorSelect";
            this.Btn_cursorSelect.Size = new System.Drawing.Size(129, 78);
            this.Btn_cursorSelect.TabIndex = 7;
            this.Btn_cursorSelect.Text = "鼠标设定目标点";
            this.Btn_cursorSelect.UseVisualStyleBackColor = true;
            this.Btn_cursorSelect.Click += new System.EventHandler(this.Btn_cursorSelect_Click);
            // 
            // Btn_StartMove
            // 
            this.Btn_StartMove.Location = new System.Drawing.Point(193, 30);
            this.Btn_StartMove.Name = "Btn_StartMove";
            this.Btn_StartMove.Size = new System.Drawing.Size(81, 50);
            this.Btn_StartMove.TabIndex = 6;
            this.Btn_StartMove.Text = "开始移动";
            this.Btn_StartMove.UseVisualStyleBackColor = true;
            this.Btn_StartMove.Click += new System.EventHandler(this.Btn_StartMove_Click);
            // 
            // numericUpDown_dest_y
            // 
            this.numericUpDown_dest_y.Location = new System.Drawing.Point(106, 63);
            this.numericUpDown_dest_y.Maximum = new decimal(new int[] {
            32768,
            0,
            0,
            0});
            this.numericUpDown_dest_y.Minimum = new decimal(new int[] {
            32768,
            0,
            0,
            -2147483648});
            this.numericUpDown_dest_y.Name = "numericUpDown_dest_y";
            this.numericUpDown_dest_y.Size = new System.Drawing.Size(70, 21);
            this.numericUpDown_dest_y.TabIndex = 5;
            // 
            // numericUpDown_dest_x
            // 
            this.numericUpDown_dest_x.Location = new System.Drawing.Point(106, 30);
            this.numericUpDown_dest_x.Maximum = new decimal(new int[] {
            32768,
            0,
            0,
            0});
            this.numericUpDown_dest_x.Minimum = new decimal(new int[] {
            32768,
            0,
            0,
            -2147483648});
            this.numericUpDown_dest_x.Name = "numericUpDown_dest_x";
            this.numericUpDown_dest_x.Size = new System.Drawing.Size(70, 21);
            this.numericUpDown_dest_x.TabIndex = 4;
            // 
            // label6
            // 
            this.label6.AutoSize = true;
            this.label6.Location = new System.Drawing.Point(8, 65);
            this.label6.Name = "label6";
            this.label6.Size = new System.Drawing.Size(83, 12);
            this.label6.TabIndex = 3;
            this.label6.Text = "目的坐标y(cm)";
            // 
            // label5
            // 
            this.label5.AutoSize = true;
            this.label5.Location = new System.Drawing.Point(8, 32);
            this.label5.Name = "label5";
            this.label5.Size = new System.Drawing.Size(83, 12);
            this.label5.TabIndex = 2;
            this.label5.Text = "目的坐标x(cm)";
            // 
            // Btn_Stop
            // 
            this.Btn_Stop.Location = new System.Drawing.Point(279, 13);
            this.Btn_Stop.Name = "Btn_Stop";
            this.Btn_Stop.Size = new System.Drawing.Size(77, 40);
            this.Btn_Stop.TabIndex = 4;
            this.Btn_Stop.Text = "停止运动";
            this.Btn_Stop.UseVisualStyleBackColor = true;
            this.Btn_Stop.Click += new System.EventHandler(this.Btn_Stop_Click);
            // 
            // groupBox_mannual
            // 
            this.groupBox_mannual.Controls.Add(this.Btn_Back);
            this.groupBox_mannual.Controls.Add(this.Btn_Back_Right);
            this.groupBox_mannual.Controls.Add(this.Btn_Back_Left);
            this.groupBox_mannual.Controls.Add(this.Brn_Front);
            this.groupBox_mannual.Controls.Add(this.Btn_Front_Right);
            this.groupBox_mannual.Controls.Add(this.Btn_Front_left);
            this.groupBox_mannual.Controls.Add(this.numericUpDown_moveduetime);
            this.groupBox_mannual.Controls.Add(this.label3);
            this.groupBox_mannual.Enabled = false;
            this.groupBox_mannual.Location = new System.Drawing.Point(248, 69);
            this.groupBox_mannual.Name = "groupBox_mannual";
            this.groupBox_mannual.Size = new System.Drawing.Size(248, 176);
            this.groupBox_mannual.TabIndex = 2;
            this.groupBox_mannual.TabStop = false;
            this.groupBox_mannual.Text = "点动控制";
            // 
            // Btn_Back
            // 
            this.Btn_Back.Location = new System.Drawing.Point(93, 119);
            this.Btn_Back.Name = "Btn_Back";
            this.Btn_Back.Size = new System.Drawing.Size(60, 33);
            this.Btn_Back.TabIndex = 8;
            this.Btn_Back.Text = "后直行";
            this.Btn_Back.UseVisualStyleBackColor = true;
            this.Btn_Back.Click += new System.EventHandler(this.Btn_Mannualmove_Click);
            // 
            // Btn_Back_Right
            // 
            this.Btn_Back_Right.Location = new System.Drawing.Point(164, 119);
            this.Btn_Back_Right.Name = "Btn_Back_Right";
            this.Btn_Back_Right.Size = new System.Drawing.Size(60, 33);
            this.Btn_Back_Right.TabIndex = 7;
            this.Btn_Back_Right.Text = "后右转";
            this.Btn_Back_Right.UseVisualStyleBackColor = true;
            this.Btn_Back_Right.Click += new System.EventHandler(this.Btn_Mannualmove_Click);
            // 
            // Btn_Back_Left
            // 
            this.Btn_Back_Left.Location = new System.Drawing.Point(22, 119);
            this.Btn_Back_Left.Name = "Btn_Back_Left";
            this.Btn_Back_Left.Size = new System.Drawing.Size(60, 33);
            this.Btn_Back_Left.TabIndex = 6;
            this.Btn_Back_Left.Text = "后左转";
            this.Btn_Back_Left.UseVisualStyleBackColor = true;
            this.Btn_Back_Left.Click += new System.EventHandler(this.Btn_Mannualmove_Click);
            // 
            // Brn_Front
            // 
            this.Brn_Front.Location = new System.Drawing.Point(93, 69);
            this.Brn_Front.Name = "Brn_Front";
            this.Brn_Front.Size = new System.Drawing.Size(60, 33);
            this.Brn_Front.TabIndex = 5;
            this.Brn_Front.Text = "前直行";
            this.Brn_Front.UseVisualStyleBackColor = true;
            this.Brn_Front.Click += new System.EventHandler(this.Btn_Mannualmove_Click);
            // 
            // Btn_Front_Right
            // 
            this.Btn_Front_Right.Location = new System.Drawing.Point(164, 69);
            this.Btn_Front_Right.Name = "Btn_Front_Right";
            this.Btn_Front_Right.Size = new System.Drawing.Size(60, 33);
            this.Btn_Front_Right.TabIndex = 4;
            this.Btn_Front_Right.Text = "前右转";
            this.Btn_Front_Right.UseVisualStyleBackColor = true;
            this.Btn_Front_Right.Click += new System.EventHandler(this.Btn_Mannualmove_Click);
            // 
            // Btn_Front_left
            // 
            this.Btn_Front_left.Location = new System.Drawing.Point(22, 69);
            this.Btn_Front_left.Name = "Btn_Front_left";
            this.Btn_Front_left.Size = new System.Drawing.Size(60, 33);
            this.Btn_Front_left.TabIndex = 3;
            this.Btn_Front_left.Text = "前左转";
            this.Btn_Front_left.UseVisualStyleBackColor = true;
            this.Btn_Front_left.Click += new System.EventHandler(this.Btn_Mannualmove_Click);
            // 
            // numericUpDown_moveduetime
            // 
            this.numericUpDown_moveduetime.Location = new System.Drawing.Point(127, 28);
            this.numericUpDown_moveduetime.Maximum = new decimal(new int[] {
            65535,
            0,
            0,
            0});
            this.numericUpDown_moveduetime.Minimum = new decimal(new int[] {
            200,
            0,
            0,
            0});
            this.numericUpDown_moveduetime.Name = "numericUpDown_moveduetime";
            this.numericUpDown_moveduetime.Size = new System.Drawing.Size(52, 21);
            this.numericUpDown_moveduetime.TabIndex = 2;
            this.numericUpDown_moveduetime.Value = new decimal(new int[] {
            200,
            0,
            0,
            0});
            this.numericUpDown_moveduetime.ValueChanged += new System.EventHandler(this.numericUpDown_moveduetime_ValueChanged);
            // 
            // label3
            // 
            this.label3.AutoSize = true;
            this.label3.Location = new System.Drawing.Point(20, 33);
            this.label3.Name = "label3";
            this.label3.Size = new System.Drawing.Size(101, 12);
            this.label3.TabIndex = 1;
            this.label3.Text = "运动持续时间(ms)";
            // 
            // Combo_ControlMode
            // 
            this.Combo_ControlMode.FormattingEnabled = true;
            this.Combo_ControlMode.Items.AddRange(new object[] {
            "静止",
            "点动控制",
            "自动导航"});
            this.Combo_ControlMode.Location = new System.Drawing.Point(180, 24);
            this.Combo_ControlMode.Name = "Combo_ControlMode";
            this.Combo_ControlMode.Size = new System.Drawing.Size(80, 20);
            this.Combo_ControlMode.TabIndex = 1;
            this.Combo_ControlMode.SelectedIndexChanged += new System.EventHandler(this.Combo_ControlMode_SelectedIndexChanged);
            // 
            // label2
            // 
            this.label2.AutoSize = true;
            this.label2.Location = new System.Drawing.Point(97, 27);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(77, 12);
            this.label2.TabIndex = 0;
            this.label2.Text = "改变工作状态";
            // 
            // NavigationWindow
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 12F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(563, 671);
            this.Controls.Add(this.groupBox1);
            this.Controls.Add(this.Btn_Search_naviTag);
            this.Controls.Add(this.DataGridView_Tag);
            this.Name = "NavigationWindow";
            this.Text = "导航控制";
            this.FormClosing += new System.Windows.Forms.FormClosingEventHandler(this.NavigationWindow_FormClosing);
            ((System.ComponentModel.ISupportInitialize)(this.DataGridView_Tag)).EndInit();
            this.groupBox1.ResumeLayout(false);
            this.groupBox1.PerformLayout();
            this.groupBox2.ResumeLayout(false);
            this.groupBox2.PerformLayout();
            this.groupBox_auto.ResumeLayout(false);
            this.groupBox_auto.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)(this.numericUpDown_dest_y)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.numericUpDown_dest_x)).EndInit();
            this.groupBox_mannual.ResumeLayout(false);
            this.groupBox_mannual.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)(this.numericUpDown_moveduetime)).EndInit();
            this.ResumeLayout(false);

        }

        #endregion

        private System.Windows.Forms.DataGridView DataGridView_Tag;
        private System.Windows.Forms.Button Btn_Search_naviTag;
        private System.Windows.Forms.GroupBox groupBox1;
        private System.Windows.Forms.Label Text_status;
        private System.Windows.Forms.GroupBox groupBox_auto;
        private System.Windows.Forms.Button Btn_StartMove;
        private System.Windows.Forms.NumericUpDown numericUpDown_dest_y;
        private System.Windows.Forms.NumericUpDown numericUpDown_dest_x;
        private System.Windows.Forms.Label label6;
        private System.Windows.Forms.Label label5;
        private System.Windows.Forms.Button Btn_Stop;
        private System.Windows.Forms.GroupBox groupBox_mannual;
        private System.Windows.Forms.Button Btn_Back;
        private System.Windows.Forms.Button Btn_Back_Right;
        private System.Windows.Forms.Button Btn_Back_Left;
        private System.Windows.Forms.Button Brn_Front;
        private System.Windows.Forms.Button Btn_Front_Right;
        private System.Windows.Forms.Button Btn_Front_left;
        private System.Windows.Forms.NumericUpDown numericUpDown_moveduetime;
        private System.Windows.Forms.Label label3;
        private System.Windows.Forms.ComboBox Combo_ControlMode;
        private System.Windows.Forms.Label label2;
        private System.Windows.Forms.Label Text_Tag_id;
        private System.Windows.Forms.Label label7;
        private System.Windows.Forms.Button Btn_cursorSelect;
        private System.Windows.Forms.DataGridViewTextBoxColumn Column_ID;
        private System.Windows.Forms.DataGridViewTextBoxColumn Column_x;
        private System.Windows.Forms.DataGridViewTextBoxColumn Column_y;
        private System.Windows.Forms.DataGridViewTextBoxColumn Column_z;
        private System.Windows.Forms.DataGridViewTextBoxColumn Column_status;
        private System.Windows.Forms.DataGridViewTextBoxColumn Column_angle;
        private System.Windows.Forms.DataGridViewTextBoxColumn Column_magn;
        private System.Windows.Forms.ComboBox comboBox_ChangeSpeed;
        private System.Windows.Forms.Label label4;
        private System.Windows.Forms.Button Btn_changespeed;
        private System.Windows.Forms.GroupBox groupBox2;
        private System.Windows.Forms.Button Btn_GetSpeed;
    }
}