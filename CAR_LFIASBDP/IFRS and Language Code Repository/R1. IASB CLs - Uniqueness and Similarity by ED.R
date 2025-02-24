# The below code computes cosine similarity measures between each comment letter in our dataset and every other comment letter in our dataset by project or ED

setwd("DIRECTORY")

# clear environment
rm(list=ls()) 
# load necessary packages
library(dplyr)
library(stopwords)
library(stringi)
library(ngram) # need ngram for its concatenate function
library(stringr)
library(stringdist)
library(hashr)
library(readxl)

## define macro values
LIST <- c("iasb", "exposure draft", "exposure", "draft", "ed", "international accounting standards board", "fax", "email", "comment letter")
stopWords <- stopwords("en")

# Load LM dictionary
lm <- read.csv2('SUBDIRECTORY/LoughranMcDonald_MasterDictionary_2014.csv', sep=",", header=TRUE)
# get all LM words in order to filter out non-English or nonsense (in the case of OCR issues) words
lm_all <- tolower(as.character(subset(lm, Sequence.Number>0, select=c(Word))[,1]))

# Get list of CLs from directory
txts_dir <- "TXTDIRECTORY"
CLDir <- as.data.frame(list.files(path = txts_dir, pattern = ".txt", full.names=F))
colnames(CLDir)[1] = "CL_newname" # rename comment letter name column for future merge step

# Load CL Master list
CLList <- read_xlsx("SUBDIRECTORY/IASB CL Master 2021'10'07 - mapped filenames.xlsx", sheet = 'IASB CLs')
### Next step is to group the CLs by project or by commenter in order to get within-ED or within-commenter uniqueness
## First three lines are for within-project measures
CLList <- CLList %>% group_by(ED) %>% mutate(Project = cur_group_id())
CLList <- CLList %>% select(Project, CL_newname) # keep only two variables needed
CLList <-subset(CLList, select = -c(ED)) # hard code removal of ED

## Next three lines are for within-commenter measures
CLList <- CLList %>% group_by(clw_id) %>% mutate(Commenter = cur_group_id())
CLList <- CLList %>% select(Commenter, CL_newname) # keep only two variables needed
CLList <-subset(CLList, select = -c(clw_id)) # hard code removal of commenter letter writer id column

## Next three lines are for within-ED-type measures
CLList <- CLList %>% group_by(ED, type) %>% mutate(ED_type = cur_group_id())
CLList <- CLList %>% select(ED_type, CL_newname) # keep only two variables needed
CLList <-subset(CLList, select = -c(ED, type)) # hard code removal of ED and Type columns

CLDir <- inner_join(CLDir, CLList, by = c("CL_newname"), keep = F) # merge the group variable into the CL directory

scored_CLs <- data.frame(CL_newname=NA,avg_cosine_sim=NA,min_cosine_sim=NA,p25_cosine_sim=NA,med_cosine_sim=NA,p75_cosine_sim=NA
                         ,max_cosine_sim=NA,std_cosine_sim=NA) # create data frame to which future results will be appended

pb = txtProgressBar(min = 0, max = 886, char = "@", style = 3) # progress bar -- adjust max to be equal to the max of the new grouping variable created
ptm <- proc.time() # start keeping time

#### This step loops over ####
for (P in 1:886) {

  vec.a <- subset(as.data.frame(CLDir[CLDir$ED_type==P,]), select = -c(ED_type)) # select only one group
  #vec.b <- as.data.frame(CLDir[12:21,1])
  
  newvec.a <- data.frame(CL=NA) # create data frame to which future results will be appended
  
  for (Q in 1:nrow(vec.a)) {
    # For each vector of CLs, I first normaize the text
    CL <- concatenate(readLines(paste0("TXTDIRECTORY", vec.a[Q,1]), warn=F, skipNul=T)) # read in single CL's text
    CL <- enc2utf8(CL) # standardize encoding
    CL <- tolower(CL) # convert CL text to lower case
    CL <- stri_replace_all_fixed(CL, "\f", " ") # remove page breaks
    CL <- str_replace_all(CL, "[^a-z]", " ") # remove all non-alphabetic characters
    CL <- concatenate(CL, collapse = " ") # remove page breaks manually
    CL <- stri_replace_all_regex(CL, "\\s\\s+", " ") # make multi-spaces single spaces
    for (i in LIST){
      CL <- stri_replace_all_fixed(CL, i, "")
    }
    ### normalization
    CL <- unlist(strsplit(as.character(CL), " ")) # coerce to list of words
    CL <- paste(CL[CL %in% lm_all]) # restrict CL text to LM words
    CL <- CL[!CL %in% stopWords] # remove stop words
    CL <- CL[!CL %in% LIST] # remove iasb-specific words
    newvec.a[Q,1] <- concatenate(CL) # coerce back to single string
  }
  
  mat.a <- data.frame(V1=NA)
  
  # create an MxL matrix where each row represents CL L and each column will be the cosine similarity between CL L and CL M
  for (L in 1:nrow(newvec.a)) {
    tryCatch({
      for (M in 1:nrow(newvec.a)) {
        mat.a[L,M] <- seq_sim(hash(strsplit(newvec.a[L,1], "\\s+")), hash(strsplit(newvec.a[(M),1], "\\s+")), 
                              method = "cosine", q=1) # calculate cosine similarity at the word level
      }
    }, error=function(e){cat(paste0("ERROR ::", Q), conditionMessage(e), "\n")}) 
  }
  
  diag(mat.a) <- NA
  
  mat.A <- mat.a
  # Get several measures of similarity
  mat.A$avg_cosine_sim <- colSums(mat.a, na.rm = T)/nrow(mat.a) # average
  mat.A$min_cosine_sim <- (mat.a %>% rowwise() %>% mutate(row_min = min(c_across(where(is.numeric)), na.rm = T)))$row_min
  mat.A$p25_cosine_sim <- (mat.a %>% rowwise() %>% mutate(row_p25 = quantile(c_across(where(is.numeric)),c(.25), na.rm=T)))$row_p25
  mat.A$med_cosine_sim <- (mat.a %>% rowwise() %>% mutate(row_median = median(c_across(where(is.numeric)), na.rm = T)))$row_median
  mat.A$p75_cosine_sim <- (mat.a %>% rowwise() %>% mutate(row_p75 = quantile(c_across(where(is.numeric)),c(.75), na.rm=T)))$row_p75
  mat.A$max_cosine_sim <- (mat.a %>% rowwise() %>% mutate(row_max = max(c_across(where(is.numeric)), na.rm = T)))$row_max
  mat.A$std_cosine_sim <- (mat.a %>% rowwise() %>% mutate(row_std = sd(c_across(where(is.numeric)), na.rm = T)))$row_std
  
  mat.B <- select(filter(mat.A), c(avg_cosine_sim,min_cosine_sim,p25_cosine_sim,med_cosine_sim,p75_cosine_sim,max_cosine_sim,std_cosine_sim)) ## remove extra vars
  
  mat.C <- bind_cols(vec.a, mat.B) # bind columns 
  
  scored_CLs <- bind_rows(scored_CLs, mat.C) # add matrix with each group's variables
  
  setTxtProgressBar(pb, P)
}
proc.time() - ptm #end time

forexport <- scored_CLs[2:12671,]

write.csv(forexport, file = "SUBDIRECTORY/IASB CL Cosine_Sim BY ED-Type 2023-02-09.csv", row.names = F)