namespace TahirFxTrader.Application.Common;
public class OperationResult
{
    public bool Succeeded { get; init; }
    public string Message { get; init; } = string.Empty;
    public static OperationResult Success(string message = "Completed successfully.") => new() { Succeeded = true, Message = message };
    public static OperationResult Failure(string message) => new() { Succeeded = false, Message = message };
}
public sealed class OperationResult<T> : OperationResult
{
    public T? Data { get; init; }
    public static OperationResult<T> Success(T data, string message = "Completed successfully.") => new() { Succeeded = true, Message = message, Data = data };
    public new static OperationResult<T> Failure(string message) => new() { Succeeded = false, Message = message };
}
