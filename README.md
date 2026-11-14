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
- (Inference Engine) llama.cpp:server-vulkan. This deployment runs the model weights and serves the OpenAI endpoint on ClusterIP port:8000, with the WebUI behind Traefik at llama.<my_domain>.com. Available at ghcr.io/ggml-org/llama.cpp:server-vulkan

The supporting deployments are as follows:
- (Agentic Harness) nousresearch/hermes-agent in a modified docker image built by me incorporating kubectl and piper-tts-1.8.0, available on my public docker hub repo at https://hub.docker.com/r/a1abeachbum/hermes-kubectl
- (STT Provider) a1abeachbum/whispervulkan-server, whisper.cpp in the Vulkan-server variation packaged in a docker container by me and available at https://hub.docker.com/r/a1abeachbum/whispervulkan-server
- (Agent Sandbox) a1abeachbum/deb-slim-ssh (stateful-set). Debian trixie slim image that acts as Hermes's workspace. It now carries a dev toolbox (git, tea, uv, node/npm, build-essential, ripgrep, jq) so Hermes can clone, code, test and open PRs on its own. Available at https://hub.docker.com/r/a1abeachbum/deb-slim-ssh
- (RAG memory) linuxserver/obsidian. Obsidian instance for Hermes, a collection of skills and memories recorded as .md files for the agent to retrieve and review based on the scope of the task requested. https://hub.docker.com/r/linuxserver/obsidian
- (My notes) a second linuxserver/obsidian instance in its own namespace that is just for me, with Syncthing next to it keeping the vault synced to my phone. Hermes can't touch this one.
- (Web search) searxng/searxng with JSON output turned on, used as Hermes's web_search backend.
- (Web extract) self-hosted Firecrawl installed from the Helm chart in the Firecrawl repo, used as Hermes's web_extract backend. The chart has no nodeSelector option so I pin it to hq with a Helm 4 post-renderer plugin (helm/firecrawl).
- (Git) Forgejo from the official Helm chart with its data on my NAS drives. Hermes has its own bot user that can push branches and open PRs in one org, but it can't push to main, can't create repos and can't merge. Everything it does comes to me as a PR.
- (TTS) KittenTTS runs off-cluster on my gaming rig. Hermes reaches it through a selectorless Service + EndpointSlice in the hermes chart. The rig's IP is one value (kittenTts.address) that feeds both the EndpointSlice and the NetworkPolicy.

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
in this repo is exposed to the internet, and I use Tailscale to reach it when I'm away from home. The only NodePorts left are Syncthing's (32384 for the GUI, 32200 TCP/UDP for device sync) since my phone has to reach it directly.
**Minimizing the attack surface by only exposing the services that require interaction was my main priority. Everything else stays internal to the cluster on ClusterIP.


### Network Policies 1.4
Hermes and its sandbox both run behind NetworkPolicies that deny everything by default (charts/hermes/templates/netpol-hermes.yaml, netpol-deb-slim.yaml). Hermes can only reach DNS, the sandbox over SSH,
the internet with all private ranges blocked, llama.cpp, whisper, SearXNG, Firecrawl and the TTS rig. The sandbox is blocked from my LAN and can reach Forgejo for git.


### Hermes git workflow 1.5
Hermes works issues from Forgejo with a skill I wrote: clone, branch, commit, push, then open a PR with tea. Branch protection on main means I review and merge everything. I tested it end to end on local Gemma and it ran clean.


### Helm charts 1.6
Everything in the cluster is now managed by Helm. My own charts live in /charts and are split by what they do instead of one big umbrella chart, since each piece gets updated on its own schedule:
- platform: namespaces, cert-manager ClusterIssuers, AMD GPU device plugin + labeller
- inference: llama.cpp + whisper
- hermes: Hermes, the deb-slim sandbox, Hermes's Obsidian, both NetworkPolicies, the KittenTTS pointer
- searxng
- knowledge: my Obsidian + Syncthing

Upstream charts (cert-manager, kube-prometheus-stack, the GPU exporter, Forgejo, Firecrawl) only get a values file in /helm with my overrides.

A few rules I stuck to: every PVC and namespace has `helm.sh/resource-policy: keep` so an uninstall can never delete my data, every image is pinned by digest, and secrets are never in a chart. They get created by hand from the templates in /secrets.
I moved the live apps into Helm without redeploying anything by keeping every name and selector the same and labeling the existing objects as Helm owned. The old raw manifests are in /historic.


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

### Rebuild order
Order matters on a fresh cluster. platform creates the namespaces everything else lives in, but its ClusterIssuers need cert-manager's CRDs, so platform goes in twice.

```bash
helm upgrade --install platform charts/platform -n kube-system --set certIssuers.enabled=false
```
-namespaces + GPU device plugin first. The release lives in kube-system so it can never delete its own namespace.

```bash
helm repo add jetstack https://charts.jetstack.io && helm repo update
helm upgrade --install cert-manager jetstack/cert-manager --version v1.21.2 -n cert-man -f helm/cert-manager.yaml
helm upgrade --install platform charts/platform -n kube-system
```
-cert-manager, then platform again to turn the ClusterIssuers on.

-Create the secrets from the templates in /secrets.

-kube-prometheus-stack (see 1.2), the AMD GPU exporter and Forgejo install from their upstream charts with the values files in /helm.

-Firecrawl installs from the chart inside the Firecrawl repo (pinned to release v2.11.162) with a post-renderer plugin that pins it to hq, since the chart has no nodeSelector option:

```bash
helm plugin install helm/firecrawl/firecrawl-postrender
helm install firecrawl <path_to_firecrawl_repo>/examples/kubernetes/firecrawl-helm -n firecrawl \
  -f helm/firecrawl/firecrawl.yaml -f secrets/firecrawl-values.yaml --post-renderer hq-pin
```

```bash
helm upgrade --install inference charts/inference -n llama-farm
helm upgrade --install hermes charts/hermes -n hermes-lair
helm upgrade --install searxng charts/searxng -n sear-search
helm upgrade --install knowledge charts/knowledge -n knowledge
```
-my own charts last.

-Before any install or upgrade I check what it will actually change against the live cluster:

```bash
helm template <release> charts/<chart> -n <namespace> | kubectl diff -f -
```
-`helm lint` only checks that the chart renders. `kubectl diff` validates against the cluster and catches typos in field names.

> If an upgrade fails with a conflict naming `kubectl-client-side-apply`, the field was originally created with kubectl apply. Add `--force-conflicts` to let Helm take it over.


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
```bash
kubectl logs deploy/obsidian-knowledge -n knowledge -f
```

-These commands are to watch the rolling logs as each service comes up




> keep in mind to run any kubectl commands against components of this stack you need to add the -n <namespace> to declare which namespace to perform the requested operation in.

> Sudo prefix may be required when running kubectl commands depending on your root access.

## What's next 4.0
- A Forgejo Actions runner for Hermes's org
- Argo CD pulling this repo from Forgejo so the cluster deploys itself from git
