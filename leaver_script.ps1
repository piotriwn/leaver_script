# IMPORTANT:
# this script superseeds previous bulk leaver
# for easier code-management, each action is performed in a separate loop, making it redundant; performance was not a consideration here

# -------- FUNCTIONS

# returns string
function Get-UserOwnedGroups {
param(
    [Parameter(Mandatory=$true)][Microsoft.ActiveDirectory.Management.ADUser]$ADUser
)
    $GroupArray = [System.Collections.ArrayList]@()
    $null = get-adgroup -filter {managedby -eq $ADUser} | foreach-object -process {$GroupArray.add($_.sAMAccountName)}
    return $GroupArray
}

# returns object
function Get-UserOwnedGroupsObject {
param(
    [Parameter(Mandatory=$true)][Microsoft.ActiveDirectory.Management.ADUser]$ADUser
)
    $GroupArray = [System.Collections.ArrayList]@()
    $null = get-adgroup -filter {managedby -eq $ADUser} -properties *| foreach-object -process {$GroupArray.add($_)}
    return $GroupArray
}

# returns common name (string)
function Get-ManagedUsers {
param(
    [Parameter(Mandatory=$true)][Microsoft.ActiveDirectory.Management.ADUser]$ADUser
)
    $ManagedByList = [System.Collections.ArrayList]@()
    $null = (get-aduser $AdUser -properties DirectReports).DirectReports | foreach-object -process {$ManagedByList.add($_.split(",")[0].split("=")[1])}
    return $ManagedByList
}

function Get-ManagedUsersSAM {
param(
    [Parameter(Mandatory=$true)][Microsoft.ActiveDirectory.Management.ADUser]$ADUser
)
    $ManagedByList = [System.Collections.ArrayList]@()
    $null = (get-aduser $AdUser -properties DirectReports).DirectReports | foreach-object -process {$ManagedByList.add($_)}
    return $ManagedByList
}


# "green/red light" function, returns 0 if "red", 1 if "green"
function Get-DataConsistency {
param(
    [Parameter(Mandatory=$true)][System.Collections.Hashtable]$Dct
)
    foreach($key in $Dct.keys ) {
        $object = $Dct[$key]
        if ( $object.AdObject.gettype().name -ne "ADUser") { return 0 }
        
        if ($object.AdObject -eq $null) { return 0 }
        elseif ( $object.AdObject.gettype().name -ne "ADUser") {return 0}
        else { }
        
        
        if ($object.TransferTo -ne $null)
        {
            if ( $object.TransferTo.gettype().name -ne "ADUser" )  { return 0 }
        }

        if ( $object.Odrive.gettype().name -eq "Int"  ) {return 0}
    }
    return 1
}

function Write-ConsoleFile {
param (
    [Parameter(Mandatory=$true)][String]$message,
    [string]$color = "gray",
    [int]$noNewLine = 0
)
    [System.IO.File]::AppendAllText($global:outputFile, $message, [System.Text.Encoding]::ASCII)
    if ($noNewLine -ne 0) {
        write-host $message -ForegroundColor $color -nonewline
    }
    else {
    add-content -path $global:outputFile -value ""
    write-host $message -ForegroundColor $color 
    }
}

function Export-UserObject {
param(
    [Parameter(Mandatory=$true)][System.Collections.Hashtable]$Dct
    
)
    "" | Add-Content $global:outputFile
    "Exporting error logs" | Add-Content $global:outputFile
    "---------" | Add-Content $global:outputFile
    $k = 1
    
    foreach($key in $Dct.keys)
    {
        $object = $Dct[$key]
        
        "Logs from row $k" | Add-Content $global:outputFile
        
        # write ADObject property
        if ( -not ( $object.AdObject.gettype().name -eq "ADUser") ) 
        { 
            "AD user: $($object.AdObject.tostring())" | Add-Content $global:outputFile 
        }
        
        # write TransferTo property     
        if ($object.TransferTo -ne $null)
        {
            #"Transfer to: NULL" | Add-Content $global:outputFile
            if ( -not ( $object.TransferTo.gettype().name -eq "ADUser") ) 
            { 
                "Transfer to: $($object.TransferTo.tostring())" | Add-Content $global:outputFile 
            } 
        }  
        

                 
        # write ODrive property
        if ((-not ($object.Odrive.gettype().name -eq "Int")) -and (-not ($object.Odrive.gettype().name -eq "Int32"))) 
        { 
            "ODrive: $($object.Odrive.tostring())" | Add-Content $global:outputFile 
        } 
        
        "---" | Add-Content $global:outputFile
        
        $k++
    }
}

# ------- MAIN CODE


import-module ActiveDirectory

# Powershell 2 way of defining working directory
$folder_path = Split-path -Path $MyInvocation.MyCommand.Definition -Parent

# get date and time, cast to string
$dateTime = (get-date -format "dd-MM-yyy HH-mm-ss").toString()

# get user executing script
$userExecuting = "$env:username"



$ticketNumber = Read-Host -prompt "Please provide the ticket number"

# description
$description = 'DISABLED ' + $ticketNumber

do
{
    $removeOrCheck = Read-Host -prompt "Do you want to check [d]ependencies or go on with full bulk [l]eaver? Type [d] or [l]"
} while ( ($removeOrCheck -ne "d") -and  ($removeOrCheck -ne "l"))


# output file
$global:outputFile = $folder_path + "\Results\" + $ticketNumber + "_" + $userExecuting + "_" + $dateTime + "_" + ".txt"

# import file
$fullPath = $folder_path + "\" + "input.csv"
$csvFile = import-csv -path $fullPath

# create an empty hashtable
$userObjectDict = @{}

# make all errors terminating
$ErrorActionPreference = "Stop"

# output info text
"" | Add-Content $global:outputFile
"" | Add-Content $global:outputFile
"#########################" | Add-Content $global:outputFile
$dateTime | Add-Content $global:outputFile
$userExecuting | Add-Content $global:outputFile
$ticketNumber | Add-Content $global:outputFile


# reading data from CSV into hashtable of PS objects
"" | Add-Content $global:outputFile
write-ConsoleFile -message "READING DATA FROM CSV FILE... " -color "blue"
write-ConsoleFile -message "----------------------------------------------" -color "blue"

$i_row = 1
foreach($row in $csvFile) {
    write-ConsoleFile -message "Reading row $i_row..." 
    
    
    # create an object
    $userObject = New-Object -TypeName psobject
    $ADErr = 0
    
    # Try to get AD User using supplied Company number
    try { $getAdUser = get-aduser $row.Company -properties *}
    catch [System.Management.Automation.ParameterBindingException] { $ADErr = $true} 
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {$ADErr = $true}
    catch { $ADErr = $true }
    
    # create ADObject attribute, populate with AD User or error 
    Write-ConsoleFile -message "Adding AD user from $i_row : " -nonewline 1
    if ($ADErr) {
        Write-ConsoleFile -message "Error writing AD User $($row.Company)" -color "red"
        $userObject | Add-Member -MemberType NoteProperty -Name "ADObject" -Value $error[0] 
    }
    else {
        try { $userObject | Add-Member -MemberType NoteProperty -Name "ADObject" -Value $getAdUser;  write-ConsoleFile -message "AD User $($row.Company) supplied to user object" -color "green"   }
        catch {write-consoleFile -message "Error writing AD User $($row.Company)" -color "red"; $userObject | Add-Member -MemberType NoteProperty -Name "ADObject" -Value $error[0] } 
    }
       
    # create TransfeTo attribute, populate with AD User or error
    write-consoleFile "Adding TransferTo AD user from $i_row : " -nonewline 1 
    try { 
    $getAdUser = get-aduser $row.TransferTo -properties *
    $userObject | Add-Member -MemberType NoteProperty -Name "TransferTo" -Value $getAdUser
    write-consoleFile -message "TransferTo AD User $($row.TransferTo) supplied to user object" -color "green"
    }
    catch [System.Management.Automation.ParameterBindingException] {$userObject | Add-Member -MemberType NoteProperty -Name "TransferTo" -Value $null; write-consoleFile -message "NULL value supplied to user object (no TransferTo given)" -color "green"}
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        write-consoleFile -message  "Error writing TransferTo AD user $($row.TransferTo)" -color "red"
        $userObject | Add-Member -MemberType NoteProperty -Name "TransferTo" -Value $error[0] #"_Error: $errorMessage"
    }
    catch {
        write-consoleFile -message "Error establishing TransferTo value $($row.TransferTo)" -color "magenta"
        $userObject | Add-Member -MemberType NoteProperty -Name "TransferTo" -Value $error[0] #"_Error: $errorMessage"
    }
 
    # create Odrve attribute, populate with days until deletion
    write-consoleFile -message "Adding ODrive from $i_row : " -nonewline 1
    if ($row.Odrive -eq "") { $val = 30}
    else {
        try { $val = [int]($row.Odrive) }
        catch [System.Management.Automation.RuntimeException] { 
            $val = $error[0] 
        }
        catch {
            $val = $error[0]
        }
    }
    if ($val.gettype().name -eq "Int32") { write-consoleFile -message "ODrive $val supplied to user object" -color "green" }
    else {write-consoleFile -message "Error writing $($row.Odrive)" -color "red"}
    $userObject | Add-Member -MemberType NoteProperty -Name "Odrive" -Value $val
    
    if ($ADErr) {
        $key = "$i_row row - error"
    }
    else {
        $key = $row.Company
    }
    $userObjectDict[$key] = $userObject
    
    $i_row++
    
    write-consoleFile -message "---------"
}

$ErrorActionPreference = "Continue"

"" | Add-Content $global:outputFile
"##" | Add-Content $global:outputFile

#Write-ConsoleFile -message "Exporting user objects..."
Export-UserObject -Dct $userObjectDict

$consistent = Get-DataConsistency -Dct $userObjectDict
if ($consistent -eq 0)
{
    write-consoleFile -message "TERMINATION - Data provided in input file not consistent, please check output.txt" -color "red"
    Exit
}
else
{
    write-consoleFile -message "Input consistent, proceding." -color "green"
}

"" | Add-Content $global:outputFile
"##" | Add-Content $global:outputFile
"" | Add-Content $global:outputFile

# get owned groups and direct reports, check if input file is properly set
write-consoleFile -message "User owned groups and managed employees"
write-consoleFile -message " "
write-consoleFile -message " "

$errorArray = @()
foreach($user in $userObjectDict.keys)
{
    $control = $false
    $currentUser = $userObjectDict[$user].ADObject
    $currentOwnedGroups = Get-UserOwnedGroups -ADUser $currentUser
    $currentManagedEmp = Get-ManagedUsers -ADUser $currentUser
    
    if ($currentOwnedGroups -eq $null)
    {
        write-consoleFile -message "$user is not an owner of any groups" -color "blue"
    }
    
    else
    {
        $control = $true
        write-consoleFile -message "$user is owner of the following groups:" -color "cyan"
        foreach($group in $currentOwnedGroups)
        {
        write-consoleFile -message "$group"
        }
    }
    
    write-consoleFile -message " "
    write-consoleFile -message " "
    
    
    if ($currentManagedEmp -eq $null)
    {
        write-consoleFile -message "$user is not a manager of any employees" -color "blue"
    }
    
    else
    {
        $control = $true
        write-consoleFile -message "$user is a manager of the following employees:" -color "cyan"
        foreach($usr in $currentManagedEmp)
        {
        write-consoleFile -message "$usr"
        }
    }
    
    
    if ( ( $control -eq $true ) -and ($userObjectDict[$user].TransferTo -eq $null) )
    {
        $errorArray += "$user has dependencies and TransferTo field has been left empty"
    }
    
    write-consoleFile -message " "
    write-consoleFile -message "------"
    write-consoleFile -message " "

}

"" | Add-Content $global:outputFile
"##" | Add-Content $global:outputFile
"" | Add-Content $global:outputFile

if ($errorArray -ne $null)
{
    foreach ($msg in $errorArray)
    {
        write-consoleFile -message "$msg"
    }
    write-consoleFile -message "There are dependencies and TransferTo field has not been prepared properly. Please check logs and go back to Service Desk in order to establish users whom dependencies should be transferred to." -color "red"
    Exit
}

# get group membership and OU that user resides in
write-consoleFile -message "Group membership - prior to further actions"

foreach($user in $userObjectDict.keys)
{
    $currentUser = $userObjectDict[$user].ADObject
    write-consoleFile -message "Assigned groups:"
    $groups = Get-ADPrincipalGroupMembership $currentUser
    foreach($grp in $groups)
    {
        write-consoleFile -message "$($grp.samAccountName) "
    }
    write-consoleFile -message " "
    write-consoleFile -message "User location in the domain: $($currentUser.distinguishedname)"
}

write-consoleFile -message " "

"" | Add-Content $global:outputFile
"##" | Add-Content $global:outputFile
"" | Add-Content $global:outputFile

# because we want to be double sure we want to go on with leaver process
if ($removeOrCheck -eq "d") { EXIT }

# reassign manager
foreach($user in $userObjectDict.keys)
{
    $currentUser = $userObjectDict[$user].ADObject
    $currentManagedEmp = Get-ManagedUsersSAM -ADUser $currentUser
    if ( $currentManagedEmp.count -gt 0)
    {
    
    foreach ($managedEmpStr in  $currentManagedEmp)
    {
            try 
            {
                $managedEmp = get-aduser $managedEmpStr  
            
            }
            catch
            {
                try 
                {
                    $managedEmp = get-adobject -filter {( objectclass -eq "contact") -and (distinguishedName -eq $managedEmpStr) }
                }
                catch
                {
                    write-consoleFile -message "Error getting $managedEmp - please check it manually" -color "red"
                    $managedEmp = $null
                }
            }
            if ( -not ($managedEmp -eq $null) )
            {
                set-aduser $managedEmp -Manager $userObjectDict[$user].TransferTo # -whatif
            }
        }
    }
}

"" | Add-Content $global:outputFile
"##" | Add-Content $global:outputFile
"" | Add-Content $global:outputFile

# reassign group ownership
foreach($user in $userObjectDict.keys)
{
    $currentUser = $userObjectDict[$user].ADObject
    $currentOwnedGroups = Get-UserOwnedGroupsObject -ADUser $currentUser
    
    if (-not ($currentOwnedGroups -eq $null) )
    {
        foreach($grp in  $currentOwnedGroups)
        {
            try
            {
                set-adgroup $grp -ManagedBy $userObjectDict[$user].TransferTo.distinguishedname # -whatif
            }
            catch
            {
                write-consoleFile -message "Error changing ownership of $($grp.distinguishedname) - please check it manually" -color "red"
                $error[0] | Add-Content $global:outputFile
            }
        }
    }
}

"" | Add-Content $global:outputFile
"##" | Add-Content $global:outputFile
"" | Add-Content $global:outputFile

# disable users and delete from groups
foreach($user in $userObjectDict.keys)
{
    $currentUser = $userObjectDict[$user].ADObject
    try
    {
        Set-ADUser $currentUser -enabled $false # -whatif
    }
    catch
    {
        write-consoleFile -message "Error disabling account $user.samaccountname - please check it manually" -color "red"
        $error[0] | Add-Content $global:outputFile
    }
    
    $currentUserGroups = Get-ADPrincipalGroupMembership $currentUser
    foreach($grp in  $currentUserGroups)
    {
        if ($grp.sAMAccountName -ne "Domain Users")
        {
            try
            {
                Remove-ADGroupMember $grp -Members $currentUser.DistinguishedName -confirm:$false # -whatif
            }
            catch
            {
                write-consoleFile -message "Error removing $user from $grp.distinguishedname - please check it manually" -color "red"
                $error[0] | Add-Content $global:outputFile
            }
        }
    }
    
}



"" | Add-Content $global:outputFile
"##" | Add-Content $global:outputFile
"" | Add-Content $global:outputFile

# change description and move to leavers OU
foreach($user in $userObjectDict.keys)
{
    $currentUser = $userObjectDict[$user].ADObject
    write-consoleFile -message "Changing description of the user $user..."
    try
    {
        Set-ADuser -identity $currentUser.distinguishedname -description "$($currentUser.description) $description"
        write-consoleFile -message "Done" -color "green"
    }
    catch
    {
        write-consoleFile -message "Could not change description, please check logs" -color "red"
        $error[0] | Add-Content $global:outputFile   
    }
    
    write-consoleFile -message "Changing OU of $user..."
    try
    {
        Move-ADObject $currentUser.distinguishedname -TargetPath "OU=Leavers,OU=Corp Managed,DC=Company,DC=net"
        write-consoleFile -message "Done" -color "green"
    }
    
    catch
    {
        write-consoleFile -message "Could not change user's OU, please change logs" -color "red"
        $error[0] | Add-Content $global:outputFile
    }

} 


"" | Add-Content $global:outputFile
"##" | Add-Content $global:outputFile
"" | Add-Content $global:outputFile

write-consoleFile -message "Now we're done with action, let's check results." -color "green"

"" | Add-Content $global:outputFile
"" | Add-Content $global:outputFile

foreach($user in $userObjectDict.keys)
{
    # again, redundant to get-user and try/catch again, but want to follow the same procedure as it was before
    try
    {
        $currentUser = get-aduser $user -properties *
        $good = $true
    }
    catch
    {
        Write-ConsoleFile -message "Error getting AD User $user: $($error[0])" -color "red"
        $good = $false
    }
    
    if ( $good -eq $true)
    {
        $Exists = "True"
        write-consoleFile -message "$($currentUser.samaccountname) Exists =  $Exists"
        write-consoleFile -message "$($currentUser.samaccountname) Enabled =  $($currentUser.enabled)"
        
        write-consoleFile -message "Assigned groups:"
        $groups = Get-ADPrincipalGroupMembership $currentUser
        foreach($grp in $groups)
        {
            write-consoleFile -message "$($grp.samAccountName) "
        }
        write-consoleFile -message " "
        write-consoleFile -message "Direct reports:"
        $reports = Get-ManagedUsers -ADUser $currentUser
        if (-not ($reports -eq $null) )
        {
            foreach($rep in $reports)
            {
                write-consoleFile -message "$rep"
            }
        }
        else
        {
            write-consoleFile -message "--none--"
        }
    
    

    }
    
   write-consoleFile -message " "
   write-consoleFile -message "------------------------"
   write-consoleFile -message " "
    
    
}

"" | Add-Content $global:outputFile
"" | Add-Content $global:outputFile

write-consoleFile -message "Please paste the following information regarding Odrives in the ticket's worknotes"
"" | Add-Content $global:outputFile


foreach($user in $userObjectDict.keys)
{
    $date = (get-date).addDays($userObjectDict[$user].Odrive).ToString("dd-MM-yyy")
    $currentUser = $userObjectDict[$user].ADObject
    if (-not ( $currentUser -eq $null ) )
    {
        $homePath = $currentUser.homedirectory
        if (-not ( ($homePath -eq $null) -or ($homePath -eq "") ) )
        {
            write-consoleFile -message "$user : Odrive to be deleted after $($userObjectDict[$user].Odrive) days, no sooner than $date"
            write-consoleFile -message "Odrive path: $homePath"
            write-consoleFile -message " "
        }
    }
    

}

write-consoleFile -message " "
write-consoleFile -message "------------------------"
write-consoleFile -message "END OF SCRIPT"
write-consoleFile -message " "