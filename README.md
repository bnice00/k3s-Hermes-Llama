# K3s inference stack on Llama.cpp/Vulkan + Hermes-agent

```
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
.........................................................-=*%@@%%%%+=:..............................
.......................................................*%@@@@@%@@@@@%#+:............................
......................................................*@@%@@%@@@@@@@@@%#-...........................
......................................................#@#*%@@@@@@@@@@@@%%...........................
.......................................................#%**%@@@@@@@@@@@@%=..........................
......................................................:*#**#@%%@@@@@@@@@%=..........................
......................................................*#*****##@@@@@@@@@@%:.........................
.......................................................*#****%@@@@@@@@@@@@#=........................
.......................................................-#**%%@@@@@@@@@@@@@=.........................
.......................................................-*%%@@#%@@@@@@@@@#-..........................
...........................................................:##@@@@@@@@@@-...........................
..........................................................=*%@@@@@@@@@@@@%-.........................
.......................................................-*@@@@@@@@@@@@@@@@@@#........................
............::::::::::::::::::::::::::::::::::::::::::*@@@@@@@@@@@@@@@@@@@@@%:::::::::::............
...........:-----------------------------------------#@@@@@@@@@@@@@@@@@@@@@@@@----------............
....................................................-@@@@@@@@@@@@@@@@@@@@@@@@@=.....................
..........................----------................#@@@@@@@@@@@@@@@@@@@@@@@@@@.....................
.........................:=@@@@@@@@+:..............=@@@@@@@@@@@@@@@@@@@@@@@@@@@.....................
...........:+++++++++======+@@@@@%+===============+@@@@@@@@@@@@@@@@@@@@@@@@@@@@:....................
.............................%@@%:...............+@@@@@@@@@@@@@@@@@@@@@@@@@@@@*=+==+++++:...........
...........:=============+*==%@@%++============+*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*.....................
.............................#@@*............:+#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%==========:...........
.............................%@@*..-+++:::::*@@@@@@@@@@%%@@@@@@@@@@@@@@@@@@@@#......................
............:::.............#@@@@-@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#......................
...........:==============+@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@++++++@@@@@=...........
..........................%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#.-+++++:=++:...........
.......................+*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#.......................
...................:===@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%:.......................
..................:#*##@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%-=##=---:................
...........:===#%%%@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%%%=...........
...........-****************************************************************************-...........
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
....................................................................................................
```
## Summary 1.0: The Journey from vLLM to Llama.cpp
This project was one i took on to learn the fundamentals of Kubernetes and also to familiarize myself with vLLM serving over a cluster on the ROCM image. Initial performance with vLLM/ROCM was less than
ideal seeing peaks from empty KV around 40 tok/s. My research shows that this is a common issue on consumer hardware with ROCM, hence the popularity of the Vulkan variants of llama.cpp,ollama,etc.
These results pushed me to explore my options with llama.cpp:server-vulkan on my current hardware. The stack now runs llama.cpp:server-vulkan as the inference engine serving Gemma-4-26B-A4B through a Hermes agent harness
averaging 70-80 tok/s throughout the KV curve from empty to filled. I am using K3s instead of traditional k8s since my basic needs did not exceed K3s capabilities. Keeping this project on K3s reduced unneccesary 
complexity in a homelab setting where i am the only user. This setup requires using the latest amdgpu linux drivers as well as the dedicated rocm/k8s-device-plugin daemonset. I am also utilizing the 
rocm/k8s-device-labeller to get more detailed GPU statistics. The k8s-device-plugin daemonset is the essential piece to advertise GPU resources properly on the cluster. Advertising the GPU this way on top of 
adding "resources.limits.amd.com/gpu: 1" to the Llama.cpp manifest allows the scheduler to only place pods on nodes whom which the device plugin advertises resources.limits.amd.com/gpu: 1.

This stack was built originally using the model Ornith1.5/9B at full precision. I was not satisfied with the performance of Ornith due to getting consistent responses leaking Mandarin into a fully english 
conversation as well as unnaceptable levels of hallucination during tools calls. Llama.cpp now serves Gemma-4-26B-A4B which works signifigantly better in my use case, and handles tool calling gracefully via Hermes
as long as the scope of the work is properly prompted. The model is interchangeable via the llama.cpp manifest & the Hermes config.yaml. 

### Hardware 1.1 
The cluster Consist of two nodes;

-BeachBumHQ/control plane= (Ryzen 3 5300G desktop, 32gb DDR4, running Ubuntu desktop 26.04) 

&&

-beachbumserve/agent= (Ryzen 9 3900x, RX 7900 XTX, 32gb ddr4, running Ubuntu server 26.04).  

I originally chose this hardware specifically to target ROCM 7.0 support since speeds and throughput seemed to have greatly increased with proper driver support for AMD silicon in the past year. Although my final 
configuration landed on llama.cpp:server-vulkan, that is not to discredit the capability of the ROCM kernel. ROCM excels on commercial serving hardware and overall throughput, Vulkan offers mature support for consumer 
hardware due to the community driven nature of the product. Factoring this in to my sitiuation I chose to proceed with Vulkan, in the future i plan to record benchmarks against the llama.cpp:server-rocm image to exonerate
vLLM/ROCM as a factor in my particular case. See the documentation in /benchmarks for further comparison. 


### Deployments 1.2
Within the cluster we run 4 deployment and 1 stateful set scaled to "replicas=1" since this project only requires availability for personal use.
- (Inference Engine)llama.cpp:server-vulkan, This deployment runs the model weights and serves the openAI endpoint on ClusterIP port:8000 as well as NodePort on port:32000. Available at ghcr.io/ggml-org/llama.cpp:server-vulkan 
The supporting deployments are as follows:      
- (Agentic Harness)nousresearch/hermes-agent in a modified docker image built by me incorporating kubectl and piper-tts-1.8.0 available on my public docker hub repo at https://hub.docker.com/r/a1abeachbum/hermes-kubectl
- (STT Provider)a1abeachbum/whispervulkan-server whisper.cpp in the Vulkan-server variation packaged in a docker container by me and available on my public docker-hub repo at https://hub.docker.com/r/a1abeachbum/whispervulkan-server
- (Agent Sandbox)a1abeachbum/deb-slim-ssh(stateful-set) debian trixie slim image base with openssh-server,python3,python-is-python3,jq,curl & wget to act as a safe workspace for Hermes, available at my public docker-hub repo at
   https://hub.docker.com/r/a1abeachbum/deb-slim-ssh 
- (RAG memory)linuxserver/obsidian obsidian instance for Hermes,a collection of skills and memories recorded as .md files for the agent to retrieve and review based on the scope of the task requested. available on docker-hub 
   https://hub.docker.com/r/linuxserver/obsidian  
Aditionally, I most recently added monitoring to the cluster with the kube-prometheus-stack public helm chart. To replicate my configuration it can be applied with the following commands and the prometheus-values.yaml file
located at /monitoring:
### Add the repo
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
```
```bash
helm repo update
```
### create namespace
```bash
kubectl create namespace monitoring
```
### create secret for Grafana
```bash
kubectl create secret generic grafana-admin -n monitoring \
  --from-literal=admin-user=<your_username> \
  --from-literal=admin-password=<your_password>
``` 
### install the chart
```bash
helm install kps prometheus-community/kube-prometheus-stack \
  --version 91.4.0 \
  --namespace monitoring \
  -f monitoring/prometheus-values.yaml
```
### verify
```bash
kubectl get pods -n monitoring
```
```bash
kubectl get pv -n monitoring
```


### Services & Exposure 1.3
In this configuration i have exposed 2 of the services stated above to my LAN via nodePort. The service manifests have been added in /manifests to facilitate a declaritive apply.
The exposed services and the respective port are as follows:
- Obsidian/Port=32300- exposed for my review and additions into Hermes memory vault.
- Llama.cpp/Port=32000- exposed for direct access to Llama.cpp webUI chat interface as a fall back when bypassing Hermes is needed for config and testing.
**Minimizing the attack surface only exposing the services that require interaction was my main priority. I was able to keep the other 3 services communication internal to the cluster  
utilizing clusterIP 


## Requirements 2.0
-prerequisites for running this stack
### Agent sandbox image build

The `deb-slim` StatefulSet is the workspace Hermes reaches over SSH. The
**public** key is baked into the image's `authorized_keys`; the **private**
key never enters the image — it is mounted into the Hermes pod from a
Secret.

#### Generate the keypair

```bash
ssh-keygen -t ed25519 -f ./hermes_ed25519 -C "hermes-agent" -N ""
```
-Generate a dedicated keypair for the agent. `-N ""` sets an empty passphrase
since Hermes authenticates non-interactively. Produces `hermes_ed25519`
(private) and `hermes_ed25519.pub` (public).

```bash
cp hermes_ed25519.pub ./deb-slim/authorized_keys
```
-Stage the public key in the build context so the Dockerfile can `COPY` it.

#### Dockerfile

```dockerfile
FROM debian:trixie-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      openssh-server \
      python3 \
      python-is-python3 \
      jq \
      curl \
      wget \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd /root/.ssh && chmod 700 /root/.ssh

COPY authorized_keys /root/.ssh/authorized_keys
RUN chmod 600 /root/.ssh/authorized_keys

RUN sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config \
    && sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D", "-e"]
```

-`PasswordAuthentication no` means key auth is the only way in. `-e` sends
sshd logs to stderr so they surface in `kubectl logs`.
#### Build and push

```bash
cd ~/<path_to_repo>/deb-slim
```
-Enter the build context containing the Dockerfile and `authorized_keys`.

```bash
docker login
```
-Authenticate to your registry.
      
```bash
docker build --platform linux/amd64 -t <your_username>/deb-slim-ssh:v1 .
```
-Build for the cluster's architecture. The `--platform` flag is required when
building on Apple Silicon for amd64 nodes.

```bash
docker push <your_username>/deb-slim-ssh:v1
```
-Push so the cluster can pull it.

> **Host key persistence:** the sandbox regenerates its SSH host key on every
> pod recreation, so Hermes sees a changed fingerprint each rebuild. Persist
> `/etc/ssh/ssh_host_*` via a Secret or PVC to avoid this.

### Initial set up 2.1

```bash
curl -sfL https://get.k3s.io | sh - 
```
-install latest version of k3s on server machine(for this example it was built upon V1.36.x)


```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```
-Get cluster agent token from file

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://<your_server_ip>:6443 K3S_TOKEN=<your_node_token> sh -
```
-install and start k3s on the agent node using the token

### Create the private ssh key in a k3s secret from step 2.0(Generate the Key pair)

```bash
kubectl create secret generic hermes-ssh-key \
  --from-file=id_ed25519=./hermes_ed25519 \
  -n hermes-lair
```
-Mounted into the Hermes pod at runtime. Base64 in a Secret is encoding, not
encryption — treat the manifest exactly like the key itself.                 
-examples templates of the secret file are included in /manifests/hermesssh-secret.yaml                    

### Firewall rules 2.2
To use this repo and run my configuration there is a few firewall rule additons that must be made. Please see k8s documentation on the reccomended, optional and required ports @:
https://docs.k3s.io/installation/requirements
If you would like to use my port configuration it is as follows:
use:

```bash
sudo ufw status numbered
```
-show current rules in a numbered list 


```bash
sudo ufw allow <rule> 
```
-Allow for each rule respectively.


```bash
sudo ufw delete <numberofrule>
```
-delete any rules added by mistake if needed. 

### Rules list 2.3

NodePort services listen on **every** node in the cluster, not only the node
the pod runs on. Allow the NodePort on whichever node you browse to.

**Control plane — `beachbumhq`**

| Port | Proto | From | Purpose |
|---|---|---|---|
| 22 | tcp | `192.168.4.0/24` | SSH |
| 6443 | tcp | Anywhere | k3s API server (agent join) |
| 8472 | udp | Anywhere | flannel VXLAN overlay |
| 10250 | tcp | Anywhere | kubelet |
| 30300 | tcp | `192.168.4.0/24` | Grafana NodePort (LAN access) |
| `<llama_nodeport>` | tcp | `192.168.4.0/24` | llama.cpp WebUI / OpenAI endpoint |
| `<obsidian_nodeport>` | tcp | `192.168.4.0/24` | Obsidian vault UI |
| — | — | `10.42.0.0/16` | pod network |
| — | — | `10.43.0.0/16` | service network |

**Agent — `beachbumserve`**

| Port | Proto | From | Purpose |
|---|---|---|---|
| 22 | tcp | `192.168.4.0/24` | SSH |
| 8472 | udp | Anywhere | flannel VXLAN overlay |
| 10250 | tcp | Anywhere | kubelet (scraped by Prometheus) |
| 9100 | tcp | `<control_plane_ip>` | node-exporter scrape |
| `<llama_nodeport>` | tcp | `192.168.4.0/24` | llama.cpp WebUI / OpenAI endpoint |
| `<obsidian_nodeport>` | tcp | `192.168.4.0/24` | Obsidian vault UI |
| — | — | `10.42.0.0/16` | pod network |
| — | — | `10.43.0.0/16` | service network |

> **node-exporter (9100):** node-exporter runs with `hostNetwork: true`, so the
> scrape arrives on the agent's physical interface as ordinary LAN traffic from
> the control plane — it never traverses the CNI. Without this rule UFW
> silently drops the SYN and the target reports `context deadline exceeded`
> rather than `connection refused`, which reads as a slow scrape rather than a
> blocked one.

#### Confirm your NodePort values

```bash
kubectl get svc -A -o wide | grep NodePort
```
-Returns every NodePort service with its assigned port. Substitute the real
values for the placeholders above.

#### Example

```bash
sudo ufw allow from 192.168.4.111 to any port 9100 proto tcp comment 'prometheus node-exporter scrape'
```
-Scoped to a single source and a single port. I prefer this over opening a port
to the whole subnet.

## Run Commands 3.0

### Apply manifests

```bash
kubectl apply -f manifests/
```
-This will create the 2 namespaces first from manifests/00-namespace.yaml, manifests/01-namespace.yaml that this stack lives within and apply all remaining manifests within this directory, replicating my exact setup. 
the GPU device-plugin daemonset (with a nodeSelector modification to keep it off the control-plane iGPU) is included and applied automatically as well.


### After manifests are applied verify with: 

```bash
kubectl get pods -o wide -A
```
-this will return active pods across all namespces with their current state

```bash
kubectl logs deployments/llama-cpp -n llama-farm -f
```
```bash
kubectl logs deploy/whisper -n llama-farm -f
```
```bash
kubectl logs deploy/hermes -n hermes-lair -f
```
```bash
kubectl logs deploy/obsidian -n hermes-lair -f 
```
```bash
kubectl logs deb-slim-0 -n hermes-lair -f
```

-These commands are to watch the rolling logs as each service comes up




> keep in mind to run any kubectl commands against components of this stack you need to add the -n <namespace> to declare which namespace to perform the requested operation in.

> Sudo prefix maybe required when running kubectl commands  depending on your root access. 

