using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TahirFxTrader.Application.Interfaces.Services;
using TahirFxTrader.Application.Models;
using TahirFxTrader.Web.Extensions;
namespace TahirFxTrader.Web.Areas.Admin.Controllers;
[Area("Admin"), Authorize(Roles = "Admin")]
public sealed class DepositsController : Controller
{
    private readonly IAdminService _service;
    public DepositsController(IAdminService service) => _service = service;
    public async Task<IActionResult> Index(CancellationToken ct) => View(await _service.GetDepositsAsync(ct));
    public async Task<IActionResult> Details(long id, CancellationToken ct) { var row = await _service.GetDepositAsync(id, ct); return row is null ? NotFound() : View(row); }
    [HttpPost] public async Task<IActionResult> Approve(ReviewTransactionRequest model, CancellationToken ct)
    { var r = await _service.ApproveDepositAsync(model.Id, User.UserId(), model.AdminNote, ct); TempData[r.Succeeded ? "Success" : "Error"] = r.Message; return RedirectToAction(nameof(Details), new { id = model.Id }); }
    [HttpPost] public async Task<IActionResult> Reject(ReviewTransactionRequest model, CancellationToken ct)
    { var r = await _service.RejectDepositAsync(model.Id, User.UserId(), model.AdminNote, ct); TempData[r.Succeeded ? "Success" : "Error"] = r.Message; return RedirectToAction(nameof(Details), new { id = model.Id }); }
}
