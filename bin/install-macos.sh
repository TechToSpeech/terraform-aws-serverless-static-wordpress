#!/bin/bash

echo 'installing brew packages'
brew update
brew tap liamg/tfsec
brew install tfenv tflint terraform-docs pre-commit liamg/tfsec/tfsec coreutils
brew upgrade tfenv tflint terraform-docs pre-commit liamg/tfsec/tfsec coreutils

echo 'installing pre-commit hooks'
pre-commit install

echo 'setting pre-commit hooks to auto-install on clone in the future'
git config --global init.templateDir ~/.git-template
pre-commit init-templatedir ~/.git-template

echo 'installing terraform with tfenv'
tfenv install min-required
tfenv use min-required
