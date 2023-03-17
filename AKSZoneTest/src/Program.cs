using System.Text;
using System.Diagnostics;
using System.Net.Http.Json;

string podName = Environment.GetEnvironmentVariable("pod_name") ?? "unknown"; // metadata.name
string hostname = Environment.GetEnvironmentVariable("k8s_hostname") ?? "unknown"; // spec.nodeName

// Read these values from IMDS (Not supported when pod ideneity is used)
IMDSResponse imdsDetails = await IMDSResponse.GetAsync();
string podDetails = $"""
    Pod Name: {podName}
    Region: {imdsDetails.location}
    Zone: {imdsDetails.zone}
    Agent Pool: {imdsDetails.vmScaleSetName}
    Node Hostname: {hostname}
    """;

string? nextHop = Environment.GetEnvironmentVariable("next_hop");

Console.WriteLine(podDetails);
Console.WriteLine(string.IsNullOrWhiteSpace(nextHop) ? "No next hop" : $"Next hop: {nextHop}");

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.Use(async (context, next) =>
{
    if (context.Response.Headers.ContainsKey("Connection"))
    {
        context.Response.Headers.Remove("Connection");
    }
    context.Response.Headers.Add("Connection", "close");
    await next.Invoke();
});

app.MapGet("/", async () => {
    var sb = new StringBuilder();
    sb.AppendLine(podDetails);
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

app.MapGet("/health", () => "ok");

app.Run();

record IMDSResponse(string location, string zone, string vmScaleSetName)
{
    private static readonly IMDSResponse _unknown = new IMDSResponse("unknown", "unknown", "unknown");
    public static async Task<IMDSResponse> GetAsync()
    {
        try
        {
            using var hc = new HttpClient();
            hc.DefaultRequestHeaders.Add("Metadata", "true");
            return await hc.GetFromJsonAsync<IMDSResponse>("http://169.254.169.254/metadata/instance/compute?api-version=2021-02-01") ?? _unknown;
        }
        catch (Exception e)
        {
            Console.WriteLine(e);
            return _unknown;
        }
    }
}