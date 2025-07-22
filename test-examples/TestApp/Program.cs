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

// Fallback for API endpoints - these are still available
app.MapGet("/api", () => new 
{ 
    Message = "TestApp - Temporary fallback application",
    Status = "Waiting for main application",
    Time = DateTime.Now,
    Environment = Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT"),
    Version = Environment.Version.ToString(),
    Note = "Visit '/' for deployment status page"
});

app.MapGet("/env", () => 
{
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
    
    return envVars;
});

app.Run();
