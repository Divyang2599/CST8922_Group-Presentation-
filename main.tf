terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# ---------------------------------------------------------------------------
# CloudNova demo environment — intentionally flawed for the AI review demo.
# Do NOT deploy this as-is. See README.md for the issues baked in here.
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "rg" {
  name     = "rg-cloudnova-demo"
  location = "canadacentral"
}

# ISSUE 1: Public blob access enabled on a storage account.
# This is the exact CloudNova incident from the business-problem slide —
# a storage account left publicly accessible for three weeks.
resource "azurerm_storage_account" "data" {
  name                     = "myvm123"          # ISSUE 4: no naming standard, looks like a VM name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  allow_nested_items_to_be_public = true         # <-- security risk
}

# ISSUE 2: Network Security Group allows SSH from the entire internet.
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-cloudnova-demo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowSSHFromAnywhere"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "0.0.0.0/0"     # <-- security risk, should be a scoped IP/CIDR
    destination_address_prefix = "*"
  }
}

# ISSUE 3: VM massively oversized for a small test workload — cost waste.
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-cloudnova-demo"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-demo"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "nic" {
  name                = "nic-testvm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "test_vm" {
  name                = "testvm1"                  # ISSUE 4 (again): no env/owner/purpose in name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D8s_v3"           # <-- cost waste: 8 vCPU / 32GB for a "small test workload"
  admin_username      = "azureuser"

  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
