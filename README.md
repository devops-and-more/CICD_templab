## 🚀 Ephemeral DevOps Labs with GitLab CI/CD + Terraform + Kubernetes

This repository showcases a complete implementation of **ephemeral lab environments** — temporary DevOps playgrounds that deploy automatically in minutes and self-destruct after a defined time.  

The idea was inspired by platforms like *KillerCoda*, *Play with K8s*, and *AWS Skill Builder*, which allow learners to spin up full lab environments effortlessly. I wanted to recreate that same experience using **CI/CD automation**.  

With this setup, a single click on the frontend triggers a **GitLab CI/CD pipeline** that:  
1️⃣ **Deploys** a fully functional environment (via Terraform)  
2️⃣ **Destroys** it automatically after a delay  

### 🧩 What’s Inside
- **Infrastructure as Code:** Terraform provisions everything on GCP or AWS  
- **Kubernetes Cluster:** GKE or EKS  
- **GitLab Stack:** GitLab, Prometheus, Grafana, etc. deployed via Helm  
- **Ingress + Monitoring:** Automated TLS and metrics forwarding  
- **Remote State Management:** S3 bucket + DynamoDB  
- **Auto-cleanup:** Timer-based destroy job for cost-efficient ephemeral labs  

### 🛠️ Tech Stack
`GitLab CI/CD` • `Terraform` • `Kubernetes` • `Helm` • `Prometheus` • `Grafana` • `AWS` • `GCP` • `S3` • `DynamoDB` • `Ingress` • `Slack Integration`

### 📹 Coming Soon
I  shared the full implementation step-by-step in my videos:

# 🧰 Requirements

Before you begin, make sure you have:

- A **GCP account**
- An **AWS account**
- **AWS CLI** installed and configured
- **gcloud CLI** installed and configured

For Terraform to deploy resources properly:

- Create a **GCP/AWS credentials keys** with the required permissions (and restrict them as much as possible).

Authenticate your CLI tools:
```bash
aws configure
gcloud auth application-default login
```

---

# 🚀 1. Deploy the GKE Cluster

This cluster acts as the **admin cluster** — it manages the deployment of temporary labs that are provisioned on AWS.  
The Terraform deployment also creates a **static IP**, which will be used later.

```bash
terraform -chdir=INFRA init
terraform -chdir=INFRA apply
```

---

# 🧱 2. Deploy the GitLab Stack and Remote Backend

The GitLab stack includes:
- GitLab
- GitLab Runners
- Prometheus
- Certificate manager, issuer, ingress/ingress controller, load balancer, and related services

Grafana is deployed **independently**, connected to Prometheus, and exposed via **Ingress**.

The Ingress uses a free DNS domain format:
```
<STATIC_IP>.nip.io
```

Deploy it with:

```bash
terraform -chdir=TempLAB init
terraform -chdir=TempLAB apply
```

> 💡 The load balancer IP comes from the external IP of the GKE service annotated by Terraform.

---

### ✅ Retrieve the URLs

```bash
kubectl get ing -A
```

Example output:

```
NAMESPACE   NAME                        CLASS          HOSTS
gitlab      gitlab-webservice-default   gitlab-nginx   gitlab.35.192.5.192.nip.io
gitlab      gitlab-registry             gitlab-nginx   registry.35.192.5.192.nip.io
gitlab      gitlab-minio                gitlab-nginx   minio.35.192.5.192.nip.io
gitlab      gitlab-kas                  gitlab-nginx   kas.35.192.5.192.nip.io
gitlab      grafana                     gitlab-nginx   grafana.35.192.5.192.nip.io
```

---

# 🔐 3. Access GitLab

Open your browser and navigate to:

```
https://gitlab.<STATIC_IP>.nip.io
```

Default credentials:

- **Username:** `root`
- **Password:** `D£v0p$&+`  
  (Defined in `main.tf` → `kubernetes_secret.gitlab_initial_root`)

> ⚠️ For security: **Disable user sign-ups** after the first login.

---

# 👤 4. Create a New Admin User (Optional but Recommended)

To avoid using the `root` account regularly:

1. Create a new user
2. Assign **Admin** permissions
3. Sign in using that account
4. Create a new project
5. Disable the protection on the main branch

---

# 🧑‍💻 5. Set Up SSH Access for GitLab

Generate SSH keys locally:

```bash
ssh-keygen
```

Then, copy your **public key** to your GitLab user profile under  
**Settings → SSH Keys**, with the title `gitlab`.

Retrieve your GitLab URL:

```bash
gitlab_url=$(terraform -chdir=TempLAB output -raw gitlab_url)
```

Create an SSH configuration file to make sure your system uses the correct key automatically:

```bash
sudo bash -c "cat <<EOF | tee /home/kub/.ssh/config > /dev/null
Host ${gitlab_url}
    HostName ${gitlab_url}
    User git
    IdentityFile /home/kub/.ssh/gitlab
    IdentitiesOnly yes
EOF"
```

This ensures your local machine knows which key to use when interacting with your GitLab instance.

---

# 📦 6. Push Your Local Repository

Clone or prepare your local project (for example, a Terraform EKS tutorial):

```bash
cd CICD/learn-terraform-provision-eks-cluster/
```

This project is based on the official [HashiCorp tutorial](https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks),  
with modifications for **remote backend** and **GitLab CI/CD integration**.

Authenticate your GitLab connection:

```bash
ssh -T git@$gitlab_url
```

You should see a message similar to:

```
The authenticity of host 'gitlab.35.192.5.192.nip.io (35.192.5.192)' can't be established.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Welcome to GitLab, @labcreator!
```

Then push your local repo:

```bash
git remote add origin git@gitlab.<STATIC_IP>.nip.io:<user/repo_name>.git
git push -u origin main
```
> 🔧 Replace `<STATIC_IP>` with your static ip.
> 🔧 Replace `<user/repo_name>` with your actual GitLab project path.

---

# 💬 7. (Optional) Integrate Slack Notifications

1. **Create a Slack App** with incoming webhooks:  
   [https://api.slack.com/apps](https://api.slack.com/apps)
2. Enable **Incoming Webhooks** and create one for your channel
3. In your GitLab project, add the webhook and AWS credentials as CI/CD variables:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_DEFAULT_REGION`
   - `SLACK_WEBHOOK_URL`

---

# 🧩 8. Trigger the Pipeline

To simulate a user requesting a temporary lab, simply **trigger the pipeline manually** in GitLab.  
This will:
- Deploy a lab (Terraform)
- Automatically destroy it after a predefined delay (10min)

# 🧹 9. Clean up:
Destroy the infrastructure:
```bash
terraform -chdir=TempLAB destroy -auto-approve
terraform -chdir=INFRA destroy -auto-approve
```