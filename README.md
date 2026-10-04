# llama-rpc-cluster

**Collega due PC con un cavo Ethernet e unisci le loro GPU per caricare modelli IA enormi.**

Usando llama.cpp RPC, la VRAM del PC secondario (Worker) si aggiunge a quella del PC principale (Master),
permettendo di caricare modelli come Qwen 2.5 32B che non entrerebbero in una sola scheda video.

---

## Come funziona

```
PC MASTER (GPU principale)  <---CAT5e/CAT6--->  PC WORKER (GPU secondaria)
RTX 5070 8GB                  Ethernet diretto   RTX 3050 4GB
llama-server.exe                                 ggml-rpc-server.exe

Risultato: 8 + 4 = 12 GB di VRAM disponibili per l'IA!
```

Il Master carica il modello e invia automaticamente i layer che non entrano nella propria GPU al Worker.
Il cavo Ethernet diretto garantisce latenza minima (~0.1ms) e banda massima (1 Gbps).

---

## Installazione in 2 comandi

> **Requisiti:** Windows 10/11, GPU Nvidia, cavo Ethernet CAT5e/CAT6, PowerShell 5+

### 1 - Sul PC MASTER (il piu' potente)

Apri **PowerShell come Amministratore** e incolla:

```powershell
irm https://raw.githubusercontent.com/KingSalvo05/llama-rpc-cluster/main/scripts/install-master.ps1 | iex
```

Lo script fa automaticamente:
- Rileva la GPU Nvidia presente
- Imposta IP statico `192.168.50.1` sulla porta Ethernet
- Apre la porta 50052 sul firewall
- Scarica l'ultima versione di llama.cpp con supporto CUDA
- Trova tutti i modelli `.gguf` gia' presenti sul PC
- Crea `Avvia_Cluster_MASTER.bat` sul Desktop

### 2 - Sul PC WORKER (il vecchio PC)

Apri **PowerShell come Amministratore** e incolla:

```powershell
irm https://raw.githubusercontent.com/KingSalvo05/llama-rpc-cluster/main/scripts/install-worker.ps1 | iex
```

Lo script fa automaticamente:
- Rileva la GPU Nvidia presente
- Imposta IP statico `192.168.50.2` sulla porta Ethernet
- Apre la porta 50052 sul firewall
- Scarica llama.cpp con supporto CUDA
- Crea `Avvia_Worker_RPC.bat` sul Desktop
- (Opzionale) Configura avvio automatico all'accensione del PC

---

## Uso quotidiano

1. **Sul Worker:** doppio click su `Avvia_Worker_RPC.bat` e lascia aperta la finestra nera.
2. **Sul Master:** doppio click su `Avvia_Cluster_MASTER.bat`, scegli il modello, premi Invio.
3. Il browser si apre da solo su `http://localhost:8080` con la chat pronta!

---

## Compatibilita' API

Il server espone un endpoint **compatibile con le API OpenAI**:

```
http://127.0.0.1:8080/v1
```

Funziona con Continue (VS Code), Open WebUI, script Python, e qualsiasi app che supporti le API OpenAI.

---

## Quanta VRAM guadagno?

| Master GPU      | Worker GPU      | VRAM Totale | Modello consigliato  |
|-----------------|-----------------|-------------|----------------------|
| RTX 5070 8GB    | RTX 3050 4GB    | ~12 GB      | Qwen 2.5 32B Q4      |
| RTX 4090 24GB   | RTX 3080 10GB   | ~34 GB      | Llama 3 70B Q4       |
| RTX 3080 10GB   | RTX 3060 8GB    | ~18 GB      | Mistral 22B Q4       |
| Qualsiasi       | Qualsiasi       | Somma VRAM  | In base al totale    |

> Nota: la VRAM effettivamente utilizzabile e' circa il 90% per via dell'overhead di sistema.

---

## Configurazione avanzata

### IP personalizzati

Per usare IP diversi da quelli di default, modifica le variabili all'inizio di `install-master.ps1`
e `install-worker.ps1` prima di eseguirli.

### Piu' Worker contemporanei

Puoi collegare **piu' PC Worker** contemporaneamente tramite uno switch di rete.
Esegui `install-worker.ps1` su ogni PC con IP diversi (`192.168.50.2`, `192.168.50.3`, ecc.)
e nel launcher Master aggiungi tutti gli indirizzi separati da virgola:

```
--rpc 192.168.50.2:50052,192.168.50.3:50052
```

---

## Domande frequenti

**Il vecchio PC deve avere il modello scaricato?**
No. Solo il Master ha bisogno del file `.gguf`. Il Worker espone solo la GPU.

**Posso usare il Wi-Fi invece del cavo?**
Funziona ma con latenza e banda ridotte. Consigliato solo per modelli piccoli (7B).

**Funziona con GPU AMD?**
Il supporto ROCm di llama.cpp e' sperimentale su Windows. Su Linux funziona meglio.

**Il vecchio PC deve avere Windows?**
Lo script e' per Windows. Su Linux puoi avviare manualmente `ggml-rpc-server` con gli stessi parametri.

---

## Licenza

MIT - Basato su [llama.cpp](https://github.com/ggml-org/llama.cpp) di Georgi Gerganov e il team ggml.