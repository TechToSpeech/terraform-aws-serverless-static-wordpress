#!/bin/bash

echo 'installing dependencies'
sudo apt install python3-pip gawk &&\
pip3 install pre-commit
curl -L "$(curl -sL https://api.github.com/repos/terraform-linters/tflint/releases/latest | grep -o -E "https://.+?_linux_amd64.zip")" > tflint.zip && unzip tflint.zip && rm tflint.zip && sudo mv tflint /usr/bin/
curl -L "$(curl -sL https://api.github.com/repos/tfsec/tfsec/releases/latest | grep -o -E "https://.+?tfsec-linux-amd64" | head -1)" > tfsec && chmod +x tfsec && sudo mv tfsec /usr/bin/
docker pull quay.io/terraform-docs/terraform-docs:latest
git clone https://github.com/tfutils/tfenv.git ~/.tfenv || true
mkdir -p ~/.local/bin/
. ~/.profile
ln -s ~/.tfenv/bin/* ~/.local/bin

echo 'installing pre-commit hooks'
pre-commit install

echo 'setting pre-commit hooks to auto-install on clone in the future'
git config --global init.templateDir ~/.git-template
pre-commit init-templatedir ~/.git-template

echo 'installing terraform with tfenv'
tfenv install min-required
tfenv use min-required
