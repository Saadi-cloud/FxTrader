namespace TahirFxTrader.Application.Models;
public sealed record FileUploadData(Stream Content, string FileName, string ContentType, long Length);
