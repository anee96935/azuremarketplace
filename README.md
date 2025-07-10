# azuremarketplace

This repo contains an ARM template to deploy resources into your Azure subscription.

## 🚀 Deploy to Azure

Click the button below to deploy this ARM template directly into your Azure subscription using the Azure portal:

[![Deploy to Azure](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fanee96935%2Fazuremarketplace%2Fmain%2Fazuredeploy.json)

---

## 🔍 Visualize the architecture

Use the ARMViz button below to visualize the resources defined in this template:

[![Visualize ARM Template](http://armviz.io/visualizebutton.png)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fanee96935%2Fazuremarketplace%2Fmain%2Fazuredeploy.json)

---

## 📂 Files

- `azuredeploy.json` - ARM template defining Azure resources.
- `azuredeploy.param.json` - Sample parameter file.
- `setup.sh` - Example script (optional setup).

---

## 🚀 Deploy via Azure CLI

```bash
az deployment group create \
  --resource-group Athena-dev \
  --template-uri https://raw.githubusercontent.com/anee96935/azuremarketplace/main/azuredeploy.json \
  --parameters https://raw.githubusercontent.com/anee96935/azuremarketplace/main/azuredeploy.param.json
