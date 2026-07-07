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
# CloudNova demo environment — FIXED VERSION
# All 4 issues corrected based on AI reviewer recommendations
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "rg" {
  name     = "rg-cloudnova-prod"  #  FIXED: Clear, descriptive name
  location = "canadacentral"
}

#  FIXED: Public blob access disabled
resource "azurerm_storage_account" "data" {
  name                     = "stcloudnovaprod01"          # FIXED: Proper naming standard (st = storage, company, env, number)
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  allow_nested_items_to_be_public = false  #  FIXED: Now blocked - data is protected
}

#  FIXED: SSH restricted to specific IP range only
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-cloudnova-prod"             #  FIXED: Production naming
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowSSHFromTrusted"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "203.0.113.0/24"        #  FIXED: Only trusted corporate IP range
    destination_address_prefix = "*"
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-cloudnova-prod"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-compute"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "nic" {
  name                = "nic-appvm-prod-01"              #  FIXED: Clear naming (nic-purpose-env-number)
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

#  FIXED: Appropriately sized VM for production workload
resource "azurerm_linux_virtual_machine" "app_vm" {
  name                = "vm-app-prod-01"                 #  FIXED: Clear naming standard (vm-purpose-env-number)
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s"                   #  FIXED: Appropriate for production (2vCPU, 4GB)

  admin_username = "azureuser"

  network_interface_ids = [azurerm_network_interface.nic.id]

  disable_password_authentication = false

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

  tags = {
    environment = "production"
    purpose     = "application-server"
    managed_by  = "terraform"
  }
}
