# skeetersweeper

> [!CAUTION] 
> This package is a work in progress, currently intended for INTERNAL use in thesis work at the University of Washington and has not been subject to CRAN review.

## Installation 

---
```{r}
devtools::install_github('nathanialaodell/skeetersweeper')
library(skeetersweeper)
```

## *Sweep_fun*

---
The primary tool contained in this package, 'sweep_fun', is a function that 
takes a raw, potentially messy .csv, .xlsx, or .xls file and both cleans and 
standardizes species collection and geospatial information.

The following table describes the function's arguments.

| Argument | Description |
|----------------------|-------------------------------------------------|
| path | Character. The directory of a single datasheet. Defaults to NULL. |
| state_name | Character. Abbreviated state (e.g. "TX", "WA") that vector data comes from. This arg is used to create a 'state' column--useful when binding multiple agencies' data. |
| extensions | If working with multi-year data that is spread across multiple files, a list of path directories. Defaults to NULL. |
| sheets | TRUE or FALSE. Indicates whether data is stored within multiple excel sheets. Defaults to FALSE. |
| type | The type of datasheet to be cleaned: either 'abundance' or 'pool'. Defaults to 'abundance'. |

The 'sweep' function can be split into a few sections and accomplishes multiple pre-processing tasks that don't require manual oversight:

1)  Standardizing the genus representation for *Aedes* (Ae), *Culex* (Cx), *Anopheles* (An), and *Psorophora* (P); ensuring that different agency standards for species ID'ing inputs don't impact statistical analyses.
2)  For agencies that record street addresses of trap locations (as opposed to giving traps unique identifiers), address representation is standardized to *HOUSE NUMBER* *STREET NAME* *STREET SUFFIX*
3) Parse geoocoordinates to ensure they are in degree decimal format (via 'parzer')
4) Geocode addresses with missing or obviously incorrect geocoordinates (outside of the county's bounding box via 'tigris'--an imperfect but reasonable solution). Observations are removed if geocode result is empty.
5)  Subset data to only include female collections

**Thus, this function has the following limitations and assumptions (specifically with respect to the data input format)**.

## Abundance information cleaning
---

1)  The input data **must** have at least the following variables/column names (all other variables are ignored--for now, anyway):

| Variable | Description |
|----------------------------|--------------------------------------------|
| county | County of collection |
| sampled_date | mm/dd/yyyy trap was collected |
| address | Street OR identifier of trap placement (e.g. "Hc11", "14", etc.) |
| collection_method | Trap type of collection |
| latitude | Coordinate. Can be of any format initially. |
| longitude | Coordinate. Can be of any format initially. |
| mosquito_id | Species collected on sampled_date |
| number_of_mosquitoes | Number of females of a particular species collected on sampled_date |

2)  It is assumed that the 'tigris' package has the most up-to-date and correct county boundaries as per its counties() function call. Tigris uses the Census line files to draw these county boundaries.
3)  Some trap locations/geocoordinates may simply be impossible to decipher/clean using the combination of 'parzer', 'tigris', and 'postmastr' leveraged in this function. This can cause issues in geospatial analysis if not caught.

3b) **It is imperative that all data cleaned using this function is turned into a shapefile and plotted prior to analysis to ensure that there are no error in spatial coordinates**.

3c) As a corollary to this: the 'sweep' function is just that--a function to perform the basic pre-processing needed to get your hands on somewhat-usable-not-totally-useless vector data. The 'mop' portion (work in progress)--which is intended to tackle the more complex and minute errors/issues--is a process that'll look different from dataset to dataset.

## Pools information cleaning

---
The procedure is identical to the one described above except for the following changes to the required input data structure (marked in bold):

| Variable | Description |
|----------------------------|--------------------------------------------|
| county | County of collection |
| sampled_date | mm/dd/yyyy trap was collected |
| address | Street OR identifier of trap placement (e.g. "Hc11", "14", etc.) |
| collection_method | Trap type of collection |
| latitude | Coordinate. Can be of any format initially. |
| longitude | Coordinate. Can be of any format initially. |
| mosquito_id | Species collected on sampled_date |
| number_of_mosquitoes | Number of a particular species collected on sampled_date (FEMALES) |
| **disease** | **The disease being tested for.** |
| **result** | **Result of test (1 if positive, else 0).** |

## Examples
---

'Toy data.csv' is available for extremely lightweight demonstration purposes:

```{r}
data <- read.csv('https://raw.githubusercontent.com/nathanialaodell/skeetersweeper/refs/heads/main/Toy%20data.csv')
```

Path that is comprised of one .csv file containing abundance data:

```{r}
skeeter_path = here("interesting collections.csv")

sweep_fun(path = skeeter_path, state_name = "WY")
```

Path that is comprised of one .csv file, with multiple sheets, containing abundance data:

```{r}
skeeter_path = here("interesting collections in sheets.csv")

sweep_fun(path = skeeter_path, state_name = "WY", sheets = TRUE)
```

Path that is comprised of multiple .xslx files with multiple sheets containing pool data:

```{r}
skeeter_stack <- c(here("interesting collections 2000-2004.xlsx"),
here("interesting collections 2005-2008.xlsx")
)

sweep_fun(extensions = skeeter.stack, state_name = "WY", type = "pool", sheets = TRUE)
```

## *prism8_daily*

------------------------------------------------------------------------

> [!NOTE] 
> This function only has the functionality to extract data from the United States.

Currently, the R 'prism' package does not have an option to download daily 
climate variables at 800m resolution. This function works around this by using 
command line operations within R to scrape their web service.

First, the user specifies which variables they want to download from the 
PRISM webservice, the date range, and whether or not they want to crop these 
climate variables to a spacial extent (such as state boundaries). 
The workflow is as follows for index i in a provided date range:

1) Download the file to the user-specified path by pasting the date into a base URL
2) Unzip the file and remove all files without a .bil or .hdr extension. Optionally, delete the .zip after extraction
3) Temporarily load the .bil into R as a raster file
4) If applicable, crop the raster to a spacial extent
5) Save the raster as a .tif (this is saved in the same path as step 1)
6) Remove all .bil and .hdr files in the directory before moving onto i + 1

Steps 4-6 are intended to limit the amount of storage required to store United 
PRISM climate data. If you were attempt to download all required data, unzip it, 
and leave it as a .bil/.hdr combination, the amount of space required per day 
can range from 50-100mb per daily. If, for example, you wanted to download data 
for precipitation, temp max, min, and mean, you would need anywhere between 
1-5TB of storage, depending on the date range. Converting to a .tif condenses 
data into 500kb-5mb chunks, with the higher end being for uncropped data 
(i.e., a daily for the entire United States).

Note that although download times for individual files are very short, as per the PRISM group's request
this function forces a 2 second sleep between download requests to avoid 
overloading PRISM servers.
