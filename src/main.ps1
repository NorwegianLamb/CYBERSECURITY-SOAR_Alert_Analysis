<#
Author: Flavio Gjoni
Status: IN-PROGRESS
Description: Parsing a CSV file, cleaning it (need to add the handling for missing values and so on),
and retrieving users' properties from the ADUC to check for SUSPICIOUS cybersecurity alarms
#>

# This function is responsible for loading and preprocessing the CSV file and using the email to get the country code
function Load-Csv {
    param (
        [string]$filePath
    )

    # Countries list to be mapped
    $countryCodeMapping = @{
    	'Germany' = 'DE'
    	'Italy' = 'IT'
    	'France' = 'FR'
    	'United Kingdom' = 'UK'
    	'Spain' = 'ES'
    	'Portugal' = 'PT'
    	'Ireland' = 'IE'
    	'Bulgaria' = 'BG'
        'Nigeria' = ''
    	# ... add manually
    }

    function Get-CountryCode {
        param (
            [string]$countryName
        )

        if ($countryName.Length -eq 2) {
            return $countryName
        } else {
            return $countryCodeMapping[$countryName]
        }
    }

    try {
        $allLines = Get-Content -Path $filePath

        $headers = $allLines[0] -split ';'
        $dataRows = $allLines | Select-Object -Skip 1

        $selectedColumns = @('@timestamp', 'source.ip', 'source.user.email', 'watcher.state', 'source.geo.country_name')

        $csvData = Import-Csv -Path $filePath
        $csvData = $dataRows | ForEach-Object {
            $data = $_ -split ';'
            $properties = [ordered]@{}
            for ($i = 0; $i -lt $headers.Length; $i++) {
                if ($headers[$i] -in $selectedColumns) {
                    $properties[$headers[$i]] = $data[$i]
                }
            }

            if ($properties['source.user.email']) {
                $adUser = Get-ADUser -Filter "mail -eq '$($properties['source.user.email'])'" -Properties co -ErrorAction SilentlyContinue
                if ($adUser) {
                    $properties['ADCountryName'] = $adUser.co
                } else {
                    # Extract the user logon name (name.surname) part from the email
                    $userLogonName = $properties['source.user.email'] -split "@" | Select-Object -First 1
            
                    # Attempt to find a user by user logon name
                    $adUser = Get-ADUser -Filter "SamAccountName -eq '$userLogonName'" -Properties co -ErrorAction SilentlyContinue
            
                    if ($adUser) {
                        $properties['ADCountryName'] = $adUser.co
                    } else {
                        $properties['ADCountryName'] = 'Manual'
                    }
                }
            } else {
                $properties['ADCountryName'] = 'No Email'
            }
            
            if ($properties['ADCountryName'] -eq 'Manual') {
                $properties['CountryMatched'] = 'Manual'
            } elseif ($properties['ADCountryName'] -eq 'Not Found' -or $properties['ADCountryName'] -eq 'No Email') {
                $properties['CountryMatched'] = $properties['ADCountryName']
            } else {
                $sourceCountryCode = Get-CountryCode -countryName $properties['source.geo.country_name']
                $adCountryCode = Get-CountryCode -countryName $properties['ADCountryName']
            
                if ($sourceCountryCode -eq $adCountryCode -or $properties['source.geo.country_name'] -eq $properties['ADCountryName']) {
                    $properties['CountryMatched'] = 'Match'
                } else {
                    $properties['CountryMatched'] = 'Not Match'
                }
            }                        

            New-Object -TypeName PSObject -Property $properties
        }

        return $csvData
    } catch {
        Write-Host "Error loading CSV file: $_"
        return $null
    }
}

# This function processes and displays information about the loaded CSV data
function Process-Data {
    param (
        [object]$df
    )

    $rowCount = ($df | Measure-Object).Count
    Write-Host "Rows: $rowCount"
    
    $df | Select-Object -Property '@timestamp', 'source.ip', 'source.user.email', 'watcher.state', 'source.geo.country_name', 'ADCountryName', 'CountryMatched' | Format-Table -AutoSize | Out-String -Width 2048 | Write-Host
}

# Entry point, it loads the CSV file and after it has been processed it saves the new DF into 2 csv(s)
function Main {
    $csvFile = 'path_to\alerts.csv' # Insert own path to alerts.csv
    $df = Load-Csv -filePath $csvFile

    if ($null -eq $df) {
        return
    }

    Process-Data -df $df

    $df | Export-Csv -Path 'path_to\filtered_alerts_all.csv' -NoTypeInformation
    $dfNotMatchAndManual = $df | Where-Object { $_.CountryMatched -eq 'Not Match' -or $_.CountryMatched -eq 'Manual' }
    $dfNotMatchAndManual | Export-Csv -Path 'path_to\filtered_alerts_notMatch.csv' -NoTypeInformation

    Write-Host "Export completed"
}


# Calling the entry point
Main