using Maui_pg.ViewModels;

namespace Maui_pg.Views;

public partial class CommuPage : ContentPage
{
    CommuPage_ViewModel View_model;
    public CommuPage(CommuPage_ViewModel vm)  
    {
		InitializeComponent();
        View_model = vm;

        this.BindingContext = vm;
	}

    protected override bool OnBackButtonPressed()
    {
        Task.Run(async () =>
        {
            bool result = await Shell.Current.DisplayAlert("提示", "退出则断开该蓝牙连接", "好的", "取消");
            if (result)
            {
                //断开蓝牙连接
                await View_model.DisconnectFromDeviceAsync_Handler();
                ////返回上一页
                //await Shell.Current.GoToAsync("..", true);  //..
                return base.OnBackButtonPressed();
            }
            else
            {
                return false;
            }
        });
        return base.OnBackButtonPressed();

    }
}