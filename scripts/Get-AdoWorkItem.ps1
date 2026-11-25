<#
.SYNOPSIS
Prints board work items as short text: type, state, title, assignee, iteration, parent, tags, description and the extra fields, optionally with comments.

.PARAMETER Fields
Extra fields after the description. The default is the Scrum and Agile acceptance criteria and repro steps; pass the profile's `Acceptance criteria field` when the process names it differently, or an empty list for none.

.EXAMPLE
.\Get-AdoWorkItem.ps1 -Organization contoso -Project "Web shop" -Id 1234, 1235 -Comments
#>
#Requires -Version 7.0
param(
    [Parameter(Mandatory = $true)][string]$Organization,
    [Parameter(Mandatory = $true)][string]$Project,
    [Parameter(Mandatory = $true)][string[]]$Id,
    [string[]]$Fields = @('Microsoft.VSTS.Common.AcceptanceCriteria', 'Microsoft.VSTS.TCM.ReproSteps'),
    [switch]$Comments,
    [string]$TokenVariable = 'PERSONAL_ACCESS_TOKEN'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AdoRest.psm1') -Force
$base = Get-AdoApiBase -Organization $Organization -Project $Project

$systemFields = @(
    'System.WorkItemType', 'System.State', 'System.Title', 'System.AssignedTo',
    'System.IterationPath', 'System.Parent', 'System.Tags', 'System.Description'
)

try {
    $ids = @($Id -split '[,\s]+' | Where-Object { $_ } | ForEach-Object { [int]$_ })
    $Fields = @($Fields -split '[,\s]+' | Where-Object { $_ })
    $batch = Invoke-Ado -TokenVariable $TokenVariable -Method Post -Uri "$base/wit/workitemsbatch?api-version=7.1" -Body @{
        ids = $ids
        fields = @($systemFields + $Fields)
    }

    $first = $true
    foreach ($item in $batch.value) {
        if (-not $first) { '' }
        $first = $false
        $f = $item.fields
        $markdown = $item.multilineFieldsFormat

        "$($item.id) $($f.'System.WorkItemType') [$($f.'System.State')] $($f.'System.Title')"
        $meta = @("Assigned: $(if ($f.'System.AssignedTo') { $f.'System.AssignedTo'.displayName } else { '-' })", "Iteration: $($f.'System.IterationPath')")
        if ($f.'System.Parent') { $meta += "Parent: $($f.'System.Parent')" }
        if ($f.'System.Tags') { $meta += "Tags: $($f.'System.Tags')" }
        $meta -join ' | '

        foreach ($name in @('System.Description') + $Fields) {
            $value = $f.$name
            if ([string]::IsNullOrWhiteSpace($value)) { continue }
            $isMarkdown = $markdown -and $markdown.$name -eq 'markdown'
            "$($name -replace '^.*\.', ''):"
            if ($isMarkdown) { $value.Trim() } else { ConvertTo-PlainText $value }
        }

        if ($Comments) {
            $list = Invoke-Ado -TokenVariable $TokenVariable -Uri "$base/wit/workItems/$($item.id)/comments?api-version=7.1-preview.4"
            "Comments ($($list.totalCount)):"
            foreach ($comment in ($list.comments | Sort-Object createdDate)) {
                $text = if ($comment.format -eq 'markdown') { $comment.text.Trim() } else { ConvertTo-PlainText $comment.text }
                "  [$($comment.createdBy.displayName) $(Format-AdoDate $comment.createdDate)] $text"
            }
        }
    }
}
catch {
    Write-Output "ERR: $($_.Exception.Message)"
    exit 1
}
