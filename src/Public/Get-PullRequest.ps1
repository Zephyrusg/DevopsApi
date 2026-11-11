function Get-PullRequest {
    <#
    .SYNOPSIS
        Retrieves pull-request details, commits and changed files.
    .DESCRIPTION
        Reads pull-request metadata with the Azure DevOps CLI and retrieves its latest
        iteration's file changes through the Git API. The result is structured for review
        or summarization; it does not generate a summary itself.
    .PARAMETER Id
        The pull request ID.
    .PARAMETER Org
        Azure DevOps organisation URL. Defaults to the active config.
    .PARAMETER Project
        Azure DevOps project name. Defaults to the active config.
    .EXAMPLE
        Get-PullRequest -Id 12 | Format-List
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Id,

        [string]$Org = $AzureDevOpsConfig.Org,
        [string]$Project = $AzureDevOpsConfig.Project
    )

    if (-not $Org -or -not $Project) {
        Write-Error "No Azure DevOps organisation/project was provided and no active config is loaded."
        return
    }

    $pullRequest = Invoke-AzJson -Action "Getting pull request $Id" -Command {
        az repos pr show --id $Id --organization $Org -o json
    }

    if (-not $pullRequest) {
        Write-Error "Pull request $Id not found."
        return
    }

    $repositoryId = [string]$pullRequest.repository.id
    if (-not $repositoryId) {
        throw "Pull request $Id did not return a repository ID."
    }

    $projectName = if ($pullRequest.repository.project.name) { [string]$pullRequest.repository.project.name } else { $Project }
    $iterations = Invoke-AzJson -Action "Getting iterations for pull request $Id" -Command {
        az devops invoke --area git --resource pullRequestIterations `
            --route-parameters "project=$projectName" "repositoryId=$repositoryId" "pullRequestId=$Id" `
            --query-parameters includeCommits=true `
            --api-version 7.1 --organization $Org -o json
    }

    $iterationList = @($iterations.value)
    if (-not $iterationList.Count) {
        throw "Pull request $Id has no iterations to inspect."
    }

    $latestIteration = $iterationList | Sort-Object id | Select-Object -Last 1
    $iterationId = [int]$latestIteration.id
    $iterationCommits = @($latestIteration.commits | Where-Object { $_.commitId })
    if (-not $iterationCommits.Count) {
        throw "Pull request $Id has no commit IDs in its latest iteration."
    }

    $latestCommitId = [string]$iterationCommits[-1].commitId
    $repoRootOutput = & git -C $PSScriptRoot rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $repoRootOutput) {
        throw "Could not locate the local Git repository for pull request $Id."
    }
    $repoRoot = ([string]($repoRootOutput | Out-String)).Trim()

    $null = & git -C $repoRoot cat-file -e "$latestCommitId^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Commit '$latestCommitId' for pull request $Id was not found in the local repository '$repoRoot'. Fetch the PR branch or commit, then retry."
    }

    $changes = Invoke-AzJson -Action "Getting changed files for pull request $Id" -Command {
        az devops invoke --area git --resource pullRequestIterationChanges `
            --route-parameters "project=$projectName" "repositoryId=$repositoryId" "pullRequestId=$Id" "iterationId=$iterationId" `
            --api-version 7.1 --organization $Org -o json
    }

    $changeEntries = if ($changes.changeEntries) { @($changes.changeEntries) } elseif ($changes.value) { @($changes.value) } else { @() }
    $files = @($changeEntries | ForEach-Object {
            $path = [string]$_.item.path
            if (-not $path) {
                throw "A changed file in pull request $Id has no path."
            }

            $relativePath = $path.TrimStart('/')
            if ($relativePath -match '(^|/)\.\.(/|$)') {
                throw "Changed file path '$path' in pull request $Id is not a repository-relative path."
            }

            $contentCommit = $latestCommitId
            $contentPath = $relativePath
            if ([string]$_.changeType -eq 'delete') {
                $contentCommit = "$latestCommitId^"
                if ($_.originalPath) { $contentPath = ([string]$_.originalPath).TrimStart('/') }
            }

            $objectSpec = "$contentCommit`:$contentPath"
            $null = & git -C $repoRoot cat-file -e $objectSpec 2>$null
            if ($LASTEXITCODE -ne 0) {
                throw "Changed file '$path' for pull request $Id was not found in local commit '$contentCommit'. Fetch the PR branch or commit, then retry."
            }

            $contentLines = & git -C $repoRoot show $objectSpec 2>$null
            if ($LASTEXITCODE -ne 0) {
                throw "Could not read changed file '$path' for pull request $Id from local commit '$contentCommit'."
            }

            [PSCustomObject]@{
                ChangeType   = $_.changeType
                Path         = $_.item.path
                OriginalPath = $_.originalPath
                Content      = [string]::Join([Environment]::NewLine, [string[]]@($contentLines))
            }
        })

    $commits = @($latestIteration.commits | ForEach-Object {
            [PSCustomObject]@{
                CommitId = $_.commitId
                Comment  = $_.comment
                Author   = $_.author.name
                Date     = $_.author.date
            }
        })

    [PSCustomObject]@{
        Id           = $pullRequest.pullRequestId
        Title        = $pullRequest.title
        Description  = $pullRequest.description
        Status       = $pullRequest.status
        IsDraft      = $pullRequest.isDraft
        Repository   = $pullRequest.repository.name
        Project      = $projectName
        SourceBranch = $pullRequest.sourceRefName -replace '^refs/heads/', ''
        TargetBranch = $pullRequest.targetRefName -replace '^refs/heads/', ''
        CreatedBy    = $pullRequest.createdBy.displayName
        CreatedDate  = $pullRequest.creationDate
        Commits      = $commits
        Changes      = $files
    }
}