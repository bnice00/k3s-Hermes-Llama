### Streamlit Docker build (vLLM stack)
> You must build the docker image prior to moving on in these steps. See my docker build commands and notes below.
Install docker desktop with your preferred package manager first.
> The included manifests are pointed at my private dockerhub repo and image. Adjust to your use case.
This is to be built on Python3 base; see dockerfile.
> Streamlit manifest reference a regcred file to pull from a private repo, this is to harden security by removing bare credentials from the manifest. Use the commands below to generate your regcred.
```bash
cd ~/<path_to_repo>/streamlit
```
-Enter into the /streamlit directory
```bash
docker login
```
-Login to your docker account
```bash
docker build --platform linux/amd64 -t <your_username>/<your_repo>:v1 .
```
-Build the docker image at your registry. ( I built this image on a apple silicon mac therefore the --platform linux/amd64 flag was required for the target machines, keep this in mind when building your image
and adjust as necessary for your target machine)
```bash
docker push <your_username>/<your_repo>:v1
```
-Push to your docker hub registry to be able to pull back into k3s as a image in the streamlit manifest.
```bash
kubectl create secret docker-registry regcred --docker-server=https://index.docker.io/v1/ --docker-username=<your_username> --docker-password=<your_token> -n vllm-rocm
```
-Create the "regcred" file using your specific docker token to avoid leaking Docker password into the shell.
>after these steps are completed verify your image is available on dockerhub; if True proceed to firewall config.


