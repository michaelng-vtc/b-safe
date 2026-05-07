using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.ComponentModel;
using System.Threading;

namespace PGRtls.Model
{
    public class IMUData:INotifyPropertyChanged
    {
        private SynchronizationContext syncContext;

        public const ushort IMU_DATA_ACC_EN = 1 << 0;
        public const ushort IMU_DATA_GYRO_EN = 1 << 1;
        public const ushort IMU_DATA_EULER_EN = 1 << 2;
        public const ushort IMU_DATA_TEMP_EN = 1 << 3;
        public const ushort IMU_DATA_Q_EN = 1 << 4;
        public const ushort IMU_DATA_MAGN_EN = 1 << 5;

        public bool Is_get_newdata { get; set; }

        private double _Acc_x;
        public double Acc_x
        {
            get
            {
                return _Acc_x;
            }
            set
            {
                _Acc_x = value;
                OnPropertyChanged("Acc_x");
            }
        }

        private double _Acc_y;
        public double Acc_y
        {
            get
            {
                return _Acc_y;
            }
            set
            {
                _Acc_y = value;
                OnPropertyChanged("Acc_y");
            }
        }

        private double _Acc_z;
        public double Acc_z
        {
            get
            {
                return _Acc_z;
            }
            set
            {
                _Acc_z = value;
                OnPropertyChanged("Acc_z");
            }
        }

        private double _Gyro_x;
        public double Gyro_x
        {
            get
            {
                return _Gyro_x;
            }
            set
            {
                _Gyro_x = value;
                OnPropertyChanged("Gyro_x");
            }
        }

        private double _Gyro_y;
        public double Gyro_y
        {
            get
            {
                return _Gyro_y;
            }
            set
            {
                _Gyro_y = value;
                OnPropertyChanged("Gyro_y");
            }
        }

        private double _Gyro_z;
        public double Gyro_z
        {
            get
            {
                return _Gyro_z;
            }
            set
            {
                _Gyro_z = value;
                OnPropertyChanged("Gyro_z");
            }
        }

        private double _Rotation_x;
        public double Rotation_x
        {
            get
            {
                return _Rotation_x;
            }
            set
            {
                _Rotation_x = value;
                OnPropertyChanged("Rotation_x");
            }
        }

        private double _Rotation_y;
        public double Rotation_y
        {
            get
            {
                return _Rotation_y;
            }
            set
            {
                _Rotation_y = value;
                OnPropertyChanged("Rotation_y");
            }
        }

        private double _Rotation_z;
        public double Rotation_z
        {
            get
            {
                return _Rotation_z;
            }
            set
            {
                _Rotation_z = value;
                OnPropertyChanged("Rotation_z");
            }
        }

        private double _Temperature;
        public double Temperature
        {
            get
            {
                return _Temperature;
            }
            set
            {
                _Temperature = value;
                OnPropertyChanged("Temperature");
            }
        }

        private double _q0;
        public double q0
        {
            get
            {
                return _q0;
            }
            set
            {
                _q0 = value;
                OnPropertyChanged("q0");
            }
        }

        private double _q1;
        public double q1
        {
            get
            {
                return _q1;
            }
            set
            {
                _q1 = value;
                OnPropertyChanged("q1");
            }
        }

        private double _q2;
        public double q2
        {
            get
            {
                return _q2;
            }
            set
            {
                _q2 = value;
                OnPropertyChanged("q2");
            }
        }

        private double _q3;
        public double q3
        {
            get
            {
                return _q3;
            }
            set
            {
                _q3 = value;
                OnPropertyChanged("q3");
            }
        }

        private double _Magn_x;
        public double Magn_x
        {
            get
            {
                return _Magn_x;
            }
            set
            {
                _Magn_x = value;
                OnPropertyChanged("Magn_x");
            }
        }

        private double _Magn_y;
        public double Magn_y
        {
            get
            {
                return _Magn_y;
            }
            set
            {
                _Magn_y = value;
                OnPropertyChanged("Magn_y");
            }
        }

        private double _Magn_z;
        public double Magn_z
        {
            get
            {
                return _Magn_z;
            }
            set
            {
                _Magn_z = value;
                OnPropertyChanged("Magn_z");
            }
        }

        private double _Magn_H;
        public double Magn_H
        {
            get
            {
                return _Magn_H;
            }
            set
            {
                _Magn_H = value;
                OnPropertyChanged("Magn_H");
            }
        }

        public bool Has_Magn_Calib { get; set; }
        public double[] Magn_bias { get; set; }
        public double[] Magn_scale { get; set; }

        public void Cal_Magn_H()
        {
            Magn_H = Math.Round(Math.Sqrt(Math.Pow(Magn_x, 2) + Math.Pow(Magn_y, 2) + Math.Pow(Magn_z, 2)), 3);
        }

        public IMUData()
        {
            syncContext = SynchronizationContext.Current;
            Is_get_newdata = false;
            Magn_bias = new double[3];
            Magn_scale = new double[3];
        }

        protected internal virtual void OnPropertyChanged(string propertyName)
        {
            var handler = PropertyChanged;
            if (handler != null)
            {
                if (syncContext != null)
                    syncContext.Post(_ => handler(this, new PropertyChangedEventArgs(propertyName)), null);
                else
                    handler(this, new PropertyChangedEventArgs(propertyName));
            }
            //PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
        public event PropertyChangedEventHandler PropertyChanged;
    }
}
