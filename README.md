# azuremarketplace

This repo contains an ARM template to deploy resources into your Azure subscription.

---

## 🚀 Deploy to Azure

Click the button below to deploy this ARM template directly into your Azure subscription using the Azure portal:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fanee96935%2Fazuremarketplace%2Fmain%2Fazuredeploy.json)

---

## 🔍 Visualize the architecture

Use the ARMViz button below to visualize the resources defined in this template:

[![Visualize](http://armviz.io/visualizebutton.png)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fanee96935%2Fazuremarketplace%2Fmain%2Fazuredeploy.json)

---

## 📁 Files in this repo

- `azuredeploy.json` - The main ARM template that defines the Azure resources.
- `azuredeploy.param.json` - Sample parameter file for deploying the template with predefined values.
- `setup.sh` - A helper shell script if needed for automation.

---

## ⚡ Quick CLI deployment

Alternatively, you can deploy using the Azure CLI:

```bash
az deployment group create \
  --resource-group Athena-dev \
  --template-file azuredeploy.json \
  --parameters @azuredeploy.param.json
