# Small setup script to restore my defaults
& az bicep install
& az bicep upgrade
& az extension add --name alias
& az alias create --name 'cg {{ rg_name }}' --command 'group create -l AustraliaEast -n {{ rg_name }}'
& az alias create --name 'dg' --command 'deployment group create'