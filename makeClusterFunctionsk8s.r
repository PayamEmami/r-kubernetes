makeClusterFunctionsk8s = function(image, PVC="",MOUNTPATH="/home",MOUNTSUB="",
                                   CPULIMIT="5",MEMORYLIMIT="4G",
                                   CPUREQ="1",MEMORYREQ="1G",templatePath="jobTemplate.json",
                                   tokenPath="/var/run/secrets/kubernetes.io/serviceaccount/token",
                                   certificatePath="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt") { 
  
  require("httr")
  require("jsonlite")
  
  user = Sys.info()["user"]
  
  jobTemplate<-readLines(templatePath)
  
  
  
  submitJob = function(reg, jc) {
    assertRegistry(reg, writeable = TRUE)
    JobName<-paste(user,jc$job.hash,sep = "-")
    print(JobName)
    req_token<-readLines(tokenPath)
    url=paste("https://kubernetes.default.svc.cluster.local/apis/batch/v1/namespaces/default/jobs",sep = "")
    dataTMP <- GET(url, config = add_headers(Authorization=paste0("Bearer ", req_token)),
                   config(cainfo=certificatePath))
    dataTMP<-content(dataTMP)
    availableJobs<-c()
    if("items"%in%names(dataTMP))
    {
      availableJobs<-sapply(dataTMP$items,function(x){x$metadata$name}) 
    }
    
    JobCounter=1
    while(JobName%in%availableJobs)
    {
      JobName<-paste(user,jc$job.hash,JobCounter,sep = "-")
      
    }
    
    replacementData<-data.frame(from=c("%JOBNAME%","%PVC%","%CONTAINERIMAGE%","%COMMAND%",
                                       "%CPULIMIT%","%MEMORYLIMIT%","%CPUREQ%","%MEMORYREQ%","%MOUNTPATH%","%MOUNTSUB%"),
                                to=c(JobName,PVC,image,
                                     paste(shQuote("Rscript",type = "cmd"),shQuote("-e",type = "cmd"),
                                           shQuote(sprintf("batchtools::doJobCollection('%s', '%s')", jc$uri, jc$log.file),type = "cmd"),
                                           sep = ",\n"),
                                     CPULIMIT,MEMORYLIMIT,CPUREQ,MEMORYREQ,MOUNTPATH,MOUNTSUB))
    
    
    for(i in 1:nrow(replacementData))
    {
      jobTemplate<-gsub(replacementData[i,"from"],replacementData[i,"to"],x = jobTemplate,fixed = T)
    }
    
    
    url="https://kubernetes.default.svc.cluster.local/apis/batch/v1/namespaces/default/jobs"
    tmpData <- POST(url, config = add_headers(Authorization=paste0("Bearer ", req_token)),body = jobTemplate,encode = "json",
                    query=list("pretty"=T),
                    config(cainfo=certificatePath))
    tmpData<-content(tmpData)
    
    
    
    if (length(tmpData$status)>0 && tmpData$status=="Failure") {
      no.res.msg = tmpData$message
      return(cfHandleUnknownSubmitError(jobTemplate, 1, tmpData$message))
    }
    return(makeSubmitJobResult(status = 0L, batch.id = JobName))
  }
  
  
  listJobs = function(reg, filter = character(0L)) {
    assertRegistry(reg, writeable = FALSE)
    
    req_token<-readLines(tokenPath)
    url=paste("https://kubernetes.default.svc.cluster.local/apis/batch/v1/namespaces/default/jobs",sep = "")
    dataTMP <- GET(url, config = add_headers(Authorization=paste0("Bearer ", req_token)),
                   config(cainfo=certificatePath))
    dataTMP<-content(dataTMP)
    availableJobs<-c()
    if("items"%in%names(dataTMP))
    {
      availableJobs<-sapply(dataTMP$items,function(x){x$metadata$name}) 
      availableJobs<-availableJobs[startsWith(x = availableJobs,prefix = as.character(user))]
    }
    return(availableJobs)
  }
  
  
  killJob = function(reg, batch.id) {
    assertRegistry(reg, writeable = TRUE)
    
    req_token<-readLines(tokenPath)
    url=paste("https://kubernetes.default.svc.cluster.local/apis/batch/v1/namespaces/default/jobs/",batch.id,sep = "")
    dataTMP <- DELETE(url, config = add_headers(Authorization=paste0("Bearer ", req_token)),
                      config(cainfo=certificatePath))
    
    
  }
  
  listJobsRunning = function(reg) {
    assertRegistry(reg, writeable = FALSE)
    req_token<-readLines(tokenPath)
    url=paste("https://kubernetes.default.svc.cluster.local/apis/batch/v1/namespaces/default/jobs",sep = "")
    dataTMP <- GET(url, config = add_headers(Authorization=paste0("Bearer ", req_token)),
                   config(cainfo=certificatePath))
    dataTMP<-content(dataTMP)
    availableJobs<-c()
    if("items"%in%names(dataTMP))
    {
      availableJobs<-sapply(dataTMP$items,function(x){if("active"%in%names(x$metadata$status)){as.character(x$metadata$name)}else{F}}) 
      availableJobs<-availableJobs[availableJobs!=F]
      if(length(availableJobs)==0)availableJobs<-c()
    }
    return(availableJobs)
  }
  
  makeClusterFunctions(name = "k8s", submitJob = submitJob, killJob = killJob, listJobsRunning = listJobsRunning,
                       store.job.collection = TRUE)
}
