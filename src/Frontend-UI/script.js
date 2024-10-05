import { BlobServiceClient } from '@azure/storage-blob';

// Replace with your actual SAS token
const sasToken = $(sasToken); // Update with your SAS token
const accountName = "umobsagbfs"; // Your storage account name
const containerName = "vehicle-data";

// console.log(sasToken);

// app.get('/', (req, res) => {
//     const sasToken = process.env.Storage_SAS; // Access the environment variable
//     res.send(`
//         <html>
//             <head>
//                 <title>SAS Token Example</title>
//                 <script>
//                     const sasToken = '${sasToken}'; // Pass the SAS token to client-side JavaScript
//                     console.log('SAS Token:', sasToken);
//                 </script>
//             </head>
//             <body>
//                 <h1>SAS Token is: ${sasToken ? sasToken : 'undefined'}</h1>
//             </body>
//         </html>
//     `);
// });

const providerSelect = document.getElementById("provider-select");
const dateSelect = document.getElementById("date-select");
const filesList = document.getElementById("files");
const currentProviderElement = document.getElementById("current-provider");
const currentDateElement = document.getElementById("current-date");
const currentFileElement = document.getElementById("current-file");
const dashboardBody = document.getElementById("dashboard-body");

let providers = [];
let dates = [];

// Create a BlobServiceClient using SAS token
const blobServiceClient = new BlobServiceClient(
    `https://${accountName}.blob.core.windows.net?${sasToken}`
);

async function fetchProviders() {
    try {
        const containerClient = blobServiceClient.getContainerClient(containerName);
        const blobs = containerClient.listBlobsFlat();

        const providerSet = new Set();
        for await (const blob of blobs) {
            console.log(`Blob name: ${blob.name}`); // Debug log
            const parts = blob.name.split('/');
            if (parts.length > 1) {
                // Ensure that we're capturing the correct provider name
                const provider = parts[0]; // Assuming provider is the first part
                providerSet.add(provider); // Add the provider to the set
            }
        }

        providers = Array.from(providerSet);
        console.log(`Providers: ${providers}`); // Debug log
        populateProviderSelect();
    } catch (error) {
        console.error('Error fetching providers:', error);
    }
}


function populateProviderSelect() {
    providerSelect.innerHTML = ""; // Clear existing options
    providers.forEach(provider => {
        const option = document.createElement("option");
        option.value = provider;
        option.textContent = provider;
        providerSelect.appendChild(option);
    });

    providerSelect.onchange = fetchDates;
    if (providers.length > 0) {
        providerSelect.value = providers[0]; // Select the first provider
        fetchDates(); // Fetch dates for the first provider
    } else {
        console.warn("No providers available.");
    }
}

async function fetchDates() {
    try {
        const selectedProvider = providerSelect.value;
        const containerClient = blobServiceClient.getContainerClient(containerName);
        const blobs = containerClient.listBlobsFlat({ prefix: `${selectedProvider}/` });

        const dateSet = new Set();
        for await (const blob of blobs) {
            console.log(`Blob name for dates: ${blob.name}`); // Debug log
            const parts = blob.name.split('/');
            if (parts.length > 2) {
                dateSet.add(parts[1]);
            }
        }

        dates = Array.from(dateSet);
        console.log(`Dates for provider ${selectedProvider}: ${dates}`); // Debug log
        populateDateSelect();
    } catch (error) {
        console.error('Error fetching dates:', error);
    }
}

function populateDateSelect() {
    dateSelect.innerHTML = ""; // Clear existing options
    dates.forEach(date => {
        const option = document.createElement("option");
        option.value = date;
        option.textContent = date;
        dateSelect.appendChild(option);
    });

    dateSelect.onchange = fetchFiles;
    if (dates.length > 0) {
        dateSelect.value = dates[0]; // Select the first date
        fetchFiles(); // Fetch files for the first date
    } else {
        console.warn("No dates available for the selected provider.");
    }
}

async function fetchFiles() {
    const selectedProvider = providerSelect.value;
    const selectedDate = dateSelect.value;
    currentProviderElement.textContent = selectedProvider;
    currentDateElement.textContent = selectedDate;

    const containerClient = blobServiceClient.getContainerClient(containerName);
    const blobs = containerClient.listBlobsFlat({ prefix: `${selectedProvider}/${selectedDate}/` });

    // Clear previous files
    filesList.innerHTML = ""; // Clear existing options

    for await (const blob of blobs) {
        if (blob.name.endsWith(".json")) {
            const option = document.createElement("option");
            const fileName = blob.name.split('/').pop(); // Get only the file name
            option.value = fileName; // Set the blob name (file name) as the option value
            option.textContent = fileName; // Display the file name
            filesList.appendChild(option);
        }
    }

    // Listen for changes in the file dropdown
    filesList.onchange = () => {
        const selectedFile = filesList.value; // This should now be just the file name
        currentFileElement.textContent = selectedFile; // Display the selected file
        fetchFileData(selectedProvider, selectedDate, selectedFile); // Fetch the data for the selected file
    };
    

    // Auto-select the first file if available
    if (filesList.options.length > 0) {
        filesList.selectedIndex = 0; // Select the first file
        currentFileElement.textContent = filesList.options[0].value; // Show the selected file
        fetchFileData(selectedProvider, selectedDate, filesList.options[0].value); // Load its data
    }
}

async function fetchFileData(provider, date, file) {
    const blobClient = blobServiceClient.getContainerClient(containerName).getBlobClient(`${provider}/${date}/${file}`);
    const blobUrl = blobClient.url;

    try {
        console.log(`Fetching blob at: ${blobUrl}`);
        
        // Try fetching directly using fetch
        const response = await fetch(blobUrl);
        if (!response.ok) {
            throw new Error(`Error fetching blob: ${response.statusText}`);
        }

        const data = await response.text(); // Use response.text() if it's a text/JSON blob
        const jsonData = JSON.parse(data);
        updateDashboard(jsonData);
    } catch (error) {
        console.error('Error fetching file data:', error);
        currentFileElement.textContent = "Error fetching file data.";
    }
}


function updateDashboard(data) {
    // Clear existing rows
    dashboardBody.innerHTML = "";

    // Check if data is an array and has items
    if (Array.isArray(data) && data.length > 0) {
        data.forEach(item => {
            const row = document.createElement("tr");
            row.innerHTML = `
                <td>${item.BikeID || 'N/A'}</td>
                <td>${item.Reserved || 'N/A'}</td>
                <td>${item.Disabled || 'N/A'}</td>
                <td>${item.Latitude || 'N/A'}</td>
                <td>${item.Longitude || 'N/A'}</td>
                <td>${item.VehicleTypeID || 'N/A'}</td>
                <td>${item.RentalURI_IOS || 'N/A'}</td>
                <td>${item.RentalURI_Android || 'N/A'}</td>
            `;
            dashboardBody.appendChild(row);
        });
    } else {
        // Handle case where there's no data
        const row = document.createElement("tr");
        row.innerHTML = `<td colspan="6">No data available.</td>`;
        dashboardBody.appendChild(row);
    }
}


// Start the process
fetchProviders().catch(console.error);
