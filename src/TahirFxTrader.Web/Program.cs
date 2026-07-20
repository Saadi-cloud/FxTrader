using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using TahirFxTrader.Application.Interfaces.Repositories;
using TahirFxTrader.Application.Interfaces.Services;
using TahirFxTrader.Application.Services;
using TahirFxTrader.Infrastructure.Data;
using TahirFxTrader.Infrastructure.Email;
using TahirFxTrader.Infrastructure.Files;
using TahirFxTrader.Infrastructure.Repositories;
using TahirFxTrader.Infrastructure.Security;
using TahirFxTrader.Web.Authorization;
using TahirFxTrader.Domain.Enums;
using System.Security.Claims;
using System.Threading.RateLimiting;
var builder = WebApplication.CreateBuilder(args);

// Visual Studio or a machine-level ASPNETCORE_URLS variable may accidentally
// include a browser path (for example, http://localhost:5188/account/login).
// Kestrel can bind only to scheme + host + port; browser paths belong in
// launchSettings.json under launchUrl. Sanitize configured development URLs
// before the web host starts so stale local settings cannot crash startup.
if (builder.Environment.IsDevelopment())
{
    var configuredUrls = builder.Configuration[WebHostDefaults.ServerUrlsKey];
    var sanitizedUrls = SanitizeServerUrls(configuredUrls);

    if (!string.IsNullOrWhiteSpace(sanitizedUrls) &&
        !string.Equals(configuredUrls, sanitizedUrls, StringComparison.OrdinalIgnoreCase))
    {
        builder.WebHost.UseUrls(sanitizedUrls.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
    }
}
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto | ForwardedHeaders.XForwardedHost;
    // Common when deployed behind IIS, Nginx, Cloudflare Tunnel, or a managed reverse proxy.
    options.KnownNetworks.Clear();
    options.KnownProxies.Clear();
});
builder.Services.AddControllersWithViews(options => options.Filters.Add(new Microsoft.AspNetCore.Mvc.AutoValidateAntiforgeryTokenAttribute()));
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy("auth", httpContext => RateLimitPartition.GetFixedWindowLimiter(
        partitionKey: httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        factory: _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = 12,
            Window = TimeSpan.FromMinutes(1),
            QueueLimit = 0,
            AutoReplenishment = true
        }));
});
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme).AddCookie(options =>
{
    options.LoginPath = "/account/login";
    options.AccessDeniedPath = "/account/access-denied";
    options.Cookie.Name = "TahirFxTrader.Auth";
    options.Cookie.HttpOnly = true;
    options.Cookie.SameSite = SameSiteMode.Lax;
    options.Cookie.SecurePolicy = CookieSecurePolicy.SameAsRequest;
    options.SlidingExpiration = true;
    options.ExpireTimeSpan = TimeSpan.FromHours(8);
    options.Events.OnValidatePrincipal = async context =>
    {
        var idValue = context.Principal?.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!long.TryParse(idValue, out var userId)) { context.RejectPrincipal(); return; }
        var repository = context.HttpContext.RequestServices.GetRequiredService<IUserRepository>();
        var user = await repository.GetByIdAsync(userId, context.HttpContext.RequestAborted);
        if (user is null || user.Status != AccountStatus.Active || !user.IsEmailVerified)
        {
            context.RejectPrincipal();
            await context.HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        }
    };
});
builder.Services.AddAuthorization();
builder.Services.AddSingleton<IAuthorizationPolicyProvider, PermissionPolicyProvider>();
builder.Services.AddScoped<Microsoft.AspNetCore.Authentication.IClaimsTransformation, DatabaseClaimsTransformation>();
builder.Services.AddScoped<IAuthorizationHandler, PermissionAuthorizationHandler>();
builder.Services.Configure<SmtpOptions>(builder.Configuration.GetSection("Smtp"));
builder.Services.AddSingleton<ISqlConnectionFactory>(_ => new SqlConnectionFactory(builder.Configuration.GetConnectionString("DefaultConnection") ?? string.Empty));
builder.Services.AddScoped<IUserRepository, UserRepository>();
builder.Services.AddScoped<IPaymentMethodRepository, PaymentMethodRepository>();
builder.Services.AddScoped<IDepositRepository, DepositRepository>();
builder.Services.AddScoped<IWithdrawalRepository, WithdrawalRepository>();
builder.Services.AddScoped<IDashboardRepository, DashboardRepository>();
builder.Services.AddScoped<IPasswordService, PasswordService>();
builder.Services.AddScoped<ICodeService, CodeService>();
builder.Services.AddScoped<IEmailService, SmtpEmailService>();
builder.Services.AddScoped<IFileStorageService, LocalFileStorageService>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IDashboardService, DashboardService>();
builder.Services.AddScoped<IDepositService, DepositService>();
builder.Services.AddScoped<IWithdrawalService, WithdrawalService>();
builder.Services.AddScoped<IAdminService, AdminService>();
var app = builder.Build();
app.UseForwardedHeaders();
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/home/error");
    app.UseHsts();
    app.UseHttpsRedirection();
}
app.UseStaticFiles(new StaticFileOptions
{
    OnPrepareResponse = context =>
    {
        if (context.Context.Request.Path.StartsWithSegments("/images/referral"))
            context.Context.Response.Headers.CacheControl = "public,max-age=86400";
    }
});
app.UseRouting();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllerRoute(name: "areas", pattern: "{area:exists}/{controller=Dashboard}/{action=Index}/{id?}");
app.MapControllerRoute(name: "default", pattern: "{controller=Dashboard}/{action=Index}/{id?}");
app.Run();

static string? SanitizeServerUrls(string? configuredUrls)
{
    if (string.IsNullOrWhiteSpace(configuredUrls))
    {
        return configuredUrls;
    }

    var sanitized = configuredUrls
        .Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
        .Select(value => Uri.TryCreate(value, UriKind.Absolute, out var uri)
            && (uri.Scheme.Equals(Uri.UriSchemeHttp, StringComparison.OrdinalIgnoreCase)
                || uri.Scheme.Equals(Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase))
                ? $"{uri.Scheme}://{uri.Authority}"
                : null)
        .Where(value => !string.IsNullOrWhiteSpace(value))
        .Distinct(StringComparer.OrdinalIgnoreCase)
        .ToArray();

    return sanitized.Length == 0 ? "http://localhost:5188" : string.Join(';', sanitized);
}
