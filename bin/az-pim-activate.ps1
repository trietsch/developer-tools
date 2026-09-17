<#
.SYNOPSIS
    Activates eligible Azure AD PIM group assignments via Microsoft Graph.

.DESCRIPTION
    Workaround for group-based PIM activation, since the Azure CLI's access token
    (az rest) lacks the Microsoft Graph scopes needed for
    identityGovernance/privilegedAccess/group endpoints, and Microsoft has not
    granted first-party consent between the Azure CLI and MS Graph for those
    scopes (see https://github.com/Azure/azure-cli/issues/26471). PowerShell's
    Microsoft.Graph module is a first-party client that does have this consent,
    so it is used here instead.

.NOTES
    Dependencies:
    - PowerShell 7+ (pwsh)
    - Microsoft.Graph.Authentication module (install with:
      Install-Module Microsoft.Graph.Authentication -Scope CurrentUser)
    - Delegated Microsoft Graph permission: PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup
      (consented interactively on first Connect-MgGraph run)
#>

# Load required assemblies
Add-Type -AssemblyName System.Web

$groupsToActivate = @(
    "RBAC-Team-Mc-Apps-Dev-Contributor"
)

$reason = "Migration work"

$duration = "PT1H"

$tenant = "70102b47-b775-4eda-b469-f5ae205343ec"

# Required Graph API permissions: PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup

function Connect-ToMicrosoftGraph {
    param(
        [string]$TenantId
    )

    try {
        Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
        Connect-MgGraph -TenantId $TenantId -Scopes "PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup"
        Write-Host "Successfully connected to Microsoft Graph" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
        return $false
    }
}

function Get-GroupByDisplayName {
    param(
        [string]$DisplayName
    )

    try {
        $encodedDisplayName = [System.Web.HttpUtility]::UrlEncode("displayName eq '$DisplayName'")
        $uri = "https://graph.microsoft.com/v1.0/groups?`$filter=$encodedDisplayName"

        $response = Invoke-MgGraphRequest -Uri $uri -Method GET
        $groups = $response.value

        if ($groups -and $groups.Count -gt 0) {
            $group = $groups[0]
            Write-Host "Found group: $DisplayName (ID: $($group.Id))" -ForegroundColor Green
            return $group
        } else {
            Write-Warning "Group not found: $DisplayName"
            return $null
        }
    }
    catch {
        Write-Error "Failed to get group '$DisplayName': $($_.Exception.Message)"
        return $null
    }
}

function Get-CurrentUserId {
    try {
        $context = Get-MgContext
        if ($context -and $context.Account) {
            # Get the user ID using Graph API directly
            $me = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/me" -Method GET
            return $me.Id
        } else {
            Write-Error "No active Graph context found"
            return $null
        }
    }
    catch {
        Write-Error "Failed to get current user ID: $($_.Exception.Message)"
        return $null
    }
}

function Get-EligibleGroupAssignments {
    param(
        [string]$PrincipalId,
        [string]$GroupId
    )

    try {
        $filter = "principalId eq '$PrincipalId' and groupId eq '$GroupId'"
        $encodedFilter = [System.Web.HttpUtility]::UrlEncode($filter)
        $uri = "https://graph.microsoft.com/v1.0/identityGovernance/privilegedAccess/group/eligibilitySchedules?`$filter=$encodedFilter"

        Write-Host "Querying eligible assignments with filter: $filter" -ForegroundColor Gray

        $response = Invoke-MgGraphRequest -Uri $uri -Method GET
        return $response.value
    }
    catch {
        Write-Error "Failed to get eligible assignments: $($_.Exception.Message)"

        # Try alternative approach - get all eligible assignments for the user and filter locally
        try {
            Write-Host "Trying alternative approach to get eligible assignments..." -ForegroundColor Yellow
            $userFilter = "principalId eq '$PrincipalId'"
            $encodedUserFilter = [System.Web.HttpUtility]::UrlEncode($userFilter)
            $uri = "https://graph.microsoft.com/v1.0/identityGovernance/privilegedAccess/group/eligibilitySchedules?`$filter=$encodedUserFilter"

            $response = Invoke-MgGraphRequest -Uri $uri -Method GET
            $allAssignments = $response.value

            # Filter locally for the specific group
            $groupAssignments = $allAssignments | Where-Object { $_.groupId -eq $GroupId }
            return $groupAssignments
        }
        catch {
            Write-Error "Alternative approach also failed: $($_.Exception.Message)"
            return $null
        }
    }
}

function Activate-PIMGroupAssignment {
    param(
        [string]$GroupId,
        [string]$PrincipalId,
        [string]$AccessId = "member",
        [string]$Duration,
        [string]$Justification
    )

    try {
        Write-Host "Activating PIM assignment for group ID: $GroupId" -ForegroundColor Yellow

        # Create the request body
        $requestBody = @{
            accessId = $AccessId
            principalId = $PrincipalId
            groupId = $GroupId
            action = "selfActivate"
            scheduleInfo = @{
                startDateTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                expiration = @{
                    type = "afterDuration"
                    duration = $Duration
                }
            }
            justification = $Justification
        }

        $uri = "https://graph.microsoft.com/v1.0/identityGovernance/privilegedAccess/group/assignmentScheduleRequests"

        # Make the API call
        $result = Invoke-MgGraphRequest -Uri $uri -Method POST -Body ($requestBody | ConvertTo-Json -Depth 10) -ContentType "application/json"

        Write-Host "Successfully submitted activation request" -ForegroundColor Green
        Write-Host "Request ID: $($result.id)" -ForegroundColor Cyan
        Write-Host "Status: $($result.status)" -ForegroundColor Cyan

        return $result
    }
    catch {
        Write-Error "Failed to activate PIM assignment: $($_.Exception.Message)"
        if ($_.Exception.Response) {
            $errorContent = $_.Exception.Response.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($errorContent) {
                Write-Host "Error details: $($errorContent.error.message)" -ForegroundColor Red
            }
        }
        return $null
    }
}

# Main script execution
Write-Host "Starting PIM Group Assignment Activation Script" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Connect to Microsoft Graph
if (-not (Connect-ToMicrosoftGraph -TenantId $tenant)) {
    Write-Error "Failed to connect to Microsoft Graph. Exiting."
    exit 1
}

# Get current user ID
$currentUserId = Get-CurrentUserId
if (-not $currentUserId) {
    Write-Error "Failed to get current user ID. Exiting."
    exit 1
}

Write-Host "Current User ID: $currentUserId" -ForegroundColor Cyan

# Process each group
foreach ($groupName in $groupsToActivate) {
    Write-Host "`nProcessing group: $groupName" -ForegroundColor Yellow

    # Get the group
    $group = Get-GroupByDisplayName -DisplayName $groupName
    if (-not $group) {
        Write-Warning "Skipping group: $groupName (not found)"
        continue
    }

    # Check if user has eligible assignments for this group
    Write-Host "Checking for eligible assignments..." -ForegroundColor Yellow
    $eligibleAssignments = Get-EligibleGroupAssignments -PrincipalId $currentUserId -GroupId $group.Id

    if (-not $eligibleAssignments -or $eligibleAssignments.Count -eq 0) {
        Write-Warning "No eligible assignments found for group: $groupName"
        continue
    }

    # Activate each eligible assignment
    foreach ($assignment in $eligibleAssignments) {
        Write-Host "Found eligible assignment - Access Type: $($assignment.accessId)" -ForegroundColor Green

        $activationResult = Activate-PIMGroupAssignment -GroupId $group.Id -PrincipalId $currentUserId -AccessId $assignment.accessId -Duration $duration -Justification $reason

        if ($activationResult) {
            Write-Host "✅ Successfully activated $($assignment.accessId) assignment for group: $groupName" -ForegroundColor Green
        } else {
            Write-Host "❌ Failed to activate $($assignment.accessId) assignment for group: $groupName" -ForegroundColor Red
        }
    }
}

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "PIM Group Assignment Activation Script Completed" -ForegroundColor Cyan
