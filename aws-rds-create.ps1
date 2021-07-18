#######################################################
# Created by: Vinay
# Created On: 18-Jul-2021
# Purpose: Create AWS RDS-MSSQL
#######################################################
[Cmdletbinding()]
Param (
    [Parameter(Mandatory=$true)]
    [string]$AccessKey,
     [Parameter(Mandatory=$true)]
    [SecureString]$SecretKey,
    [Parameter(Mandatory=$true)]
    [string]$RegionName,
    [Parameter(Mandatory=$true)]
    [string]$DBInstanceIdentifier,
    [Parameter(Mandatory=$true)]
    [string]$DBEngine='sqlserver-ex',
    [Parameter(Mandatory=$true)]
    [string]$DBInstanceClass='db.t2.micro',
    [Parameter(Mandatory=$true)]
    [string]$MasterUsername,   
    [Parameter(Mandatory=$true)]
    [SecureString]$MasterUserPassword, ## Do not to include a forward slash, @ symbol, double quotes or spaces
    [Parameter(Mandatory=$true)]
    [int]$AllocatedStorageInGB=20,  ## Gigabytes
    [bool]$PubliclyAccessible = $false,      ## to connect over the internet
    $tags,
    [ValidateNotNullOrEmpty()]
    [string]$LogFolder
)
Begin {
    $ErrorActionPreference = "Stop"
    $WarningPreference = "SilentlyContinue"
    $RAISE_ERROR = $True
        
    #region "Functions"
    function Set-PSModule {
    Param (
        $moduleName
    )            
        $LoadedModules = Get-Module -Name $moduleName -ListAvailable
        if (!$LoadedModules) {
            Write-Verbose "${moduleName} is available."
              Import-Module -Name $moduleName
          }else{
            $installedModule = Get-InstalledModule -Name $moduleName -ErrorAction $WarningPreference
            if ($null -ne $installedModule) {
                Write-Verbose ('Module [{0}] (v {1}) is installed.' -f $moduleName, $installedModule.Version)
            }
            else {
              Write-Verbose "${moduleName} module not found. will be installed now."
              Install-Module -Name $moduleName -Force
            }
              Import-Module -Name $moduleName
          }    
    }

    ## Configure tags in AWS native format
    Function Get-TagSpecs {   
        Param (
            $tags,
            $resourceType
        )
        $tagSpec = $null             
        if ($tags -and $tags.Keys.Count -gt 0 ) {
            $awstags = @()
            $tags.Keys | ForEach-Object {
                $tag = New-Object Amazon.EC2.Model.Tag
                $tag.Key = $_
                $tag.Value = $tags[$_]

                $awstags += $tag
            }

            $tagSpec = New-Object Amazon.EC2.Model.TagSpecification
            $tagSpec.Tags = $awstags
            $tagSpec.ResourceType = $resourceType        
        }
        return $tagSpec
    }

    function Get-MyDate {
        return get-date -format "dd-MMM-yyyy HH:mm:ss 'GMT'zzz"
    }
    #endregion  

    $TASK_NAME = "aws-rds"
    [string]$currentdate = Get-Date -Format "yyyyMMdd"
    [string]$sLogBasePath = Join-Path -Path (Join-Path -Path $LogFolder "PostProvTasks") $TASK_NAME
    if (-Not (Test-Path $sLogBasePath)) {
        New-Item -Path $sLogBasePath -ItemType Directory | Out-Null
    }
    [string]$sLogFile = "mycloud_${InstanceId}_${currentdate}.log"  
    [string]$sLogPath = Join-Path -Path $sLogBasePath -ChildPath $sLogFile
    Start-Transcript -Path $sLogPath -Append

    Set-PSModule "AWSPowershell"

    Initialize-AWSDefaultConfiguration -AccessKey $AccessKey -SecretKey ($SecretKey | ConvertFrom-SecureString -AsPlainText)  -Region $RegionName
    Write-Output "Initialize-AWSDefaultConfiguration done."
    
}
Process {
    Try {
        #*** Get RDS Engine
        # Get-RDSDBEngineVersion | Group-Object -Property Engine
        $rdsEngineVer=Get-RDSDBEngineVersion -Engine $DBEngine | Format-Table -Property EngineVersion
        Write-Output "Get-RDSDBEngineVersion: $($rdsEngineVer)"
        
        ## configure tags structure
        $tagSpec = Get-TagSpecs -tags $tags -resourceType 'rds'
  
            $parameters = @{
                DBInstanceIdentifier = $DBInstanceIdentifier
                Engine = $DBEngine
                DBInstanceClass = $DBInstanceClass
                MasterUsername = $MasterUsername
                MasterUserPassword = $MasterUserPassword ## Do not to include a forward slash, @ symbol, double quotes or spaces
                AllocatedStorage = $AllocatedStorageInGB ## Gigabytes
                PubliclyAccessible = $PubliclyAccessible ## to connect over the internet
                Tags = $tagSpec
            }
            Write-Output "parameters set. creating RDSDBInstance now...StartTime: $(Get-MyDate)"
            $instance = New-RDSDBInstance @parameters
            $instance
         
        while ((Get-RDSDBInstance -DBInstanceIdentifier $instance.DBInstanceIdentifier).DBInstanceStatus -ne 'available') {
            Write-Host 'Waiting for instance to be created...'
            Start-Sleep -Seconds 30
        }
        Write-Output "DB Instance is successfully created. RDSDBInstanceId: $($instance), EndTime: $(Get-MyDate), State: $($RDSDBInstance.State)"
    }
    catch {
        Write-Output "`t`nFailed" $RAISE_ERROR
        Write-Output "Exception Type: $($_.Exception.GetType().FullName)" $RAISE_ERROR
        Write-Output "Exception Message: $($_.Exception.Message)" $RAISE_ERROR
        
        throw $_.Exception.Message
    }
    finally {
        ### final
    }
}
End {
    Write-Output "-- end of script --"
    Stop-Transcript
}