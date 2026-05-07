using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.ComponentModel;
using System.Threading;

namespace PGRtls.Model
{
    class Rx_Diag:INotifyPropertyChanged
    {
        private SynchronizationContext syncContext;
        //计算常量
        public double A = 121.74;


        //最大噪声
        private double _maxNoise;
        public double maxNoise
        {
            get
            {
                return _maxNoise;
            }
            set
            {
                _maxNoise = value;                
                OnPropertyChanged("maxNoise");
            }
        }
        
        //噪声均方根值
        private double _stdNoise;
        public double stdNoise
        {
            get
            {
                return _stdNoise;
            }
            set
            {
                _stdNoise = value;
                OnPropertyChanged("stdNoise");
            }
        }

        //第一路径分量1
        private double _firstPathAmp1;
        public double firstPathAmp1
        {
            get
            {
                return _firstPathAmp1;
            }
            set
            {
                _firstPathAmp1 = value;
                OnPropertyChanged("firstPathAmp1");
            }
        }

        //第一路径分量2
        private double _firstPathAmp2;
        public double firstPathAmp2
        {
            get
            {
                return _firstPathAmp2;
            }
            set
            {
                _firstPathAmp2 = value;
                OnPropertyChanged("firstPathAmp2");
            }
        }

        //第一路径分量3
        private double _firstPathAmp3;
        public double firstPathAmp3
        {
            get
            {
                return _firstPathAmp3;
            }
            set
            {
                _firstPathAmp3 = value;
                OnPropertyChanged("firstPathAmp3");
            }
        }

        //最大CIR值
        private double _maxGrowthCIR;
        public double maxGrowthCIR
        {
            get
            {
                return _maxGrowthCIR;
            }
            set
            {
                _maxGrowthCIR = value;
                OnPropertyChanged("maxGrowthCIR");
            }
        }

        //接收前导码数量
        private double _rxPreamCount;
        public double rxPreamCount
        {
            get
            {
                return _rxPreamCount;
            }
            set
            {
                _rxPreamCount = value;               
                OnPropertyChanged("rxPreamCount");
            }
        }

        //第一路径值
        private double _firstPath;
        public double firstPath
        {
            get
            {
                return _firstPath;
            }
            set
            {
                _firstPath = value;
                OnPropertyChanged("firstPath");
            }
        }

        //根据第一路径计算的接收强度
        private string _FPPower;
        public string FPPower
        {
            get
            {
                return _FPPower;
            }
            set
            {
                _FPPower = value;
                OnPropertyChanged("FPPower");
            }
        }

        //根据接收强度估计理论接收强度
        private string _RxPower;
        public string RxPower
        {
            get
            {
                return _RxPower;
            }
            set
            {
                _RxPower = value;
                OnPropertyChanged("RxPower");
            }
        }

        public Rx_Diag()
        {
            syncContext = SynchronizationContext.Current;
        }

        public void rx_diagnostic_init()
        {

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
        }
        public event PropertyChangedEventHandler PropertyChanged;
    }
}
