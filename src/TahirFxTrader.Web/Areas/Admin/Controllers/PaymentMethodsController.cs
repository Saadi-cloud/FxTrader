using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TahirFxTrader.Application.Interfaces.Services;
using TahirFxTrader.Application.Models;
using TahirFxTrader.Domain.Entities;
using TahirFxTrader.Web.Extensions;
namespace TahirFxTrader.Web.Areas.Admin.Controllers;
[Area("Admin"), Authorize(Roles = "Admin")]
public sealed class PaymentMethodsController : Controller
{
    private readonly IAdminService _service;
    public PaymentMethodsController(IAdminService service) => _service = service;
    public async Task<IActionResult> Index(CancellationToken ct) => View(await _service.GetPaymentMethodsAsync(ct));
    [HttpGet] public IActionResult Create() => View("Edit", new PaymentMethod { IsActive = true, SupportsDeposit = true, SupportsWithdrawal = true, DisplayOrder = 1 });
    [HttpGet] public async Task<IActionResult> Edit(int id, CancellationToken ct) { var model = await _service.GetPaymentMethodAsync(id, ct); return model is null ? NotFound() : View(model); }
    [HttpPost]
    public async Task<IActionResult> Save(PaymentMethod model, IFormFile? qrImage, CancellationToken ct)
    {
        FileUploadData? qr = null; Stream? stream = null;
        try
        {
            if (qrImage is not null) { stream = qrImage.OpenReadStream(); qr = new FileUploadData(stream, qrImage.FileName, qrImage.ContentType, qrImage.Length); }
            var result = await _service.SavePaymentMethodAsync(model, User.UserId(), qr, ct);
            if (!result.Succeeded) { ModelState.AddModelError(string.Empty, result.Message); return View("Edit", model); }
            TempData["Success"] = result.Message; return RedirectToAction(nameof(Index));
        }
        catch (InvalidOperationException ex) { ModelState.AddModelError(nameof(qrImage), ex.Message); return View("Edit", model); }
        finally { if (stream is not null) await stream.DisposeAsync(); }
    }
    [HttpPost]
    public async Task<IActionResult> Delete(int id, CancellationToken ct)
    { var result = await _service.DeletePaymentMethodAsync(id, User.UserId(), ct); TempData[result.Succeeded ? "Success" : "Error"] = result.Message; return RedirectToAction(nameof(Index)); }
}
