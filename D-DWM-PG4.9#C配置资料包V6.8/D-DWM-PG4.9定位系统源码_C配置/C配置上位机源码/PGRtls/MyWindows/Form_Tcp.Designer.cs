
namespace PGRtls.MyWindows
{
    partial class Form_Tcp
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
            this.label1 = new System.Windows.Forms.Label();
            this.label2 = new System.Windows.Forms.Label();
            this.textBox_Port = new System.Windows.Forms.TextBox();
            this.button_Tcp = new System.Windows.Forms.Button();
            this.button_Search = new System.Windows.Forms.Button();
            this.comboBox_ServerIp = new System.Windows.Forms.ComboBox();
            this.SuspendLayout();
            // 
            // label1
            // 
            this.label1.AutoSize = true;
            this.label1.Location = new System.Drawing.Point(24, 32);
            this.label1.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label1.Name = "label1";
            this.label1.Size = new System.Drawing.Size(136, 16);
            this.label1.TabIndex = 0;
            this.label1.Text = "TCP连接服务端IP:";
            // 
            // label2
            // 
            this.label2.AutoSize = true;
            this.label2.Location = new System.Drawing.Point(96, 77);
            this.label2.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(64, 16);
            this.label2.TabIndex = 1;
            this.label2.Text = "端口号:";
            // 
            // textBox_Port
            // 
            this.textBox_Port.Location = new System.Drawing.Point(167, 74);
            this.textBox_Port.Name = "textBox_Port";
            this.textBox_Port.Size = new System.Drawing.Size(143, 26);
            this.textBox_Port.TabIndex = 3;
            this.textBox_Port.Text = "5000";
            // 
            // button_Tcp
            // 
            this.button_Tcp.Location = new System.Drawing.Point(198, 118);
            this.button_Tcp.Name = "button_Tcp";
            this.button_Tcp.Size = new System.Drawing.Size(112, 36);
            this.button_Tcp.TabIndex = 4;
            this.button_Tcp.Text = "连接服务器";
            this.button_Tcp.UseVisualStyleBackColor = true;
            this.button_Tcp.Click += new System.EventHandler(this.button_Tcp_Click);
            // 
            // button_Search
            // 
            this.button_Search.Location = new System.Drawing.Point(58, 118);
            this.button_Search.Name = "button_Search";
            this.button_Search.Size = new System.Drawing.Size(112, 36);
            this.button_Search.TabIndex = 5;
            this.button_Search.Text = "搜索服务器";
            this.button_Search.UseVisualStyleBackColor = true;
            this.button_Search.Click += new System.EventHandler(this.button_Search_Click);
            // 
            // comboBox_ServerIp
            // 
            this.comboBox_ServerIp.FormattingEnabled = true;
            this.comboBox_ServerIp.Location = new System.Drawing.Point(167, 29);
            this.comboBox_ServerIp.Name = "comboBox_ServerIp";
            this.comboBox_ServerIp.Size = new System.Drawing.Size(143, 24);
            this.comboBox_ServerIp.TabIndex = 6;
            // 
            // Form_Tcp
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(8F, 16F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(345, 175);
            this.Controls.Add(this.comboBox_ServerIp);
            this.Controls.Add(this.button_Search);
            this.Controls.Add(this.button_Tcp);
            this.Controls.Add(this.textBox_Port);
            this.Controls.Add(this.label2);
            this.Controls.Add(this.label1);
            this.Font = new System.Drawing.Font("宋体", 12F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(134)));
            this.Margin = new System.Windows.Forms.Padding(4);
            this.MaximizeBox = false;
            this.MinimizeBox = false;
            this.Name = "Form_Tcp";
            this.StartPosition = System.Windows.Forms.FormStartPosition.CenterParent;
            this.Text = "TCP连接配置";
            this.FormClosing += new System.Windows.Forms.FormClosingEventHandler(this.Form_Tcp_FormClosing);
            this.ResumeLayout(false);
            this.PerformLayout();

        }

        #endregion

        private System.Windows.Forms.Label label1;
        private System.Windows.Forms.Label label2;
        private System.Windows.Forms.TextBox textBox_Port;
        private System.Windows.Forms.Button button_Tcp;
        private System.Windows.Forms.Button button_Search;
        private System.Windows.Forms.ComboBox comboBox_ServerIp;
    }
}