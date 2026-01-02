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
#' state_name = c("OR", "TX"))
#'
#' @details
#' If using lists for template and state_name args, the elements must be aligned to avoid misnamed .tif files.
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
      if (progress) {
        print(paste("File", i, "of", length(dates), sep = " "))
      }

      # turning dates into readable strings to attach to the URL
      day <- strftime(dates[i], "%Y%m%d")
      url <- paste0(base_url, "/", v, "/", day, "?format=bil")

      # download file into specified folder

      dest_file <- file.path(dir, paste0(v, "_", day, ".bil.zip"))
      download.file(url, destfile = dest_file, mode = "wb")

      ex_fl <- unzip(dest_file, exdir = dir)

      # .bil and .hdr are needed to build rasters, nothing else. remove others ASAP

      irrelevant <- ex_fl[!grepl("\\.bil$|\\.hdr$", ex_fl)]
      file.remove(irrelevant)

      relevant <- ex_fl[grepl("\\.bil$|\\.hdr$", ex_fl)]

      # as in shapefiles in 'sf', only need to call in the .bil for rasters

      bil <- ex_fl[grepl("\\.bil$", ex_fl)]


      # remove .zip folder (default)
      if (remove) {
        file.remove(dest_file)
      }

      # some instances where having the entire US may be useful, so giving the option here
      if (!missing(template)) {
        # do this outside proceeding loop for speed
        dat <- terra::rast(bil)
        terra::project(dat, CRS)

        # cropping the read raster to relevant bounding boxes if multiple

        if (is.list(template)) {
          for (k in seq_along(template)) {
            out <- terra::crop(dat, sf::st_transform(template[[k]], terra::crs(dat)))

            terra::writeRaster(out, paste0(dir,"/",state_name[k], "_", v, "_", day, ".tif"))
          }
        }

        else {
          out <- terra::crop(dat, sf::st_transform(template, terra::crs(dat)))

          terra::writeRaster(out, paste0(dir,"/",state_name, "_", v, "_", day, ".tif"))
        }

        # remove everything that isn't a .tif prior to moving on to the next date
        file.remove(relevant)

      }

    }

  }

  # polite pause to not overload servers
  Sys.sleep(3.5)

}
