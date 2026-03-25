# ByteHide Monitor — .NET Server Agent

Zero-code runtime protection (RASP) for .NET applications. Install once on any server — all .NET apps are automatically protected.

## Quick Install (no SDK required)

```bash
curl -sSL https://raw.githubusercontent.com/bytehide/monitor-dotnet-agent/main/install.sh | bash -s -- --token <your-token>
```

This downloads a self-contained binary, installs the agent, and configures all .NET processes on the server for automatic protection.

## Alternative: dotnet tool

If you have the .NET SDK installed:

```bash
dotnet tool install -g Bytehide.Monitor.AgentCli
bytehide-agent install --token <your-token>
```

## How it works

The agent uses two .NET mechanisms to inject protection without code changes:

1. **`DOTNET_STARTUP_HOOKS`** — Loads the agent DLL before `Main()` in every .NET process
2. **`ASPNETCORE_HOSTINGSTARTUPASSEMBLIES`** — Registers middleware for ASP.NET Core apps (WAF, request inspection)

### What gets installed

| Path | Description |
|------|-------------|
| `/opt/bytehide/agent/` (Linux) | Agent DLLs |
| `C:\Program Files\ByteHide\Agent\` (Windows) | Agent DLLs |
| `/usr/local/share/bytehide/agent/` (macOS) | Agent DLLs |
| Environment variables | `DOTNET_STARTUP_HOOKS`, `ASPNETCORE_HOSTINGSTARTUPASSEMBLIES`, `BYTEHIDE_MONITOR_TOKEN` |

## Commands

```bash
bytehide-agent install --token <token>   # Install and configure
bytehide-agent status                     # Check agent status
bytehide-agent config set token <token>   # Update token
bytehide-agent config show                # Show configuration
bytehide-agent logs --follow              # View agent logs
bytehide-agent uninstall                  # Remove agent
```

## Docker / Containers

```dockerfile
# Option A: Shell script (no SDK in image)
RUN curl -sSL https://raw.githubusercontent.com/bytehide/monitor-dotnet-agent/main/install.sh | bash -s -- --token $BYTEHIDE_TOKEN

# Option B: Multi-stage with dotnet tool
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
RUN dotnet tool install -g Bytehide.Monitor.AgentCli \
    && ~/.dotnet/tools/bytehide-agent install --token $BYTEHIDE_TOKEN

FROM mcr.microsoft.com/dotnet/aspnet:8.0
COPY --from=build /opt/bytehide/agent /opt/bytehide/agent
ENV DOTNET_STARTUP_HOOKS=/opt/bytehide/agent/Bytehide.Monitor.ServerAgent.dll
ENV ASPNETCORE_HOSTINGSTARTUPASSEMBLIES=Bytehide.Monitor.ServerAgent
ENV BYTEHIDE_MONITOR_TOKEN=<your-token>
```

## Compatibility

- **.NET 6, 7, 8, 9+** — Any .NET Core application
- **Linux** x64, ARM64, Alpine (musl)
- **macOS** x64, Apple Silicon
- **Windows** x64

## Links

- [ByteHide Monitor](https://www.bytehide.com/products/monitor)
- [Documentation](https://docs.bytehide.com/)
- [Get your token](https://app.bytehide.com)
