using CommunityToolkit.Maui;
using Maui_pg.Services;
using Maui_pg.Tools;
using Maui_pg.ViewModels;
using Maui_pg.Views;

namespace Maui_pg;

public static class MauiProgram
{
	public static MauiApp CreateMauiApp()
	{
		var builder = MauiApp.CreateBuilder();
        
        // Initialise the toolkit
        builder.UseMauiApp<App>().UseMauiCommunityToolkit();
        
        builder
			.UseMauiApp<App>()
			.ConfigureFonts(fonts =>
			{
				fonts.AddFont("OpenSans-Regular.ttf", "OpenSansRegular");
				fonts.AddFont("OpenSans-Semibold.ttf", "OpenSansSemibold");
                fonts.AddFont("fa_solid.ttf", "FontAwesome");  //注册使用图标字体库
                fonts.AddFont("fa-brands-400.ttf", "FontAwesomeBrands");
            });

        builder.Services.AddSingleton<BluetoothService>();    //创建蓝牙单例服务 后续需要用到的服务可以直接单例注入
        builder.Services.AddSingleton<DatabaseHelper>();

		builder.Services.AddSingleton<MainPage_ViewModel>();  //创建vm 交给应用创建服务        		
        builder.Services.AddSingleton<MainPage>();  

        builder.Services.AddTransient<CommuPage_ViewModel>();  //创建vm 交给应用创建服务        		
        builder.Services.AddTransient<CommuPage>();  

        builder.Services.AddTransient<DisplayPage_ViewModel>();  //创建vm 交给应用创建服务        		
        builder.Services.AddTransient<DisplayPage>();  

        builder.Services.AddSingleton<AboutPage>();

        builder.Services.AddTransient<AnchorList_ViewModel>();
        builder.Services.AddTransient<AnchorList_Page>();  

        builder.Services.AddTransient<AnchorItem_ViewModel>();
        builder.Services.AddTransient<AnchorItem_Page>(); 
        return builder.Build();
	}
}
