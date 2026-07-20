using Microsoft.Data.SqlClient;
namespace TahirFxTrader.Infrastructure.Data;
internal static class SqlReaderExtensions
{
    public static bool HasColumn(this SqlDataReader r, string name)
    {
        for (var i = 0; i < r.FieldCount; i++)
            if (string.Equals(r.GetName(i), name, StringComparison.OrdinalIgnoreCase)) return true;
        return false;
    }
    public static string String(this SqlDataReader r, string name) => r[name] == DBNull.Value ? string.Empty : Convert.ToString(r[name])!;
    public static string? NullableString(this SqlDataReader r, string name) => r[name] == DBNull.Value ? null : Convert.ToString(r[name]);
    public static int Int(this SqlDataReader r, string name) => Convert.ToInt32(r[name]);
    public static long Long(this SqlDataReader r, string name) => Convert.ToInt64(r[name]);
    public static decimal Decimal(this SqlDataReader r, string name) => Convert.ToDecimal(r[name]);
    public static decimal? NullableDecimal(this SqlDataReader r, string name) => r[name] == DBNull.Value ? null : Convert.ToDecimal(r[name]);
    public static bool Bool(this SqlDataReader r, string name) => Convert.ToBoolean(r[name]);
    public static DateTime DateTime(this SqlDataReader r, string name) => Convert.ToDateTime(r[name]);
    public static DateTime? NullableDateTime(this SqlDataReader r, string name) => r[name] == DBNull.Value ? null : Convert.ToDateTime(r[name]);
}
