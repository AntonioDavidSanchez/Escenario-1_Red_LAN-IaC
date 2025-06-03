# main.tf

resource "time_static" "deployment_start" {
  triggers = {
    always_run = timestamp()
  }
}


module "ubuntu_server_1" {
  source = "./modules/vm"

  vm_name        = "UbuntuServer"
  vm_description = "Ubuntu Server con Wazuh Indexer, Server y Dashboard"
  node_name      = "kvm1"
  vm_id          = 850
  vm_tags        = ["UbuntuServer"]
  dns_servers = ["8.8.8.8"]
  ipv4_address   = "192.168.10.50/24"
  ipv4_gateway   = "192.168.10.6"
  clone_vm_id    = 111
  clone_full = true
}

module "ubuntu_server_2" {
  source = "./modules/vm"

  vm_name        = "UbuntuServer1"
  vm_description = "Ubuntu Server con Wazuh Agent"
  node_name      = "kvm1"
  vm_id          = 852
  vm_tags        = ["UbuntuServer1"]
  dns_servers = ["8.8.8.8"]
  ipv4_address   = "192.168.10.52/24"
  ipv4_gateway   = "192.168.10.6"
  clone_vm_id    = 111
  clone_full = true
  depends_on = [module.ubuntu_server_1]
}

module "windows_11" {
  source = "./modules/vm"

  vm_name        = "WindowsOS11"
  vm_description = "Windows 11 con Wazuh Agent"
  node_name      = "kvm1"
  vm_id          = 851
  vm_tags        = ["WindowsOS11"]
  dns_servers = ["8.8.8.8"]
  ipv4_address   = "192.168.10.51/24"
  ipv4_gateway   = "192.168.10.6"
  clone_vm_id    = 102
  clone_full = true
  depends_on = [ module.ubuntu_server_2]
}

# Ejecutar instalación de Wazuh usando SSH
 resource "null_resource" "install_wazuh" {
  triggers = {
    always_run = "${timestamp()}"
  }
  connection {
    type        = "ssh"
    user        = var.vm_user_ubuntuserver # Usuario en la máquina virtual donde se va a instalar Wazuh
    password    = var.vm_password_ubuntuserver # Contraseña de la máquina virtual
    host = split("/", module.ubuntu_server_1.ipv4_address)[0]
    port = 22
    bastion_host        = var.bastion_host  # Servidor Proxmox accesible desde el PC
    bastion_user        = var.bastion_user  # Usuario en el servidor intermediario
    bastion_private_key  = file("Ruta_Clave_Privada")
  
  }
  provisioner "remote-exec" {
  inline = [
    "sudo apt install -y curl",
    "curl -sO https://packages.wazuh.com/4.5/wazuh-install.sh",
    "sudo -S bash ./wazuh-install.sh -a -i"
  ]
  }
  depends_on = [module.windows_11]
}


resource "null_resource" "install_wazuh_agent_ubuntuserver" {
  triggers = {
    always_run = "${timestamp()}"
  }

  connection {
    type        = "ssh"
    user        = var.vm_user_ubuntuserver
    password    = var.vm_password_ubuntuserver
    host = split("/", module.ubuntu_server_2.ipv4_address)[0]
    port        = 22
    bastion_host        = var.bastion_host
    bastion_user        = var.bastion_user
    bastion_private_key  = file("Ruta_Clave_Privada")
  }

  provisioner "remote-exec" {
    inline = [
      "curl -so wazuh-agent.deb https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.5.4-1_amd64.deb && sudo WAZUH_MANAGER='${split("/", module.ubuntu_server_1.ipv4_address)[0]}' WAZUH_AGENT_NAME='Ubuntu' dpkg -i ./wazuh-agent.deb",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable wazuh-agent",
      "sudo systemctl start wazuh-agent"
    ]
  }
  depends_on = [null_resource.install_wazuh]
}

resource "null_resource" "install_wazuh_agent_windows11" {
  triggers = {
    always_run = "${timestamp()}"
  }

  connection {
    type     = "ssh"
    user     = var.vm_user_windows11
    password = var.vm_password_windows11
    host     = split("/", module.windows_11.ipv4_address)[0]
    port     = 22
    bastion_host     = var.bastion_host
    bastion_user     = var.bastion_user
    bastion_private_key  = file("Ruta_Clave_Privada")
    target_platform  = "windows"
  }

  provisioner "remote-exec" {
    inline = [
      "powershell -Command \"Write-Output 'Descargando Wazuh Agent...'\"",
      "powershell -Command \"Invoke-WebRequest -Uri 'https://packages.wazuh.com/4.x/windows/wazuh-agent-4.5.4-1.msi' -OutFile $env:TEMP\\wazuh-agent.msi\"",
      "powershell -Command \"Write-Output 'Instalando Wazuh Agent...'\"",
      "powershell -Command \"Start-Process msiexec.exe -ArgumentList '/i', $env:TEMP\\wazuh-agent.msi, '/qn', 'WAZUH_MANAGER=${split("/", module.ubuntu_server_1.ipv4_address)[0]}', 'WAZUH_REGISTRATION_SERVER=${split("/", module.ubuntu_server_1.ipv4_address)[0]}', 'WAZUH_AGENT_NAME=Windows', '/L*v', $env:TEMP\\wazuh_install.log -NoNewWindow -Wait\"",
      "powershell -Command \"if (Get-Service -Name 'Wazuh' -ErrorAction SilentlyContinue) { Start-Service 'Wazuh'; Write-Output 'Wazuh Agent iniciado.' } else { Write-Error 'ERROR: El servicio Wazuh no existe tras la instalación'; exit 1 }\""
    ]
  }

   depends_on = [
    module.windows_11,
    null_resource.install_wazuh
  ]
}
