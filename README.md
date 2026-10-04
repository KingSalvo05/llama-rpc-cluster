# llama-rpc-cluster

**Link two PCs with an Ethernet cable to combine their GPUs and run massive AI models locally.**

Using llama.cpp RPC, the VRAM of a secondary PC (Worker) is added to the main PC (Master),
making it possible to load huge models like Qwen 2.5 32B that would never fit on a single GPU.

---

## How it works

```
MASTER PC (main GPU)        <--- CAT5e/CAT6 --->   WORKER PC (secondary GPU)
RTX 5070 8GB                  direct Ethernet       RTX 3050 4GB
llama-server.exe                                    ggml-rpc-server.exe

Result: 8 + 4 = 12 GB of combined VRAM available for AI!
```

The Master loads the model and automatically offloads the layers that do not fit in its own GPU
to the Worker. A direct Ethernet cable (no router) ensures minimum latency (~0.1ms) and
maximum bandwidth (1 Gbps).

---

## Installation - 2 commands, fully automatic

> **Requirements:** Windows 10/11, Nvidia GPU, CAT5e or CAT6 Ethernet cable, PowerShell 5+

### 1 - On the MASTER PC (the powerful one)

Open **PowerShell as Administrator** and paste:

```powershell
irm https://raw.githubusercontent.com/KingSalvo05/llama-rpc-cluster/main/scripts/install-master.ps1 | iex
```

The script will automatically:
- Detect the Nvidia GPU
- Set a static IP `192.168.50.1` on the Ethernet port
- Open port 50052 on Windows Firewall
- Download the latest llama.cpp release with CUDA support
- Scan all drives for existing `.gguf` model files
- Create `Avvia_Cluster_MASTER.bat` on your Desktop

### 2 - On the WORKER PC (the old one)

Open **PowerShell as Administrator** and paste:

```powershell
irm https://raw.githubusercontent.com/KingSalvo05/llama-rpc-cluster/main/scripts/install-worker.ps1 | iex
```

The script will automatically:
- Detect the Nvidia GPU
- Set a static IP `192.168.50.2` on the Ethernet port
- Open port 50052 on Windows Firewall
- Download llama.cpp with CUDA support
- Create `Avvia_Worker_RPC.bat` on your Desktop
- (Optional) Register an auto-start task on Windows login

---

## Daily usage

1. **On the Worker PC:** double-click `Avvia_Worker_RPC.bat` and leave the black window open.
2. **On the Master PC:** double-click `Avvia_Cluster_MASTER.bat`, choose the model, press Enter.
3. Your browser opens automatically at `http://localhost:8080` with a ready-to-use chat interface.

---

## API compatibility

The server exposes an **OpenAI-compatible** endpoint at:

```
http://127.0.0.1:8080/v1
```

Works out of the box with Continue (VS Code), Open WebUI, Python scripts, and any app
that supports the OpenAI API format.

---

## How much VRAM do I gain?

| Master GPU      | Worker GPU      | Total VRAM  | Recommended model    |
|-----------------|-----------------|-------------|----------------------|
| RTX 5070 8GB    | RTX 3050 4GB    | ~12 GB      | Qwen 2.5 32B Q4_K_M  |
| RTX 4090 24GB   | RTX 3080 10GB   | ~34 GB      | Llama 3 70B Q4_K_M   |
| RTX 3080 10GB   | RTX 3060 8GB    | ~18 GB      | Mistral 22B Q4_K_M   |
| Any             | Any             | Sum of VRAM | Depends on total     |

> Note: effective usable VRAM is approximately 90% due to system overhead.

---

## Advanced configuration

### Custom IP addresses

To use different IPs than the defaults, edit the IP variables at the top of
`install-master.ps1` and `install-worker.ps1` before running them.

### Multiple Workers at the same time

You can connect **multiple Worker PCs** simultaneously using a network switch.
Run `install-worker.ps1` on each PC with different IPs (`192.168.50.2`, `192.168.50.3`, etc.)
and add all addresses separated by commas in the Master launcher:

```
--rpc 192.168.50.2:50052,192.168.50.3:50052
```

---

## FAQ

**Does the Worker PC need the model downloaded?**
No. Only the Master needs the `.gguf` file. The Worker only contributes its GPU.

**Can I use Wi-Fi instead of a cable?**
It works but with higher latency and lower bandwidth. Recommended only for small models (7B).

**Does it work with AMD GPUs?**
llama.cpp ROCm support is experimental on Windows. It works better on Linux.

**Does the Worker have to run Windows?**
The install script targets Windows. On Linux you can manually launch `ggml-rpc-server`
with the same parameters.

---

## License

MIT - Built on top of [llama.cpp](https://github.com/ggml-org/llama.cpp) by Georgi Gerganov and the ggml team.