using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.ComponentModel;
using System.Threading;

namespace PGRtls.Model
{
    public class Anchor : INotifyPropertyChanged
    {

        //基站x坐标
        private double _x;
        public double x
        {
            get
            {
                return _x;
            }
            set
            {
                 _x = value;
                OnPropertyChanged("x");
            }
        }

        //基站y坐标
        private double _y;
        public double y
        {
            get
            {
                return _y;
            }
            set
            {
                _y = value;
                OnPropertyChanged("y");
            }
        }

        //基站z坐标
        private double _z;
        public double z
        {
            get
            {
                return _z;
            }
            set
            {
                _z = value;
                OnPropertyChanged("z");
            }
        }

        //基站是否使能
        private bool _isUse;
        public bool IsUse 
        { 
            get 
            {
                return _isUse;
            }
            set 
            {
                if (Id == "A基站")
                    _isUse = true;
                else
                    _isUse = value;
                OnPropertyChanged("isUse");
            } 
        }

        //基站ID
        public string Id { get; set; }

        //基站本次测距距离
        public uint Dist_Now { get; set; }

        public Anchor(string _id)
        {
            Id = _id;
            IsUse = false;
            x = 0;
            y = 0;
            z = 0;
        }

        public Anchor()
        {
            Id = "xxx";
            IsUse = false;
            x = 0;
            y = 0;
            z = 0;
        }



        public event PropertyChangedEventHandler PropertyChanged;
        protected internal virtual void OnPropertyChanged(string propertyName)
        {           
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));            
        }

    }

    public class Calib_anc : Anchor
    {
        public double First_x { get; set; }
        public double First_y { get; set; }
        public bool First_ok { get; set; }
        public double Second_x { get; set; }
        public double Second_y { get; set; }
        public bool Second_ok { get; set; }
        public bool Final_ok { get; set; }
    }


}
