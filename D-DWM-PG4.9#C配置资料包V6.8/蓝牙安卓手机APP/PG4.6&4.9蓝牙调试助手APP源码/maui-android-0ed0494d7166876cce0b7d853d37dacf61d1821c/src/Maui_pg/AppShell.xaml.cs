using Maui_pg.Views;

namespace Maui_pg;

public partial class AppShell : Shell
{
	public AppShell()
	{
		InitializeComponent();
        Routing.RegisterRoute("CommuPage", typeof(CommuPage));
        Routing.RegisterRoute(nameof(AnchorList_Page), typeof(AnchorList_Page));
        Routing.RegisterRoute(nameof(AnchorItem_Page), typeof(AnchorItem_Page));
    }
}
