using System.Data;
using Microsoft.Data.SqlClient;
using TahirFxTrader.Application.Common;
using TahirFxTrader.Infrastructure.Data;
namespace TahirFxTrader.Infrastructure.Repositories;
public abstract class RepositoryBase
{
    protected readonly ISqlConnectionFactory Connections;
    protected RepositoryBase(ISqlConnectionFactory connections) => Connections = connections;
    protected static SqlCommand StoredProcedure(SqlConnection connection, string name)
    {
        // SQL Server gives special lookup behavior to procedure names beginning with
        // "sp_" and may search master first. Always schema-qualify application
        // procedures so calls resolve in the connection's configured database.
        var qualifiedName = name.Contains('.', StringComparison.Ordinal) ? name : $"dbo.{name}";
        return new SqlCommand(qualifiedName, connection)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 60
        };
    }
    protected static void Add(SqlCommand command, string name, object? value) => command.Parameters.AddWithValue(name, value ?? DBNull.Value);
    protected static async Task<DbOperationResult> ReadResultAsync(SqlCommand command, CancellationToken ct)
    {
        await using var reader = await command.ExecuteReaderAsync(ct);
        if (!await reader.ReadAsync(ct)) return new(false, "The database did not return a result.");
        var success = reader.Bool("Succeeded");
        var message = reader.String("Message");
        var id = reader.GetOrdinal("Id") >= 0 && reader["Id"] != DBNull.Value ? Convert.ToInt64(reader["Id"]) : (long?)null;
        return new(success, message, id);
    }
}
