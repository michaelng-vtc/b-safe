using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Maui_pg.Models;
using Maui_pg.Tools;
using Maui_pg.Views;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maui_pg.ViewModels
{
    public partial class AnchorList_ViewModel : ObservableObject
    {

        public IAsyncRelayCommand Add_newItem_Command { get; set; }
        public IAsyncRelayCommand ChangeItem_Command { get; set; }
        public IAsyncRelayCommand DeleteItem_Command { get; set; }
        public ObservableCollection<UWBAnchor> Anc_List { get; set; } = new ObservableCollection<UWBAnchor>();

        DatabaseHelper SQLiteDatabase_Helper;

        public AnchorList_ViewModel(DatabaseHelper db)
        {
            SQLiteDatabase_Helper = db;
            Add_newItem_Command = new AsyncRelayCommand(Add_newItem_Handler);
            ChangeItem_Command = new AsyncRelayCommand<UWBAnchor>(ChangeItem_Handler);
            DeleteItem_Command = new AsyncRelayCommand<UWBAnchor>(DeleteItem_Handler);
            //Vm_test();

        }

        private async Task DeleteItem_Handler(UWBAnchor anc)
        {
            if (anc == null)
            {
                return;
            }
            await SQLiteDatabase_Helper.DeleteItemAsync(anc);
            await Refresh_view();
        }

        private async Task ChangeItem_Handler(UWBAnchor anc)
        {
            if (anc == null)
            {
                return;
            }
            await Navigate_to_ItemPage(false, anc);
        }

        public async Task Refresh_view()
        {
            var items = await SQLiteDatabase_Helper.GetItemsAsync();
            MainThread.BeginInvokeOnMainThread(() =>
            {
                Anc_List.Clear();
                foreach (var item in items)
                    Anc_List.Add(item);

            });
        }


        private async Task Add_newItem_Handler()
        {
            //await Shell.Current.GoToAsync($"/{nameof(AnchorItem_Page)}", true);
            await Navigate_to_ItemPage(true);
        }


        private async Task Navigate_to_ItemPage(bool is_add, UWBAnchor anc = null)
        {
            if(is_add)  //添加基站
            {
                await Shell.Current.GoToAsync($"/{nameof(AnchorItem_Page)}", true, new Dictionary<string, object>
                {
                    ["Edit_anc"] = new UWBAnchor()
                });
            }
            else  //更改基站
            {
                if(anc == null)
                {
                    return;
                }
                await Shell.Current.GoToAsync($"/{nameof(AnchorItem_Page)}", true, new Dictionary<string, object>
                {
                    ["Edit_anc"] = anc
                });
            }
        }


        public void Vm_test()
        {
            Anc_List.Add(new UWBAnchor()
            {
                ID = "A基站"
            });
            Anc_List.Add(new UWBAnchor()
            {
                ID = "B基站"
            });
        }
    }
}
