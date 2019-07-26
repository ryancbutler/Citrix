# Copyright (c) 2010 - 2014 Citrix Systems, Inc. All rights reserved.
# 
# Version   Date            Details
# 7.1       01.21.14        Fixes LA5474 ('Enabled' type change) and LA5584 (AccessControl Filter Import)
#           02.14.18        Edited to work with XenDesktop 7.16

<#
$snapin = "Citrix.Common.GroupPolicy"
if (!(Get-PSSnapin $snapin))
{
    Write-Host "Loading $snapin..." -ForegroundColor Yellow
    Add-PSSnapin $snapin -ea SilentlyContinue
}
#>

##########################

<#
    .SYNOPSIS
        Exports group policies to XML files.
    .DESCRIPTION
        This cmdlet exports group policies from a Citrix farm into XML files in the specified folder.
    .PARAMETER  FolderPath
        The folder path where the files will be created.
    .PARAMETER  PolicyName
        The policy name.
    .PARAMETER  Type
        The policy type. Allowed values are User and Computer.
    .PARAMETER  DriveName
        An optional drive name. Defaults to LocalFarmGpo.
    .EXAMPLE
        PS C:\> Export-CtxGroupPolicy c:\policies
        This command exports all the group policies in the farm using the LocalFarmGpo drive.
    .EXAMPLE
        PS C:\> Export-CtxGroupPolicy c:\policies pol* user
        This command exports the user policies whose names match pol*.
    .INPUTS
        String.
    .OUTPUTS
        Policy object.
    .NOTES
        Multiple files are created in the specified folder.
    .LINK
        Import-CtxGroupPolicy
#>
function Export-CtxGroupPolicy
{
	[CmdletBinding()]
	param(
		[Parameter(Position = 0,Mandatory = $true)]
		[string]$FolderPath,
		[Parameter(Position = 1,ValueFromPipelineByPropertyName = $true)]
		[string[]]$PolicyName = "*",
		[Parameter(Position = 2,ValueFromPipelineByPropertyName = $true)]
		[string][ValidateSet("Computer","User")] $Type,
		[Parameter()]
		[string]$DriveName = "LocalFarmGpo"
	)

	process
	{
		if (!(Test-Path $FolderPath))
		{
			$dir = New-Item $FolderPath -Type Directory -Force -ErrorAction Stop
		}

		$pols = Get-CtxGroupPolicy $PolicyName $Type -DriveName $DriveName
		$configs = $pols | Get-CtxGroupPolicyConfiguration -DriveName $DriveName
		$filters = $pols | Get-CtxGroupPolicyFilter -DriveName $DriveName

		$pols | Export-Clixml "$FolderPath\GroupPolicy.xml"
		$configs | Export-Clixml "$FolderPath\GroupPolicyConfiguration.xml"
		$filters | Export-Clixml "$FolderPath\GroupPolicyFilter.xml"
	}
}

<#
    .SYNOPSIS
        Imports group policies from XML files.
    .DESCRIPTION
        This cmdlet imports group policies to Citrix farm using the XML files in the specified folder.
    .PARAMETER  FolderPath
        The folder path where the files are located.
    .PARAMETER  PolicyName
        The policy name.
    .PARAMETER  Type
        The policy type. Allowed values are User and Computer.
    .PARAMETER  DriveName
        An optional drive name. Defaults to LocalFarmGpo.
    .EXAMPLE
        PS C:\> Import-CtxGroupPolicy c:\policies
        This command imports the group policies from the specified folder using the LocalFarmGpo drive.
    .EXAMPLE
        PS C:\> Import-CtxGroupPolicy c:\policies pol* user
        This command imports the user policies whose names match pol*.
    .INPUTS
        String.
    .OUTPUTS
        Policy object.
    .NOTES
        If the group policies already exist, only the necessary updates will be performed.
    .LINK
        Export-CtxGroupPolicy
#>
function Import-CtxGroupPolicy
{
	[CmdletBinding()]
	param(
		[Parameter(Position = 0,Mandatory = $true)]
		[string]$FolderPath,
		[Parameter(Position = 1,ValueFromPipelineByPropertyName = $true)]
		[string[]]$PolicyName = "*",
		[Parameter(Position = 2,ValueFromPipelineByPropertyName = $true)]
		[string][ValidateSet("Computer","User")] $Type,
		[Parameter()]
		[string]$DriveName = "LocalFarmGpo"
	)

	process
	{
		$types = if (!$Type) { @("Computer","User") } else { @($Type) }
		if (!(Test-Path $FolderPath)) { throw "Invalid folder path" }

		$pols = Import-Clixml "$FolderPath\GroupPolicy.xml" -ErrorAction Stop
		$configs = Import-Clixml "$FolderPath\GroupPolicyConfiguration.xml" -ErrorAction Stop
		$filters = Import-Clixml "$FolderPath\GroupPolicyFilter.xml" -ErrorAction Stop

		foreach ($pol in @($pols | Where-Object { (FilterString $_.PolicyName $PolicyName) -and (FilterString $_.Type $types) }))
		{
			Write-Verbose "Importing $($pol.PolicyName) $($pol.Type)"
			if ($pol | Get-CtxGroupPolicy -DriveName $DriveName -ea 0)
			{
				Write-Verbose "Updating existing policy $($pol.PolicyName)"
				$pol | Set-CtxGroupPolicy -DriveName $DriveName
			}
			else
			{
				Write-Verbose "Creating new policy $($pol.PolicyName)"
				$pol | New-CtxGroupPolicy -DriveName $DriveName
			}

			$configs | Where-Object { ($_.PolicyName -eq $pol.PolicyName) -and ($_.Type -eq $pol.Type) } |
			Set-CtxGroupPolicyConfiguration -DriveName $DriveName

			foreach ($filter in @($filters | Where-Object { (FilterString $_.PolicyName $pol.PolicyName) -and (FilterString $_.Type $pol.Type) }))
			{
				if ($filter | Get-CtxGroupPolicyFilter -DriveName $DriveName -ea 0)
				{
					Write-Verbose "Updating existing filter $($filter.FilterName)"
					$filter | Set-CtxGroupPolicyFilter -DriveName $DriveName
				}
				else
				{
					Write-Verbose "Creating new filter $($filter.FilterName)"
					$filter | Add-CtxGroupPolicyFilter -DriveName $DriveName
				}
			}
		}
	}
}

<#
    .SYNOPSIS
        Gets group policies.
    .DESCRIPTION
        This cmdlet gets group policies using the Citrix.Common.GroupPolicy provider.
    .PARAMETER  PolicyName
        The policy name.
    .PARAMETER  Type
        The policy type. Allowed values are User and Computer.
    .PARAMETER  DriveName
        An optional drive name. Defaults to LocalFarmGpo.
    .EXAMPLE
        PS C:\> Get-CtxGroupPolicy
        This command gets all the group policies using the LocalFarmGpo drive.
    .EXAMPLE
        PS C:\> Get-CtxGroupPolicy pol*
        This command gets the policies of all types whose names match pol*.
    .INPUTS
        String.
    .OUTPUTS
        Policy object.
    .NOTES
    .LINK
        Set-CtxGroupPolicy
#>
function Get-CtxGroupPolicy
{
	[CmdletBinding()]
	param(
		[Parameter(Position = 0,ValueFromPipelineByPropertyName = $true)]
		[string[]]$PolicyName = "*",
		[Parameter(Position = 1,ValueFromPipelineByPropertyName = $true)]
		[string][ValidateSet("Computer","User",$null)] $Type,
		[Parameter()]
		[string]$DriveName = "LocalFarmGpo"
	)

	process
	{
		$types = if (!$Type) { @("Computer","User") } else { @($Type) }
		foreach ($polType in $types)
		{
			$pols = @(Get-ChildItem "$($DriveName):\$polType" | Where-Object { FilterString $_.Name $PolicyName })
			foreach ($pol in $pols)
			{
				$props = CreateDictionary
				$props.PolicyName = $pol.Name
				$props.Type = $poltype
				$props.Description = $pol.Description
				$props.enabled = $pol.enabled
				$props.Priority = $pol.Priority
				CreateObject $props $pol.Name
			}
		}
	}
}

<#
    .SYNOPSIS
        Gets group policy configurations.
    .DESCRIPTION
        This cmdlet gets group policy configurations using the Citrix.Common.GroupPolicy provider.
    .PARAMETER  PolicyName
        The policy name.
    .PARAMETER  Type
        The policy type. Allowed values are User and Computer.
    .PARAMETER  ConfiguredOnly
        List only the configured settings.
    .PARAMETER  DriveName
        An optional drive name. Defaults to LocalFarmGpo.
    .EXAMPLE
        PS C:\> Get-CtxGroupPolicyConfiguration pol1 user
        This command gets the configuration of the user policy pol1.
    .EXAMPLE
        PS C:\> Get-CtxGroupPolicyConfiguration pol* -ConfiguredOnly
        This command gets the active policy configurations of policies of all types whose names match pol*.
    .INPUTS
        String.
    .OUTPUTS
        Policy object.
    .NOTES
    .LINK
        Set-CtxGroupPolicyConfiguration
#>
function Get-CtxGroupPolicyConfiguration
{
	[CmdletBinding()]
	param(
		[Parameter(Position = 0,ValueFromPipelineByPropertyName = $true)]
		[String[]]$PolicyName = "*",
		[Parameter(Position = 1,ValueFromPipelineByPropertyName = $true)]
		[ValidateSet("Computer","User",$null)] [string]$Type,
		[Parameter()]
		[switch]$ConfiguredOnly,
		[Parameter()]
		[string]$DriveName = "LocalFarmGpo"
	)

	process
	{
		$types = if (!$Type) { @("Computer","User") } else { @($Type) }
		foreach ($poltype in $types)
		{
			$pols = @(Get-ChildItem "$($DriveName):\$poltype" | Where-Object { FilterString $_.Name $PolicyName })
			foreach ($pol in $pols)
			{
				$props = CreateDictionary
				$props.PolicyName = $pol.Name
				$props.Type = $poltype

				foreach ($setting in @(Get-ChildItem "$($DriveName):\$poltype\$($pol.Name)\Settings" -Recurse |
						Where-Object { $_.State -ne $null }))
				{
					if (!$ConfiguredOnly -or $setting.State -ne "NotConfigured")
					{
						$setname = $setting.PSChildName
						$config = CreateDictionary
						$config.State = $setting.State.ToString()
						if ($setting.Values -ne $null) { $config.Values = ([array]($setting.Values)) }
						if ($setting.value -ne $null) { $config.value = ([string]($setting.value)) }
						$config.path = $setting.PSPath.Substring($setting.PSPath.IndexOf("\Settings\") + 10)
						$props.$setname = CreateObject $config
					}
				}
				CreateObject $props $pol.Name
			}
		}
	}
}

<#
    .SYNOPSIS
        Gets group policy filters.
    .DESCRIPTION
        This cmdlet gets group policy filters using the Citrix.Common.GroupPolicy provider.
    .PARAMETER  PolicyName
        The policy name.
    .PARAMETER  Type
        The policy type. Allowed values are User and Computer.
    .PARAMETER  FilterName
        The policy filter name.
    .PARAMETER  FilterType
        The policy filter type.
    .PARAMETER  DriveName
        An optional drive name. Defaults to LocalFarmGpo.
    .EXAMPLE
        PS C:\> Get-CtxGroupPolicyFilter
        This command gets all the group policy filters using the LocalFarmGpo drive.
    .EXAMPLE
        PS C:\> Get-CtxGroupPolicyFilter pol1 user
        This command gets the policy filters of the user policy pol1.
    .INPUTS
        String.
    .OUTPUTS
        Policy object.
    .NOTES
    .LINK
        Set-CtxGroupPolicyFilter
        Add-CtxGroupPolicyFilter
        Remove-CtxGroupPolicyFilter
#>
function Get-CtxGroupPolicyFilter
{
	[CmdletBinding()]
	param(
		[Parameter(Position = 0,ValueFromPipelineByPropertyName = $true)]
		[String[]]$PolicyName = "*",
		[Parameter(Position = 1,ValueFromPipelineByPropertyName = $true)]
		[ValidateSet("Computer","User",$null)] [string]$Type,
		[Parameter(Position = 2,ValueFromPipelineByPropertyName = $true)]
		[String[]]$FilterName = "*",
		[Parameter(Position = 3,ValueFromPipelineByPropertyName = $true)]
		[string]$FilterType = "*",
		[Parameter()]
		[string]$DriveName = "LocalFarmGpo"
	)

	process
	{
		$types = if (!$Type) { @("Computer","User") } else { @($Type) }
		foreach ($poltype in $types)
		{
			$pols = @(Get-ChildItem "$($DriveName):\$poltype" | Where-Object { ($_.Name -ne "Unfiltered") -and (FilterString $_.Name $PolicyName) })
			foreach ($pol in $pols)
			{
				foreach ($filter in @(Get-ChildItem "$($DriveName):\$poltype\$($pol.Name)\Filters" -Recurse |
						Where-Object { ($_.FilterType -ne $null) -and (FilterString $_.Name $FilterName) -and (FilterString $_.FilterType $FilterType) }))
				{
					$props = CreateDictionary
					$props.PolicyName = $pol.Name
					$props.Type = $poltype
					$props.FilterName = $filter.Name
					$props.FilterType = $filter.FilterType
					$props.enabled = $filter.enabled
					$props.Mode = [string]($filter.Mode)
					$props.FilterValue = $filter.FilterValue
					if ($filter.FilterType -eq "AccessControl")
					{
						$props.ConnectionType = $filter.ConnectionType
						$props.AccessGatewayFarm = $filter.AccessGatewayFarm
						$props.AccessCondition = $filter.AccessCondition
					}
					CreateObject $props $filter.Name
				}
			}
		}
	}
}

<#
    .SYNOPSIS
        Creates group policies.
    .DESCRIPTION
        This cmdlet creates group policies using the Citrix.Common.GroupPolicy provider.
    .PARAMETER  PolicyName
        The policy name.
    .PARAMETER  Type
        The policy type. Allowed values are User and Computer.
    .PARAMETER  Description
        The policy description.
    .PARAMETER  Enabled
        The enabled status.
    .PARAMETER  Priority
        The priority.
    .PARAMETER  DriveName
        An optional drive name. Defaults to LocalFarmGpo.
    .EXAMPLE
        PS C:\> New-CtxGroupPolicy pol1 user
        This command creates a user policy named pol1.
    .INPUTS
        String.
    .OUTPUTS
        Policy object.
    .NOTES
    .LINK
        Set-CtxGroupPolicy
        Remove-CtxGroupPolicy
#>
function New-CtxGroupPolicy
{
	[CmdletBinding(SupportsShouldProcess = $true)]
	param(
		[Parameter(Position = 0,Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
		[string]$PolicyName,
		[Parameter(Position = 1,Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
		[string][ValidateSet("Computer","User")] $Type,
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[string]$Description,
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[Boolean]$Enabled,
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[int]$Priority,
		[Parameter()]
		[string]$DriveName = "LocalFarmGpo"
	)

	process
	{
		$params = $PSCmdlet.MyInvocation.BoundParameters
		if ($PsCmdlet.ShouldProcess($PolicyName))
		{
			$item = New-Item "$($DriveName):\$Type\$PolicyName"
			foreach ($prop in "Description","Enabled","Priority")
			{
				if ($params.ContainsKey($prop)) { Set-ItemProperty "$($DriveName):\$Type\$PolicyName" $prop $params.$prop }
			}
			Get-CtxGroupPolicy $PolicyName $Type -DriveName $DriveName
		}
	}
}

<#
    .SYNOPSIS
        Sets group policies.
    .DESCRIPTION
        This cmdlet sets group policy properties using the Citrix.Common.GroupPolicy provider.
    .PARAMETER  PolicyName
        The policy name.
    .PARAMETER  Type
        The policy type. Allowed values are User and Computer.
    .PARAMETER  Description
        The policy description.
    .PARAMETER  Enabled
        The enabled status.
    .PARAMETER  Priority
        The priority.
    .PARAMETER  DriveName
        An optional drive name. Defaults to LocalFarmGpo.
    .PARAMETER  Passthru
        To output the object processed.
    .EXAMPLE
        PS C:\> Set-CtxGroupPolicy pol1 user -Description test
        This command sets the description of the user policy pol1.
    .INPUTS
        String.
    .OUTPUTS
        Policy object.
    .NOTES
    .LINK
        New-CtxGroupPolicy
        Remove-CtxGroupPolicy
#>
function Set-CtxGroupPolicy
{
	[CmdletBinding(SupportsShouldProcess = $true)]
	param(
		[Parameter(Position = 0,Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
		[String[]]$PolicyName,
		[Parameter(Position = 1,Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
		[string][ValidateSet("Computer","User")] $Type,
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[string]$Description,
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[Boolean]$Enabled,
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[int]$Priority,
		[Parameter()]
		[string]$DriveName = "LocalFarmGpo",
		[Parameter()]
		[switch]$Passthru
	)

	process
	{
		$params = $PSCmdlet.MyInvocation.BoundParameters
		$pols = Get-CtxGroupPolicy $PolicyName $Type -DriveName $DriveName

		foreach ($pol in $pols)
		{
			if ($PsCmdlet.ShouldProcess($pol.PolicyName))
			{
				foreach ($prop in "Description","Enabled","Priority")
				{
					if ($params.ContainsKey($prop) -and ($pol.$prop -ne $params.$prop))
					{
						Write-Verbose ("Setting {0} to {1}" -f $prop,$params.$prop)
						Set-ItemProperty "$($DriveName):\$Type\$($pol.PolicyName)" $prop $params.$prop
					}
				}
				if ($Passthru) { Get-CtxGroupPolicy $($pol.PolicyName) -Type $Type -DriveName $DriveName }
			}
		}
	}
}

<#
    .SYNOPSIS
        Removes group policies.
    .DESCRIPTION
        This cmdlet removes group policy properties using the Citrix.Common.GroupPolicy provider.
    .PARAMETER  PolicyName
        The policy name.
    .PARAMETER  Type
        The policy type. Allowed values are User and Computer.
    .PARAMETER  DriveName
        An optional drive name. Defaults to LocalFarmGpo.
    .PARAMETER  Passthru
        To output the object processed.
    .EXAMPLE
        PS C:\> Remove-CtxGroupPolicy pol1 user
        This command removes the user policy pol1.
    .INPUTS
        String.
    .OUTPUTS
        Policy object.
    .NOTES
    .LINK
        New-CtxGroupPolicy
        Set-CtxGroupPolicy
#>
function Remove-CtxGroupPolicy
{
	[CmdletBinding(SupportsShouldProcess = $true)]
	param(
		[Parameter(Position = 0,Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
		[String[]]$PolicyName,
		[Parameter(Position = 1,Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
		[string][ValidateSet("Computer","User")] $Type,
		[Parameter()]
		[string]$DriveName = "LocalFarmGpo",
		[Parameter()]
		[switch]$Passthru
	)

	process
	{
		$pols = @(Get-CtxGroupPolicy $PolicyName $Type -DriveName $DriveName)
		foreach ($pol in $pols)
		{
			if ($PSCmdlet.ShouldProcess($pol.PolicyName))
			{
				Remove-Item "$($DriveName):\$Type\$($pol.PolicyName)" -Recurse -Force
				if ($Passthru) { $pol }
			}
		}
	}
}

<#
    .SYNOPSIS
        Sets group policy configurations.
    .DESCRIPTION
        This cmdlet sets group policy configurations using the Citrix.Common.GroupPolicy provider.
    .PARAMETER  PolicyName
        The policy name.
    .PARAMETER  Type
        The policy type. Allowed values are User and Computer.
    .PARAMETER  Setting
        The setting name.
    .PARAMETER  State
        The setting state. Allowed values are Enabled, Disabled, NotConfigured, Allowed, Prohibited and UseDefault
    .PARAMETER  Value
        The setting value.
    .PARAMETER  InputObject
        The policy configuration object to update.
    .PARAMETER  DriveName
        An optional drive name. Defaults to LocalFarmGpo.
    .PARAMETER  Passthru
        To output the object processed.
    .EXAMPLE
        PS C:\> SGet-CtxGroupPolicyConfiguration user1 user AllowSpeedFlash Enabled
        This command enables the speed flash configuration for the user policy user1.
    .EXAMPLE
        PS C:\> $obj = Get-CtxGroupPolicyConfiguration user1 user
        PS C:\> $obj.AllowSpeedFlash.State = "Enabled"
        PS C:\> Set-CtxGroupPolicyConfiguration $obj
        This command enables the speed flash configuration for the user policy user1.
    .INPUTS
        Object.
    .OUTPUTS
        Policy object.
    .NOTES
    .LINK
        Get-CtxGroupPolicyConfiguration
#>
function Set-CtxGroupPolicyConfiguration
{
	[CmdletBinding(SupportsShouldProcess = $true)]
	param(
		[Parameter(ParameterSetName = "Config",Position = 0,Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
		[String[]]$PolicyName,
		[Parameter(ParameterSetName = "Config",Position = 1,Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
		[string][ValidateSet("Computer","User")] $Type,
		[Parameter(ParameterSetName = "Config",Position = 2,Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
		[string]$ConfigurationName,
		[Parameter(ParameterSetName = "Config",Position = 3,ValueFromPipelineByPropertyName = $true)]
		[string][ValidateSet("Enabled","Disabled","NotConfigured","Allowed","Prohibited","UseDefault")] $State,
		[Parameter(ParameterSetName = "Config",Position = 4,ValueFromPipelineByPropertyName = $true)]
		[string]$Value,
		[Parameter(ParameterSetName = "Object",Position = 0,Mandatory = $true,ValueFromPipeline = $true)]
		[psobject]$InputObject,
		[Parameter()]
		[string]$DriveName = "LocalFarmGpo",
		[Parameter()]
		[switch]$Passthru
	)

	process
	{
		Write-Verbose "ParameterSetName=$($PSCmdlet.ParameterSetName)"
		if ($PSCmdlet.ParameterSetName -eq "Object")
		{
			$obj = $InputObject
			$PolicyName = $obj.PolicyName
			$poltype = $obj.Type

			if ($PsCmdlet.ShouldProcess($PolicyName))
			{
				$current = $obj | Get-CtxGroupPolicyConfiguration -DriveName $DriveName
				if ($current -eq $null) { throw "Policy not found" }

				$ConfigurationObject = CompareObject $obj $current
				if ($ConfigurationObject -ne $null)
				{
					foreach ($prop in @($ConfigurationObject | Get-Member -Type Properties | Select-Object -Expand Name))
					{
						Write-Verbose "Processing setting $prop"
						$config = $ConfigurationObject.$prop
						$path = $config.path
						$state = $config.State.ToString()
						if ($state -ne "NotConfigured")
						{
							if ($config.Values -ne $null)
							{ Set-ItemProperty "$($DriveName):\$poltype\$PolicyName\Settings\$path" Values ([object[]]($config.Values)) }
							if ($config.value -ne $null)
							{ Set-ItemProperty "$($DriveName):\$poltype\$PolicyName\Settings\$path" Value ([string]($config.value)) }
						}
						Set-ItemProperty "$($DriveName):\$poltype\$PolicyName\Settings\$path" State $state
					}
				}
				if ($Passthru) { $obj | Get-CtxGroupPolicyConfiguration -ConfiguredOnly -DriveName $DriveName }
			}
		}
		else
		{
			if ($PsCmdlet.ShouldProcess($PolicyName))
			{
				$pol = Get-CtxGroupPolicy $PolicyName $Type -ea Stop
				$setting = Get-ChildItem "$($DriveName):\$Type\unfiltered\Settings" -Recurse | Where-Object { ($_.State -ne $null) -and ($_.PSChildName -eq $ConfigurationName) }
				if ($setting -eq $null)
				{
					throw "Invalid configuration name"
				}
				$path = $setting.PSPath.Substring($setting.PSPath.IndexOf("\Settings\") + 10)
				if ($State)
				{ Set-ItemProperty "$($DriveName):\$Type\$PolicyName\Settings\$path" State $state }
				if ($Value)
				{ Set-ItemProperty "$($DriveName):\$Type\$PolicyName\Settings\$path" Value $value }
				if ($Passthru) { Get-CtxGroupPolicyConfiguration $PolicyName $Type -ConfiguredOnly -DriveName $DriveName }
			}
		}
	}
}

<#
    .SYNOPSIS
        Sets group policy filters.
    .DESCRIPTION
        This cmdlet sets group policy filters using the Citrix.Common.GroupPolicy provider.
    .PARAMETER  PolicyName
        The policy name.
    .PARAMETER  Type
        The policy type. Allowed values are User and Computer.
    .PARAMETER  FilterName
        The policy filter name.
    .PARAMETER  FilterType
        The policy filter type.
    .PARAMETER  FilterValue
        The policy filter value.
    .PARAMETER  Enabled
        The enabled state.
    .PARAMETER  Mode
        The policy filter mode. Allowed values are Allow and Deny.
    .PARAMETER  DriveName
        An optional drive name. Defaults to LocalFarmGpo.
    .EXAMPLE
        PS C:\> Set-CtxGroupPolicyFilter pol1 user filter1 workergroup wg1
        This command sets the worker group filter filter1 to wg1 for user policy pol1.
    .INPUTS
        String.
    .OUTPUTS
        Policy object.
    .NOTES
    .LINK
        Get-CtxGroupPolicyFilter
        Add-CtxGroupPolicyFilter
        Remove-CtxGroupPolicyFilter
#>
function Set-CtxGroupPolicyFilter
{
	[CmdletBinding(SupportsShouldProcess = $true)]
	param(
		[Parameter(Position = 0,Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
		[string]$PolicyName,
		[Parameter(Position = 1,Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
		[string][ValidateSet("Computer","User")] $Type,
		[Parameter(Position = 2,Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
		[string]$FilterName,
		[Parameter(Position = 3,Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
		[string]$FilterType,
		[Parameter(Position = 4,Mandatory = $false,ValueFromPipelineByPropertyName = $true)]
		[string]$FilterValue,
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[string]$Enabled,
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[string][ValidateSet("Allow","Deny")] $Mode,
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[string]$AccessGatewayFarm,
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[string]$AccessCondition,
		[Parameter()]
		[string]$DriveName = "LocalFarmGpo",
		[Parameter()]
		[switch]$Passthru
	)

	process
	{
		$params = $PSCmdlet.MyInvocation.BoundParameters
		$filters = Get-CtxGroupPolicyFilter $PolicyName $Type $FilterName $FilterType -DriveName $DriveName -ErrorAction Stop

		if ($PsCmdlet.ShouldProcess($FilterName))
		{
			if ($FilterType -eq "AccessControl" -or $FilterType -eq "BranchRepeater")
			{
				Write-Verbose "it is an access control filter named $FilterName"
				#$item = New-Item "$($DriveName):\$Type\$PolicyName\Filters\$FilterType\$FilterName"
			}
			else
			{
				Write-Verbose "Filter named $FilterName with a value of $FilterValue"
				#$item = New-Item "$($DriveName):\$Type\$PolicyName\Filters\$FilterType\$FilterName" $FilterValue -ErrorAction Stop
				if ($filtertype -eq "ClientIP")
				{
					$item = Set-Item "$($DriveName):\$Type\$PolicyName\Filters\$FilterType\$FilterName" $FilterValue
				}
				else
				{
					$item = Set-Item -Path "$($DriveName):\$Type\$PolicyName\Filters" -Name $filtervalue -ItemType $filtertype
				}

			}

			foreach ($prop in "Enabled","Mode","AccessGatewayFarm","AccessCondition","ConnectionType")
			{
				if ($params.ContainsKey($prop))
				{
					Write-Verbose "$prop :  $($params.$prop) $FilterType"
					#Set-ItemProperty "$($DriveName):\$Type\$PolicyName\Filters\$FilterType\$FilterName" $prop $params.$prop
					if ($FilterType -ne "BranchRepeater" -and $FilterType -ne "AccessControl" -and $FilterType -ne "ClientIP")
					{
						Set-ItemProperty -Path "$($DriveName):\$Type\$PolicyName\Filters\$FilterType\$FilterValue" -Name $prop -Value $params.$prop
					}
					else
					{
						Set-ItemProperty "$($DriveName):\$Type\$PolicyName\Filters\$FilterType\$FilterName" -Name $prop -Value $params.$prop
					}
				}
			}

			if ($Passthru) { Get-CtxGroupPolicyFilter $PolicyName $FilterName -Type $Type -DriveName $DriveName }
		}
	}

}

<#
    .SYNOPSIS
        Adds group policy filters.
    .DESCRIPTION
        This cmdlet adds group policy filters using the Citrix.Common.GroupPolicy provider.
    .PARAMETER  PolicyName
        The policy name.
    .PARAMETER  Type
        The policy type. Allowed values are User and Computer.
    .PARAMETER  FilterName
        The policy filter name.
    .PARAMETER  FilterType
        The policy filter type.
    .PARAMETER  FilterValue
        The policy filter value.
    .PARAMETER  Enabled
        The enabled state.
    .PARAMETER  Mode
        The policy filter mode. Allowed values are Allow and Deny.
    .PARAMETER  DriveName
        An optional drive name. Defaults to LocalFarmGpo.
    .EXAMPLE
        PS C:\> Add-CtxGroupPolicyFilter pol1 user filter1 workergroup wg1
        This command adds the worker group filter filter1 with value wg1 for user policy pol1.
    .INPUTS
        String.
    .OUTPUTS
        Policy object.
    .NOTES
    .LINK
        Get-CtxGroupPolicyFilter
        Set-CtxGroupPolicyFilter
        Remove-CtxGroupPolicyFilter
#>
function Add-CtxGroupPolicyFilter
{
	[CmdletBinding(SupportsShouldProcess = $true)]
	param(
		[Parameter(Position = 0,Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
		[string]$PolicyName,
		[Parameter(Position = 1,Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
		[string][ValidateSet("Computer","User")] $Type,
		[Parameter(Position = 2,Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
		[string]$FilterName,
		[Parameter(Position = 3,Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
		[string]$FilterType,
		[Parameter(Position = 4,Mandatory = $false,ValueFromPipelineByPropertyName = $true)]
		[string]$FilterValue = "",
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[string]$Enabled,
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[string][ValidateSet("Allow","Deny")] $Mode,
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[string]$AccessGatewayFarm,
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[string]$AccessCondition,
		[Parameter()]
		[string]$DriveName = "LocalFarmGpo"
	)

	process
	{
		$params = $PSCmdlet.MyInvocation.BoundParameters
		if ($PsCmdlet.ShouldProcess($FilterName))
		{
			if ($FilterType -eq "AccessControl" -or $FilterType -eq "BranchRepeater")
			{
				Write-Verbose "it is an access control filter named $FilterName"
				$item = New-Item "$($DriveName):\$Type\$PolicyName\Filters\$FilterType\$FilterName"
			}
			else
			{
				Write-Verbose "Filter named $FilterName with a value of $FilterValue"
				#$item = New-Item "$($DriveName):\$Type\$PolicyName\Filters\$FilterType\$FilterName" $FilterValue -ErrorAction Stop
				if ($filtertype -eq "ClientIP")
				{
					$item = New-Item "$($DriveName):\$Type\$PolicyName\Filters\$FilterType\$FilterName" $FilterValue
				}
				else
				{
					$item = New-Item -Path "$($DriveName):\$Type\$PolicyName\Filters" -Name $filtervalue -ItemType $filtertype
				}


			}

			foreach ($prop in "Enabled","Mode","AccessGatewayFarm","AccessCondition","ConnectionType")
			{
				if ($params.ContainsKey($prop))
				{
					Write-Verbose "$prop :  $($params.$prop)"
					#Set-ItemProperty "$($DriveName):\$Type\$PolicyName\Filters\$FilterType\$FilterName" $prop $params.$prop
					if ($FilterType -ne "BranchRepeater" -and $FilterType -ne "AccessControl" -and $FilterType -ne "ClientIP")
					{
						Set-ItemProperty -Path "$($DriveName):\$Type\$PolicyName\Filters\$FilterType\$FilterValue" -Name $prop -Value $params.$prop
					}
					else
					{
						Set-ItemProperty "$($DriveName):\$Type\$PolicyName\Filters\$FilterType\$FilterName" -Name $prop -Value $params.$prop
					}
				}
			}
			Get-CtxGroupPolicyFilter $PolicyName $FilterName -Type $Type -DriveName $DriveName
		}
	}
}

<#
    .SYNOPSIS
        Removes group policy filters.
    .DESCRIPTION
        This cmdlet removes group policy filters using the Citrix.Common.GroupPolicy provider.
    .PARAMETER  PolicyName
        The policy name.
    .PARAMETER  Type
        The policy type. Allowed values are User and Computer.
    .PARAMETER  FilterName
        The policy filter name.
    .PARAMETER  FilterType
        The policy filter type.
    .PARAMETER  DriveName
        An optional drive name. Defaults to LocalFarmGpo.
    .EXAMPLE
        PS C:\> Remove-CtxGroupPolicyFilter pol1 user filter1 workergroup
        This command removes the filter filter1 from user policy pol1.
    .INPUTS
        String.
    .OUTPUTS
        Policy object.
    .NOTES
    .LINK
        Get-CtxGroupPolicyFilter
        Add-CtxGroupPolicyFilter
        Set-CtxGroupPolicyFilter
#>
function Remove-CtxGroupPolicyFilter
{
	[CmdletBinding(SupportsShouldProcess = $true)]
	param(
		[Parameter(Position = 0,Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
		[String[]]$PolicyName,
		[Parameter(Position = 1,Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
		[ValidateSet("Computer","User")] [string]$Type,
		[Parameter(Position = 2,Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
		[String[]]$FilterName,
		[Parameter(Position = 3,Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
		[string]$FilterType,
		[Parameter()]
		[string]$DriveName = "LocalFarmGpo",
		[Parameter()]
		[switch]$Passthru
	)

	process
	{
		$filters = Get-CtxGroupPolicyFilter $PolicyName $Type $FilterName $FilterType -DriveName $DriveName -ErrorAction Stop
		foreach ($filter in $filters)
		{
			if ($PSCmdlet.ShouldProcess($filter.FilterName))
			{
				Remove-Item "$($DriveName):\$Type\$PolicyName\Filters\$FilterType\$FilterName"
				if ($Passthru) { $filter }
			}
		}
	}
}

#############################################

function FilterString
{
	param([string]$value,[string[]]$wildcards)

	$wildcards | Where-Object { $value -like $_ }
}

function CreateDictionary
{
	return New-Object "System.Collections.Generic.Dictionary``2[System.String,System.Object]"
}

function CreateObject
{
	param([System.Collections.IDictionary]$props,[string]$name)

	$obj = New-Object PSObject
	foreach ($prop in $props.Keys)
	{
		$obj | Add-Member NoteProperty -Name $prop -Value $props.$prop
	}
	if ($name)
	{
		$obj | Add-Member ScriptMethod -Name "ToString" -Value $executioncontext.invokecommand.NewScriptBlock('"{0}"' -f $name) -Force
	}
	return $obj
}

function CompareObject
{
	param([psobject]$NewObject,[psobject]$CurrentObject)

	$props = CreateDictionary

	$oldprops = $CurrentObject | Get-Member -MemberType Properties | Select-Object -Expand Name
	$newprops = $NewObject | Get-Member -MemberType Properties | Select-Object -Expand Name
	foreach ($prop in $newprops)
	{
		if ($oldprops -contains $prop)
		{
			if (-not (AreValuesEqual $prop $NewObject.$prop $CurrentObject.$prop))
			{
				$props.$prop = $NewObject.$prop
			}
		}
	}
	if ($props.Keys.Count -gt 0)
	{
		CreateObject $props
	}
}

function AreValuesEqual
{
	param($prop,$new,$old)

	if ($new -eq $null) { return $true }
	if ($old -eq $null) { return $false }

	if ($new -is [array])
	{
		return (Compare-Object $new $old | Measure-Object).Count -eq 0
	}
	if ($new -is [psobject])
	{
		return (CompareObject $new $old) -eq $null
	}
	$equal = $new -eq $old
	if ($prop -eq "State")
	{
		switch ($new)
		{
			"Enabled" { $equal = "Enabled","Allowed" -contains $old }
			"Disabled" { $equal = "Disabled","Prohibited","UseDefault" -contains $old }
		}
	}
	return $equal
}

#################################

Export-ModuleMember -Function "*-*"
