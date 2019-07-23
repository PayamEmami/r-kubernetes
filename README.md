# r-kubernetes
A simple script to offload R sessions to Kubernetes

# How it works
It's assumed that the parent r/rstudio is running in a pod in the same cluster as Kubernetes. 

You will also need to prepare your docker image which must contain all the required packages including batchtools, future.batchtools and listenv!

You can for example download rocker https://github.com/rocker-org/rocker-versioned and add the following line at the end of the Dockerfile in the r subdicrectory and build it.

RUN R -e 'install.packages(c("batchtools","future.batchtools","listenv"))'

To run test the script you can use future.batchtools:


library(future.batchtools)
cluster.functions <- makeClusterFunctionsk8s(image = "payamemami/r-ver:latest",MEMORYREQ ="5G",MEMORYLIMIT = "16G")

plan(batchtools_custom, cluster.functions = cluster.functions)
library(listenv)
results <- listenv()

for (ss in 1:100) {
  results[[ss]] %<-% {
    princomp(matrix(rnorm(32000000), 1000000, 32))$sdev[1]
  }
}

as.list(results)

The code above runs 100 PCAs on a large dataset. 

# How to provision R

The easiest way is to either use Rancher or KubeNow! I used Kubenow as it provisions a GlusterFS node which makes things a lot easier!

Given that you use KubeNow to deploy a cluster, you can ssh into the master e.g. kn ssh and run:

    helm repo add rstudio-helm
    https://payamemami.github.io/rstudio-helm-chart

and then 

    helm upgrade
    --install
    --set rstudio_image_registry="docker.io",rstudio_image_tag=":v1",passwd_rstudio="https://raw.githubusercontent.com/PayamEmami/tmp/master/tt.txt",use_ingress="yes",hostname="rstudio",domain="MASTERIP.nip.io",external_ingress_controller="yes",pvc_exists="yes",rstudio_pvc="{{ jupyter_pvc }}",rstudio_resource_req_cpu="{{ jupyter_resource_req_cpu }}",rstudio_resource_req_memory="{{ jupyter_resource_req_memory }}"
    --version "0.1.0"
    "jupyter-rstudio-0.1.0"
    rstudio-helm/rstudio
  no_log: "{{ nologging }}"


MASTER ip should be the floating ip address assigned to your master passwd_rstudio is a file that contains user and passwords for the users of rstudio (this should be available through a link). The file is comma separated and should be username,password,userid,groupid,true or false (whether the user has admin premission),022


