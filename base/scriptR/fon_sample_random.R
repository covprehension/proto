poolRandom_fct <- function(tab,n1,n2){
  ##n1 le nombre d'observation tirer pour produire un échantillon
  ##n2 le nombre d'échantillon qu'on veux en sortie
  tps_sample<-NULL
  mysampledataset<-NULL
  for(i in 1:n2){
    tps_sample<-sample(tab,n1,replace = FALSE)
    group<-rep(i,n1)
    tps.df<-cbind(tps_sample,group)
    mysampledataset <- as.data.frame(rbind(mysampledataset,tps.df))
  }
  
  
  return(mysampledataset)
}