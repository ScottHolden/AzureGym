# PG_Dump ACI

[![Deploy To Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FScottHolden%2FAzureGym%2Fmain%2FPGDumpACI%2Fgenerated%2Fdeploy.json)

This is a small demo using an Azure Container Instance (ACI) to execute pg_dump, writing to an Azure File's share. The ACI Container Group can either be manually started, or a recurring Logic App can start it for scheduled dumps.

_Note: The first execution of the Logic App may fail if the role assignment/permission hasn't propogated._

Each dump is written to the Storage Account with a timestamped name:

![Storage Account File Example](media/files.png)

## Logical Overview
![Logical Diagram](media/overview.png)

## Azure Resource List
![Resource List](media/resources.png)
_+ RBAC Role & Assignment not shown in the list above_