using Maui_pg.Models;
using SQLite;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maui_pg.Tools
{
    public class DatabaseHelper
    {
        SQLiteAsyncConnection Database;

        public const string DatabaseFilename = "PG_maui_db.db3";

        public const SQLiteOpenFlags Flags =
        // open the database in read/write mode
        SQLiteOpenFlags.ReadWrite |
        // create the database if it doesn't exist
        SQLiteOpenFlags.Create |
        // enable multi-threaded database access
        SQLiteOpenFlags.SharedCache;

        public static string DatabasePath =>
        Path.Combine(FileSystem.AppDataDirectory, DatabaseFilename);

        async Task Init()
        {
            if (Database is not null)
                return;

            Database = new SQLiteAsyncConnection(DatabasePath, Flags);
            var result = await Database.CreateTableAsync<UWBAnchor>();
        }

        public async Task<List<UWBAnchor>> GetItemsAsync()
        {
            await Init();
            return await Database.Table<UWBAnchor>().ToListAsync();
        }

        //public async Task<List<UWBAnchor>> GetItemsNotDoneAsync()
        //{
        //    await Init();
        //    return await Database.Table<UWBAnchor>().Where(t => t.Done).ToListAsync();

        //    // SQL queries are also possible
        //    //return await Database.QueryAsync<UWBAnchor>("SELECT * FROM [UWBAnchor] WHERE [Done] = 0");
        //}

        public async Task<UWBAnchor> GetItemAsync(int id)
        {
            await Init();
            return await Database.Table<UWBAnchor>().Where(i => i.ID_Index == id).FirstOrDefaultAsync();
        }

        public async Task<int> SaveItemAsync(UWBAnchor item)
        {
            await Init();
            if (item.ID_Index != 0)
            {
                return await Database.UpdateAsync(item);
            }
            else
            {
                return await Database.InsertAsync(item);
            }
        }

        public async Task<int> DeleteItemAsync(UWBAnchor item)
        {
            await Init();
            return await Database.DeleteAsync(item);
        }
    }
}
