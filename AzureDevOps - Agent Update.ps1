$filedate = Get-Date -Format yyyyMMdd
$UserName = "myusername"
$PAT = "myPat"
$org = "organization"
$proj = "project"
$BaseURI = "https://dev.azure.com/$org/$proj/_apis/"

function New-AuthHeader {
    Param(
        [Parameter(Mandatory=$true)] [string] $username,
        [Parameter(Mandatory=$true)] [string] $accesstoken
    )
    $base64Authorization = [System.Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username, $accesstoken)))
    @{Authorization=("Basic {0}" -f $base64Authorization)}
}

function Get-ADOBuildIDs {
    $auth = New-AuthHeader -username $UserName -accesstoken $PAT
    $BuildDefinitionEndpoint = "build/definitions?api-version=6.1-preview.7"
    $BuildDefListURI = $BaseURI + $BuildDefinitionEndpoint

    $BuildDefinitionListRes = Invoke-WebRequest -Method Get -Uri $BuildDefListURI -Headers $auth -ContentType "application/json" -UseBasicParsing | ConvertFrom-Json
    return $BuildDefinitionListRes.value.id
}

function Check-ADOBuildAgent{
    Param (        
        [Parameter(Mandatory=$true)] [string] $definitionID
    )

    $auth = New-AuthHeader -username $UserName -accesstoken $PAT
    $BuildDefinitionDetailEndpoint = "build/definitions/$($definitionID)?api-version=6.1-preview.7"
    $BuildDefinitionDetailURI = $BaseURI + $BuildDefinitionDetailEndpoint

    $BuildDefinitionDetailRes = Invoke-WebRequest -Method Get -Uri $BuildDefinitionDetailURI -UseBasicParsing -Headers $auth -ContentType "application/json" -UseBasicParsing | ConvertFrom-Json

    foreach ($definition in $BuildDefinitionDetailRes){
        $pool = $definition.queue.pool.name
        $agent = $definition.process.target.agenctSpecification.identifier

        if(($agent -like $badAgent) -or ($pool -like $badPool)){
            Write-Host "Found $($definition.name) - $($definition.id)"
            return $definition.id
        }
    }
}

function Update-ADOBuildAgent {
    Param (
        [Parameter(Mandatory=$true)] [string] $definitionId,
        [Parameter(Mandatory=$true)] [string] $buildAgent,
        [Parameter(Mandatory=$true)] [string] $agentPool,
        [Parameter(Mandatory=$true)] [int]    $queueId,
        [Parameter(Mandatory=$true)] [int]    $poolQueueId,
        [Parameter(Mandatory=$false)] [string] $badAgent,
        [Parameter(Mandatory=$false)] [string] $badPool
    )
    $auth = New-AuthHeader -username $UserName -accesstoken $PAT
    $BuildDefinitionEndPoint = "build/definitions/$($definitionID)?api-version=6.1-preview.7"
    $BuildDefinitionURI = $BaseURI + $BuildDefinitionEndPoint
    $BuildDefinition = Invoke-RestMethod -Uri $BuildDefinitionURI -Method Get -Headers $auth

    Write-Host "Pipeline = $($BuildDefinition | ConverTo-Json -depth 100)"
    #If build agents of a specific identifier within the correct pool need to be changed (like updating within Azure Pipelines)
    if ($BuildDefinition.process.target.agentSpecification.identifier -eq $badAgent) {
        Write-Host "Updating build agent for $($BuildDefinition.name)"
        $BuildDefinition.process.target.agentSpecification.identifier = $buildAgent
        $json = @($BuildDefinition) | ConvertTo-Json -Depth 99
        $updateDefinition = Invoke-RestMethod -Uri $BuildDefinitionURI -Method Put -Body $json -Headers $auth -ContentType "application/json"
        Write-Host "the build agent has been updated for: $($updateDefinition.name)"
    }

    #If the pipeline pool needs to be changed, a double update should occur. Like when moving from Hosted VS2017 to Azure Pipelines w/ windows-latest. 
    if($BuildDefinition.queue.name -eq $badPool){
        Write-host "Updating $($BuildDefinition.name) Pool: $($agentPool)"
        $BuildDefinition.queue.name = $agentPool
        $BuildDefinition.queue.id = $queueId
        $BuildDefinition.queue.pool.name = $agentPool
        $BuildDefinition.queue.pool.id = $poolQueueId
        $json = @($BuildDefinition) | ConvertTo-Json -Depth 99
        $updateDefinition = Invoke-RestMethod -Uri $BuildDefinitionURI -Method Put -Body $json -Headers $auth -ContentType "application/json"
        
        #Wait to run the second request:
        Write-Host "Pool updated...beginning Agent Update"
        Start-Sleep -Seconds 3
        Write-Host "Updating agent for $($BuildDefinition.name)"
        #Make the second request to update the agent
        $updatedBuild = Invoke-RestMethod -Uri $BuildDefinitionURI -Headers $auth -Method Get
        $newAgentSpec = [PSCustomObject]@{
            identifier = $buildAgent
        }
        $updatedBuild.process.target.agentSpecification = $newAgentSpec
        $updatejson = @($updatedBuild) | ConvertTo-Json -Depth 99
        $secondBuildDef = Invoke-RestMethod -Uri $BuildDefinitionURI -Method Put -Body $updatejson -ContentType "application/json" -Headers $auth
        Write-Host "The build agent has been updated for: $($secondBuildDef.name)"      
    }            
}
