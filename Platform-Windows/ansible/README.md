# Ansible Setup

## Installation on Ubuntu

### Install PIP
```bash
sudo apt install python3-pip
```

### Install Ansible
```bash
python3 -m pip install --user ansible pywinrm
```

### If not on path, add with
```bash
export PATH="$PATH:$HOME/.local/bin"
```

### Running

Run all playbooks from this directory (`Platform-Windows/ansible/`):
```bash
ansible-playbook -i inventory/inventory.ini playbook.yml -l windows
```

### Testing
```bash
ansible all -i inventory/inventory.ini -m win_ping
```
