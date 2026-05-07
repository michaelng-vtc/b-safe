using Maui_pg.ViewModels;

namespace Maui_pg.Views;

public partial class AnchorItem_Page : ContentPage
{
	public AnchorItem_Page(AnchorItem_ViewModel vm)
	{
		InitializeComponent();
		this.BindingContext = vm;	
	}
}