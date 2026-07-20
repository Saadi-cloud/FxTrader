param(
    [Parameter(Mandatory = $true)]
    [string]$ReferralUrl
)

$ErrorActionPreference = 'Stop'

Write-Host "Checking referral page: $ReferralUrl" -ForegroundColor Cyan
$response = Invoke-WebRequest -Uri $ReferralUrl -UseBasicParsing
$html = $response.Content

$required = @(
    'og:title',
    'og:description',
    'og:url',
    'og:image',
    'og:image:secure_url',
    'og:image:type',
    'og:image:width',
    'og:image:height'
)

foreach ($property in $required) {
    if ($html -notmatch [regex]::Escape("property=\"$property\"") -and
        $html -notmatch [regex]::Escape("property='$property'")) {
        throw "Missing Open Graph property: $property"
    }
}

$imageMatch = [regex]::Match($html, '<meta\s+property=["'']og:image["'']\s+content=["'']([^"'']+)', 'IgnoreCase')
if (-not $imageMatch.Success) {
    throw 'Could not extract og:image URL.'
}

$imageUrl = $imageMatch.Groups[1].Value
Write-Host "Checking preview image: $imageUrl" -ForegroundColor Cyan
$imageResponse = Invoke-WebRequest -Uri $imageUrl -Method Head -UseBasicParsing

Write-Host "Page status: $($response.StatusCode)" -ForegroundColor Green
Write-Host "Image status: $($imageResponse.StatusCode)" -ForegroundColor Green
Write-Host "Image content type: $($imageResponse.Headers['Content-Type'])" -ForegroundColor Green
Write-Host 'Referral preview metadata is available.' -ForegroundColor Green
