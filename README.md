# 🧠 llama-rpc-cluster

**Trasforma due PC qualunque in un cluster per l'IA locale — un click, zero configurazione manuale.**

Collegando due PC con un cavo Ethernet, questo progetto unisce le VRAM delle loro GPU Nvidia tramite **llama.cpp RPC**, permettendo di caricare modelli enormi (es. Qwen 2.5 32B) che non entrerebbero in un'unica scheda video.

---

## ✨ Come funziona

```
┌─────────────────────┐        CAT5e/CAT6        ┌──────────────────────┐
│   PC MASTER         │◄──────────────────────►│   PC WORKER          │
│   RTX 5070 8GB      │       Ethernet diretto   │   RTX 3050 4GB       │
│   llama-server.exe  │                          │   ggml-rpc-server.exe│
│   = 12 GB VRAM totali!                         │                      │
└─────────────────────┘                          └──────────────────────┘
```

Il PC Master carica il modello e distribuisce automaticamente i layer che non entrano nella propria GPU al Worker. Il cavo Ethernet diretto (senza router) garantisce latenza minima (~0.1ms) e banda massima (1 Gbps).

---

## 🚀 Installazione in 2 comandi

> **Requisiti:** Windows 10/11, GPU Nvidia, cavo Ethernet CAT5e o CAT6, PowerShell 5+

### 1. Sul PC MASTER (il più potente)

Apri **PowerShell come Amministratore** e incolla:

```powershell
irm https://raw.githubusercontent.com/TUO_USERNAME/llama-rpc-cluster/main/scripts/install-master.ps1 | iex
```

Lo script farà automaticamente:
- ✅ Rileva la GPU Nvidia presente
- ✅ Imposta IP statico `192.168.50.1` sulla porta Ethernet
- ✅ Apre la porta 50052 sul firewall
- ✅ Scarica l'ultima versione di llama.cpp con supporto CUDA
- ✅ Trova tutti i modelli `.gguf` già presenti sul PC
- ✅ Crea `Avvia_Cluster_MASTER.bat` sul Desktop

### 2. Sul PC WORKER (il vecchio PC)

Apri **PowerShell come Amministratore** e incolla:

```powershell
irm https://raw.githubusercontent.com/TUO_USERNAME/llama-rpc-cluster/main/scripts/install-worker.ps1 | iex
```

Lo script farà automaticamente:
- ✅ Rileva la GPU Nvidia presente
- ✅ Imposta IP statico `192.168.50.2` sulla porta Ethernet
- ✅ Apre la porta 50052 sul firewall
- ✅ Scarica llama.cpp con supporto CUDA
- ✅ Crea `Avvia_Worker_RPC.bat` sul Desktop
- ✅ (Opzionale) Imposta avvio automatico all'accensione del PC

---

## 🎮 Uso quotidiano

1. **Sul Worker:** doppio click su `Avvia_Worker_RPC.bat` e lascia aperta la finestra.
2. **Sul Master:** doppio click su `Avvia_Cluster_MASTER.bat`, scegli il modello, premi Invio.
3. Il browser si apre da solo su `http://localhost:8080` con la chat! 🎉

---

## 🔌 Compatibilità API (VS Code, script Python, ecc.)

Il server espone un endpoint **compatibile con le API di OpenAI**:

```
http://127.0.0.1:8080/v1
```

Puoi usarlo con **Continue** (VS Code), **Open WebUI**, **script Python**, o qualsiasi app che supporti le API OpenAI.

---

## 📊 Quanta VRAM guadagno?

| Master GPU | Worker GPU | VRAM Totale | Modello consigliato |
|------------|------------|-------------|---------------------|
| RTX 5070 8GB | RTX 3050 4GB | ~12 GB | Qwen 2.5 32B Q4 |
| RTX 4090 24GB | RTX 3080 10GB | ~34 GB | Llama 3 70B Q4 |
| RTX 3080 10GB | RTX 3060 8GB | ~18 GB | Mistral 22B Q4 |
| Qualsiasi | Qualsiasi | Somma | In base al totale |

> **Nota:** La VRAM effettiva utilizzabile è circa il 90% per via dell'overhead di sistema.

---

## 🛠️ Configurazione avanzata

### IP personalizzati

Se vuoi usare IP diversi da quelli di default, modifica le variabili nei file generati:
- Master: modifica `192.168.50.1` in `install-master.ps1`
- Worker: modifica `192.168.50.2` in `install-worker.ps1`

### Più Worker contemporanei

Puoi collegare **più PC Worker** contemporaneamente! Basta eseguire `install-worker.ps1` su ogni PC con IP diversi (`192.168.50.2`, `192.168.50.3`, ecc.) e nel launcher Master aggiungere tutti gli indirizzi separati da virgola:

```
--rpc 192.168.50.2:50052,192.168.50.3:50052
```

### Connessione tramite Switch (3+ PC)

Se hai uno switch di rete, puoi collegare tutti i PC allo switch invece che in modo diretto. Gli IP statici funzionano allo stesso modo.

---

## ❓ FAQ

**Q: Il vecchio PC ha bisogno del modello scaricato?**
No! Solo il Master ha bisogno del file `.gguf`. Il Worker espone solo la GPU.

**Q: Posso usare connessione Wi-Fi invece del cavo?**
Funziona, ma con latenza più alta e banda ridotta. Consigliato solo per modelli piccoli (7B).

**Q: Funziona con GPU AMD?**
Il supporto ROCm di llama.cpp è ancora sperimentale su Windows. Su Linux funziona meglio.

**Q: Il vecchio PC deve avere Windows?**
Lo script di installazione è per Windows. Su Linux puoi avviare manualmente `ggml-rpc-server` con gli stessi parametri.

**Q: Posso usare questo per più utenti in rete locale?**
Sì! Il server Master espone l'API su `0.0.0.0:8080`, raggiungibile da qualsiasi PC nella stessa rete.

---

## 📝 Licenza

MIT — Fai quello che vuoi, ma un ⭐ sul repo è sempre apprezzato!

---

## 🙏 Credits

Basato su [llama.cpp](https://github.com/ggml-org/llama.cpp) di Georgi Gerganov e il team ggml.
