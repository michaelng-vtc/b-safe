using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Maui_pg.Models;
using Maui_pg.Shares;
using Maui_pg.Views;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maui_pg.ViewModels
{
    public class DisplayPage_ViewModel : ObservableObject
    {


        private ObservableCollection<UWBTag> _Tag_List;
        public ObservableCollection<UWBTag> Tag_List
        {
            get => _Tag_List;
            set => SetProperty(ref _Tag_List, value);
        }


        private float _Draw_scale;
        public float Draw_scale
        {
            get => _Draw_scale;
            set => SetProperty(ref _Draw_scale, value);
        }


        private bool _Has_trace;
        public bool Has_trace
        {
            get => _Has_trace;
            set => SetProperty(ref _Has_trace, value);
        }

        public RelayCommand Add_ancCommand { get; set; }

        public AsyncRelayCommand ChangeScale_Command { get; set; }

        public DisplayPage_ViewModel()
        {
            Tag_List = new ObservableCollection<UWBTag>();
            Refresh_TagList();
            Add_ancCommand = new RelayCommand(Add_anc_Handler);
            ChangeScale_Command = new AsyncRelayCommand(ChangeScale_Handler);
            Draw_scale = 3;
        }

        private async Task ChangeScale_Handler()
        {
            string result = await Shell.Current.DisplayPromptAsync("显示比例", "设置显示比例", initialValue: Draw_scale.ToString(), keyboard: Keyboard.Numeric);
            if (string.IsNullOrWhiteSpace(result))
            {
                return;
            }
            if (!float.TryParse(result, out float r))
            {
                await Shell.Current.DisplayAlert("提示", "请输入有效数字!", "ok");
                return;
            }
            Draw_scale = r;
        }

        private async void Add_anc_Handler()
        {
            //测试而已
            //if(Share_Data.TagList.Count > 0)
            //{
            //    Share_Data.TagList[0].X += 10;
            //    Share_Data.TagList[0].Y += 10;
            //}
            await Shell.Current.GoToAsync($"/{nameof(AnchorList_Page)}", true);
        }

        public void Refresh_TagList()
        {
            if(Tag_List == null)
            {
                return;
            }
            Tag_List.Clear();
            for (int i = 0; i < Share_Data.TagList.Count; i++)
            {
                Tag_List.Add(Share_Data.TagList[i]);
            }            
        }



    }
}
