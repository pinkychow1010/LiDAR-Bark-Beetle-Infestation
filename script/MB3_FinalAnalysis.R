# Load libraries
library(devtools)
library(ggplot2) # visualization
library(tidyverse)
library(dbplyr)
library(lidR) # process LiDAR point clouds
library(sf) # spatial analysis
library(raster)
library(rgdal)
library(leafR) # calculate LAI from LiDAR point cloud
library(gstat)
library(rgeos)
library(dplyr)
library(patchwork) # plotting layout
library(hrbrthemes)

# Set up working environment
getwd()
setwd("C:/Users/Admin/Desktop/MB3/BGL")

# Loading the Data
# load the height normalized point clouds into leafR package
voxels <- lad.voxels("norm_las_aoi_ground.laz", grain.size = 1, k = 1)
# calculate the lad profile from lad.voxels
profile <- lad.profile(voxels, relative = FALSE)
# get LAI raster map
ras <- lai.raster(voxels, min = 1, relative.value = NULL)

# read data of unhealthy trees
sub10 <- st_read("10quantile_tree.gpkg")
sub10_spdf <- as_Spatial(sub10) # convert to spatial point data frame

# read data of healthy trees
sub90 <- st_read("90quantile_tree.gpkg")
sub90_spdf <- as_Spatial(sub90) # convert to spatial point data frame

#export raster file
#raster::writeRaster(ras, filename="LAI.tif",options=c('TFW=YES'))

# LAI raster
lai <- raster("LAI.tif")

# To define healthy and unhealthy tree condition, we use a NDVI threshold
# As NDVI are relative high in the whole study plot
# We use the relative threshold (Lower 10% quantile instead of absolute value)
ndvi_val <- as(raster("planet_clip_resample.tif"),"matrix")
thres <- quantile(ndvi_val, probs=0.1)

# Mask LAI value to healthy and unhealthy population
unhealthy_tree <- mask(lai, sub10_spdf)
healthy_tree <- mask(lai, sub90_spdf)

# Save data as matrix and calculate the mean for both groups
unhealthy_mat <- as(unhealthy_tree,"matrix")
mean(unhealthy_mat, na.rm=TRUE)

healthy_mat <- as(healthy_tree,"matrix")
mean(healthy_mat, na.rm=TRUE)

# Mean for the whole population
mat <- as(raster("LAI.tif"), "matrix")
mean(mat)

# LAI distribution for the study plot
hist(mat,col = 'purple',breaks = 30,
     xlab='LAI', main='Distribution of LAI in the study plot')

# For high NDVI area
hist(healthy_mat,col = 'purple',breaks = 30,
     xlab='LAI', main='Healthy Tree: LAI Distribution')

# For low NDVI area
hist(unhealthy_mat,col = 'blue',breaks = 30,
     xlab='LAI', main='Unhealthy Tree: LAI Distribution')

# LAI and NDVI analysis
file.exists("ttopsBGL_norm.shp") # check if shapefile exists
tree_pt <- st_read("ttopsBGL_norm.shp") # read detected tree tops
tree_pt_spdf <- as_Spatial(tree_pt) # to spatial data frame

# Extract LAI from only Tree Tops rather than the whole area
lai_pt<- raster::extract(lai,tree_pt_spdf)
hist(lai_pt, xlab="LAI",col="darkblue",breaks=30,main="LAI")

# Get LAI and NDVI for the spatial points
tree_pt_spdf$lai <- raster::extract(lai,tree_pt_spdf)
tree_pt_spdf$ndvi <- raster::extract(ndvi,tree_pt_spdf)
tree_pt_spdf$height <- tree_pt_spdf$Z

# Plot Correlation between LAI and Tree Heights
d0 <- data.frame(lai = tree_pt_spdf$lai,
                 h = tree_pt_spdf$height,
                 r = (tree_pt_spdf$lai/tree_pt_spdf$height))

# Look at the ratio of LAI to Tree Height
ratio = d0$lai/d0$h
hist(ratio, col="blue",breaks=30)

# Mutate a new column indicating the LAI-Height ratio
d0 <- d0 %>% mutate(proxy = case_when(r > 0.1 ~ "High",r <= 0.1 ~ "Low"))

# Plotting
ggplot(d0, aes(x = h, y = lai, color = proxy)) +
  geom_point(size=1.2,alpha=0.75) + 
  scale_x_continuous(limits=c(min(d0$h),max(d0$h))) + 
  scale_y_continuous(limits=c(min(d0$lai),max(d0$lai))) + 
  geom_rug(col=rgb(.5,0,0,alpha=.2)) + 
  labs(x="Height", y="LAI",
       title="Pearson Correlation",
       subtitle="From UAV Point Cloud and Planet Data",
       caption="MB3 Field Measurement") + 
  stat_smooth(method = "lm",color="blue",size = 1) + 
  theme_ft_rc()

# Extract Healthy and Unhealthy Tree Tops
unhealthy_ind <- tree_pt_spdf[(tree_pt_spdf$ndvi) < thres,]
healthy_ind <- tree_pt_spdf[(tree_pt_spdf$ndvi) > thres,]

# Plot a Boxplot for Vegetation Indices according to tree health
coeff = 1/7 #rescale second axis

# Create a new dataframe
d <- data.frame(type=c(rep("LAI",170),rep("NDVI",170)),
                health=c(rep("unhealthy",40),rep("healthy",130),
                         rep("unhealthy",40),rep("healthy",130)),
                val=c(unhealthy_ind$lai,healthy_ind$lai,
                      (unhealthy_ind$ndvi)*7,(healthy_ind$ndvi)*7))

# Plot figure
p <- ggplot(d, aes(x=type, y=val, fill=health)) 
# Add style
p2 <- p + geom_boxplot(color="red", alpha=0.6, width=0.5) +  #aes(color="red", fill="orange", alpha=0.2, width=0.5)
  scale_y_continuous(
    # Features of the first axis
    name = "LAI",
    # Add a second axis and specify its features
    sec.axis = sec_axis(~.*coeff, name="NDVI")
  ) + 
  labs(x="vegetation index", y="",
           title="Indices of Trees (n=170)",
           subtitle="From UAV Point Cloud and Planet Data",
           caption="MB3 Field Measurement") + 
  theme_ft_rc(grid="Y")
p2

# Calculate Correlation between NDVI and LAI
ndvi <- raster("ndvi_planet_resample.tif") # read NDVI
ndvi_clip <- crop(ndvi,lai) # crop raster
ndvi_clip

#extract ndvi from point
ndvi_pt<- raster::extract(ndvi,tree_pt_spdf) # Get NDVI
hist(ndvi_pt, xlab= "NDVI",col="darkgreen",breaks=30,main="NDVI") # NDVI distribution

# set same extent for raster stacking
extent(ndvi_clip) <- c(352565, 352668, 5273829, 5273924)
extent(lai) <- c(352565, 352668, 5273829, 5273924)

# stacking
s <- stack(lai,ndvi_clip)

# Get Correlation
jnk <- layerStats(s, 'pearson', na.rm=T)
corr_matrix <- jnk$'pearson correlation coefficient'

# Visualization

# create data frame for LAI and NDVI
corr_df <- data.frame(lai=getValues(lai),
                ndvi=getValues(ndvi_clip))

# Plotting
ggplot(corr_df, aes(x = lai, y = ndvi)) +
  geom_point(color="#294fdc",size=0.7,alpha=0.75) + 
  labs(x="LAI", y="NDVI",
       title="Pearson Correlation",
       subtitle="From UAV Point Cloud and Planet Data",
       caption="MB3 Field Measurement") + 
  geom_smooth(color="red",size = 1) + 
  theme_ft_rc()



