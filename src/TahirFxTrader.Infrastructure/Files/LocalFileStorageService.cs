using Microsoft.AspNetCore.Hosting;
using TahirFxTrader.Application.Interfaces.Services;
using TahirFxTrader.Application.Models;
namespace TahirFxTrader.Infrastructure.Files;
public sealed class LocalFileStorageService : IFileStorageService
{
    private static readonly HashSet<string> AllowedContentTypes = new(StringComparer.OrdinalIgnoreCase) { "image/jpeg", "image/png", "image/webp" };
    private readonly IWebHostEnvironment _environment;
    public LocalFileStorageService(IWebHostEnvironment environment) => _environment = environment;
    public Task<string> SavePaymentProofAsync(FileUploadData file, CancellationToken ct = default) => SaveAsync(file, "uploads/payment-proofs", 5 * 1024 * 1024, ct);
    public Task<string> SavePaymentMethodQrAsync(FileUploadData file, CancellationToken ct = default) => SaveAsync(file, "uploads/payment-methods", 3 * 1024 * 1024, ct);
    private async Task<string> SaveAsync(FileUploadData file, string relativeFolder, long maxBytes, CancellationToken ct)
    {
        if (file.Length <= 0 || file.Length > maxBytes) throw new InvalidOperationException($"File size must be between 1 byte and {maxBytes / 1024 / 1024} MB.");
        if (!AllowedContentTypes.Contains(file.ContentType)) throw new InvalidOperationException("Only JPG, PNG, or WEBP images are allowed.");
        await ValidateImageSignatureAsync(file.Content, file.ContentType, ct);
        var extension = file.ContentType.ToLowerInvariant() switch { "image/png" => ".png", "image/webp" => ".webp", _ => ".jpg" };
        var fileName = $"{DateTime.UtcNow:yyyyMMddHHmmss}_{Guid.NewGuid():N}{extension}";
        var folder = Path.Combine(_environment.WebRootPath, relativeFolder.Replace('/', Path.DirectorySeparatorChar));
        Directory.CreateDirectory(folder);
        var absolute = Path.Combine(folder, fileName);
        await using var output = new FileStream(absolute, FileMode.CreateNew, FileAccess.Write, FileShare.None, 81920, true);
        await file.Content.CopyToAsync(output, ct);
        return "/" + relativeFolder.Trim('/') + "/" + fileName;
    }
    private static async Task ValidateImageSignatureAsync(Stream stream, string contentType, CancellationToken ct)
    {
        if (!stream.CanSeek) throw new InvalidOperationException("The uploaded image stream must support validation.");
        var header = new byte[12];
        var originalPosition = stream.Position;
        var read = await stream.ReadAsync(header.AsMemory(0, header.Length), ct);
        stream.Position = originalPosition;
        var isJpeg = read >= 3 && header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF;
        var isPng = read >= 8 && header.AsSpan(0, 8).SequenceEqual(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A });
        var isWebp = read >= 12 && header.AsSpan(0, 4).SequenceEqual("RIFF"u8) && header.AsSpan(8, 4).SequenceEqual("WEBP"u8);
        var valid = contentType.ToLowerInvariant() switch { "image/jpeg" => isJpeg, "image/png" => isPng, "image/webp" => isWebp, _ => false };
        if (!valid) throw new InvalidOperationException("The uploaded file content does not match a supported image format.");
    }
}
