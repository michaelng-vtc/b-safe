using CommunityToolkit.Mvvm.ComponentModel;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maui_pg.Models
{
    public class UWBTag : ObservableObject
    {
        public int Id { get; set; }

        private short _X;
        public short X
        {
            get => _X;
            set => SetProperty(ref _X, value);
        }

        private short _Y;
        public short Y
        {
            get => _Y;
            set => SetProperty(ref _Y, value);
        }

        private short _Z;
        public short Z
        {
            get => _Z;
            set => SetProperty(ref _Z, value);
        }



    }
}
