using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TahirFxTrader.Application.Interfaces.Services;
using TahirFxTrader.Application.Models;
using TahirFxTrader.Web.Extensions;
namespace TahirFxTrader.Web.Areas.Admin.Controllers;
[Area("Admin"), Authorize(Roles = "Admin")]
public sealed class WithdrawalsController : Controller
{
    private readonly IAdminService _service;
    public WithdrawalsController(IAdminService service) => _service = service;
    public async Task<IActionResult> Index(CancellationToken ct) => View(await _service.GetWithdrawalsAsync(ct));
    public async Task<IActionResult> Details(long id, CancellationToken ct) { var row = await _service.GetWithdrawalAsync(id, ct); return row is null ? NotFound() : View(row); }
    [HttpPost] public async Task<IActionResult> Process(ReviewTransactionRequest model, CancellationToken ct)
    { var r = await _service.ProcessWithdrawalAsync(model.Id, User.UserId(), model.AdminNote, ct); TempData[r.Succeeded ? "Success" : "Error"] = r.Message; return RedirectToAction(nameof(Details), new { id = model.Id }); }
    [HttpPost] public async Task<IActionResult> Complete(ReviewTransactionRequest model, CancellationToken ct)
    { var r = await _service.CompleteWithdrawalAsync(model.Id, User.UserId(), model.PaymentReference, model.AdminNote, ct); TempData[r.Succeeded ? "Success" : "Error"] = r.Message; return RedirectToAction(nameof(Details), new { id = model.Id }); }
    [HttpPost] public async Task<IActionResult> Reject(ReviewTransactionRequest model, CancellationToken ct)
    { var r = await _service.RejectWithdrawalAsync(model.Id, User.UserId(), model.AdminNote, ct); TempData[r.Succeeded ? "Success" : "Error"] = r.Message; return RedirectToAction(nameof(Details), new { id = model.Id }); }
}
