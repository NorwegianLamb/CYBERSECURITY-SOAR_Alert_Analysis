function Load-Csv {
    param (
        [string]$filePath
    )

    # Da mappare lista countries
    $countryCodeMapping = @{
    	'Germany' = 'DE'
    	'Italy' = 'IT'
    	'France' = 'FR'
    	'United Kingdom' = 'UK'
    	'Spain' = 'ES'
    	'Portugal' = 'PT'
    	'Ireland' = 'IE'
    	'Bulgaria' = 'BG'
    	# ... aggiungere manualmente per il momento
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

        $headers = $allLines[1] -split ';'
        $dataRows = $allLines | Select-Object -Skip 2

        $selectedColumns = @('@timestamp', 'source.ip', 'source.user.email', 'watcher.state', 'source.geo.country_name')

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
                    $properties['ADCountryName'] = 'Not Found'
                }
            } else {
                $properties['ADCountryName'] = 'No Email'
            }

            $sourceCountryCode = Get-CountryCode -countryName $properties['source.geo.country_name']
            $adCountryCode = Get-CountryCode -countryName $properties['ADCountryName']

            if ($sourceCountryCode -eq $adCountryCode -or $properties['source.geo.country_name'] -eq $properties['ADCountryName']) {
                $properties['CountryMatched'] = 'Match'
            } else {
                $properties['CountryMatched'] = 'Not Match'
            }

            New-Object -TypeName PSObject -Property $properties
        }

        return $csvData
    } catch {
        Write-Host "Error loading CSV file: $_"
        return $null
    }
}


function Process-Data {
    param (
        [object]$df
    )

    $rowCount = ($df | Measure-Object).Count
    Write-Host "Rows: $rowCount"
    
    $df | Select-Object -Property '@timestamp', 'source.ip', 'source.user.email', 'watcher.state', 'source.geo.country_name', 'ADCountryName', 'CountryMatched' | Format-Table -AutoSize | Out-String -Width 2048 | Write-Host
}



function Main {
    $csvFile = 'path_to_alerts.csv' # INSERIRE IL PROPRIO PERCORSO
    $df = Load-Csv -filePath $csvFile

    if ($null -eq $df) {
        return
    }

    Process-Data -df $df

    $df | Export-Csv -Path 'path_to_filtered_alerts_all.csv' -NoTypeInformation

    $dfNotMatch = $df | Where-Object { $_.CountryMatched -eq 'Not Match' }

    $dfNotMatch | Export-Csv -Path 'path_to_filtered_alerts_notMatch.csv' -NoTypeInformation

    Write-Host "Export completato."
}

# Entry Point
Main