using Maui_pg.Drawables;
using Maui_pg.Shares;
using Maui_pg.Tools;
using Maui_pg.ViewModels;

namespace Maui_pg.Views;

public partial class DisplayPage : ContentPage
{
	IDispatcherTimer Draw_timer;
    DisplayDrawable Draw_instance;
    DisplayPage_ViewModel Viewmodel;
    DatabaseHelper SQLiteDatabase_Helper;

	public DisplayPage(DisplayPage_ViewModel vm, DatabaseHelper db)
	{
		InitializeComponent();
        Viewmodel = vm;
        SQLiteDatabase_Helper = db;
        this.BindingContext = Viewmodel;

        Draw_instance = new DisplayDrawable();
        Graphic_draw.Drawable = Draw_instance;
        Draw_instance.Init(Graphic_draw.Width, Graphic_draw.Height);

        Draw_timer = Dispatcher.CreateTimer();
        Draw_timer.Interval = new TimeSpan(TimeSpan.TicksPerMillisecond * 50);
        Draw_timer.Tick += Draw_timer_Tick;
        Draw_timer.Start();
    }

    private void Draw_timer_Tick(object sender, EventArgs e)
    {

        if (!Draw_instance.Has_Init)  //未知bug：可能是渲染需要时间所以宽度高度可能一开始初始化失败 需要多次尝试赋值
        {
            Draw_instance.Init(Graphic_draw.Width, Graphic_draw.Height);
        }

        Draw_instance.Render(Viewmodel.Has_trace, Viewmodel.Draw_scale);
        Graphic_draw.Invalidate();
    }

    protected override async void OnNavigatedTo(NavigatedToEventArgs args)
    {
        base.OnNavigatedTo(args);

        Viewmodel.Refresh_TagList();
        var items = await SQLiteDatabase_Helper.GetItemsAsync();
        MainThread.BeginInvokeOnMainThread(() =>
        {
            Share_Data.AncList.Clear();
            foreach (var item in items)
                Share_Data.AncList.Add(item);

        });
    }
}