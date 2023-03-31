using System.Text;

string podName = Environment.GetEnvironmentVariable("pod_name") ?? "unknown"; // metadata.name
string hostName = Environment.GetEnvironmentVariable("k8s_hostname") ?? "unknown"; // spec.nodeName

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/", () => Results.Text($@"
<!DOCTYPE html>
<html lang='en'><head>
<meta charset='utf-8'>
<meta name='viewport' content='width=device-width, initial-scale=1'>
<title>{podName} - PathTest</title><style>
html, body {{
    margin: 0;
    padding: 0;
}}
div {{
    margin: 10px;
}}
pre {{
    border: solid #000 1px;
    min-height: 10em;
    overflow: scroll visible;
}}
.container {{
    margin: 0 auto;
    padding: 20px;
    max-width: 800px;
    min-height: calc(100vh - 40px);
    background-color: #eee;
}}
</style></head><body><div class='container'>
    <h1>Path Test</h1>
    <h2>{podName} on {hostName}</h2>
    <div><a href='/ping'>Text Endpoint</a> | <a href='/json'>Json Endpoint</a><br></div>
    <div><label>Url to GET (via pod): <input type='text' id='targetUrl' /></label><button type='button' id='callButton'>Call</button></div>
    <div><pre id='response'>
    </pre></div></div>
    <script>
        (()=>{{
            const fx = () => {{
                fetch('/call', {{
                    method: 'POST',
                    headers: {{ 'Content-Type': 'application/json' }},
                    body: JSON.stringify({{url: document.getElementById('targetUrl').value}})
                }})
                    .then(x=>x.text())
                    .then(x=>{{console.log(x);document.getElementById('response').innerText=x;}})
                    .catch(x=>document.getElementById('response').innerText='JS Error: '+x);
            }};
            document.getElementById('callButton').addEventListener('click', fx);
            document.getElementById('targetUrl').addEventListener('keypress', x => {{if(x.keyCode==13) fx();}});
        }})();
    </script>
</body></html>
", "text/html", Encoding.UTF8));

app.MapPost("/call", async (CallRequest call) =>
{
    try
    {
        if (Uri.TryCreate(call.url, UriKind.Absolute, out Uri? uri) && uri != null)
        {
            using HttpClient hc = new(); // Bad practice recreating, but gets around DNS cache
            return Results.Text(await hc.GetStringAsync(uri), "text/plain", Encoding.UTF8);
        }
        return Results.Text("Error: Invalid URL", "text/plain", Encoding.UTF8);
    }
    catch (Exception e)
    {
        return Results.Text("Error: " + e.Message, "text/plain", Encoding.UTF8);
    }
});
app.MapGet("/ping", () => $"Hello from {podName} on {hostName}");
app.MapGet("/json", () => new
{
    podName = podName,
    hostName = hostName
});

app.Run();

record CallRequest(string url);