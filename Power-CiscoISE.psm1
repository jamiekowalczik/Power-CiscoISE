Function Connect-CiscoISE {
  <#
    .SYNOPSIS
    Establishes a connection to an Cisco ISE and saves the connection information
	to a global variable to be used by subsequent Cisco ISE REST commands.

    .DESCRIPTION
    Attempt to esablish a connection to an Cisco ISE and if the connection succeeds
	then it is saved to a global variable to be used for subsequent Cisco ISE commands.
	
    .EXAMPLE
    PS C:\> Connect-CiscoISE -SkipCertificateCheck -ISEHost ise.local -Username admin -Password password

  #>
  
  [CmdLetBinding(DefaultParameterSetName="ISEHost")]
  
  Param(
    [Parameter(Mandatory=$false)][Switch]$SkipCertificateCheck = $True,
    [Parameter(Mandatory=$true)][String]$ISEHost = "",
    [Parameter(Mandatory=$false)][String]$ISEPort = "9060",
    [Parameter(Mandatory=$false)][String]$Username = "",
    [Parameter(Mandatory=$false)][String]$Password = "",
    [Parameter(Mandatory=$false)][String]$Accept = "",
    [Parameter(Mandatory=$false)][Switch]$Troubleshoot
  )
  
  begin {}
  
  process {
    # If credentials aren't passed to the function then prompt the user for them.
    If($Username -eq "" -And $Password -eq ""){
      $creds = Get-Credential
      $Username = $creds.GetNetworkCredential().Username
      $Password = $creds.GetNetworkCredential().Password
    }
  
    $basicAuthValue = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username, $Password)))

    $Headers = @{}
    $Headers.Add("Authorization", "Basic $($basicAuthValue) ")
    $Headers.Add("Content-Type", "application/json")
    $Headers.Add("Accept", "application/vnd.com.cisco.ise.identity.endpointgroup.1.0+xml")
    $Headers.Add("charset", "utf-8")
    
    $URI = "https://$($ISEHost):$($ISEPort)/ers/config/endpointgroup"
    Try {
      If($SkipCertificateCheck) {
        $requests = Invoke-WebRequest -Uri $URI -Method 'GET' -Headers $Headers -SkipCertificateCheck
      } else {
        $requests = Invoke-WebRequest -Uri $URI -Method 'GET' -Headers $Headers
      }
    } catch {
      if($_.Exception.Response.StatusCode -eq "Unauthorized") {
        Write-Host -ForegroundColor Red "`nThe Cisco ISE connection failed - Unauthorized`n"
        Return $False
      } else {
        Write-Error "Error connecting to Cisco ISE"
        Write-Error "`n($_.Exception.Message)`n"
        Return $False
      }
    }

    $Headers = @{
          "Authorization"="Basic $basicAuthValue "
          "Content-Type"="application/json"
          "Accept"=""
          "charset"="utf-8"
    }
    $global:ciscoISEProxyConnection = new-object PSObject -Property @{
        'Server' = "https://$($ISEHost):$($ISEPort)"
        'headers' = $Headers
        'SkipCertificateCheck' = $SkipCertificateCheck
        'troubleshoot' = $Troubleshoot
    }
    $global:ciscoISEProxyConnection
  }
  
  end {}
  
}

Function Send-CiscoISERestRequest {
  <#
    .SYNOPSIS
    Invoke a request to the Cisco ISE API.

    .DESCRIPTION
    Invoke a request to the Cisco ISE API.
	
    .EXAMPLE
    PS C:\> Send-CiscoISERestRequest -Method GET -URI "/ers/config/endpointgroup"
	
    .EXAMPLE
    $EndPoint = new-object PSObject -Property @{ ERSEndPoint = @{ name = 'deadbeefcafe'; description = 'deadbeefcafe'; mac = 'de:ad:be:ef:ca:fe'; groupId = 'c1a23601-3abc-23ba-a15e-2a3ba113215a' } }
    PS C:\> Send-CiscoISERestRequest -Method POST -URI "/ers/config/endpoint" -PSObject $EndPoint -Accept "application/vnd.com.cisco.ise.identity.endpoint.1.0+xml"

  #>
  
  [CmdLetBinding(DefaultParameterSetName="URI")]
  
  Param(
    [String]$Method = "GET",
    [Parameter(Mandatory=$true)][String]$URI,
    [Parameter(Mandatory=$false)][String]$Accept = "",
    [PSObject]$PSObject
  )

  If ($PSObject) {
    $POSTData = $PSObject | ConvertTo-Json -Depth 100
  } Else {
    $POSTData = ""
  }
  If ($global:ciscoISEProxyConnection.Troubleshoot) {
     Write-Output "URI: $($URI)"
     Write-Output "Method: $($Method)"
     $POSTData
  }

  $global:ciscoISEProxyConnection.headers['Accept'] = $Accept
  
  $Page = 1
 
  $Separator = "?"
  If($URI -Like "*``?*"){ $Separator = "&" }

  If (-Not $global:ciscoISEProxyConnection) { Write-error "No Cisco ISE Connection found, please use Connect-CiscoISE" } Else {
      $URI = "$($global:ciscoISEProxyConnection.Server)$($URI)"
      Try {
        If($global:ciscoISEProxyConnection.SkipCertificateCheck) {
          If ($POSTData) {
            [Xml]$Response = Invoke-RestMethod -Uri $URI -Headers $global:ciscoISEProxyConnection.headers -Method $Method -SkipCertificateCheck -Body $POSTData
          } Else {
            [Xml]$Response = Invoke-RestMethod -Uri "$($URI)$($Separator)page=$($Page)" -Headers $global:ciscoISEProxyConnection.headers -Method $Method -SkipCertificateCheck
            $ResponseResults = $Response.searchResult.resources.resource
            If ($Response.searchResult.nextPage) {
              Do {
                $Page++
                [Xml]$Response = Invoke-RestMethod -Uri "$($URI)$($Separator)page=$($Page)" -Headers $global:ciscoISEProxyConnection.headers -Method $Method -SkipCertificateCheck
                $ResponseResults+=$Response.searchResult.resources.resource
              }
              While ($Response.searchResult.nextPage)
            }
	  }
        } else {
          If ($POSTData) {
            [Xml]$Response = Invoke-RestMethod -Uri $URI -Headers $global:ciscoISEProxyConnection.headers -Method $Method -Body $POSTData
          } Else {
            [Xml]$Response = Invoke-RestMethod -Uri "$($URI)?page=$($Page)" -Headers $global:ciscoISEProxyConnection.headers -Method $Method
            $ResponseResults = $Response.searchResult.resources.resource
            If ($Response.searchResult.nextPage) {
              Do {
                $Page++
                [Xml]$Response = Invoke-RestMethod -Uri "$($URI)?page=$($Page)" -Headers $global:ciscoISEProxyConnection.headers -Method $Method
                $ResponseResults+=$Response.searchResult.resources.resource
              }
              While ($Response.searchResult.nextPage)
            }
          }
        }
      } catch {
        if($_.Exception.Response.StatusCode -eq "Unauthorized") {
          Write-Host -ForegroundColor Red "`nThe Cisco ISE connection failed - Unauthorized`n"
          Return $False
        } else {
          Write-Error "Error connecting to Cisco ISE"
          Write-Error "`n($_.Exception.Message)`n"
          Return $False
       }
    }    
    
    Return $ResponseResults
  }
}

Function Get-CiscoISEEndpointIdentityGroups {
  Param(
     [String]$FilterName=""
  )
  $Filter = ""
  If($FilterName){
     $Filter = "?filter=name.EQ.$($FilterName)"
  }
  $URI = "/ers/config/endpointgroup$($Filter)"
  $Accept = "application/vnd.com.cisco.ise.identity.endpointgroup.1.0+xml"
  $CiscoISEEndpointGroups = Send-CiscoISERestRequest -Method GET -URI $URI -Accept $Accept
  Return $CiscoISEEndpointGroups
}

Function Get-CiscoISEEndpoints {
  Param(
     [String]$FilterName=""
  )
  $Filter = ""
  If($FilterName){
     $FilterName = ([System.Web.HttpUtility]::UrlEncode($FilterName)).ToUpper()
     $Filter = "/name/$($FilterName)"
     $URI = "/ers/config/endpoint$($Filter)"
     $URI = "$($global:ciscoISEProxyConnection.Server)$($URI)"
     $global:ciscoISEProxyConnection.headers['Accept'] = "application/vnd.com.cisco.ise.identity.endpoint.1.0+xml"
     If($global:ciscoISEProxyConnection.SkipCertificateCheck) {
        [Xml]$Response = Invoke-RestMethod -Uri "$($URI)" -Headers $global:ciscoISEProxyConnection.headers -Method Get -SkipCertificateCheck
     }Else{
        [Xml]$Response = Invoke-RestMethod -Uri "$($URI)" -Headers $global:ciscoISEProxyConnection.headers -Method Get
     }
     Return $Response.endpoint
  }Else{
     $URI = "/ers/config/endpoint"
     $Accept = "application/vnd.com.cisco.ise.identity.endpoint.1.0+xml"
     $CiscoISEEndpoints = Send-CiscoISERestRequest -Method GET -URI $URI -Accept $Accept
     Return $CiscoISEEndpoints
   }
}

Function New-CiscoISEEndPoint {
   Param(
      [Parameter(Mandatory = $true, HelpMessage = 'Endpoint name')]
      [string]$Name = "",
      [Parameter(Mandatory = $true, HelpMessage = 'Endpoint description')]
      [string]$Description = "",
      [Parameter(Mandatory = $true, HelpMessage = 'Endpoint MAC address')]
      [string]$Mac = "",
      [Parameter(Mandatory = $true, HelpMessage = 'Endpoint Group Name')]
      [string]$GroupName = ""
   )

   $GroupId = (Get-CiscoISEEndpointIdentityGroups -FilterName "$($GroupName)").id
   If(-Not $GroupId){
      Write-Error "Group does not exist"
      Return $false
   }
   $payload = @{
      ERSEndPoint = @{
         name = $Name
         description = $Description
         mac = $Mac
         groupId = $GroupId
         staticGroupAssignment = $true
      }
   }

   $URI = "/ers/config/endpoint"
   $Accept = "application/vnd.com.cisco.ise.identity.endpoint.1.0+xml"
   $CiscoISEEndpoint = Send-CiscoISERestRequest -Method Post -URI $URI -Accept $Accept -PSObject $payload
   Return $CiscoISEEndpoint
}

Function Update-CiscoISEEndPoint {
   Param(
      [Parameter(Mandatory = $false, HelpMessage = 'Endpoint name')]
      [string]$Name = "",
      [Parameter(Mandatory = $false, HelpMessage = 'Endpoint description')]
      [string]$Description = "",
      [Parameter(Mandatory = $false, HelpMessage = 'Endpoint MAC address')]
      [string]$Mac = "",
      [Parameter(Mandatory = $false, HelpMessage = 'Endpoint Group Name')]
      [string]$GroupName = ""
   )

   $GroupId = (Get-CiscoISEEndpointIdentityGroups -FilterName "$($GroupName)").id
   If(-Not $GroupId){
      Write-Error "Group does not exist"
      Return $false
   }
   $payload = @{
      ERSEndPoint = @{
         name = $Name
         description = $Description
         mac = $Mac
         groupId = $GroupId
         staticGroupAssignment = $true
      }
   }
   
   $ID = Get-CiscoISEEndpoints -FilterName $Name
   
   $ID = ([System.Web.HttpUtility]::UrlEncode($ID.id))
   $Filter = "/$($ID)"
   $URI = "/ers/config/endpoint$($Filter)"
   $URI = "$($global:ciscoISEProxyConnection.Server)$($URI)"
   $POSTData = $payload | ConvertTo-Json -Depth 100
   $global:ciscoISEProxyConnection.headers['Accept'] = "application/json"
   If($global:ciscoISEProxyConnection.SkipCertificateCheck) {
      $Response = Invoke-RestMethod -Uri "$($URI)" -Headers $global:ciscoISEProxyConnection.headers -Method PATCH -SkipCertificateCheck -Body $POSTData
   }Else{
      $Response = Invoke-RestMethod -Uri "$($URI)" -Headers $global:ciscoISEProxyConnection.headers -Method PATCH -Body $POSTData
   }
   Return $Response
}

Function Remove-CiscoISEEndPoint {
Param(
      [Parameter(Mandatory = $false, HelpMessage = 'Endpoint name')]
      [string]$Name = ""
   )
   
   $ID = Get-CiscoISEEndpoints -FilterName $Name
   
   $ID = ([System.Web.HttpUtility]::UrlEncode($ID.id))
   $Filter = "/$($ID)"
   $URI = "/ers/config/endpoint$($Filter)"
   $URI = "$($global:ciscoISEProxyConnection.Server)$($URI)"
   $global:ciscoISEProxyConnection.headers['Accept'] = "application/json"
   If($global:ciscoISEProxyConnection.SkipCertificateCheck) {
      $Response = Invoke-RestMethod -Uri "$($URI)" -Headers $global:ciscoISEProxyConnection.headers -Method DELETE -SkipCertificateCheck
   }Else{
      $Response = Invoke-RestMethod -Uri "$($URI)" -Headers $global:ciscoISEProxyConnection.headers -Method DELETE
   }
   Return $Response
}
   



