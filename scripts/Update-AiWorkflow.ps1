<#
.SYNOPSIS
Moves the ai-workflow submodule to the latest module commit in every project found under a folder.

.DESCRIPTION
Searches -Path for git repositories whose .gitmodules has a submodule with "ai-workflow" in its URL (normally <backlog>/.ai-workflow) and, in each one, does what README "Update or change the module" describes:

1. git submodule update --init --remote <submodule>, so sessions on this machine read the latest rules;
2. commits the new pin in the backlog ("Update ai-workflow"), only that path, on the current branch;
3. pushes that commit, so the team gets the same version.

With -LocalOnly it stops after step 1.

A project is skipped, with the reason in the summary, when its submodule has uncommitted changes or commits that are on no remote branch (someone is changing the rules from inside it), or when the backlog is on a detached HEAD or has not committed the submodule yet (setup in progress; the module is then refreshed locally only). The pin is committed but not pushed when the backlog branch has no upstream, is behind it, or already has other unpushed commits; push those by hand.

.PARAMETER Path
Folders to search, with all their subfolders. Default: the current folder. Folders such as node_modules, .git, bin and obj are not searched.

.PARAMETER Depth
How many folder levels below -Path to search. Default 10.

.PARAMETER LocalOnly
Only refresh the module on this machine; do not commit or push the pin.

.EXAMPLE
.\Update-AiWorkflow.ps1 -Path C:\Code
Updates, commits and pushes the module pin in every project under C:\Code.
.EXAMPLE
.\Update-AiWorkflow.ps1 -Path C:\Code -WhatIf
Lists the projects that would be updated, changing nothing.
.EXAMPLE
.\Update-AiWorkflow.ps1 -Path C:\Code -LocalOnly
Refreshes the module on this machine only.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string[]]$Path = @((Get-Location).Path),
    [ValidateRange(0, 50)]
    [int]$Depth = 10,
    [switch]$LocalOnly
)

$ErrorActionPreference = 'Stop'
$Commit = -not $LocalOnly
$Push = -not $LocalOnly

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git was not found on PATH."
}

# Invoke-Git <repo> <git arguments...>: returns stdout lines; throws on a non-zero exit code. stderr goes to the console.
# No param block on purpose: with one, PowerShell would bind git flags such as -r to a parameter by prefix.
function Invoke-Git {
    $repo = $args[0]; $gitArgs = @($args | Select-Object -Skip 1)
    $out = & git -C $repo @gitArgs
    if ($LASTEXITCODE -ne 0) { throw "git $($gitArgs -join ' ') failed in $repo (exit $LASTEXITCODE)." }
    return $out
}

# Same, but returns $null instead of throwing (for queries whose failure is an answer, e.g. no upstream).
function Get-GitValue {
    $repo = $args[0]; $gitArgs = @($args | Select-Object -Skip 1)
    $out = & git -C $repo @gitArgs 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return $out
}

function Get-Short([string]$Sha) {
    if ([string]::IsNullOrEmpty($Sha)) { return '-' }
    return $Sha.Substring(0, [Math]::Min(8, $Sha.Length))
}

# 1. Find the repositories and their ai-workflow submodules.
$skipFolders = @('.git', 'node_modules', 'bin', 'obj', '.vs', '.idea', 'packages', 'dist', 'build', 'target', '.venv', 'venv', '__pycache__')
$targets = @()
foreach ($root in $Path) {
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        Write-Warning "Not a folder, skipped: $root"
        continue
    }
    # Walk the tree by hand so heavy folders are pruned instead of enumerated.
    $repos = @()
    $queue = New-Object System.Collections.Queue
    $queue.Enqueue(@((Resolve-Path -LiteralPath $root).ProviderPath, 0))
    while ($queue.Count -gt 0) {
        $dir, $level = $queue.Dequeue()
        if (Test-Path -LiteralPath (Join-Path $dir '.gitmodules') -PathType Leaf) { $repos += $dir }
        if ($level -ge $Depth) { continue }
        $children = Get-ChildItem -LiteralPath $dir -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { $skipFolders -notcontains $_.Name -and -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) }
        foreach ($child in $children) { $queue.Enqueue(@($child.FullName, ($level + 1))) }
    }
    foreach ($repo in $repos) {
        $urls = Get-GitValue $repo config -f .gitmodules --get-regexp '^submodule\..*\.url$'
        foreach ($line in @($urls)) {
            if ($line -notmatch '^submodule\.(.+)\.url\s+(.+)$') { continue }
            $name = $Matches[1]; $url = $Matches[2]
            if ($url -notmatch 'ai-workflow(\.git)?/?$') { continue }
            $sub = Get-GitValue $repo config -f .gitmodules --get "submodule.$name.path"
            if (-not $sub) { continue }
            $targets += [pscustomobject]@{ Repo = $repo; Submodule = $sub; Name = $name; Url = $url }
        }
    }
}
$targets = @($targets | Sort-Object Repo, Submodule -Unique)

if ($targets.Count -eq 0) {
    Write-Host "No repository with an ai-workflow submodule found under: $($Path -join ', ') (depth $Depth)."
    return
}
Write-Host "Found $($targets.Count) project(s) with an ai-workflow submodule."

# 2. Update each one.
$results = foreach ($t in $targets) {
    $repo = $t.Repo; $sub = $t.Submodule
    $subDir = Join-Path $repo $sub
    $r = [pscustomobject]@{ Project = $repo; From = '-'; To = '-'; Result = '' }
    Write-Host ""
    Write-Host "== $subDir" -ForegroundColor Cyan
    try {
        $pinned = ((Get-GitValue $repo ls-tree HEAD -- $sub) -split '\s+')[2]
        $r.From = Get-Short $pinned
        $initialised = Test-Path -LiteralPath (Join-Path $subDir '.git')

        if ($initialised) {
            if (Invoke-Git $subDir status --porcelain) {
                $r.Result = 'skipped: the submodule has uncommitted changes'
                $r; continue
            }
            Invoke-Git $subDir fetch --quiet origin | Out-Null
            if (-not (Invoke-Git $subDir branch -r --contains HEAD)) {
                $r.Result = 'skipped: the submodule has commits on no remote branch; push them first'
                $r; continue
            }
        }

        if (-not $PSCmdlet.ShouldProcess($subDir, 'git submodule update --init --remote')) {
            # Same commit that "update --remote" would take: the configured branch, else the remote HEAD.
            $trackBranch = Get-GitValue $repo config -f .gitmodules --get "submodule.$($t.Name).branch"
            $ref = 'HEAD'
            if ($trackBranch) { $ref = "refs/heads/$trackBranch" }
            $latest = $null
            $remoteLine = @(Get-GitValue $repo ls-remote $t.Url $ref) | Select-Object -First 1
            if ($remoteLine) { $latest = ($remoteLine -split '\s+')[0] }
            $r.To = Get-Short $latest

            if (-not $latest) { $r.Result = 'would update (could not read the latest module commit)' }
            elseif (-not $pinned) { $r.Result = 'would refresh locally only: the submodule is not committed in this backlog yet' }
            elseif ($latest -eq $pinned) { $r.Result = 'up to date' }
            else { $r.Result = 'would update, commit and push' }
            if ($LocalOnly -and $r.Result -like 'would update, commit*') { $r.Result = 'would update locally' }
            $r; continue
        }
        Invoke-Git $repo submodule update --init --remote -- $sub | Out-Null
        $new = Invoke-Git $subDir rev-parse HEAD
        $r.To = Get-Short $new

        if ($new -eq $pinned) {
            $r.Result = 'up to date'
            $r; continue
        }
        if (-not $Commit) {
            $r.Result = 'updated locally (pin not committed)'
            $r; continue
        }

        if (-not $pinned) {
            $r.Result = 'updated locally; not committed: the submodule is not committed in this backlog yet (setup in progress)'
            $r; continue
        }

        $branch = Get-GitValue $repo symbolic-ref --quiet --short HEAD
        if (-not $branch) {
            $r.Result = 'updated locally; not committed: the backlog is on a detached HEAD'
            $r; continue
        }

        # Decide about pushing before committing, so earlier local commits are not pushed by accident.
        $pushBlocker = $null
        $upstream = Get-GitValue $repo rev-parse --abbrev-ref --symbolic-full-name '@{u}'
        if (-not $upstream) {
            $pushBlocker = "branch $branch has no upstream"
        }
        else {
            Invoke-Git $repo fetch --quiet | Out-Null
            $counts = (Invoke-Git $repo rev-list --left-right --count "$upstream...HEAD") -split '\s+'
            if ([int]$counts[0] -gt 0) { $pushBlocker = "$branch is $($counts[0]) commit(s) behind $upstream; pull and push by hand" }
            elseif ([int]$counts[1] -gt 0) { $pushBlocker = "$branch already has $($counts[1]) unpushed commit(s); push by hand" }
        }

        Invoke-Git $repo add -- $sub | Out-Null
        Invoke-Git $repo commit --quiet -m 'Update ai-workflow' -m "$(Get-Short $pinned) -> $(Get-Short $new)" -- $sub | Out-Null

        if ($pushBlocker) {
            $r.Result = "committed on $branch; not pushed: $pushBlocker"
        }
        else {
            Invoke-Git $repo push --quiet | Out-Null
            $r.Result = "committed and pushed on $branch"
        }
    }
    catch {
        $r.Result = "failed: $($_.Exception.Message)"
    }
    $r
}

Write-Host ""
Write-Host "Summary:"
foreach ($r in $results) {
    $color = 'Green'
    if ($r.Result -like 'failed*') { $color = 'Red' }
    elseif ($r.Result -like 'skipped*' -or $r.Result -like '*not pushed*' -or $r.Result -like '*not committed*') { $color = 'Yellow' }
    Write-Host ("  {0}  [{1} -> {2}]  {3}" -f $r.Project, $r.From, $r.To, $r.Result) -ForegroundColor $color
}
if (@($results | Where-Object { $_.Result -like 'failed*' }).Count -gt 0) { exit 1 }
