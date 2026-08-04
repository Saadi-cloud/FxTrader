using TahirFxTrader.Application.Common;
using TahirFxTrader.Application.Interfaces.Repositories;
using TahirFxTrader.Application.Interfaces.Services;
using TahirFxTrader.Application.Models;
using TahirFxTrader.Domain.Entities;
namespace TahirFxTrader.Application.Services;
public sealed class DepositService : IDepositService
{
    private readonly IDepositRepository _deposits;
    private readonly IPaymentMethodRepository _methods;
    private readonly IUserRepository _users;
    private readonly IFileStorageService _files;
    private readonly IEmailService _emailService;
    public DepositService(
    IUserRepository users,
    IPaymentMethodRepository methods,
    IDepositRepository deposits,
    IFileStorageService files,
    IEmailService emailService)
    {
        _users = users;
        _methods = methods;
        _deposits = deposits;
        _files = files;
        _emailService = emailService;
    }
    public DepositService(IDepositRepository deposits, IPaymentMethodRepository methods, IUserRepository users, IFileStorageService files)
    { _deposits = deposits; _methods = methods; _users = users; _files = files; }
    public Task<IReadOnlyList<PaymentMethod>> GetMethodsAsync(CancellationToken ct = default) => _methods.GetActiveDepositMethodsAsync(ct);
    public Task<IReadOnlyList<DepositTransaction>> GetHistoryAsync(long userId, CancellationToken ct = default) => _deposits.GetByUserAsync(userId, ct);

    public async Task<OperationResult<long>> SubmitAsync(
    long userId,
    CreateDepositRequest request,
    FileUploadData proof,
    CancellationToken ct = default)
    {
        var user = await _users.GetByIdAsync(userId, ct);

        if (user is null || !user.CanDeposit)
            return OperationResult<long>.Failure("Deposits are disabled for this account.");


        var method = await _methods.GetByIdAsync(request.PaymentMethodId, ct);

        if (method is null || !method.IsActive || !method.SupportsDeposit)
            return OperationResult<long>.Failure("The selected deposit method is unavailable.");


        if (request.Amount < method.MinDeposit ||
            (method.MaxDeposit.HasValue && request.Amount > method.MaxDeposit.Value))
        {
            return OperationResult<long>.Failure(
                $"Deposit amount must be between {method.MinDeposit:N2} and {(method.MaxDeposit?.ToString("N2") ?? "the allowed maximum")}."
            );
        }


        var path = await _files.SavePaymentProofAsync(proof, ct);


        // Save deposit request
        var result = await _deposits.CreateAsync(userId, request, path, ct);



        if (!result.Succeeded || !result.Id.HasValue)
        {
            return OperationResult<long>.Failure(result.Message);
        }



        // Send email to admin after successful deposit creation
        try
        {
            await _emailService.SendAdminDepositRequestAsync(
                user.FullName,
                user.Email,
                (decimal)request.Amount,
                result.Id.Value.ToString(),
                ct);
        }
        catch
        {
            // Do not fail deposit if email fails
            // Log exception here if logging is available
        }



        return OperationResult<long>.Success(
            result.Id.Value,
            result.Message
        );
    }

    //public async Task<OperationResult<long>> SubmitAsync(long userId, CreateDepositRequest request, FileUploadData proof, CancellationToken ct = default)
    //{
    //    var user = await _users.GetByIdAsync(userId, ct);
    //    if (user is null || !user.CanDeposit) return OperationResult<long>.Failure("Deposits are disabled for this account.");
    //    var method = await _methods.GetByIdAsync(request.PaymentMethodId, ct);
    //    if (method is null || !method.IsActive || !method.SupportsDeposit) return OperationResult<long>.Failure("The selected deposit method is unavailable.");
    //    if (request.Amount < method.MinDeposit || (method.MaxDeposit.HasValue && request.Amount > method.MaxDeposit.Value))
    //        return OperationResult<long>.Failure($"Deposit amount must be between {method.MinDeposit:N2} and {(method.MaxDeposit?.ToString("N2") ?? "the allowed maximum")}.");
    //    var path = await _files.SavePaymentProofAsync(proof, ct);
    //    var result = await _deposits.CreateAsync(userId, request, path, ct);
    //    return result.Succeeded && result.Id.HasValue
    //        ? OperationResult<long>.Success(result.Id.Value, result.Message)
    //        : OperationResult<long>.Failure(result.Message);
    //}
}
