using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TahirFxTrader.Application.Interfaces.Services;
using TahirFxTrader.Application.Models;
using TahirFxTrader.Web.Extensions;
namespace TahirFxTrader.Web.Areas.Admin.Controllers;
[Area("Admin"), Authorize(Roles = "Admin")]
public sealed class UserBalancesController : Controller
{
    private readonly IAdminService _service;
    public UserBalancesController(IAdminService service) => _service = service;
    public async Task<IActionResult> Index(CancellationToken ct) => View(await _service.GetUserBalancesAsync(ct));
    [HttpGet]
    public async Task<IActionResult> AddProfit(long id, CancellationToken ct)
    {
        var balance = await _service.GetUserBalanceAsync(id, ct);
        if (balance is null) return NotFound();
        return View(new ApplyProfitRequest
        {
            UserId = balance.UserId, UserTraceId = balance.UserTraceId, FullName = balance.FullName, Email = balance.Email,
            InvestmentBalance = balance.InvestmentBalance, ProfitBalance = balance.ProfitBalance, CommissionBalance = balance.CommissionBalance
        });
    }
    [HttpPost]
    public async Task<IActionResult> AddProfit(ApplyProfitRequest model, CancellationToken ct)
    {
        var balance = await _service.GetUserBalanceAsync(model.UserId, ct);
        if (balance is null) return NotFound();
        model.UserTraceId = balance.UserTraceId; model.FullName = balance.FullName; model.Email = balance.Email; model.InvestmentBalance = balance.InvestmentBalance; model.ProfitBalance = balance.ProfitBalance; model.CommissionBalance = balance.CommissionBalance;
        if (!ModelState.IsValid) return View(model);
        var result = await _service.ApplyProfitAsync(model, User.UserId(), ct);
        if (!result.Succeeded) { ModelState.AddModelError(string.Empty, result.Message); return View(model); }
        TempData["Success"] = result.Message;
        return RedirectToAction(nameof(Index));
    }

    [HttpGet]
    public async Task<IActionResult> ApplyProfitToAll(CancellationToken ct)
    {
        var balances = await _service.GetUserBalancesAsync(ct);
        return View(BuildBulkModel(new ApplyProfitToAllRequest(), balances));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ApplyProfitToAll(ApplyProfitToAllRequest model, CancellationToken ct)
    {
        var balances = await _service.GetUserBalancesAsync(ct);
        model = BuildBulkModel(model, balances);
        if (!ModelState.IsValid) return View(model);
        var result = await _service.ApplyProfitToAllAsync(model, User.UserId(), ct);
        if (!result.Succeeded)
        {
            ModelState.AddModelError(string.Empty, result.Message);
            return View(model);
        }
        TempData["Success"] = result.Message;
        return RedirectToAction(nameof(Index));
    }

    private static ApplyProfitToAllRequest BuildBulkModel(ApplyProfitToAllRequest model, IReadOnlyList<AdminUserBalanceItem> balances)
    {
        var eligible = balances.Where(x => x.Status == TahirFxTrader.Domain.Enums.AccountStatus.Active && x.CompoundProfitBase > 0).ToList();
        model.EligibleUserCount = eligible.Count;
        model.TotalCompoundingBase = eligible.Sum(x => x.CompoundProfitBase);
        return model;
    }
}
