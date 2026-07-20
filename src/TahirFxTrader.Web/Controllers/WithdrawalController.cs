using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using TahirFxTrader.Application.Interfaces.Services;
using TahirFxTrader.Application.Models;
using TahirFxTrader.Web.Authorization;
using TahirFxTrader.Web.Extensions;
using TahirFxTrader.Web.Models;

namespace TahirFxTrader.Web.Controllers;

[Authorize]
public sealed class WithdrawalController : Controller
{
    private readonly IWithdrawalService _service;
    private readonly IDashboardService _dashboard;

    public WithdrawalController(IWithdrawalService service, IDashboardService dashboard)
    {
        _service = service;
        _dashboard = dashboard;
    }

    [Authorize(Policy = "Permission:" + Permissions.WithdrawalCreate)]
    [HttpGet]
    public async Task<IActionResult> Create(CancellationToken ct)
    {
        var dash = await _dashboard.GetAsync(User.UserId(), ct);
        return View(BuildPage(await _service.GetMethodsAsync(ct), dash));
    }

    [Authorize(Policy = "Permission:" + Permissions.WithdrawalCreate)]
    [HttpPost]
    [EnableRateLimiting("auth")]
    public async Task<IActionResult> Create(WithdrawalPageViewModel model, CancellationToken ct)
    {
        var dash = await _dashboard.GetAsync(User.UserId(), ct);
        model.Methods = await _service.GetMethodsAsync(ct);
        ApplyBalances(model, dash);

        if (!ModelState.IsValid) return View(model);

        var result = await _service.BeginVerificationAsync(User.UserId(), model.Request, ct);
        if (!result.Succeeded)
        {
            ModelState.AddModelError(string.Empty, result.Message);
            return View(model);
        }

        TempData["Success"] = result.Message;
        return RedirectToAction(nameof(VerifyOtp), new { id = result.Data });
    }

    [Authorize(Policy = "Permission:" + Permissions.WithdrawalCreate)]
    [HttpGet]
    public async Task<IActionResult> VerifyOtp(long id, CancellationToken ct)
    {
        var model = await _service.GetVerificationAsync(User.UserId(), id, ct);
        if (model is null) return NotFound();
        return View(model);
    }

    [Authorize(Policy = "Permission:" + Permissions.WithdrawalCreate)]
    [HttpPost]
    [EnableRateLimiting("auth")]
    public async Task<IActionResult> VerifyOtp(WithdrawalOtpPageModel model, CancellationToken ct)
    {
        var current = await _service.GetVerificationAsync(User.UserId(), model.Request.ChallengeId, ct);
        if (current is null) return NotFound();

        if (!ModelState.IsValid)
        {
            current.Request = model.Request;
            return View(current);
        }

        var result = await _service.VerifyAndSubmitAsync(User.UserId(), model.Request, ct);
        if (!result.Succeeded)
        {
            ModelState.AddModelError(string.Empty, result.Message);
            current.Request = model.Request;
            current.FailedAttempts += 1;
            return View(current);
        }

        TempData["Success"] = result.Message;
        return RedirectToAction(nameof(History));
    }

    [Authorize(Policy = "Permission:" + Permissions.WithdrawalCreate)]
    [HttpPost]
    [EnableRateLimiting("auth")]
    public async Task<IActionResult> ResendOtp(long id, CancellationToken ct)
    {
        var result = await _service.ResendVerificationAsync(User.UserId(), id, ct);
        TempData[result.Succeeded ? "Success" : "Error"] = result.Message;
        return result.Succeeded
            ? RedirectToAction(nameof(VerifyOtp), new { id = result.Data })
            : RedirectToAction(nameof(VerifyOtp), new { id });
    }

    [Authorize(Policy = "Permission:" + Permissions.WithdrawalHistory)]
    public async Task<IActionResult> History(CancellationToken ct)
        => View(await _service.GetHistoryAsync(User.UserId(), ct));

    private static WithdrawalPageViewModel BuildPage(IReadOnlyList<TahirFxTrader.Domain.Entities.PaymentMethod> methods, DashboardData dash)
    {
        var model = new WithdrawalPageViewModel { Methods = methods };
        ApplyBalances(model, dash);
        return model;
    }

    private static void ApplyBalances(WithdrawalPageViewModel model, DashboardData dash)
    {
        model.AvailableBalance = dash.AvailableBalance;
        model.InvestmentBalance = dash.InvestmentBalance;
        model.ProfitBalance = dash.ProfitBalance;
        model.CommissionBalance = dash.CommissionBalance;
        model.InvestmentWithdrawalFeePercent = dash.InvestmentWithdrawalFeePercent;
    }
}
