Function Connect-CiscoISE {
  <#
    .SYNOPSIS
    Establishes a connection to an Cisco ISE and saves the connection information
	to a global variable to be used by subsequent Cisco ISE REST commands.

    .DESCRIPTION
    Attempt to esablish a connection to an Cisco ISE and if the connection succeeds
	then it is saved to a global variable to be used for subsequent Cisco ISE commands.
	
    .EXAMPLE
    PS C:\> Connect-CiscoISE -SkipCertificateCheck -Host ise.local -Username admin -Password password

  #>
  
  [CmdLetBinding(DefaultParameterSetName="Host")]
  
  Param(
    [Parameter(Mandatory=$false)][Switch]$SkipCertificateCheck = $True,
    [Parameter(Mandatory=$true, HelpMessage="Hostname or IP Address")][String]$Host,
    [Parameter(Mandatory=$false)][String]$Port = "9060",
    [Parameter(Mandatory=$true, HelpMessage="Username")][String]$Username,
    [Parameter(Mandatory=$false, HelpMessage="Password")][String]$Password,
    [Parameter(Mandatory=$false)][String]$Accept = "",
    [Parameter(Mandatory=$false)][Switch]$Troubleshoot
  )
  
  begin {}
  
  process {
    If($Password -eq ""){
      $Password = Read-Host 'Password' -MaskInput
    }
    $basicAuthValue = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username, $Password)))

    $Headers = @{}
    $Headers.Add("Authorization", "Basic $($basicAuthValue) ")
    $Headers.Add("Content-Type", "application/json")
    $Headers.Add("Accept", "application/json")
    $Headers.Add("charset", "utf-8")
    
    $URI = "https://$($Host):$($Port)/ers/config/op/systemconfig/iseversion"
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
        'Server' = "https://$($Host):$($Port)"
        'headers' = $Headers
        'SkipCertificateCheck' = $SkipCertificateCheck
        'troubleshoot' = $Troubleshoot
    }
    $global:ciscoISEProxyConnection
  }
  
  end {}
  
}

Function Send-CiscoISERestSimpleRequest {
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
  
  $Separator = "?"
  If($URI -Like "*``?*"){ $Separator = "&" }

  If (-Not $global:ciscoISEProxyConnection) { Write-error "No Cisco ISE Connection found, please use Connect-CiscoISE" } Else {
      $URI = "$($global:ciscoISEProxyConnection.Server)$($URI)"
      Try {
        If($global:ciscoISEProxyConnection.SkipCertificateCheck) {
          If ($POSTData) {
            $Response = Invoke-RestMethod -Uri $URI -Headers $global:ciscoISEProxyConnection.headers -Method $Method -SkipCertificateCheck -Body $POSTData
          } Else {
            $Response = Invoke-RestMethod -Uri "$($URI)" -Headers $global:ciscoISEProxyConnection.headers -Method $Method -SkipCertificateCheck
	        }
        } else {
          If ($POSTData) {
            $Response = Invoke-RestMethod -Uri $URI -Headers $global:ciscoISEProxyConnection.headers -Method $Method -Body $POSTData
          } Else {
            $Response = Invoke-RestMethod -Uri "$($URI)" -Headers $global:ciscoISEProxyConnection.headers -Method $Method
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
    
    Return $Response
  }
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
            $Response = Invoke-RestMethod -Uri $URI -Headers $global:ciscoISEProxyConnection.headers -Method $Method -SkipCertificateCheck -Body $POSTData
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
            $Response = Invoke-RestMethod -Uri $URI -Headers $global:ciscoISEProxyConnection.headers -Method $Method -Body $POSTData
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

Function Get-CiscoISEVersion {
  $URI = "/ers/config/op/systemconfig/iseversion"
  $Accept = "application/json"
  $Response = Send-CiscoISERestSimpleRequest -Method GET -URI $URI -Accept $Accept
  Return $Response.OperationResult.resultValue
}

Function Get-CiscoISEEndpointIdentityGroups {
  Param(
     [String]$Name=""
  )
  $Filter = ""
  If($Name){
     $Filter = "?filter=name.EQ.$($Name)"
  }

  $URI = "/ers/config/endpointgroup$($Filter)"
  $Accept = "application/vnd.com.cisco.ise.identity.endpointgroup.1.0+xml"
  $CiscoISEEndpointGroups = Send-CiscoISERestRequest -Method GET -URI $URI -Accept $Accept
  Return $CiscoISEEndpointGroups
}

Function Get-CiscoISEEndpoints {
  Param(
     [String]$Name=""
  )
  Try {
    $Filter = ""
    If($Name){
      $Name = ([System.Web.HttpUtility]::UrlEncode($Name)).ToUpper()
      $Filter = "/name/$($Name)"
      $URI = "/ers/config/endpoint$($Filter)"
      $Accept = "application/json"
      
      $Response = Send-CiscoISERestSimpleRequest -Method GET -URI $URI -Accept $Accept
      Return $Response.ERSEndPoint
    }Else{
      $URI = "/ers/config/endpoint"
      $Accept = "application/vnd.com.cisco.ise.identity.endpoint.1.0+xml"
      $CiscoISEEndpoints = Send-CiscoISERestRequest -Method GET -URI $URI -Accept $Accept
      Return $CiscoISEEndpoints
    }
  } catch {
    if($_.Exception.Response.StatusCode -eq "Unauthorized") {
      Write-Host -ForegroundColor Red "`nThe Cisco ISE connection failed - Unauthorized`n"
    } elseif($_.Exception.Response.StatusCode -eq 404) {
      Write-Error "Endpoint Doesn't Exist"
    } else {
      Write-Error "Error connecting to Cisco ISE"
      Write-Error "`n($_.Exception.Message)`n"
    }
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

   $GroupId = (Get-CiscoISEEndpointIdentityGroups -Name "$($GroupName)").id
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

   $GroupId = (Get-CiscoISEEndpointIdentityGroups -Name "$($GroupName)").id
   If(-Not $GroupId){
      Write-Error "Group does not exist"
      Return
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
   
   $ID = Get-CiscoISEEndpoints -Name $Name
   $ID = ([System.Web.HttpUtility]::UrlEncode($ID.id))
   $Filter = "/$($ID)"

   $URI = "/ers/config/endpoint$($Filter)"
   $Accept = "application/json"
   $Response = Send-CiscoISERestRequest -Method PATCH -URI $URI -Accept $Accept -PSObject $payload
   Return $Response
}

Function Remove-CiscoISEEndPoint {
Param(
      [Parameter(Mandatory = $false, HelpMessage = 'Endpoint name')]
      [string]$Name = ""
     )
   
  $ID = Get-CiscoISEEndpoints -Name $Name
  $ID = ([System.Web.HttpUtility]::UrlEncode($ID.id))
  $Filter = "/$($ID)"
  
  $URI = "/ers/config/endpoint$($Filter)"
  $Accept = "application/json"
  $Response = Send-CiscoISERestRequest -Method DELETE -URI $URI -Accept $Accept
  Return $Response
}
   



