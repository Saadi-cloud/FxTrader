using Microsoft.AspNetCore.Mvc;
namespace TahirFxTrader.Web.Controllers;
public sealed class HomeController : Controller
{
    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error() => View();
}
