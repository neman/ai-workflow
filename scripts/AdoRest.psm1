try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch { }

function Get-AdoApiBase {
    param(
        [Parameter(Mandatory = $true)][string]$Organization,
        [Parameter(Mandatory = $true)][string]$Project
    )
    "https://dev.azure.com/$Organization/$([Uri]::EscapeDataString($Project))/_apis"
}

function Invoke-Ado {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [string]$Method = 'Get',
        [object]$Body,
        [string]$ContentType = 'application/json',
        [string]$TokenVariable = 'PERSONAL_ACCESS_TOKEN'
    )
    $token = [Environment]::GetEnvironmentVariable($TokenVariable, 'User')
    if (-not $token) { $token = [Environment]::GetEnvironmentVariable($TokenVariable, 'Process') }
    if (-not $token) { throw "The environment variable $TokenVariable is empty; store the token first (azure-devops.md, Setup, step 2)." }

    $request = @{ Method = $Method; Uri = $Uri; Headers = @{ Authorization = "Basic $token" } }
    if ($null -ne $Body) {
        $json = if ($Body -is [string]) { $Body } else { ConvertTo-Json -InputObject $Body -Depth 20 -Compress }
        $request.Body = [Text.Encoding]::UTF8.GetBytes($json)
        $request.ContentType = "$ContentType; charset=utf-8"
    }
    try {
        Invoke-RestMethod @request
    }
    catch {
        $status = $_.Exception.Response.StatusCode.value__
        $detail = $_.ErrorDetails.Message
        try { $detail = ($detail | ConvertFrom-Json).message } catch { }
        $path = $Uri -replace '\?.*$', ''
        throw "Azure DevOps answered $status to $($Method.ToUpper()) $path$(if ($detail) { ": $detail" })"
    }
}

function ConvertTo-PlainText {
    param([string]$Html)
    if ([string]::IsNullOrWhiteSpace($Html)) { return '' }
    $text = $Html -replace '(?i)<br\s*/?>|</p>|</div>|</li>|</h\d>|</tr>', "`n"
    $text = $text -replace '(?i)<li[^>]*>', '- '
    $text = $text -replace '<[^>]+>', ''
    $text = [Net.WebUtility]::HtmlDecode($text)
    (($text -split "`n" | ForEach-Object { $_.Trim() }) -join "`n" -replace "`n{3,}", "`n`n").Trim()
}

function Format-AdoDate {
    param($Value)
    if (-not $Value) { return '' }
    ([DateTimeOffset]$Value).ToLocalTime().ToString('yyyy-MM-dd HH:mm')
}

Export-ModuleMember -Function Get-AdoApiBase, Invoke-Ado, ConvertTo-PlainText, Format-AdoDate
