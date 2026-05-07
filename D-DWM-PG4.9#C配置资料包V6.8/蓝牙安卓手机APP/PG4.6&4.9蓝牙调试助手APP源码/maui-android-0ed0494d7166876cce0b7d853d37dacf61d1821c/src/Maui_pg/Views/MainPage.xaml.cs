using Maui_pg.ViewModels;

namespace Maui_pg.Views;

public partial class MainPage : ContentPage
{

	public MainPage(MainPage_ViewModel vm)
	{
		InitializeComponent();
		this.BindingContext = vm;
	}

}

