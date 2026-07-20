namespace TahirFxTrader.Application.Common;
public sealed record DbOperationResult(bool Succeeded, string Message, long? Id = null);
