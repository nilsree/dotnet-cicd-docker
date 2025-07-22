var builder = WebApplication.CreateBuilder(args);

// Set content root to current directory (where the app actually runs from)
builder.Environment.ContentRootPath = Directory.GetCurrentDirectory();
builder.Environment.WebRootPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot");

// Add services to the container
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Configure default files to serve index.html when requesting "/"
var defaultFilesOptions = new DefaultFilesOptions();
defaultFilesOptions.DefaultFileNames.Clear();
defaultFilesOptions.DefaultFileNames.Add("index.html");
app.UseDefaultFiles(defaultFilesOptions);

// Enable static files to serve our beautiful loading page
app.UseStaticFiles();

app.UseRouting();
app.MapControllers();

// Fallback for API endpoints - these return HTTP 503 Service Unavailable
app.MapGet("/api", (HttpContext context) => 
{
    context.Response.StatusCode = 503; // Service Unavailable
    return new 
    { 
        Message = "TestApp - Temporary fallback application",
        Status = "Waiting for main application",
        Time = DateTime.Now,
        Environment = Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT"),
        Version = Environment.Version.ToString(),
        Note = "Visit '/' for deployment status page",
        StatusCode = 503
    };
});

app.MapGet("/env", (HttpContext context) => 
{
    context.Response.StatusCode = 503; // Service Unavailable
    
    var envVars = new Dictionary<string, string>();
    
    // Get common environment variables
    var commonVars = new[] 
    {
        "DOTNET_ENVIRONMENT",
        "ASPNETCORE_ENVIRONMENT",
        "ASPNETCORE_URLS",
        "SA_PASSWORD",
        "MSSQL_PID",
        "ENABLE_CI_CD",
        "GITHUB_REPO",
        "GITHUB_BRANCH",
        "ConnectionStrings__DefaultConnection"
    };
    
    foreach (var var in commonVars)
    {
        var value = Environment.GetEnvironmentVariable(var);
        if (!string.IsNullOrEmpty(value))
        {
            // Hide sensitive information
            if (var.Contains("PASSWORD") || var.Contains("TOKEN") || var.Contains("ConnectionString"))
            {
                envVars[var] = "***HIDDEN***";
            }
            else
            {
                envVars[var] = value;
            }
        }
    }
    
    return new { Environment = envVars, StatusCode = 503 };
});

// Health check endpoint (also returns 503)
app.MapGet("/health", (HttpContext context) => 
{
    context.Response.StatusCode = 503; // Service Unavailable
    return new 
    {
        Status = "Service Unavailable",
        Message = "Main application is being deployed",
        StatusCode = 503,
        Time = DateTime.Now
    };
});

// SPA Fallback - serve index.html for all non-API routes with 503 status
app.MapFallback(async (HttpContext context) =>
{
    // Don't handle API routes, Swagger, or static files here
    var path = context.Request.Path.Value?.ToLowerInvariant() ?? "";
    
    if (path.StartsWith("/api") || 
        path.StartsWith("/swagger") || 
        path.StartsWith("/health") ||
        path.StartsWith("/env") ||
        Path.HasExtension(path)) // Skip files with extensions (CSS, JS, images, etc.)
    {
        context.Response.StatusCode = 404;
        return;
    }
    
    // Set 503 status for all fallback routes
    context.Response.StatusCode = 503;
    context.Response.ContentType = "text/html";
    
    // Serve the index.html file
    var indexPath = Path.Combine(app.Environment.WebRootPath, "index.html");
    if (File.Exists(indexPath))
    {
        await context.Response.SendFileAsync(indexPath);
    }
    else
    {
        await context.Response.WriteAsync("<h1>503 - Service Unavailable</h1><p>Deployment in progress...</p>");
    }
});

app.Run();
