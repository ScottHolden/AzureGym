FROM mcr.microsoft.com/dotnet/aspnet:7.0 AS base
WORKDIR /app
EXPOSE 80

FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build
WORKDIR /src
COPY "AKSCrossVnetOverlay/src/PathTester.csproj" "AKSCrossVnetOverlay/src/PathTester.csproj"
RUN dotnet restore "AKSCrossVnetOverlay/src/PathTester.csproj"
COPY 'AKSCrossVnetOverlay/src' "AKSCrossVnetOverlay/src"
RUN dotnet build "AKSCrossVnetOverlay/src/PathTester.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "AKSCrossVnetOverlay/src/PathTester.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "PathTester.dll"]