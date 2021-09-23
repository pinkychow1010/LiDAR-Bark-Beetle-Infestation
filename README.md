## Bark Beetle Infestation and Dead Tree Assessment using UAV LiDAR and optical data

* [MB3 – From Field Measurements to Geoinformation](http://eagle-science.org/project/mb3-from-field-measurements-to-geoinformation/)
* 23rd September 2021
* EAGLE M.Sc. (Applied Earth Observation and Geoanalysis)

<br>

**Background:**

Bark beetle infestation causes tree mortality in the national park which acts as a natural process. However, the infestation would spread outside of the national park and causes economic loss of the commercial forests, hence early detection of spread would be helpful for implementing preventive measures.

**Objective:**

Using LiDAR UAV data collected during excursion, this project aims to integrated information from high-resolution optical imagery and LiDAR data to improve detection performance of dead tree that possibly caused by bark beetle infestation within the research study plot.

**Assumptions:**

1) NDVI is insufficient to estimate dead trees as there are there are multiple reasons for low NDVI values (eg. no vegetation)
2) LiDAR data alone is ineffective to inspect dead trees as dead trees have similar 3D structure before collapsing and phases such as yellowing of leaves is invisiable from point clouds
3) Dead tree patches would give signal in NDVI that it can be first detected before looking into the point clouds
4) Combining both data can aid dead tree detection

**Research Questions:**

1) What are the health status of the trees within study plot and what are the count of dead tree?
2) Is it feasible/ effective to combine 3D structural information from LiDAR and spectral information from optical data to detect dead trees?

**Data source:**

1) [Planet optical imagery](https://www.planet.com/)
2) UAV field data in the Berchtesgaden National Park

**Tools:**

R packages - 
1) [lidR](https://github.com/Jean-Romain/lidR) (3D point cloud processing) 
2) [leafR](https://rdrr.io/cran/leafR/) (LAI calculation)

**Methods:**

In order to combine structural and spectral information, NDVI is calculated from the Planet imagery used for first inspection with resolution of 3 meters. The pixels with low NDVI values are further inspected by overlaying the pixel boundary with the UAV data so information such as LAI, height, and tree count can be retrieved. The end product would be statistical information about dead tree counts as well as their conditions.

**LiDAR point cloud post-processing:**

Import laz file to R ➤ Classify Ground Points ➤ Calculate DTM ➤ Height Normalization ➤ Calculate DSM and CHM (Canopy Height Model) ➤ Detect Tree Tops

![alt text](https://github.com/pinkychow1010/LiDAR_barkBeetleInfestation/blob/main/graphics/workflow.JPG "Fig. Workflow of this project")

**Results:**

1) Dead tree pixels are not detected from the Planet data as the pixel of minimum NDVI is above 0.7. Inspection then is focused on the pixels with relative lower NDVI for retrieving structural information from LiDAR. Significant differences of LAI are found between average NDVI and low NDVI group. For high NDVI values, LAI saturates and have no noticeable differences.
2) LAI highly correlated to tree heights and health of trees can be distinguished by the ratio of LAI to height.
3) LAI is saturated for high NDVI and thus show no significant correlation.
4) Tree count is 170, with average 30 m height and LAI value of 2.

**Limitations:**

It is possible that dead trees are misclassified from the NDVI due to insufficient spatial resolution of Planet imagery (3m^2 could include several individual trees).

**Key Messages/ Conclusions:**

1) Dead trees are not detected in the study plot although it is quite clear that they exist in the plot. It is possibly because of the  insufficient resolution of Planet data or other uncertainties of the estimated NDVI.
2) It is possible to combine spectral and structural information for detecting dead trees using open source R packages.
3) Yet, the resolution of spectral data is critical for the assessment as it limits the size of dead tree patches that would be potentially detected for further investigation using LiDAR.
4) LAI-height might be used to esitmate tree health instead of NDVI when spectral data is unavailable.
