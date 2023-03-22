using System.Net.Mime;
using System.Text;
using System.Reflection;
using System.Collections.Concurrent;

static class ResultsExtensions
{
    public static IResult EmbeddedResourceHtml<T>(this IResultExtensions resultExtensions, string resourceName)
    {
        var contents = GetResource<T>(resourceName);
        if (contents is null) throw new KeyNotFoundException($"{resourceName} not found as embedded resource");
        return new HtmlResult(contents);
    }
    private static ConcurrentDictionary<(Assembly, string), string?> _resourceCache = new();
    private static string? GetResource<T>(string resourceName)
        => _resourceCache.GetOrAdd((typeof(T).Assembly, resourceName), ((Assembly assembly, string name) cacheKey) => {
            var key = $"{cacheKey.assembly.GetName().Name}.{cacheKey.name}";
            using var stream = cacheKey.assembly.GetManifestResourceStream(key);
            if (stream == null) return null;
            using var streamReader = new StreamReader(stream);
            return streamReader.ReadToEnd();
        });
}

class HtmlResult : IResult
{
    private readonly string _html;

    public HtmlResult(string html)
    {
        _html = html;
    }

    public Task ExecuteAsync(HttpContext httpContext)
    {
        httpContext.Response.ContentType = MediaTypeNames.Text.Html;
        httpContext.Response.ContentLength = Encoding.UTF8.GetByteCount(_html);
        return httpContext.Response.WriteAsync(_html);
    }
}