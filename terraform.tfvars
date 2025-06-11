# terraform.tfvars

proxmox_endpoint = "https://IP_Proxmox:8006"
proxmox_api_token = "Token_asociado_al_usuario"

# Usuario de cada máquina virtual
vm_user_ubuntuserver = "Usuario"
vm_user_windows11 = "Usuario"
vm_password_ubuntuserver = "Contraseña"
vm_password_windows11 = "Contraseña"

# IP del servidor intermediario entre el PC y la máquina virtual
bastion_host = "IP_Servidor_Bastion"

# Usuario del servidor intermediario entre el PC y la máquina virtual
bastion_user        = "Usuario_Servidor_Bastion"

# Contraseña del usuario del servidor intermediario entre el PC y la máquina virtual
bastion_password =  "Contraseña_Servidor_Bastion"

