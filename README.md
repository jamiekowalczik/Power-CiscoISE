## Power-CiscoISE
Powershell module for Cisco ISE
## Powershell module to provide CRUD functionality for Cisco ISE Endpoints
### Import Module and Connect to Cisco ISE
```
PS > Import-Module .\Power-CiscoISE
PS > connect-ciscoISE -Host 1.1.1.1 -Username admin -Password password

Server                   SkipCertificateCheck headers
------                   -------------------- -------
https://1.1.1.1:9060 True                 {[charset, utf-8], [Content-Type, application/json], [Authorization, Basic tyZtYNE4aW46Rk1OQGNASDFASDFADASDaasdfd3MHJkADSFAe…
```
### Create
```
PS > New-CiscoISEEndPoint -Name "deadbeefcafe" -Description "deadbeefcafe" -Mac "de:ad:be:ef:ca:fe" -GroupName "Guest-Endpoints"
PS >
```
### Read
```
PS > Get-CiscoISEEndpoints -Name deadbeefcafe

description             : deadbeefcafe
id                      : 599b8642-1dfc-52af-c98b-1016769d3tyg
name                    : deadbeefcafe
ers                     : ers.ise.cisco.com
xs                      : http://www.w3.org/2001/XMLSchema
ns4                     : identity.ers.ise.cisco.com
link                    : link
customAttributes        : customAttributes
groupId                 : 1sg23e40-6ln1-adge-b76b-4d6cd784676c
identityStore           :
identityStoreId         :
mac                     : DE:AD:BE:EF:CA:FE
portalUser              :
profileId               :
staticGroupAssignment   : true
staticProfileAssignment : false

PS >
```
### Update
```
PS > Update-CiscoISEEndPoint -name DE:AD:BE:EF:CA:FE -Description "DE:AD:BE:EF:CA:FE 1" -Mac DE:AD:BE:EF:CA:FE -GroupName Contractor-Endpoints

ERSEndPoint
-----------
@{id=599b8642-1dfc-52af-c98b-1016769d3tyg; name=DE:AD:BE:EF:CA:FE; description=DE:AD:BE:EF:CA:FE 1; mac=DE:AD:BE:EF:CA:FE; profileId=; staticProfileAssignment=Fa…
PS >
```
### Delete
```
PS > Remove-CiscoISEEndPoint -name DE:AD:BE:EF:CA:FE

PS >
```
