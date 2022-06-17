resource "azurerm_availability_set" "avset" {
   name                         = "avset"
   location                     = azurerm_resource_group.Weight-Tracker-App.location
   resource_group_name          = azurerm_resource_group.Weight-Tracker-App.name
 }
######DB-SERVER-DEPLOYMENT########
resource "azurerm_virtual_machine" "VM-DB-SERVER" {
   count                 = 1
  # name                  = "VM-DB-SERVER"
   name                  = "VM-DB-SERVER"
   location              = azurerm_resource_group.Weight-Tracker-App.location
   availability_set_id   = azurerm_availability_set.avset.id
   resource_group_name   = azurerm_resource_group.Weight-Tracker-App.name
   network_interface_ids = [azurerm_network_interface.VM-DB-NIC[0].id]
   vm_size               = "Standard_DS1_v2"



   storage_image_reference {
    offer     = "0001-com-ubuntu-server-focal"
    publisher = "Canonical"
    sku       = "20_04-lts"
    version   = "latest"
   }

   storage_os_disk {
     name              = "dbOsDisk"
     caching           = "ReadWrite"
     create_option     = "FromImage"
     managed_disk_type = "Standard_LRS"
   }



   storage_data_disk {
     name            = azurerm_managed_disk.VM-DB-SERVER-DISK.name
     managed_disk_id = azurerm_managed_disk.VM-DB-SERVER-DISK.id
     create_option   = "Attach"
     lun             = 1
     disk_size_gb    = azurerm_managed_disk.VM-DB-SERVER-DISK.disk_size_gb
   }

   os_profile {
     computer_name  = "VM-DB-SERVER"
     admin_username = admin_DB_user
     admin_password = admin_DB_pass
   }

   os_profile_linux_config {
     disable_password_authentication = false
   }

 }
 resource "azurerm_managed_disk" "VM-DB-SERVER-DISK" {
  name                 = "VM-DB-SERVER-DISK"
  location             = azurerm_resource_group.Weight-Tracker-App.location
  resource_group_name  = azurerm_resource_group.Weight-Tracker-App.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "70"
 }

 ######App-SERVER-DEPLOYMENT########
 resource "azurerm_virtual_machine" "VM-APP-SERVER" {
   count                 = 3
   name                  = "VM-APP-SERVER${count.index}"
   location              = azurerm_resource_group.Weight-Tracker-App.location
   availability_set_id   = azurerm_availability_set.avset.id
   resource_group_name   = azurerm_resource_group.Weight-Tracker-App.name
   #network_interface_ids = [azurerm_network_interface.VM-APP-NIC[count.index].id]
   network_interface_ids =[element(azurerm_network_interface.VM-APP-NIC.*.id, count.index)]
   vm_size               = "Standard_DS1_v2"



   storage_image_reference {
    offer     = "0001-com-ubuntu-server-focal"
    publisher = "Canonical"
    sku       = "20_04-lts"
    version   = "latest"
   }

   storage_os_disk {
     name              = "APPsDisk${count.index}"
     caching           = "ReadWrite"
     create_option     = "FromImage"
     managed_disk_type = "Standard_LRS"
   }



  #  storage_data_disk {
  #    name            = azurerm_managed_disk.VM-APP-SERVER-DISK.name
  #    managed_disk_id = azurerm_managed_disk.VM-APP-SERVER-DISK.id
  #    create_option   = "Attach"
  #    lun             = 1
  #    disk_size_gb    = azurerm_managed_disk.VM-APP-SERVER-DISK.disk_size_gb
  #  }

   os_profile {
     computer_name  = "VM-APP-SERVER"
     admin_username = admin_app_user
     admin_password = admin_app_pass
   }

   os_profile_linux_config {
     disable_password_authentication = false
   }

 }
 resource "azurerm_managed_disk" "VM-APP-SERVER-DISK" {
  name                 = "VM-APP-SERVER-DISK" 
  location             = azurerm_resource_group.Weight-Tracker-App.location
  resource_group_name  = azurerm_resource_group.Weight-Tracker-App.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "70"
 }