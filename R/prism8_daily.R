#' Download and convert daily PRISM data at 800m resolution to .tif files.
#'
#' @param var Character, or list of character. The type of data you would like to download.  Must be "ppt", "tmean", "tmin", "tmax", "tdmean", "vpdmin", or "vpdmax".
#' @param start_date Date. The first date in a range of days to download data for.
#' @param end_date Date. The last date in a range of days to download data for.
#' @param dir Character. The location that data will be downloaded to. Defaults to working directory.
#' @param remove Logical. Removes zip files after extraction; HIGHLY recommended. Defaults to TRUE.
#' @param date_list List of date. If you already know which dates you'd like to download data frame, use this to avoid downloading irrelevant data. Preferred method.
#' @param bil Logical. Removes all extracted files that do not end in .bil or .hdr; which are the minimum files needed to build a raster. Defaults to TRUE.
#' @param template bbox. The extent(s) to which to crop downloaded data. Can be a list.
#' @param state_name Character. If template is not missing, then the state(s) for which the bounding box is pulled from. Used for writing raster images.
#' @param progress Logical. Whether to create a message in the console at the beginning of each file download initialization.
#' @examples
#'
#' # downloading precipitation, temp mean, min, and max data for Texas and Oregon
#' box1 <- matrix(
#'  c(-124.56624, 41.99179, -116.46350, 46.29083),
#'  nrow = 1,
#'  byrow = TRUE,
#'  dimnames = list(NULL, c("xmin", "ymin", "xmax", "ymax"))
#' )
#'
#' box2 <- matrix(
#'  c(-106.64565, 25.83738, -93.50829, 36.50070),
#'  nrow = 1,
#'  byrow = TRUE,
#'  dimnames = list(NULL, c("xmin", "ymin", "xmax", "ymax"))
#' )
#'
#' boxes <- list(box1, box2)
#'
#' prism8_daily(var = c("ppt", "tmean", "tmin", "tmax"),
#' start_date = "2025-12-25",
#' end_date = "2025-12-26",
#' template = boxes,
#' state_name = c("OR", "TX")
#' )
#'
#' # alternatively, do not crop data
#' prism8_daily(var = c("ppt", "tmean", "tmin", "tmax"),
#' start_date = "2025-12-25",
#' end_date = "2025-12-26"
#' )
#'
#'
#' @details
#' Create a .tif for the entire United States is the default functionality. If using lists for template and state_name args, the elements must be aligned to avoid misnamed .tif files.
#' E.g., if the first element of template is a bounding box for Wyoming then the first element of state_name must be "WY", and so on.
#'
#'
#' @import lubridate
#' @import janitor
#' @import terra
#' @export

prism8_daily <- function(var,
                         start_date,
                         end_date,
                         date_list = NULL,
                         dir = getwd(),
                         remove = TRUE,
                         bil = TRUE,
                         template,
                         state_name = NULL,
                         progress = TRUE) {
  base_url <- "https://services.nacse.org/prism/data/get/us/800m"
  CRS = "+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0"

  for (v in var) {
    if (!is.null(date_list)) {
      dates <- date_list
    }

    else{
      dates <- seq(as.Date(start_date), as.Date(end_date), by = "1 day")
    }
    for (i in seq_along(dates)) {
      # turning dates into readable strings to attach to the URL
      day <- strftime(dates[i], "%Y%m%d")

      # check if output .tif file(s) already exist
      if (!missing(template)) {
        if (is.list(template)) {
          # check if all state .tif files exist
          all_exist <- all(sapply(state_name, function(sn) {
            file.exists(file.path(dir, paste0(sn, "_", v, "_", day, ".tif")))
          }))
          if (all_exist) {
            print(paste0("Skipping ", as.Date(day, format = "%Y%m%d"), ": .tif already in directory!"))
              next
            }
        } else {
          # check if single state .tif file exists
          if (file.exists(file.path(dir, paste0(
            state_name, "_", v, "_", day, ".tif"
          )))) {
            print(paste0("Skipping ", as.Date(day, format = "%Y%m%d"), ": .tif already in directory!"))
            next
          }
        }
      } else {
        # check if US .tif file exists
        if (file.exists(file.path(dir, paste0("US_", v, "_", day, ".tif")))) {
          print(paste0("Skipping ", as.Date(day, format = "%Y%m%d"), ": .tif already in directory!"))
          next
        }
      }

      url <- paste0(base_url, "/", v, "/", day, "?format=bil")

      # download file into specified folder
      if (progress) {
        print(paste("File", i, "of", length(dates), sep = " "))
      }

      dest_file <- file.path(dir, paste0(v, "_", day, ".bil.zip"))


      download.file(url, destfile = dest_file, mode = "wb")

      ex_fl <- unzip(dest_file, exdir = dir)

      # remove .zip folder (default)
      if (remove) {
        file.remove(dest_file)
      }

      # .bil and .hdr are needed to build rasters, nothing else. remove others ASAP

      irrelevant <- ex_fl[!grepl("\\.bil$|\\.hdr$", ex_fl)]
      file.remove(irrelevant)

      relevant <- ex_fl[grepl("\\.bil$|\\.hdr$", ex_fl)]

      # as in shapefiles in 'sf', only need to call in the .bil for rasters

      bil <- ex_fl[grepl("\\.bil$", ex_fl)]

      dat <- terra::rast(bil)

      # some instances where having the entire US may be useful, so giving the option here
      if (!missing(template)) {
        # cropping the read raster to relevant bounding boxes if multiple

        if (is.list(template)) {
          for (k in seq_along(template)) {
            out <- terra::crop(dat, sf::st_transform(template[[k]], terra::crs(dat)))
            out <- terra::project(out, CRS)

            terra::writeRaster(out,
                               paste0(dir, "/", state_name[k], "_", v, "_", day, ".tif"),
                               overwrite = TRUE)
          }
        }

        else {
          out <- terra::crop(dat, sf::st_transform(template, terra::crs(dat)))
          out <- terra::project(out, CRS)

          terra::writeRaster(out,
                             paste0(dir, "/", state_name, "_", v, "_", day, ".tif"),
                             overwrite = TRUE)
        }

      }

      else {
        terra::writeRaster(dat, paste0(dir, "/US_", v, "_", day, ".tif"),
                           overwrite = TRUE)
      }

      # remove everything that isn't a .tif prior to moving on to the next date
      file.remove(relevant)

      # terra will create temp files that won't be removed until the R session ends
      terra::tmpFiles(remove = TRUE)

      # polite pause to not overload servers
      Sys.sleep(2)

      if (i %% 5 == 0) {
        gc()
      }
    }

  }
}
