# r-kubernetes
A simple script to offload R sessions to Kubernetes

# How it works
It's assumed that the parent r/rstudio is running in a pod in the same cluster as Kubernetes. 

You will also need to prepare your docker image which must contain all the required packages including batchtools, future.batchtools and listenv!

You can for example download rocker https://github.com/rocker-org/rocker-versioned and add the following line at the end of the Dockerfile in the r subdicrectory and build it.
```
RUN R -e 'install.packages(c("batchtools","future.batchtools","listenv"))'
```
To run test the script you can use future.batchtools:

```
library(batchtools)
library(future.batchtools)
cluster.functions <- makeClusterFunctionsk8s(image = "payamemami/r-ver:latest",MEMORYREQ ="5G",MEMORYLIMIT = "16G",PVC="r-pvc")

plan(batchtools_custom, cluster.functions = cluster.functions)
library(listenv)
results <- listenv()

for (ss in 1:100) {
  results[[ss]] %<-% {
    princomp(matrix(rnorm(32000000), 1000000, 32))$sdev[1]
  }
}

as.list(results)
```

The code above runs 100 PCAs on a large dataset. 

If you want to run a for loop you can use doFuture package:
```
library(future.batchtools)
library(batchtools)
cluster.functions <- makeClusterFunctionsk8s(image = "payamemami/r-ver:v1",MEMORYREQ ="3G",MEMORYLIMIT = "16G",PVC = "pvc-j5bj4")
library(doFuture)
registerDoFuture()
plan(batchtools_custom, cluster.functions = cluster.functions)
mu <- 1.0
sigma <- 2.0
x <- foreach(i = 1:3, .export = c("mu", "sigma")) %dopar% {
  rnorm(i, mean = mu, sd = sigma)
}
```
# How to provision R

The easiest way is to either use Rancher or KubeNow! I used Kubenow as it provisions a GlusterFS node which makes things a lot easier!

Given that you use KubeNow to deploy a cluster, you can ssh into the master e.g. kn ssh and run:

    helm repo add rstudio-helm
    https://payamemami.github.io/rstudio-helm-chart

and then 

    helm upgrade
    --install
    --set rstudio_image_registry="docker.io",rstudio_image_tag=":v1",passwd_rstudio="https://raw.githubusercontent.com/PayamEmami/r-kubernetes/master/USERPW.txt",use_ingress="yes",hostname="rstudio",domain="MASTERIP.nip.io",external_ingress_controller="yes",pvc_exists="yes",rstudio_pvc="yourPVC",rstudio_resource_req_cpu="2",rstudio_resource_req_memory="5G"
    --version "0.1.0"
    "jupyter-rstudio-0.1.0"
    rstudio-helm/rstudio


MASTER ip should be the floating ip address assigned to your master passwd_rstudio is a file that contains user and passwords for the users of rstudio (this should be available through a link). The file is comma separated and should be username,password,userid,groupid,true or false (whether the user has admin premission),022

If using Rancher, you need to run this as they have restricted the API usage outside the Rancher OS

```
kubectl create rolebinding serviceaccounts-admin --clusterrole=admin --serviceaccount=default:default --namespace=default
```

and
```
kubectl create clusterrolebinding default-admin --clusterrole cluster-admin --serviceaccount=default:default
```

If you want replication of rstudio server, you might need to set up nginx and use for example:

Deploy nginx:

```
helm install stable/nginx-ingress --name my-nginx

```


```
helm install stable/nginx-ingress --name my-nginx --set rbac.create=true

```
for the Ingress

```
---
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: rstudio
  labels:
    app: payam
spec:
  replicas: 3
  selector:
    matchLabels:
      app: payam
      task: rstudio
  template:
    metadata:
      labels:
        app: payam
        task: rstudio
    spec:
      containers:
      - name: rstudio
        image: payamemami/rstudio:holmdahl
        #args: ["-e","rstudioPWD=https://raw.githubusercontent.com/PayamEmami/tmp/master/tt.txt"]
        env:
        - name: rstudioPWD
          value: "https://raw.githubusercontent.com/PayamEmami/tmp/master/tt.txt"
        ports:
          - containerPort: 8787
        resources:
          requests:
            memory: 2G
            cpu: 2
        volumeMounts:
          - mountPath: "/home"
            name: shared-volume
      volumes:
        - name: shared-volume
          persistentVolumeClaim:
            claimName: [YOURPVC]
      restartPolicy: Always
            
---
apiVersion: v1
kind: Service
metadata:
  name: rstudio
spec:
  ports:
  - name: http
    targetPort: 8787
    port: 8787
  selector:
    app: payam
    task: rstudio
    
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: rstudio-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/add-base-url: "true"
    nginx.ingress.kubernetes.io/proxy-redirect-from: "$scheme://$host/"
    nginx.ingress.kubernetes.io/proxy-redirect-to: "$scheme://$host/"
    nginx.ingress.kubernetes.io/proxy-read-timeout: 20d
    nginx.ingress.kubernetes.io/affinity: "cookie"
    nginx.ingress.kubernetes.io/session-cookie-name: "route"
    nginx.ingress.kubernetes.io/session-cookie-hash: "sha1"
spec:
  rules:
  - host: rstudio.[YOURIP].nip.io
    http:
      paths:
      - path: /
        backend:
          serviceName: rstudio
          servicePort: http
```
