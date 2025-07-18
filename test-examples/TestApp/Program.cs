var builder = WebApplication.CreateBuilder(args);

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

app.UseRouting();
app.MapControllers();

// Simple endpoints for testing
app.MapGet("/", () => new 
{ 
    Message = "Hello from .NET in Docker!",
    Time = DateTime.Now,
    Environment = Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT"),
    Version = Environment.Version.ToString()
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
