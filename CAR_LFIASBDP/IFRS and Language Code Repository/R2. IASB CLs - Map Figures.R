# This code combines the rnaturalearth and rnaturalearthdata packages with the comment letter data to generate world maps illustrating key descriptives about IFRS countries, their commenting behavior, and linguistic distance

setwd("DIRECTORY")

rm(list=ls()) # clear environment
library(ggplot2)
library(ggpattern)
library(sf)
library(rnaturalearth)
library(rnaturalearthdata)
library(dplyr)
library(magick)


cldata <- read.csv("SUBDIRECTORY/mapdata_from_stata_0124.csv") # comment letter data

world <- ne_countries(scale = "medium", returnclass = "sf") # get world dataset from rnaturalearth 

world2 <- left_join(world, cldata, by = c("brk_a3" = "cl_country_code"))

world2$ln_NCLs_country = log(world2$NCLs_country_all)
world2$ifrs_status_2007 <- ifelse(world2$adopted_by_2007==1, 2, ifelse((world2$partial_by_2007==1 & world2$adopted_by_2007==0), 1, NA))
world2$ifrs_status_2014 <- ifelse(world2$adopted_by_2014==1, 2, ifelse((world2$partial_by_2014==1 & world2$adopted_by_2014==0), 1, NA))
world2$ifrs_status_2021 <- ifelse(world2$adopted_by_2021==1, 2, ifelse((world2$partial_by_2021==1 & world2$adopted_by_2021==0), 1, NA))
world2$translation_ed2 <- ifelse(world2$translation_ed==1,1,0)
world2$translation_ed3 <- ifelse(is.na(world2$translation_ed2),0,world2$translation_ed)
world2$translation_ed4 <- ifelse(world2$lang1=="english",2,ifelse(is.na(world2$translation_ed2),0,world2$translation_ed))
world2$translation_ed5 <- ifelse(is.na(world2$translation_ed4),0,world2$translation_ed4)
world2$translation_ed5 <- ifelse(world2$sovereignt=="Japan",1,world2$translation_ed5)
world2$commenting_quint2 <- ifelse(is.na(world2$commenting_quint),0,world2$commenting_quint)


#### IFRS Adoption maps ####
## 2007
ifrs_adoption_map_2007 <- 
  ggplot(data = world2) + 
  geom_sf(aes(fill = as.factor(ifrs_status_2007), color = NULL), size = 0.01) + # fill = 'variable' color=NULL with the size option added make the borders thin and unobtrusive
  scale_fill_manual(name = "IFRS Status", values = c("#fcbddb", "#0a4440"), na.value = "white", labels = c("Partial Adoption \nor Convergence \nProject", "Fully Adopted", "Not Allowed or \nUnknown")) +
  ggtitle("Panel A: IFRS Adoption Status -- January 1, 2007") +
  theme(plot.title = element_text(family = "Times New Roman", size=14, face = "bold", hjust = 0.5), plot.subtitle = element_text(family = "Times New Roman", size=8, face="plain"), 
        legend.position = "none")

ifrs_adoption_map_2007

## 2014
ifrs_adoption_map_2014 <- 
  ggplot(data = world2) + 
  geom_sf(aes(fill = as.factor(ifrs_status_2014), color = NULL), size = 0.01) + # fill = 'variable' color=NULL with the size option added make the borders thin and unobtrusive
  scale_fill_manual(name = "IFRS Status", values = c("#fcbddb", "#0a4440"), na.value = "white", labels = c("Partial Adoption \nor Convergence \nProject", "Fully Adopted", "Not Allowed or \nUnknown")) +
  ggtitle("Panel B: IFRS Adoption Status -- January 1, 2014") +
  theme(plot.title = element_text(family = "Times New Roman", size=14, face = "bold", hjust = 0.5), plot.subtitle = element_text(family = "Times New Roman", size=8, face="plain"),
        legend.position = "none")

ifrs_adoption_map_2014

## 2021
ifrs_adoption_map_2021 <- 
  ggplot(data = world2) + 
  geom_sf(aes(fill = as.factor(ifrs_status_2021), color = NULL), size = 0.01) + # fill = 'variable' color=NULL with the size option added make the borders thin and unobtrusive
  scale_fill_manual(name = "IFRS Status", values = c("#fcbddb", "#0a4440"), na.value = "white", labels = c("Partial Adoption \nor Convergence \nProject", "Fully Adopted", "Not Allowed or \nUnknown")) +
  ggtitle("Panel C: IFRS Adoption Status -- January 1, 2021") +
  theme(plot.title = element_text(family = "Times New Roman", size=12, face = "bold", hjust = 0.5), plot.subtitle = element_text(family = "Times New Roman", size=8, face="plain"), 
        legend.position = "bottom")

ifrs_adoption_map_2021


# IFRS Exposure Draft Translations -- Figure 3
ifrs_adoption_map4 <- 
  ggplot(data = world2) + 
  geom_sf(aes(fill = as.factor(translation_ed5), color = NULL), size = 0.01) + # fill = 'variable' color=NULL with the size option added make the borders thin and unobtrusive
  scale_fill_manual(name = "Exposure \nDraft \nTranslation:", values = c("#ffffff","#fcbddb", "#0a4440"), labels = c("Unavailable", "Available", "N/A - English")) +
  
  theme(plot.title = element_text(family = "Times New Roman", size=14, face = "bold", hjust = 0.5), plot.subtitle = element_text(family = "Times New Roman", size=8, face="plain"), 
        legend.position = "bottom", legend.direction = "horizontal", legend.title = element_text(family = "Times New Roman", size=8, face="bold"), legend.text = element_text(family = "Times New Roman", size=6), axis.title.x = element_text(family = "Times New Roman", size=7))

ifrs_adoption_map4


# Linguistic distance -- Figure 2
ifrs_adoption_map3 <- 
  ggplot(data = world2) + 
  geom_sf(aes(fill = as.factor(lfi_quart), color = NULL), size = 0.1) + # fill = 'variable' color=NULL with the size option added make the borders thin and unobtrusive
  scale_fill_manual(name = "LDistance \nQuartile:", values = c("#f9d7f6", "#d77737", "#0a4440","#000000"), na.value = "white", labels = c("1st", "2nd", "3rd", "4th", "Not in Sample")) +
  
  theme(plot.title = element_text(family = "Times New Roman", size=14, face = "bold", hjust = 0.5), plot.subtitle = element_text(family = "Times New Roman", size=8, face="plain"), 
        legend.position = "bottom", legend.direction = "horizontal", legend.title = element_text(family = "Times New Roman", size=8, face="bold"), legend.text = element_text(family = "Times New Roman", size=6), axis.title.x = element_text(family = "Times New Roman", size=7))

ifrs_adoption_map3


# Commenting behavior -- Figure 1
ifrs_adoption_map2 <- 
  ggplot(data = world2) + 
  geom_sf(aes(fill = as.factor(commenting_quint2), color = NULL), size = 0.1) + # fill = 'variable' color=NULL with the size option added make the borders thin and unobtrusive
  scale_fill_manual(name = "Comment Letters \nReceived:", values = c("#ffffff", "#f9d7f6", "#d77737", "#0a4440","#000000"), labels = c("0", "1-10", "11-75", "76-150", ">150")) +

  theme(plot.title = element_text(family = "Times New Roman", size=14, face = "bold", hjust = 0.5), plot.subtitle = element_text(family = "Times New Roman", size=8, face="plain"), 
        legend.position = "bottom", legend.direction = "horizontal", legend.title = element_text(family = "Times New Roman", size=8, face="bold"), legend.text = element_text(family = "Times New Roman", size=6), axis.title.x = element_text(family = "Times New Roman", size=7))

ifrs_adoption_map2
