using System.Text;
using System.Diagnostics;

string podName = Environment.GetEnvironmentVariable("pod_name") ?? "unknown"; // metadata.name
string region = Environment.GetEnvironmentVariable("k8s_region") ?? "unknown"; // topology.kubernetes.io/region
string zone = Environment.GetEnvironmentVariable("k8s_zone") ?? "unknown"; // topology.kubernetes.io/zone
string agentPool = Environment.GetEnvironmentVariable("k8s_agentpool") ?? "unknown"; // kubernetes.azure.com/agentpool
string hostname = Environment.GetEnvironmentVariable("k8s_hostname") ?? "unknown"; // kubernetes.io/hostname

string? nextHop = Environment.GetEnvironmentVariable("next_hop");

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/", async () => {
    var sb = new StringBuilder();
    sb.AppendLine($"""
    Pod Name: {podName}
    Region: {region}
    Zone: {zone}
    Agent Pool: {agentPool}
    Node Hostname: {hostname}
    """);
    if (string.IsNullOrWhiteSpace(nextHop))
    {
        sb.AppendLine("Last hop (no next hop set)");
        sb.AppendLine("----------");
    }
    else
    {
        try
        {
            // Not a best practice at all, but force a new client each request
            using var hc = new HttpClient();
            var sw = Stopwatch.StartNew();
            var resp = await hc.GetStringAsync(nextHop);
            sw.Stop();
            sb.AppendLine($"Called next hop in {sw.ElapsedMilliseconds}ms");
            sb.AppendLine("----------");
            sb.Append(resp);
        }
        catch (Exception e)
        {
            sb.AppendLine($"Exception calling next hop: {e.Message}");
        }
    }
    return sb.ToString();
});

app.Run();