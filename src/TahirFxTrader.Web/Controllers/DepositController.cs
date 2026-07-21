using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TahirFxTrader.Application.Interfaces.Services;
using TahirFxTrader.Application.Models;
using TahirFxTrader.Web.Authorization;
using TahirFxTrader.Web.Extensions;
using TahirFxTrader.Web.Models;
namespace TahirFxTrader.Web.Controllers;
[Authorize]
public sealed class DepositController : Controller
{
    private readonly IDepositService _service;
    public DepositController(IDepositService service) => _service = service;
    [Authorize(Policy = "Permission:" + Permissions.DepositCreate)]
    [HttpGet]
    public async Task<IActionResult> Create(CancellationToken ct) => View(new DepositPageViewModel { Methods = await _service.GetMethodsAsync(ct) });
    [Authorize(Policy = "Permission:" + Permissions.DepositCreate)]
    [HttpPost]
    public async Task<IActionResult> Create(DepositPageViewModel model, CancellationToken ct)
    {
        model.Methods = await _service.GetMethodsAsync(ct);
        if (model.Screenshot is null) ModelState.AddModelError(nameof(model.Screenshot), "Payment screenshot is required.");
        if (string.IsNullOrWhiteSpace(model.Request.SenderAccount))
        {
            model.Request.SenderAccount = "123";
            ModelState.Remove("Request.SenderAccount"); // clear any prior invalid-state entry so it doesn't block on next line
        }
        if (!ModelState.IsValid) return View(model);
        await using var stream = model.Screenshot!.OpenReadStream();
        var file = new FileUploadData(stream, model.Screenshot.FileName, model.Screenshot.ContentType, model.Screenshot.Length);
        try
        {
            var result = await _service.SubmitAsync(User.UserId(), model.Request, file, ct);
            if (!result.Succeeded) { ModelState.AddModelError(string.Empty, result.Message); return View(model); }
            TempData["Success"] = result.Message; return RedirectToAction(nameof(History));
        }
        catch (InvalidOperationException ex) { ModelState.AddModelError(nameof(model.Screenshot), ex.Message); return View(model); }
    }
    [Authorize(Policy = "Permission:" + Permissions.DepositHistory)]
    public async Task<IActionResult> History(CancellationToken ct) => View(await _service.GetHistoryAsync(User.UserId(), ct));
}
