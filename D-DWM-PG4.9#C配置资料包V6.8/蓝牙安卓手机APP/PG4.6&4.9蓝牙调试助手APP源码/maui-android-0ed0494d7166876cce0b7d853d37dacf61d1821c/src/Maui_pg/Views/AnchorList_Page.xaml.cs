using Maui_pg.ViewModels;

namespace Maui_pg.Views;

public partial class AnchorList_Page : ContentPage
{
    AnchorList_ViewModel View_model;
    public AnchorList_Page(AnchorList_ViewModel vm)
	{
		InitializeComponent();
        View_model = vm;

        this.BindingContext = vm;
	}

    protected override async void OnNavigatedTo(NavigatedToEventArgs args)
    {
        base.OnNavigatedTo(args);
        await View_model.Refresh_view();
    }
}