<#
.SYNOPSIS
Prints a pull request as short text: state, branches, commits, reviewers and their votes, work items and description; optionally its iterations and threads. With -Branch, lists the pull requests of a source branch instead.

.PARAMETER Threads
Review threads (those with a status) with every comment. Add -System for the system threads too: votes, auto-complete, pushes, completion.

.PARAMETER Brief
Leaves out the description.

.EXAMPLE
.\Get-AdoPullRequest.ps1 -Organization contoso -Project "Web shop" -Repository shop-api -Id 321 -Iterations -Threads
.EXAMPLE
.\Get-AdoPullRequest.ps1 -Organization contoso -Project "Web shop" -Repository shop-api -Branch fix/1234-login-timeouts
#>
#Requires -Version 7.0
param(
    [Parameter(Mandatory = $true)][string]$Organization,
    [Parameter(Mandatory = $true)][string]$Project,
    [Parameter(Mandatory = $true)][string]$Repository,
    [int]$Id,
    [string]$Branch,
    [switch]$Iterations,
    [switch]$Threads,
    [switch]$System,
    [switch]$Brief,
    [string]$TokenVariable = 'PERSONAL_ACCESS_TOKEN'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AdoRest.psm1') -Force
$repo = "$(Get-AdoApiBase -Organization $Organization -Project $Project)/git/repositories/$([Uri]::EscapeDataString($Repository))"

function Get-Vote([int]$vote) {
    switch ($vote) { 10 { 'approved' } 5 { 'approved with suggestions' } 0 { 'no vote' } -5 { 'waiting for author' } -10 { 'rejected' } default { "$vote" } }
}

function Get-Short([string]$ref) { $ref -replace '^refs/heads/', '' }

try {
    if ($Branch) {
        $ref = [Uri]::EscapeDataString("refs/heads/$Branch")
        $list = Invoke-Ado -TokenVariable $TokenVariable -Uri "$repo/pullrequests?searchCriteria.sourceRefName=$ref&searchCriteria.status=all&api-version=7.1"
        if ($list.count -eq 0) { "No pull request from $Branch." }
        foreach ($pr in $list.value) {
            "$($pr.pullRequestId) $($pr.status) $(Get-Short $pr.sourceRefName) -> $(Get-Short $pr.targetRefName) | $($pr.title)"
        }
        exit 0
    }
    if (-not $Id) { throw 'Pass -Id or -Branch.' }

    $pr = Invoke-Ado -TokenVariable $TokenVariable -Uri "$repo/pullRequests/$($Id)?api-version=7.1"
    "PR $($pr.pullRequestId) $($pr.status)$(if ($pr.isDraft) { ' (draft)' }): $($pr.title)"
    "$(Get-Short $pr.sourceRefName) -> $(Get-Short $pr.targetRefName) | by $($pr.createdBy.displayName) $(Format-AdoDate $pr.creationDate) | merge: $($pr.mergeStatus)"
    $commits = "Source $($pr.lastMergeSourceCommit.commitId) | Target $($pr.lastMergeTargetCommit.commitId)"
    if ($pr.status -eq 'completed') { $commits += " | Merge commit $($pr.lastMergeCommit.commitId)" }
    if ($pr.closedDate) { $commits += " | Closed $(Format-AdoDate $pr.closedDate)$(if ($pr.closedBy) { " by $($pr.closedBy.displayName)" })" }
    $commits
    "Reviewers: " + (($pr.reviewers | ForEach-Object { "$($_.displayName) = $(Get-Vote $_.vote)$(if ($_.isRequired) { ' (required)' })" }) -join '; ')

    $workItems = Invoke-Ado -TokenVariable $TokenVariable -Uri "$repo/pullRequests/$Id/workitems?api-version=7.1"
    if ($workItems.count -gt 0) { "Work items: " + (($workItems.value | ForEach-Object { $_.id }) -join ', ') }
    if ($pr.autoCompleteSetBy) { "Auto-complete set by $($pr.autoCompleteSetBy.displayName)" }

    if (-not $Brief -and $pr.description) {
        'Description:'
        $pr.description.Trim()
    }

    if ($Iterations) {
        $list = Invoke-Ado -TokenVariable $TokenVariable -Uri "$repo/pullRequests/$Id/iterations?api-version=7.1"
        'Iterations:'
        foreach ($iteration in $list.value) {
            $title = ($iteration.description -split "`n")[0]
            "  $($iteration.id) $($iteration.sourceRefCommit.commitId.Substring(0, 8)) base $($iteration.commonRefCommit.commitId.Substring(0, 8)) $(Format-AdoDate $iteration.createdDate) $title"
        }
    }

    if ($Threads -or $System) {
        $list = Invoke-Ado -TokenVariable $TokenVariable -Uri "$repo/pullRequests/$Id/threads?api-version=7.1"
        $review = @($list.value | Where-Object { $_.status -and -not $_.isDeleted })
        "Threads: $($review.Count) review, $(@($list.value | Where-Object { -not $_.status }).Count) system"
        foreach ($thread in $list.value) {
            if ($thread.isDeleted) { continue }
            $comments = @($thread.comments | Where-Object { -not $_.isDeleted })
            if ($thread.status -and $Threads) {
                $where = ''
                if ($thread.threadContext.filePath) {
                    $where = " $($thread.threadContext.filePath):$($thread.threadContext.rightFileStart.line)"
                    if ($thread.threadContext.rightFileEnd.line -and $thread.threadContext.rightFileEnd.line -ne $thread.threadContext.rightFileStart.line) {
                        $where += "-$($thread.threadContext.rightFileEnd.line)"
                    }
                }
                "--- $($thread.id) $($thread.status)$where"
                foreach ($comment in $comments) {
                    "  #$($comment.id) [$($comment.author.displayName) $(Format-AdoDate $comment.publishedDate)] $($comment.content)"
                }
            }
            elseif (-not $thread.status -and $System) {
                $comment = $comments | Select-Object -First 1
                "--- $($thread.id) system [$($comment.author.displayName) $(Format-AdoDate $comment.publishedDate)] $($comment.content)"
            }
        }
    }
}
catch {
    Write-Output "ERR: $($_.Exception.Message)"
    exit 1
}
