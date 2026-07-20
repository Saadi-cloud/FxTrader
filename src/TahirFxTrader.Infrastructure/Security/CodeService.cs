using System.Security.Cryptography;
using System.Text;
using TahirFxTrader.Application.Interfaces.Services;
namespace TahirFxTrader.Infrastructure.Security;
public sealed class CodeService : ICodeService
{
    public string GenerateNumericCode(int digits = 6)
    {
        if (digits is < 4 or > 9) throw new ArgumentOutOfRangeException(nameof(digits));
        var min = (int)Math.Pow(10, digits - 1);
        var max = (int)Math.Pow(10, digits);
        return RandomNumberGenerator.GetInt32(min, max).ToString();
    }
    public string HashCode(string code) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(code.Trim())));
    public bool VerifyCode(string code, string hash)
    {
        var actual = Encoding.UTF8.GetBytes(HashCode(code));
        var expected = Encoding.UTF8.GetBytes(hash);
        return actual.Length == expected.Length && CryptographicOperations.FixedTimeEquals(actual, expected);
    }
}
