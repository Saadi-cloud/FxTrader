using Microsoft.Data.SqlClient;
namespace TahirFxTrader.Infrastructure.Data;
public interface ISqlConnectionFactory { SqlConnection CreateConnection(); }
public sealed class SqlConnectionFactory : ISqlConnectionFactory
{
    private readonly string _connectionString;
    public SqlConnectionFactory(string connectionString)
    {
        if (string.IsNullOrWhiteSpace(connectionString)) throw new ArgumentException("Database connection string is missing.", nameof(connectionString));
        _connectionString = connectionString;
    }
    public SqlConnection CreateConnection() => new(_connectionString);
}
