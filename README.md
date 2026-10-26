# Azure Load Balancer Infrastructure with Bicep

This repository provides an Infrastructure as Code (IaC) template using Azure Bicep to deploy a highly available, load-balanced web infrastructure in Azure.

## 📐 Architecture Overview

The deployment provisions the following resources within a single Azure Resource Group:

* **Virtual Network (`VNet-srv-lb-001`)**: `10.0.0.0/16` with a backend subnet `10.0.1.0/24`.
* **Network Security Group (`NSG-srv-lb-001`)**: Secures incoming traffic, allowing:
  * **HTTP (Port 80)**: For public web access.
  * **RDP (Port 3389)**: For administrative access.
* **Standard Public IP (`pip-srv-lb-001`)**: Provides a static entry point for the infrastructure.
* **Azure Load Balancer (`LB-srv-lb-001`)**: Standard SKU Load Balancer configured with:
  * A Frontend IP configuration linked to the Public IP.
  * A Backend Address Pool containing two web servers.
  * An HTTP Health Probe (Port 80, checking every 5 seconds).
  * A Load Balancing Rule routing incoming TCP Port 80 traffic to the backend pool.
* **Virtual Machines (`srv-IIS-001` & `srv-IIS-002`)**: Two Windows Server 2022 VMs running IIS with a custom HTML page displaying the server's local hostname.

## 📁 Repository Structure

```text
├── .gitignore                 # Prevents sensitive parameter files from being tracked
├── main.bicep                 # Primary Bicep template defining all Azure resources
├── main.bicepparam.example    # Parameter template example for public reference
├── script/
│   └── configure-iis.ps1      # PowerShell script for IIS installation & web configuration
└── README.md                  # Project documentation
```

## 🔒 Security & Best Practices

* **Sensitive Data Protection**: The actual parameter file containing real credentials (`main.bicepparam`) is excluded via `.gitignore` to prevent secret leaks to public repositories.
* **Example Parameter File**: A `main.bicepparam.example` file is provided as a reference for required parameter definitions without disclosing real values.

## 🚀 Deployment Instructions

### Prerequisites

* Install the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli).
* Install [Visual Studio Code](https://code.visualstudio.com/) with the **Bicep** extension.
* An active **Azure Subscription**.

### Step 1: Environment Setup

1. Clone this repository to your local machine:
   ```bash
   git clone [https://github.com/ipmc-solutions/Project-srv-lb-001.git](https://github.com/ipmc-solutions/Project-srv-lb-001.git)
   cd Project-srv-lb-001
   ```

2. Create your local parameter file by copying the template example:
   ```bash
   cp main.bicepparam.example main.bicepparam
   ```

3. Open `main.bicepparam` and update `adminPassword` with a strong password meeting Windows complexity requirements.

### Step 2: Authentication & Deployment

1. Log in to your Azure account via Azure CLI:
   ```bash
   az login
   ```

2. Create the target Resource Group:
   ```bash
   az group create --name rg-srv-lb-001 --location italynorth
   ```

3. Deploy the Bicep template:
   ```bash
   az deployment group create \
     --resource-group rg-srv-lb-001 \
     --template-file main.bicep \
     --parameters main.bicepparam
   ```

## 🧪 Verification

1. Retrieve the Load Balancer's Public IP address:
   ```bash
   az network public-ip show --resource-group rg-srv-lb-001 --name pip-srv-lb-001 --query "ipAddress" -o tsv
   ```

2. Open your web browser and navigate to:
   ```text
   http://<PUBLIC_IP_ADDRESS>
   ```

3. Refresh the page to verify that the traffic alternates between `srv-IIS-001` and `srv-IIS-002`.

## 🧹 Cleanup

To avoid incurring unexpected charges, delete all provisioned resources when testing is complete:

```bash
az group delete --name rg-srv-lb-001 --yes --no-wait
```
