# MB3 Project - SS21
# author: Cornelia Zygar

# loading packages
library(lidR)
library(raster)
library(sf)
library(rgdal)
library(rgeos)
# for plotting:
library(ggplot2)
library(hrbrthemes)

# setting working directory
setwd("...")


###### DATA PREPARATION (DATA IS ALREADY CREATED) ######
# importing LiDAR pointcloud
# las <- readLAS("laser_1_2021-07-09-12-04-37.laz")

# validating the data
# las_check(las)

# create raster from pointcloud to create shapefile in QGIS
# qgis_raster <- grid_canopy(las, res = 1, p2r())
# writeRaster(qgis_raster, "lasArea.tif")

# importing aoi as shapefile
# aoi <- read_sf(dsn = "BGLaoi.shp")

# clipping the pointcloud data to aoi
# las_aoi <- clip_roi(las, aoi)

# print(las_aoi)


###### CLASSIFYING GROUNDPOINTS (DATA IS ALREADY CREATED!) ######
# classify ground
# las_aoi_ground <- classify_ground(las_aoi,algorithm = pmf(ws = 5, th = 3))

# exporting the data
# writeLAS(las_aoi_ground, "BGL_aoi_ground.laz")

###### DATA IMPORT #########
# importing data with classified ground points
las_aoi_ground <- readLAS("BGL_aoi_ground.laz")

# checking the data
las_check(las_aoi_ground)
plot(las_aoi_ground)

# checking for classes in pointcloud
unique(las_aoi_ground$Classification) # 2 and 0

# clipping ground classified data to an even smaller area
aoi_2 <- read_sf(dsn = "BGLaoi_2.shp")
las_aoi_ground_2 <- clip_roi(las_aoi_ground, aoi_2)


###### CALCULATING DTM ######
# kriging() function is used to interpolate the area between the ground points
dtm_2 <- grid_terrain(las_aoi_ground_2, res=5, algorithm=kriging())
plot_dtm3d(dtm_2, bg="white") # 3D Plot

# writeRaster(dtm, "dtm.tif")


####### NORMALIZE HEIGHT ######
norm_las_aoi_ground_2 <- normalize_height(las_aoi_ground_2,dtm_2)

# plotting normalized vs. non-normalized point cloud
plot(norm_las_aoi_ground_2) # normalized
plot(las_aoi_ground_2) # non-normalized

# exporting the data
# writeLAS(las_aoi_ground_2, "las_aoi_ground_2.laz")
# writeLAS(norm_las_aoi_ground_2, "norm_las_aoi_ground_2.laz")


###### CALCULATING DSM #####
dsm <- grid_canopy(las_aoi_ground_2, 1, dsmtin())

# plotting
plot_dtm3d(dsm)
x11()
plot(dsm)


###### CALCULATING CHM #####
chm <- grid_canopy(norm_las_aoi_ground_2, 1, dsmtin())

# plotting
plot_dtm3d(chm)
plot(chm)


###### TREE DETECTION + TREE HEIGHT ######
# tree top calculation based on non-normalized point cloud
ttops <- find_trees(las_aoi_ground_2, lmf(ws = 5))

dim(ttops)

# tree top calculation based on normalized point cloud
ttops_norm <- find_trees(norm_las_aoi_ground_2, lmf(ws = 5))

dim(ttops_norm)

# exporting the data
# writeOGR(ttops, "ttops", "ttopsBGL", driver="ESRI Shapefile")
# writeOGR(ttops_norm, "ttops_norm", "ttopsBGL_norm", driver="ESRI Shapefile")

# plotting tree tops on top of chm
x11()
#par(bg = 'black', col= "white")
plot(chm, col = height.colors(50))
plot(ttops, add = TRUE)

# the tree tops calculated based on the normalized point cloud already contain
# height information.

extract(chm, ttops) # non-normalized point cloud -> wrong values
extract (chm, ttops_norm) # normalized point cloud -> reasonable values


###### SEPERATING BETWEEN HEALTHY AND UNHEALTHY TREES ######
# importing shapefile of unhealthy tree areas (defined based on NDVI values)
unhealty_shp <- read_sf(dsn = "10quantile_tree.gpkg")
# converting it from sf to sp (SpatialPolygonsDataframe)
unhealty_sp <- as_Spatial(unhealty_shp)

# plotting the dataframes
x11()
plot(unhealty_shp)
plot(unhealty_sp)


###### calculating height of "unhealthy" trees ######

unhealthy_ttops_norm <- crop(ttops_norm, unhealty_sp)
unhealthy_ttops_norm

# exporting result
writeOGR(unhealthy_ttops_norm, "unhealthy_ttops_norm", "unhealthy_ttops_norm", driver="ESRI Shapefile")

# plotting the result
x11()
plot(chm, col = height.colors(50))
plot(unhealthy_ttops_norm, add = TRUE)

###### calculating height of "healthy" trees ######

# creating "healthy"-polygon
aoi_2_sp <- as_Spatial(aoi_2) 
healthy_sp <- gDifference(aoi_2_sp, unhealty_sp)

# extracting trees located in the "healthy"-polygon
healthy_ttops_norm <- crop(ttops_norm, healthy_sp)
healthy_ttops_norm

# exporting the result
writeOGR(healthy_ttops_norm, "healthy_ttops_norm", "healthy_ttops_norm", driver="ESRI Shapefile")

# plotting the result
x11()
plot(chm, col = height.colors(50))
plot(healthy_ttops_norm, add = TRUE)

###### CREATING A DATA FRAME CONTAINING TREE HEIGHTS ######
# data frame containing heights of healthy trees
healthy_ttops_norm
healthy_df <- as.data.frame(healthy_ttops_norm$Z)
healthy_df$health <- "healthy"
colnames(healthy_df)[1] <- "Z"
healthy_df
dim(healthy_df)

# data frame containing heights of unhealthy trees
unhealthy_ttops_norm
unhealthy_df <- as.data.frame(unhealthy_ttops_norm$Z)
unhealthy_df$health <- "unhealthy"
colnames(unhealthy_df)[1] <- "Z"
unhealthy_df
dim(unhealthy_df)

# combining both data frames
tree_df <- rbind(healthy_df, unhealthy_df)
tree_df


###### PLOTTING ######
# comparing tree height of healthy and unhealthy trees
x11()
ggplot(tree_df, aes(x=health, y=Z))+
  geom_boxplot(color="red")+
  labs(x="Health Status", y="Tree Height",
       title="Tree Height",
       subtitle="From UAV Point Cloud",
       caption="MB3 Field Measurement")+
  theme_ft_rc(grid="Y")


##### LAI for every tree within plot #####
lai <- raster("LAI.tif")
dim(healthy_ttops_norm)
class(unhealthy_ttops_norm)

# SAME RESULT AS VERSION WITHOUT SECIFIED BUFFER!
lai_unhealthy <- raster::extract(lai, unhealthy_ttops_norm, buffer=0.5, small=TRUE, fun=mean)
lai_unhealthy

lai_healthy <- raster::extract(lai, healthy_ttops_norm, buffer=0.5, small=TRUE, fun=mean)
class(lai_healthy)

# combine them into dataframe
lai_unhealthy_df <- as.data.frame(lai_unhealthy)
lai_unhealthy_df$health <- "unhealthy"
colnames(lai_unhealthy_df)[1] <- "lai"
lai_unhealthy_df

lai_healthy_df <- as.data.frame(lai_healthy)
lai_healthy_df$health <- "healthy"
colnames(lai_healthy_df)[1] <- "lai"
lai_healthy_df

lai_df <- rbind(lai_healthy_df, lai_unhealthy_df)
lai_df

### plotting
x11()
ggplot(lai_df, aes(x=health, y=lai))+
  geom_boxplot(color="red")+
  labs(x="Health Status", y="LAI value",
       title="LAI for each tree",
       subtitle="(Radius around tree top: 0.5m)",
       caption="MB3 Field Measurement")+
  theme_ft_rc(grid="Y")


