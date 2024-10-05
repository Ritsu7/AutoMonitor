# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' porperty is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

# Fetch the GBFS systems CSV
$csvUrl = "https://raw.githubusercontent.com/MobilityData/gbfs/master/systems.csv"
$csvData = Invoke-RestMethod -Uri $csvUrl -ContentType "text/csv"

# Convert CSV data into a usable format
$providerData = $($csvData | ConvertFrom-Csv)

# Define the IDs of the providers you want to filter
Write-Host "ProviderData = $($providerData.Count)"
$Providers = $env:Providers
$providerIds = @($Providers)

Write-Host "ProviderIDs = $providerIds"

# Iterate through providerData and filter based on providerIds
foreach ($provider in $providerData) {
    $systemId = $provider."System ID".Trim()  # Trim whitespace
    if ($providerIds -match $systemId) {
        # Directly add the name and URL to the selectedProviders array
        $selectedProviders += @($provider.Name, $provider."Auto-Discovery URL")
    }
}

# Debugging output
if ($selectedProviders.Count -eq 0) {
    Write-Host "No matching providers found."
} else {
    Write-Host "Provider Data Found!!"
}
# Function to fetch and process data
function Fetch-VehicleStats {

    for ($i = 0; $i -lt $selectedProviders.Count; $i += 2) {
            Write-Host "Name: $($selectedProviders[$i]), URL: $($selectedProviders[$i + 1])"
 
        # Fetch the JSON data
        try {
            $newJsonData = Invoke-RestMethod -Uri $($selectedProviders[$i + 1])
            $jsonOutput = $newJsonData | ConvertTo-Json -Depth 10

            # Prepare Azure Blob Storage context
            $storageAccountConnectionString = $env:AzureWebJobsStorage # Connection string from App Settings
            $context = New-AzStorageContext -ConnectionString $storageAccountConnectionString

            # Prepare blob name
            $blobName = "$($selectedProviders[$i])/gbfs.json"

            # Check if the blob exists
            $existingBlob = Get-AzStorageBlob -Container 'gbfs-data' -Blob $blobName -Context $context -ErrorAction SilentlyContinue

            

            if ($existingBlob) {
                # Download existing JSON from blob storage
                $tempExistingJsonFilePath = [System.IO.Path]::GetTempFileName() + ".json"
                Get-AzStorageBlobContent -Container 'gbfs-data' -Blob $blobName -Context $context -Destination $tempExistingJsonFilePath

                # Read the existing JSON data
                $existingJsonData = Get-Content -Path $tempExistingJsonFilePath -Raw

                # Normalize both JSON outputs
                $normalizedNewJson = $jsonOutput | ConvertFrom-Json | ConvertTo-Json -Depth 10
                $normalizedExistingJson = $existingJsonData | ConvertFrom-Json | ConvertTo-Json -Depth 10

                # Compare the existing JSON with the new JSON
                if ($normalizedNewJson  -ne $normalizedExistingJson) {
                    Write-Host "New version found, updating the blob."

                    # Save the new JSON output to a temporary file for upload
                    $tempJsonFilePath = [System.IO.Path]::GetTempFileName() + ".json"
                    $jsonOutput | Out-File -FilePath $tempJsonFilePath -Encoding utf8

                    # Upload the new JSON file to Blob Storage
                    Set-AzStorageBlobContent -File $tempJsonFilePath -Container 'gbfs-data' -Blob $blobName -Context $context -Force

                    Write-Host "Data updated and saved to blob storage as $blobName."
                    $uploadNeeded = $true

                    # Clean up temporary files
                    Remove-Item $tempJsonFilePath -Force
                } else {
                    Write-Host "No changes detected. The existing JSON is up to date."
                }

                # Clean up the existing file
                Remove-Item $tempExistingJsonFilePath -Force
            } else {
                Write-Host "Blob does not exist. Uploading new JSON file."

                # Save the new JSON output to a temporary file for upload
                $tempJsonFilePath = [System.IO.Path]::GetTempFileName() + ".json"
                $jsonOutput | Out-File -FilePath $tempJsonFilePath -Encoding utf8

                # Upload the new JSON file to Blob Storage
                Set-AzStorageBlobContent -File $tempJsonFilePath -Container 'gbfs-data' -Blob $blobName -Context $context -Force

                Write-Host "Data saved to blob storage as $blobName."

                $uploadNeeded = $true 

                # Clean up temporary files
                Remove-Item $tempJsonFilePath -Force
            }
        } catch {
            Write-Host "Failed to fetch data: $_"
        }

         # Upload if needed

        if ($uploadNeeded) {
            try {
                # Fetch the GBFS JSON data
                $gbfsResponse = Invoke-RestMethod -Uri $($selectedProviders[$i + 1])
                
                # Initialize the BikeStatus URL variable
                $BikeStatusURL = $null
                
                # Iterate through available languages to find the free_bike_status URL
                foreach ($lang in $gbfsResponse.data.PSObject.Properties.Name) {
                    $endpoints = $gbfsResponse.data.$lang
                    foreach ($endpoint in $endpoints.feeds) {
                        if ($endpoint.name -eq "free_bike_status" -and $endpoint.url) {
                            $BikeStatusURL = $endpoint.url
                            break
                        }
                    }
                    if ($BikeStatusURL) { break }
                }

                if (-not $BikeStatusURL) {
                    Write-Host "No valid vehicle status URL found for $($selectedProviders[$i])"
                    continue
                }

                # Fetch the vehicle data
                $BikeData = Invoke-RestMethod -Uri $BikeStatusURL
                $allStats = @()

                foreach ($VehicleData in $BikeData.data.bikes) {
                    $stats = [PSCustomObject]@{
                        BikeID              = $VehicleData.bike_id
                        Reserved            = $VehicleData.is_reserved
                        Disabled            = $VehicleData.is_disabled
                        Latitude            = $VehicleData.lat
                        Longitude           = $VehicleData.lon
                        VehicleTypeID       = $VehicleData.vehicle_type_id
                        RentalURI_IOS       = $VehicleData.rental_uris.ios
                        RentalURI_Android   = $VehicleData.rental_uris.android
                    }
                    $allStats += $stats
                }

                # Prepare folder path for the blob storage
                $datePath = (Get-Date).ToString("yyyyMMdd") # Current date in YYYYMMDD format
                $providerFolder = $($selectedProviders[$i]) -replace " ", "_" # Replace spaces with underscores for the blob name

                # Prepare the blob name
                $blobName = "$providerFolder/$datePath/VehicleStats_$(Get-Date -Format 'HHmmss').json"

                # Convert the stats to JSON
                $jsonOutput = $allStats | ConvertTo-Json -Depth 10

                # Save to Azure Blob Storage
                $storageAccountConnectionString = $env:AzureWebJobsStorage # Connection string from App Settings
                
                # Upload the JSON to Blob Storage
                $tempJsonFilePath = [System.IO.Path]::GetTempFileName() + ".json" # Create a temporary file for upload
                $jsonOutput | Out-File -FilePath $tempJsonFilePath -Encoding utf8

                # Get the context for the storage account
                $context = New-AzStorageContext -ConnectionString $storageAccountConnectionString

                # Upload the JSON to Blob Storage using PowerShell
                Set-AzStorageBlobContent -File $tempJsonFilePath -Container 'vehicle-data' -Blob $blobName -Context $context

                Write-Host "Data saved to blob storage as $blobName"

                # Clean up temporary file
                Remove-Item $tempJsonFilePath -Force

            } catch {
                Write-Host "Failed to fetch data from $($provider.Name): $_"
            }
        }else {
                Write-Host "GBFS data is still same. Hence no update required."
            }
    }
}

# Main script execution
Fetch-VehicleStats


# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"
