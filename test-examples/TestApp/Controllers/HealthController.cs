using Microsoft.AspNetCore.Mvc;

namespace TestApp.Controllers;

[ApiController]
[Route("api/[controller]")]
public class HealthController : ControllerBase
{
    [HttpGet]
    public IActionResult Get()
    {
        return Ok(new 
        { 
            Status = "Healthy",
            Time = DateTime.Now,
            Environment = Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT"),
            MachineName = Environment.MachineName,
            Version = Environment.Version.ToString()
        });
    }

    [HttpGet("database")]
    public IActionResult Database()
    {
        try
        {
            var connectionString = Environment.GetEnvironmentVariable("ConnectionStrings__DefaultConnection");
            
            if (string.IsNullOrEmpty(connectionString))
            {
                return Ok(new { Status = "No database connection string configured" });
            }

            // Simple connection test without EF
            using var connection = new Microsoft.Data.SqlClient.SqlConnection(connectionString);
            connection.Open();
            
            using var command = new Microsoft.Data.SqlClient.SqlCommand("SELECT @@VERSION", connection);
            var version = command.ExecuteScalar()?.ToString();
            
            return Ok(new 
            { 
                Status = "Database Connected",
                ServerVersion = version,
                ConnectionString = connectionString.Replace("Password=", "Password=***")
            });
        }
        catch (Exception ex)
        {
            return Ok(new 
            { 
                Status = "Database Error",
                Error = ex.Message
            });
        }
    }
}
