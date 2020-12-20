#Update your cloud-init before running this
param(
$name = "jitsiauto"
,$resourceGroup = "" # This is used if you want to add this to an existing resource group. if null or empty, the resource group will be set to $name.
,$location = "" # To see possible locations: az account list-locations -o table
,$adminUserName = "admin" 
,$vmSize = 'Standard_B1s'
)
#A1
Write-Host "Logging you in, follow the prompts"
az login | OUT-NULL

if([string]::IsnUllOrEmpty($resourceGroup)){
    $resourceGroup = $name
}

if([string]::IsnUllOrEmpty($appServicePlan)){
    $appServicePlan = $name
}

if([string]::IsnUllOrEmpty($appServicePlan)){
    $appServicePlan = $name
}


$getSubscription = $true
while($getSubscription){
    try{
    Write-Host "We are using the following azure subscription, is this correct?:"
    az account show

        
    $response = Read-Host "(Y)es/No"
    if($response -in @("Yes","y")){
        $getSubscription = $false
        break
    }
        Write-Host "All accounts:"
        $AllAccounts = az account list | ConvertFrom-Json

        $AllAccounts | Select-Object id,name,cloudName, homeTenantID, state | Format-Table
            
        $subscription = Read-Host "What subscription should we use? Enter the ID or name"

        az account set --subscription $subscription
    }
    catch{
        Write-Error "There was an error setting the subscription" -ErrorAction Stop
    }
}
$groupExists = az group exists -n $resourceGroup
if ($groupExists -ne "true"){
    Write-Log "creating resource group: $resourceGroup at $location"
    az group create --name $resourceGroup --location $location
}

#A3
try{
$result = az vm create `
--resource-group $resourceGroup `
--name $name `
--image UbuntuLTS `
--admin-username $adminUserName `
--generate-ssh-keys `
--custom-data cloud-init `
--size $vmSize
}
catch{
    Write-Error "There was an error setting up your VM"
}
$result

#az vm resize -g $resourceGroup -n $name 
az vm open-port --port 80 --resource-group $resourceGroup --name $name --priority 310
az vm open-port --port 443 --resource-group $resourceGroup --name $name --priority 311
az vm open-port --port 22 --resource-group $resourceGroup --name $name --priority 312
az vm open-port --port 4443 --resource-group $resourceGroup --name $name --priority 313 #RTC over tcp
az vm open-port --port 10000 --resource-group $resourceGroup --name $name --priority 314 #RTC over udp