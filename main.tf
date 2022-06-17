# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "Weight-Tracker-App" {
  name     = "Weight-Tracker-App"
  location = "West us"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "Weight-Tracker-Network"
  address_space       = ["10.0.0.0/16"]
  location            = "West us"
  resource_group_name = azurerm_resource_group.Weight-Tracker-App.name
}
resource "azurerm_subnet" "AppSubnet" {
   name                 = "AppSubnet"
   resource_group_name  = azurerm_resource_group.Weight-Tracker-App.name
   virtual_network_name = azurerm_virtual_network.vnet.name
   address_prefixes     = ["10.0.1.0/24"]
 }

resource "azurerm_subnet" "DBSubnet" {
   name                 = "DBSubnet"
   resource_group_name  = azurerm_resource_group.Weight-Tracker-App.name
   virtual_network_name = azurerm_virtual_network.vnet.name
   address_prefixes     = ["10.0.2.0/24"]
 }



######Network-Security-Group
#resource "azurerm_resource_group" "DB-NET" {
#  name     = "Weight-Tracker-App"
#  location = "West us"
#}

resource "azurerm_network_security_group" "DB-NET" {
  name                = "DB-NET-NSG"
  location            = azurerm_resource_group.Weight-Tracker-App.location
  resource_group_name = azurerm_resource_group.Weight-Tracker-App.name

###SSH PORT
  security_rule {
    name                       = "SSH"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "22"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Dev"
  }
###PostgresSQL
  security_rule {
    name                       = "PORT_5432"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "5432"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }


###Deny ALL
    security_rule {
    name                       = "Deny_all"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }


}
#####App_Network
#resource "azurerm_resource_group" "App-Net" {
 # name     = "Weight-Tracker-App"
  #location = "West us"
#}

resource "azurerm_network_security_group" "APP-NET" {
  name                = "APP-NET-NSG"
  location            = azurerm_resource_group.Weight-Tracker-App.location
  resource_group_name = azurerm_resource_group.Weight-Tracker-App.name

 security_rule {
    name                       = "PORT_8080"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "8080"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Dev"
  }

 security_rule {
    name                       = "PORT_22"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "22"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.2.0/24"
    destination_address_prefix = "*"
  }

}
resource "azurerm_public_ip" "Public_IP" {
   name                         = "publicIPForLB"
   location                     = azurerm_resource_group.Weight-Tracker-App.location
   resource_group_name          = azurerm_resource_group.Weight-Tracker-App.name
   allocation_method            = "Static"
 }
 resource "azurerm_lb" "Load-Balancer-app" {
   name                = "loadBalancer"
   location            = azurerm_resource_group.Weight-Tracker-App.location
   resource_group_name = azurerm_resource_group.Weight-Tracker-App.name

   frontend_ip_configuration {
     name                 = "LB-FRONT"
     public_ip_address_id = azurerm_public_ip.Public_IP.id
   }
 }
 resource "azurerm_lb_backend_address_pool" "LB-Back" {
   loadbalancer_id     = azurerm_lb.Load-Balancer-app.id
   name                = "BackEndAddressPool"
 }
####load balancer rule
resource "azurerm_lb_rule" "LoadBalancerRule8080" {
  loadbalancer_id                = azurerm_lb.Load-Balancer-app.id
  name                           = "port_8080"
  protocol                       = "Tcp"
  frontend_port                  = 8080
  backend_port                   = 8080
  frontend_ip_configuration_name = "LB-FRONT"
  probe_id                       = azurerm_lb_probe.lbProbe.id
  backend_address_pool_ids = [ azurerm_lb_backend_address_pool.LB-Back.id ]
  disable_outbound_snat          = true
}

resource "azurerm_lb_probe" "lbProbe" {
  name = "tcpProbe"
  loadbalancer_id     = azurerm_lb.Load-Balancer-app.id
  protocol            = "Http"
  port                = 8080
  interval_in_seconds = 5
  number_of_probes    = 2
  request_path        = "/"

}

resource "azurerm_network_interface_backend_address_pool_association" "LB-BACK-ASSAIN" {
  count                   = 3
  backend_address_pool_id = azurerm_lb_backend_address_pool.LB-Back.id
  ip_configuration_name   = azurerm_network_interface.VM-APP-NIC[count.index].ip_configuration[0].name
  network_interface_id    = element(azurerm_network_interface.VM-APP-NIC[count.index].*.id,count.index)
}


 resource "azurerm_network_interface" "VM-APP-NIC" {
   count               = 3
   name                = "VM-APP-NIC${count.index}"
   location            = azurerm_resource_group.Weight-Tracker-App.location
   resource_group_name = azurerm_resource_group.Weight-Tracker-App.name

   ip_configuration {
     name                          = "VM-APP-SUB"
     subnet_id                     = azurerm_subnet.AppSubnet.id
     private_ip_address_allocation = "Dynamic"
   }
 }

 resource "azurerm_network_interface" "VM-DB-NIC" {
   count               = 1
   name                = "VM-DB-NIC${count.index}"
   location            = azurerm_resource_group.Weight-Tracker-App.location
   resource_group_name = azurerm_resource_group.Weight-Tracker-App.name

   ip_configuration {
     name                          = "VM-DB-SUB"
     subnet_id                     = azurerm_subnet.DBSubnet.id
     private_ip_address_allocation = "Dynamic"
   }
 }