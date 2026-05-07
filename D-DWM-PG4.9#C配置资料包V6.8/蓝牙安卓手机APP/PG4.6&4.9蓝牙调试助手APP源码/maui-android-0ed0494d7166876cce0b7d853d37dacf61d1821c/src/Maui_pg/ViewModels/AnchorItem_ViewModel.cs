using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Maui_pg.Models;
using Maui_pg.Tools;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maui_pg.ViewModels
{
    [QueryProperty("Edit_anc", "Edit_anc")]
    public partial class AnchorItem_ViewModel : ObservableObject
    {

        private UWBAnchor _Edit_anc;
        public UWBAnchor Edit_anc
        {
            get => _Edit_anc;
            set => SetProperty(ref _Edit_anc, value);
        }

        private UWBAnchor Anc_reserve = new UWBAnchor();
        DatabaseHelper SQLiteDatabase_Helper;

        public IAsyncRelayCommand Save_AncCommand { get; set; }

        public IAsyncRelayCommand Cancel_Command { get; set; }
        public AnchorItem_ViewModel(DatabaseHelper db)
        {
            SQLiteDatabase_Helper = db;
            Save_AncCommand = new AsyncRelayCommand(Save_Anc_Handler);
            Cancel_Command = new AsyncRelayCommand(Cancel_Handler);
            if (Edit_anc != null)
            {
                Anc_reserve.ID = Edit_anc.ID;
                Anc_reserve.X = Edit_anc.X;
                Anc_reserve.Y = Edit_anc.Y;
            }
        }

        private async Task Cancel_Handler()
        {
            if (Edit_anc != null)
            {
                Edit_anc.ID = Anc_reserve.ID;
                Edit_anc.X = Anc_reserve.X;
                Edit_anc.Y = Anc_reserve.Y;
            }
            await Shell.Current.GoToAsync("..");
        }

        private async Task Save_Anc_Handler()
        {
            if(Edit_anc == null)
            {
                await Shell.Current.DisplayAlert("提示", "保存失败", "ok");
                return;
            }
            if (string.IsNullOrWhiteSpace(Edit_anc.ID))
            {
                await Shell.Current.DisplayAlert("提示", "保存失败", "ok");
                return;
            }

            await SQLiteDatabase_Helper.SaveItemAsync(Edit_anc);
            await Shell.Current.GoToAsync("..");
        }
    }
}
