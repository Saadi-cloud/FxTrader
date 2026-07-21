using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace TahirFxTrader.Web.Controllers;

[Authorize]
public sealed class CompanyInfoController : Controller
{
    public IActionResult Index()
    {
        ViewData["Title"] = "Company Profile";
        ViewData["Subtitle"] = "About OLX Trade and our global presence";
        return View();
    }
}
