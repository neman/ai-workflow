<#
.SYNOPSIS
Posts a pull request comment from a UTF-8 Markdown file: a reply in an existing thread, a new thread on a file line, or a new general thread. Reads the thread back and fails when the stored text differs from the file.

.DESCRIPTION
A new thread on a file is anchored on the changes of one iteration against the common base: the file's changeTrackingId and both comparing iterations set to that iteration, so the line stays on the right spot when later iterations arrive. Line numbers are those of the file at the iteration's source commit.

.PARAMETER BodyFile
The comment text, UTF-8. Writing it to a file keeps quotation marks and non-ASCII letters intact.

.PARAMETER Iteration
The iteration the line numbers come from; the latest when left out. The script prints the iteration and its source commit it used.

.PARAMETER Status
The thread status after posting: for a new thread the default is active; for a reply the status changes only when given.

.EXAMPLE
.\Add-AdoPullRequestComment.ps1 -Organization contoso -Project "Web shop" -Repository shop-api -Id 321 -BodyFile finding-1.md -FilePath src/Orders/Checkout.cs -Line 120 -EndLine 124
.EXAMPLE
.\Add-AdoPullRequestComment.ps1 -Organization contoso -Project "Web shop" -Repository shop-api -Id 321 -BodyFile reply.md -ThreadId 45678 -Status active
#>
#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)][string]$Organization,
    [Parameter(Mandatory = $true)][string]$Project,
    [Parameter(Mandatory = $true)][string]$Repository,
    [Parameter(Mandatory = $true)][int]$Id,
    [Parameter(Mandatory = $true)][string]$BodyFile,
    [int]$ThreadId,
    [string]$FilePath,
    [int]$Line,
    [int]$EndLine,
    [int]$Iteration,
    [ValidateSet('active', 'fixed', 'wontFix', 'closed', 'byDesign', 'pending')][string]$Status,
    [string]$TokenVariable = 'PERSONAL_ACCESS_TOKEN'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AdoRest.psm1') -Force
$prUri = "$(Get-AdoApiBase -Organization $Organization -Project $Project)/git/repositories/$([Uri]::EscapeDataString($Repository))/pullRequests/$Id"

function Invoke-Pr([string]$Path, [string]$Method = 'Get', [object]$Body) {
    $separator = if ($Path.Contains('?')) { '&' } else { '?' }
    Invoke-Ado -TokenVariable $TokenVariable -Method $Method -Body $Body -Uri "$prUri$Path$($separator)api-version=7.1"
}

try {
    $content = (Get-Content -LiteralPath $BodyFile -Raw -Encoding utf8).Replace("`r`n", "`n").TrimEnd()
    if (-not $content) { throw "$BodyFile is empty." }
    if ($ThreadId -and $FilePath) { throw 'Pass either -ThreadId (a reply) or -FilePath (a new thread on a file), not both.' }
    if ($FilePath -and -not $Line) { throw '-FilePath needs -Line.' }

    if ($ThreadId) {
        $action = "reply in thread $ThreadId of PR $Id"
        $body = @{ parentCommentId = 1; content = $content; commentType = 1 }
        if ($PSCmdlet.ShouldProcess($action)) {
            $comment = Invoke-Pr -Path "/threads/$ThreadId/comments" -Method Post -Body $body
            if ($Status) { Invoke-Pr -Path "/threads/$ThreadId" -Method Patch -Body @{ status = $Status } | Out-Null }
            $commentId = $comment.id
            $threadIdPosted = $ThreadId
        }
        else {
            ConvertTo-Json -InputObject $body -Depth 10
        }
    }
    else {
        $thread = @{
            comments = @(@{ parentCommentId = 0; content = $content; commentType = 1 })
            status = if ($Status) { $Status } else { 'active' }
        }
        $action = "new thread on PR $Id"
        if ($FilePath) {
            $path = '/' + $FilePath.TrimStart('/').Replace('\', '/')
            $last = if ($EndLine) { $EndLine } else { $Line }
            $iterations = (Invoke-Pr -Path '/iterations').value
            $used = if ($Iteration) { $iterations | Where-Object { $_.id -eq $Iteration } } else { $iterations | Select-Object -Last 1 }
            if (-not $used) { throw "PR $Id has no iteration $Iteration." }
            $changes = Invoke-Pr -Path "/iterations/$($used.id)/changes?`$top=2000"
            $change = $changes.changeEntries | Where-Object { $_.item.path -eq $path } | Select-Object -First 1
            if (-not $change) { throw "$path is not among the changes of iteration $($used.id); check the path (case matters) or the iteration." }

            $thread.threadContext = @{
                filePath = $path
                rightFileStart = @{ line = $Line; offset = 1 }
                rightFileEnd = @{ line = $last; offset = 1 }
            }
            $thread.pullRequestThreadContext = @{
                changeTrackingId = $change.changeTrackingId
                iterationContext = @{ firstComparingIteration = $used.id; secondComparingIteration = $used.id }
            }
            $action = "new thread on $($path):$Line-$last of PR $Id, iteration $($used.id) ($($used.sourceRefCommit.commitId.Substring(0, 8)))"
        }
        if ($PSCmdlet.ShouldProcess($action)) {
            $posted = Invoke-Pr -Path '/threads' -Method Post -Body $thread
            $threadIdPosted = $posted.id
            $commentId = $posted.comments[0].id
        }
        else {
            ConvertTo-Json -InputObject $thread -Depth 10
        }
    }

    if ($threadIdPosted) {
        $check = Invoke-Pr -Path "/threads/$threadIdPosted"
        $stored = $check.comments | Where-Object { $_.id -eq $commentId }
        if ("$($stored.content)".Replace("`r`n", "`n").TrimEnd() -ne $content) {
            throw "Thread $threadIdPosted comment $commentId was stored with $($stored.content.Length) characters instead of $($content.Length); read it on the PR and fix it."
        }
        "Posted: $action -> thread $threadIdPosted, comment $commentId, status $($check.status), by $($stored.author.displayName), $($content.Length) characters."
    }
}
catch {
    Write-Output "ERR: $($_.Exception.Message)"
    exit 1
}
