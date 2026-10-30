<#
.SYNOPSIS
Stores an Azure DevOps personal access token, Base64-encoded as ":<PAT>", in a user environment variable.

.PARAMETER Name
The variable name: PERSONAL_ACCESS_TOKEN for the first organization on this machine, ADO_PAT_<ORG> for every further one.

.EXAMPLE
.\Set-AdoPat.ps1 -Name PERSONAL_ACCESS_TOKEN
.EXAMPLE
.\Set-AdoPat.ps1 -Name ADO_PAT_CONTOSO
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Z][A-Z0-9_]*$')]
    [string]$Name
)

$pat = [Net.NetworkCredential]::new("", (Read-Host "PAT for $Name" -AsSecureString)).Password
if ([string]::IsNullOrWhiteSpace($pat)) {
    Write-Error "Nothing was entered; the variable was not changed. Run the script again and paste the token at the prompt."
    exit 1
}
if ($pat -notmatch '^[A-Za-z0-9]+$') {
    Write-Error "The token contains characters outside A-Z, a-z, 0-9; check that only the PAT was pasted. The variable was not changed."
    exit 1
}

$encoded = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
[Environment]::SetEnvironmentVariable($Name, $encoded, "User")
Remove-Variable pat, encoded

Write-Host "$Name stored ($( ([Environment]::GetEnvironmentVariable($Name, 'User')).Length ) characters). Close every terminal and agent window before using it."
