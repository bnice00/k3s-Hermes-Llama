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
This project was one i took on to learn the fundamentals of Kubernetes and also to familiarize myself with vLLM serving over a cluster on the ROCm image. Initial performance with vLLM/ROCm was less than
ideal seeing peaks from empty KV around 40 tok/s. My research shows that this is a common issue on consumer hardware with ROCm, hence the popularity of the Vulkan variants of llama.cpp, ollama, etc.
These results pushed me to explore my options with llama.cpp:server-vulkan on my current hardware. The stack now runs llama.cpp:server-vulkan as the inference engine serving Gemma-4-26B-A4B through a Hermes agent harness
averaging 70-80 tok/s throughout the KV curve from empty to filled. I am using K3s instead of traditional k8s since my basic needs did not exceed K3s capabilities. Keeping this project on K3s reduced unnecessary
complexity in a homelab setting where i am the only user. This setup requires using the latest amdgpu linux drivers as well as the dedicated rocm/k8s-device-plugin daemonset. I am also utilizing the
rocm/k8s-device-labeller to get more detailed GPU statistics. The k8s-device-plugin daemonset is the essential piece to advertise GPU resources properly on the cluster. Advertising the GPU this way on top of
adding "resources.limits.amd.com/gpu: 1" to the Llama.cpp manifest allows the scheduler to only place pods on nodes where the device plugin advertises amd.com/gpu.

This stack was built originally using the model Ornith1.5/9B at full precision. I was not satisfied with the performance of Ornith due to getting consistent responses leaking Mandarin into a fully english
conversation as well as unacceptable levels of hallucination during tool calls. Llama.cpp now serves Gemma-4-26B-A4B which works significantly better in my use case, and handles tool calling gracefully via Hermes
as long as the scope of the work is properly prompted. The model is interchangeable via the llama.cpp manifest & the Hermes config.yaml.

Since then the stack has grown past just inference. Hermes now has its own self-hosted git server (Forgejo) where it opens pull requests for me to review, a self-hosted search and page extraction pipeline
(SearXNG + Firecrawl) so it no longer depends on paid APIs, and network policies that keep it locked out of my LAN. The original vLLM + Streamlit version of this stack lives in /historic.

### Hardware 1.1
The cluster consists of two nodes;

-beachbumhq/control plane= (Ryzen 3 5300G, 32gb DDR4, running NixOS 26.05 headless). This box also doubles as my NAS and runs my media stack in Docker outside the cluster.

&&

-beachbumserve/agent= (Ryzen 9 3900x, RX 7900 XTX, 32gb ddr4, running Ubuntu server 26.04).

I originally chose this hardware specifically to target ROCm 7.0 support since speeds and throughput seemed to have greatly increased with proper driver support for AMD silicon in the past year. Although my final
configuration landed on llama.cpp:server-vulkan, that is not to discredit the capability of ROCm. ROCm excels on commercial serving hardware and overall throughput, Vulkan offers mature support for consumer
hardware due to the community driven nature of the product. Factoring this in to my situation I chose to proceed with Vulkan. In the future i plan to record benchmarks against the llama.cpp:server-rocm image to rule out
vLLM/ROCm as a factor in my particular case, and those will go in /benchmarks.

hq gets backed up every night with restic to an external SSD (k3s server state, a Forgejo dump, app data and /etc/nixos). The backup job is declared in my NixOS config so it rebuilds with the machine.


### Deployments 1.2
Everything in the cluster is scaled to "replicas=1" since this project only requires availability for personal use.
- (Inference Engine) llama.cpp:server-vulkan. This deployment runs the model weights and serves the OpenAI endpoint on ClusterIP port:8000 as well as NodePort on port:32000. Available at ghcr.io/ggml-org/llama.cpp:server-vulkan

The supporting deployments are as follows:
- (Agentic Harness) nousresearch/hermes-agent in a modified docker image built by me incorporating kubectl and piper-tts-1.8.0, available on my public docker hub repo at https://hub.docker.com/r/a1abeachbum/hermes-kubectl
- (STT Provider) a1abeachbum/whispervulkan-server, whisper.cpp in the Vulkan-server variation packaged in a docker container by me and available at https://hub.docker.com/r/a1abeachbum/whispervulkan-server
- (Agent Sandbox) a1abeachbum/deb-slim-ssh (stateful-set). Debian trixie slim image that acts as Hermes's workspace. It now carries a dev toolbox (git, tea, uv, node/npm, build-essential, ripgrep, jq) so Hermes can clone, code, test and open PRs on its own. Available at https://hub.docker.com/r/a1abeachbum/deb-slim-ssh
- (RAG memory) linuxserver/obsidian. Obsidian instance for Hermes, a collection of skills and memories recorded as .md files for the agent to retrieve and review based on the scope of the task requested. Syncthing runs next to it to keep the vault synced to my devices. https://hub.docker.com/r/linuxserver/obsidian
- (Web search) searxng/searxng with JSON output turned on, used as Hermes's web_search backend.
- (Web extract) self-hosted Firecrawl installed from the Helm chart in the Firecrawl repo, used as Hermes's web_extract backend. The chart has no nodeSelector option so I pin it to hq with a Helm 4 post-renderer plugin (helm/firecrawl).
- (Git) Forgejo from the official Helm chart with its data on my NAS drives. Hermes has its own bot user that can push branches and open PRs in one org, but it can't push to main, can't create repos and can't merge. Everything it does comes to me as a PR.
- (TTS) KittenTTS runs off-cluster on my gaming rig. Hermes reaches it through a selectorless Service + EndpointSlice (kitten-tts-serve.yaml / kitten-tts-eps.yaml).

Additionally, I added monitoring to the cluster with the kube-prometheus-stack public helm chart. To replicate my configuration it can be applied with the following commands and the values file located at /helm/kps.yaml:
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
  -f helm/kps.yaml
```
### verify
```bash
kubectl get pods -n monitoring
```
```bash
kubectl get pv -n monitoring
```


### Services & Exposure 1.3
Most services are reached through Traefik ingress on subdomains of my own domain, with TLS certs from cert-manager using the Cloudflare DNS challenge. The DNS records point at LAN addresses so nothing
in this repo is exposed to the internet, and I use Tailscale to reach it when I'm away from home. Llama.cpp (32000) and Obsidian (32300) are also still on NodePorts as a fallback.
**Minimizing the attack surface by only exposing the services that require interaction was my main priority. Everything else stays internal to the cluster on ClusterIP.


### Network Policies 1.4
Hermes and its sandbox both run behind NetworkPolicies that deny everything by default (manifests/hermes-netpol.yaml, manifests/deb-slim-net.yaml). Hermes can only reach DNS, the sandbox over SSH,
the internet with all private ranges blocked, llama.cpp, whisper, SearXNG, Firecrawl and the TTS rig. The sandbox is blocked from my LAN and can reach Forgejo for git.

One thing that tripped me up: NetworkPolicy ports are the pod's port, not the Service port, because the policy gets checked after the Service translates it. SearXNG's Service is on 8181 but the policy has to allow 8080.


### Hermes git workflow 1.5
Hermes works issues from Forgejo with a skill I wrote: clone, branch, commit, push, then open a PR with tea. Branch protection on main means I review and merge everything. I tested it end to end on local Gemma and it ran clean.


## Requirements 2.0
-prerequisites for running this stack
### Agent sandbox image build

The `deb-slim` StatefulSet is the workspace Hermes reaches over SSH. Hermes logs in as `hermes-agent` (uid 10000), not root. The **public** key is baked into the image's `authorized_keys`; private keys never go in the image.
Hermes's SSH key is mounted into the Hermes pod from a Secret, and the sandbox's own Forgejo key and API token come from the `hermes-forgejo` Secret and get copied into place when the container starts.

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

-The Dockerfile, entrypoint.sh and ssh_config are in /deb-slim.
-`entrypoint.sh` copies the Forgejo key and token from the mounted Secret into the user's home with the right owner and permissions (SSH refuses keys owned by root), logs tea in, then starts sshd.
-`ssh_config` sets up a `forgejo` host alias so Hermes can just run `git clone forgejo:<org>/<repo>.git`.

#### Build and push

```bash
cd ~/<path_to_repo>/deb-slim
```
-Enter the build context containing the Dockerfile, `entrypoint.sh`, `ssh_config` and `authorized_keys`.

```bash
docker login
```
-Authenticate to your registry.

```bash
docker buildx build --platform linux/amd64 -t <your_username>/deb-slim-ssh:<date> --push .
```
-Build for the cluster's architecture and push in one step. The `--platform` flag is required when
building on Apple Silicon for amd64 nodes. I pin the image by digest in the StatefulSet instead of using a tag.

> **Host key persistence:** the sandbox regenerates its SSH host key on every
> pod recreation, so Hermes sees a changed fingerprint each rebuild. Persist
> `/etc/ssh/ssh_host_*` via a Secret or PVC to avoid this.

### Initial set up 2.1
My control plane is NixOS so k3s comes from `services.k3s` in configuration.nix, pinned to 1.36 to match the agent. The curl install below works on any other distro.

```bash
curl -sfL https://get.k3s.io | sh -
```
-install latest version of k3s on server machine (for this example it was built upon v1.36.x)


```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```
-Get cluster agent token from file

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://<your_server_ip>:6443 K3S_TOKEN=<your_node_token> sh -
```
-install and start k3s on the agent node using the token

### Secrets

```bash
kubectl create secret generic hermes-ssh-key \
  --from-file=id_ed25519=./hermes_ed25519 \
  -n hermes-lair
```
-Mounted into the Hermes pod at runtime. Base64 in a Secret is encoding, not
encryption, so treat the manifest exactly like the key itself.

```bash
kubectl create secret generic hermes-forgejo -n hermes-lair \
  --from-file=id_ed25519=./hermes_forgejo \
  --from-file=known_hosts=./forgejo_known_hosts \
  --from-literal=token=<forgejo_api_token>
```
-The sandbox's Forgejo key, the Forgejo host key and an API token (repository + issue write, user read).

-Example templates of every secret are in /secrets as `*.example.yaml`. The real ones are gitignored.

### Firewall rules 2.2
To use this repo and run my configuration there are a few firewall rule additions that must be made. Please see the k3s documentation on the recommended, optional and required ports @:
https://docs.k3s.io/installation/requirements

beachbumserve uses UFW. beachbumhq is NixOS so its ports are opened in `networking.firewall` in configuration.nix instead.
For UFW use:

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

**Control plane — `beachbumhq` (NixOS)**

| Port | Proto | Purpose |
|---|---|---|
| 22 | tcp | SSH |
| 80, 443 | tcp | Traefik ingress |
| 6443 | tcp | k3s API server (agent join) |
| 8472 | udp | flannel VXLAN overlay |
| 10250 | tcp | kubelet |
| 30000-32767 | tcp | NodePort range |

-`cni0`, `flannel.1` and `tailscale0` are set as trusted interfaces.

**Agent — `beachbumserve` (UFW)**

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
> the control plane and never traverses the CNI. Without this rule UFW
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
-This creates the namespaces first and then applies all remaining manifests in this directory, replicating my exact setup.
The GPU device-plugin daemonset (with a nodeSelector modification to keep it off the control-plane iGPU) is included and applied automatically as well.

### Helm releases

-cert-manager, kube-prometheus-stack, the AMD GPU exporter and Forgejo install from their upstream charts with the values files in /helm. Values files only hold my overrides, not the full defaults.

-Firecrawl installs from the chart inside the Firecrawl repo (pinned to release v2.11.162) with a post-renderer plugin that pins it to hq:

```bash
helm plugin install helm/firecrawl/firecrawl-postrender
```
```bash
helm install firecrawl <path_to_firecrawl_repo>/examples/kubernetes/firecrawl-helm -n firecrawl \
  -f helm/firecrawl/firecrawl.yaml -f secrets/firecrawl-values.yaml --post-renderer hq-pin
```


### After everything is applied verify with:

```bash
kubectl get pods -o wide -A
```
-this will return active pods across all namespaces with their current state

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
```bash
kubectl logs deploy/searxng -n sear-search -f
```

-These commands are to watch the rolling logs as each service comes up




> keep in mind to run any kubectl commands against components of this stack you need to add the -n <namespace> to declare which namespace to perform the requested operation in.

> Sudo prefix may be required when running kubectl commands depending on your root access.

## What's next 4.0
- Convert the raw manifests into Helm charts split by what they do (inference, hermes, knowledge, searxng, platform)
- A Forgejo Actions runner for Hermes's org
- Argo CD pulling this repo from Forgejo so the cluster deploys itself from git
