#region Global
$username = ""
$PAT = ""
$org = "myorg"
$proj = "adoProject"
$api = "https://vsrm.dev.azure.com/$org/$proj/_apis/"
#endregion

function New-AuthHeader {
Param
(
    [Parameter(Mandatory=$true)] [string] $username,
    [Parameter(Mandatory=$true)] [string] $pat
)

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username,$pat)))
@{Authorizatoin=("Basic {0}" -f $base64AuthInfo)}

}

function Get-ReleaseDefinitionByID{
Param
(
    [Parameter(Mandatory=$true)] [string] $definitionID
)
$endpoint = "release/definitions/$($definitionID)?api-version=6.1-preview.4"
$defURL = $api + $endpoint

$DefinitionResponse = Invoke-WebRequest -Method Get -Uri $defURL -Headers $auth -ContentType "application/json" | ConvertFrom-Json

Write-Host $DefinitionResponse

}

function Main {
$auth = New-AuthHeader -username $username -pat $PAT
$defID = 22
Get-ReleaseDefinitionByID -definitionID $defID

}