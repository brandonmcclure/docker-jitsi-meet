#Requires -Version 7.0
# https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-docker
#
# Make sure to open ports in your firewall:
# 80/tcp for Web UI HTTP (really just to redirect, after uncommenting ENABLE_HTTP_REDIRECT=1 in .env)
# 443/tcp for Web UI HTTPS
# 4443/tcp for RTP media over TCP
# 10000/udp for RTP media over UDP

# If you have issues getting the LetsEncrypt cert on the web site/are still getting the default/wildcard self signed cert that is default then prune: docker system prune -a

$HTTPPort = "80"
$HTTPSPort = "443"
$RESTART_POLICY = 'unless-stopped'
$DOCKER_HOST_ADDRESS = ''
$TIME_ZONE = 'UTC'
$LetsEncryptEnable = $false
$LetsEncryptEmail = ''
$LetsEncryptDomain = ''
$CONFIG_PATH = './jitsi-meet-cfg'
$ENABLE_GUESTS=$false
$AUTH_TYPE = "internal"
function generatePassword() {
    
    function Get-RandomCharacters($length, $characters) { 
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length } 
    $private:ofs="" 
    return [String]$characters[$random]
}
    function Scramble-String([string]$inputString){     
        $characterArray = $inputString.ToCharArray()   
        $scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length     
        $outputString = -join $scrambledStringArray
        return $outputString 
    }

    $password = Get-RandomCharacters -length 16 -characters 'abcdefghiklmnoprstuvwxyzABCDEFGHKLMNOPRSTUVWXYZ1234567890!-_'
    
   Write-Output (Scramble-String($password) | ConvertTo-SecureString -AsPlainText -Force)
}
$ACCESS_CONTROL_LIST = @(
    @{Username ='admin';
        Password = (ConvertTo-SecureString 'staticPassword' -AsPlainText)},
    @{Username ='user2';
        Password =$(generatePassword)},
    @{Username ='user3';
        Password =$(generatePassword)}
)


[Environment]::SetEnvironmentVariable("CONFIG_PATH", "$CONFIG_PATH", "user")

if($IsLinux){
    Write-Host "Is running on linux, setting DOCKER_HOST_ADDRESS"
    $DOCKER_HOST_ADDRESS = $(ip a | awk '/inet / { print $2 }' | sed -n 2p | cut -d "/" -f1)
}

# Create Secure Passwords in the config


$JICOFO_COMPONENT_SECRET=$(generatePassword)
$JICOFO_AUTH_PASSWORD=$(generatePassword)
$JVB_AUTH_PASSWORD=$(generatePassword)
$JIGASI_XMPP_PASSWORD=$(generatePassword)
$JIBRI_RECORDER_PASSWORD=$(generatePassword)
$JIBRI_XMPP_PASSWORD=$(generatePassword)

$filePath = "$($PSScriptRoot)\env.example"
$tempFilePath = "$env:TEMP\$($filePath | Split-Path -Leaf)"

function replaceWith{
    
  [cmdletbinding()]
param(
    [parameter(ValueFromPipeline)]
    $string,
$find = 'foo',
$replace = 'bar'
)
PROCESS {
    $outVal = $string -replace $find, $replace
    Write-Output $outVal
}
}

$content = Get-Content -Path $filePath
$content | replaceWith -find "JICOFO_COMPONENT_SECRET=" -replace "JICOFO_COMPONENT_SECRET=$(ConvertFrom-SecureString $JICOFO_COMPONENT_SECRET -AsPlainText  )"`
| replaceWith -find "JICOFO_AUTH_PASSWORD=" -replace "JICOFO_AUTH_PASSWORD=$(ConvertFrom-SecureString $JICOFO_AUTH_PASSWORD -AsPlainText  )"`
| replaceWith -find "JVB_AUTH_PASSWORD=" -replace "JVB_AUTH_PASSWORD=$(ConvertFrom-SecureString $JVB_AUTH_PASSWORD -AsPlainText  )"`
| replaceWith -find "JIGASI_XMPP_PASSWORD=" -replace "JIGASI_XMPP_PASSWORD=$(ConvertFrom-SecureString $JIGASI_XMPP_PASSWORD -AsPlainText  )"`
| replaceWith -find "JIBRI_RECORDER_PASSWORD=" -replace "JIBRI_RECORDER_PASSWORD=$(ConvertFrom-SecureString $JIBRI_RECORDER_PASSWORD -AsPlainText  )"`
| replaceWith -find "JIBRI_XMPP_PASSWORD=" -replace "JIBRI_XMPP_PASSWORD=$(ConvertFrom-SecureString $JIBRI_XMPP_PASSWORD -AsPlainText  )"`
| foreach-object{if (-not [string]::IsNullOrEmpty($HTTPPort)){$_ | replaceWith -find "HTTP_PORT=8000" -replace "HTTP_PORT=$HTTPPort"}else{$_}}`
| foreach-object{if (-not [string]::IsNullOrEmpty($HTTPSPort)){$_ | replaceWith -find "HTTPS_PORT=8443" -replace "HTTPS_PORT=$HTTPSPort"}else{$_}}`
| foreach-object{if (-not [string]::IsNullOrEmpty($RESTART_POLICY)){$_ | replaceWith -find "RESTART_POLICY=unless-stopped" -replace "RESTART_POLICY=$RESTART_POLICY"}else{$_}}`
| foreach-object{if (-not [string]::IsNullOrEmpty($CONFIG_PATH)){$_ | replaceWith -find "CONFIG=~/.jitsi-meet-cfg" -replace "CONFIG=$CONFIG_PATH"}else{$_}}`
| foreach-object{if ($LetsEncryptEnable){$_ | replaceWith -find "#ENABLE_LETSENCRYPT=1" -replace "ENABLE_LETSENCRYPT=1"}else{$_}}`
| foreach-object{if ($LetsEncryptEnable){$_ | replaceWith -find "#LETSENCRYPT_DOMAIN=meet.example.com" -replace "LETSENCRYPT_DOMAIN=$LetsEncryptDomain"}else{$_}}`
| foreach-object{if ($LetsEncryptEnable){$_ | replaceWith -find "#LETSENCRYPT_EMAIL=alice@atlanta.net" -replace "LETSENCRYPT_EMAIL=$LetsEncryptEmail"}else{$_}}`
| foreach-object{if ($LetsEncryptEnable){$_ | replaceWith -find "#PUBLIC_URL=https://meet.example.com" -replace "PUBLIC_URL=https://$LetsEncryptDomain"}else{$_}}`
| foreach-object{if ($true){$_ | replaceWith -find "#ENABLE_HTTP_REDIRECT=1" -replace "ENABLE_HTTP_REDIRECT=1"}else{$_}}`
| foreach-object{if (-not [string]::IsNullOrEmpty($DOCKER_HOST_ADDRESS)){$_ | replaceWith -find "#DOCKER_HOST_ADDRESS=192.168.1.1" -replace "DOCKER_HOST_ADDRESS=$DOCKER_HOST_ADDRESS"}else{$_}}`
| foreach-object{if (-not [string]::IsNullOrEmpty($TIME_ZONE)){$_ | replaceWith -find "TZ=UTC" -replace "TZ=$TIME_ZONE"}else{$_}}`
| foreach-object{if (-not $ENABLE_GUESTS){$_ | replaceWith -find "#ENABLE_GUESTS=1" -replace "ENABLE_GUESTS=0"}else{$_}}`
| foreach-object{if (-not [string]::IsNullOrEmpty($AUTH_TYPE)){$_ | replaceWith -find "#AUTH_TYPE=internal" -replace "AUTH_TYPE=$AUTH_TYPE"}else{$_}}`
| foreach-object{if (-not [string]::IsNullOrEmpty($AUTH_TYPE)){$_ | replaceWith -find "#ENABLE_AUTH=1" -replace "ENABLE_AUTH=1"}else{$_}}`
| Add-Content -Path $tempFilePath


Remove-Item -Path "$(Split-Path $filePath -Parent)\.env" -ErrorAction Ignore
Move-Item -Path $tempFilePath -Destination "$(Split-Path $filePath -Parent)\.env" -Force

# Create CONFIG directories
If (Test-Path "$($PSScriptRoot)\$CONFIG_PATH"){
    Remove-Item "$($PSScriptRoot)\$CONFIG_PATH" -Recurse -Force
}
New-Item -Path "$($PSScriptRoot)\$CONFIG_PATH\web\letsencrypt" -ItemType Directory -Force
New-Item -Path "$($PSScriptRoot)\$CONFIG_PATH\transcripts" -ItemType Directory -Force
New-Item -Path "$($PSScriptRoot)\$CONFIG_PATH\prosody\config" -ItemType Directory -Force
New-Item -Path "$($PSScriptRoot)\$CONFIG_PATH\prosody\prosody-plugins-custom" -ItemType Directory -Force
New-Item -Path "$($PSScriptRoot)\$CONFIG_PATH\jicofo" -ItemType Directory -Force
New-Item -Path "$($PSScriptRoot)\$CONFIG_PATH\jvb" -ItemType Directory -Force
New-Item -Path "$($PSScriptRoot)\$CONFIG_PATH\jigasi" -ItemType Directory -Force
New-Item -Path "$($PSScriptRoot)\$CONFIG_PATH\jibri" -ItemType Directory -Force

# Generate script to create internal Auth users
if (-not [string]::IsNullOrEmpty($AUTH_TYPE)){
$aclText = '$domainName = "meet.jitsi"

$users = @('

    foreach($a in $ACCESS_CONTROL_LIST){
        
        $aclText+= '@{Username="'+$a.UserName+'";Password="'+$($a.password | ConvertFrom-SecureString)+'"}
        '
    }
    $aclText = $aclText.TrimEnd(',')
$aclText+= ')'

    $aclText += '
    foreach($user in $users){
        $btr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR(($user.Password | ConvertTo-SecureString))
		try {
			$plaintext = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($btr)
		} finally {
			[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($btr)
		}
        Write-Host "Configuring access for $($user.UserName) $domainName $plaintext"
		docker-compose exec prosody prosodyctl --config /config/prosody.cfg.lua register $($user.UserName) $domainName $plaintext
    }'
    Write-Verbose "Generated Powershell:"
    Write-Verbose $aclText
    $aclText | Set-Content configureInternalAuth.ps1
}