###############################################################
#
# Project: Medication Alignment Algorithm (Medal)
# Author: Arturo Lopez Pineda (arturolp[at]stanford[dot]edu)
# Date: Feb 26, 2019
#
###############################################################

#library(tsne)
#library(Rtsne)

mycolors = c("1"="mediumorchid3", "2"="darkturquoise", "3"="olivedrab3", "4"="orangered3")

rightCensoring <- function(data, year){
  
  days = year*365
  dataC = data
  
  #Remove all rows with start date beyond right censoring (days)
  indexes = which(dataC$start>days)
  if(length(indexes)>0){
    dataC = dataC[-indexes, ]
  }
  
  #Right censoring of days
  indexes = which(dataC$end>days)
  dataC[indexes, "end"] = days
  
  return(dataC)
}

rightCensoringMonths <- function(data, year){
  
  months = year*12
  dataC = data
  
  #Remove all rows with start date beyond right censoring (months)
  indexes = which(dataC$start>months)
  if(length(indexes)>0){
    dataC = dataC[-indexes, ]
  }
  
  #Right censoring of months
  indexes = which(dataC$end>months)
  if(length(indexes)>0){
  dataC[indexes, "end"] = months
  }
  return(dataC)
}

twoTailCensoring <- function(data, startYear, endYear){
  
  startDays = startYear*365
  endDays = endYear*365
  dataC = data
  
  #Remove all rows with start date beyond right censoring (days)
  indexes = which(dataC$start>endDays)
  if(length(indexes)>0){
    dataC = dataC[-indexes, ]
  }
  
  #Remove all rows with end date befor left censoring (days)
  indexes = which(dataC$end<startDays)
  if(length(indexes)>0){
    dataC = dataC[-indexes, ]
  }
  
  #Right censoring of days
  indexes = which(dataC$end>endDays)
  if(length(indexes)>0){
    dataC[indexes, "end"] = endDays
  }
  
  #Left censoring of days
  indexes = which(dataC$start<startDays)
  if(length(indexes)>0){
    dataC[indexes, "start"] = startDays
  }
  
  return(dataC)
}

rightCensoringExclusive <- function(data, endYear){
  
  dataC = twoTailCensoring(data, 0, 1)
  
  for(i in 1:(endYear-1)){
    dataC = rbind(dataC, twoTailCensoring(data, i, (i+1)))
  }
  
  return(dataC)
}


getDendrogram <- function(d, k, color.vector=mycolors){
  

  # Create Dendrogram
  dend <- d %>% dist(method="minkowski") %>% #as.dist %>%
    hclust(method="ward.D") %>% as.dendrogram
  
  #Get color ordering
  assignment = cutree(dend, k)
  order = unique(assignment[order.dendrogram(dend)])
  ordered.colors = color.vector[order]
  
  dend <- dend %>% 
    set("branches_k_color", value = ordered.colors, k = k) %>% 
    set("branches_lwd", 0.7) %>%
    set("labels_cex", 0.6) %>% 
    set("labels_colors", value = "grey30", k = k) %>%
    set("leaves_pch", 19) %>% 
    set("leaves_cex", 0.5)
  #ggd1 <- as.ggdend(dend)
  #ggplot(ggd1, horiz = FALSE)
  
  # dend <- d %>% as.dist %>%
  #   hclust(method="ward.D") %>% as.dendrogram %>%
  #   set("branches_k_color", value = color.vector, k = k) %>% 
  #   set("branches_lwd", 0.7) %>%
  #   set("labels_cex", 0.6) %>% 
  #   set("labels_colors", value = "grey30", k = k) %>%
  #   set("leaves_pch", 19) %>% 
  #   set("leaves_cex", 0.5)
  # ggd1 <- as.ggdend(dend)
  #gClust <- ggplot(ggd1, horiz = FALSE)
  
  #pca1 = prcomp(dend, scale. = FALSE)
  #hclust.assignment = cutree(dend, k)
  #scores = as.data.frame(pca1$x)
  
  #scores = cbind(scores, cluster=as.character(hclust.assignment))
  
  return(dend)
}

getKMeansClusteringPCA <- function(d, k){
  
  #K-means clustering
  k2 <- kmeans(d, centers = k, nstart = 25)
  
  pca1 = prcomp(d, scale. = FALSE)
  scores = as.data.frame(pca1$x)
  
  scores = cbind(scores, cluster=as.character(k2$cluster))
  
  return(scores)
}

getKMeansClusteringTSNE <- function(d, k, tsne){
  
  #K-means clustering
  k2 <- kmeans(d, centers = k, nstart = 25)
  
  tsne1 = cbind(tsne, cluster=as.character(k2$cluster))
  rownames(tsne1) <- rownames(d)
  
  return(tsne1)
}

getHierarchicalClusteringTSNE <- function(d, k, tsne){
  # Create Dendrogram
  dend <- d %>% as.dist %>%
    hclust(method="ward.D") %>% as.dendrogram 
  hclust.assignment = cutree(dend, k)
  
  tsne1 = cbind(tsne, cluster=as.character(hclust.assignment))
  rownames(tsne1) <- rownames(d)
  
  return(tsne1)
}



pyMedal <- function(medal="../pymedal/pymedal.py", file){
  
  system(paste("python3", medal, file), wait=TRUE)
  
  distMatrix = read.table("distance_mat.txt")
  patientIDs = read.table("patientID.txt", sep=",")
  
  pID = as.vector(unlist(patientIDs))
  colnames(distMatrix) = pID
  rownames(distMatrix) = pID
  
  return(distMatrix)
}

cleanEvents <- function(data, groups){
  
  # Clean data =======
  
  #For single-day medication without end date
  indexes = intersect(which(is.na(data$end)), which(!is.na(data$start)))
  for(ind in indexes){
    data[ind, "end"] = data[ind, "start"]+1
  }
  
  #For single-day medication without start date
  indexes = intersect(which(!is.na(data$end)), which(is.na(data$start)))
  for(ind in indexes){
    data[ind, "start"] = data[ind, "end"]-1
  }
  
  #For negative start/end day
  indexes = which(as.numeric(as.character(data$start)) < 1)
  if(length(indexes) > 0 ){
    data[indexes, "start"] = 1
  }
  indexes = which(as.numeric(as.character(data$end)) < 1)
  if(length(indexes) > 0 ){
    data[indexes, "end"] = 1
  }
  
  #Remove NA/NA
  indexes = intersect(which(!is.na(data$start)), which(!is.na(data$end)))
  data = data[indexes,]
  
  
  # Group by class of medication
  data$medication <- tolower(data$medication)
  
  # for(medclass in names(groups)){
  #   print(toupper(medclass))
  #   for(med in groups[[medclass]]){
  #     print(med)
  #   }
  #   print("-----")
  # }
  
  #Group together all medications of the same class
  for(medclass in names(groups)){
    indexes = which(data$medication %in% groups[[medclass]])
    data[indexes, "medication"] = medclass
  }
  
  return(data)
}


getClusterProfiles <- function(profiles, outcomes, years){
  #Get profiles for patients in each cluster
  pat1 <- getClusterScores(profiles, 1, outcomes, years) %>% mutate(cluster="1")
  pat2 <- getClusterScores(profiles, 2, outcomes, years) %>% mutate(cluster="2")
  pat3 <- getClusterScores(profiles, 3, outcomes, years) %>% mutate(cluster="3")
  pat4 <- getClusterScores(profiles, 4, outcomes, years) %>% mutate(cluster="4")
  pat5 <- getClusterScores(profiles, 5, outcomes, years) %>% mutate(cluster="5")
  pat6 <- getClusterScores(profiles, 6, outcomes, years) %>% mutate(cluster="6")
  
  pat <- pat1 %>%
    bind_rows(pat2) %>%
    bind_rows(pat3) %>%
    bind_rows(pat4) %>%
    bind_rows(pat5) %>%
    bind_rows(pat6)
  
  pat <- pat %>%
    mutate(one = case_when(cluster == 1 ~ 1, TRUE ~ 0)) %>%
    mutate(two = case_when(cluster == 2 ~ 1, TRUE ~ 0)) %>%
    mutate(three = case_when(cluster == 3 ~ 1, TRUE ~ 0)) %>%
    mutate(four = case_when(cluster == 4 ~ 1, TRUE ~ 0)) %>%
    mutate(five = case_when(cluster == 5 ~ 1, TRUE ~ 0)) %>%
    mutate(six = case_when(cluster == 6 ~ 1, TRUE ~ 0))
  
  #Convert days to years
  pat <- pat %>%
    mutate(years=daysSinceOnset/365)
}
