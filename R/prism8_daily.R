#' Extract daily PRISM data at 800m resolution.
#'
#' @param var Character. The type of data you would like to download.  Must be "ppt", "tmean", "tmin", "tmax", "tdmean", "vpdmin", or "vpdmax".
#' @param start_date Date. The first date in a range of days to download data for.
#' @param end_date Date. The last date in a range of days to download data for.
#' @param dir Character. The location that data will be downloaded to. Defaults to working directory.
#' @param remove Logical. Removes zip files after extraction; HIGHLY recommended. Defaults to TRUE.
#' @param date_list List of date. If you already know which dates you'd like to download data frame, use this to avoid downloading irrelevant data. Prefered method.
#' @import lubridate
#' @import janitor
#' @export

prism8_daily <- function(var, start_date, end_date, date_list = NULL,
                         dir = getwd(), remove = TRUE){

  clim_var <- var
  base_url <- "https://services.nacse.org/prism/data/get/us/800m"

  if (!is.null(date_list)){
    for (i in seq_along(date_list)){
      day <- strftime(date_list[[i]], "%Y%m%d")
      url <- paste0(base_url, "/", clim_var, "/", day, "?format=bil")

      # Download file into temp folder
      dest_file <- file.path(dir, paste0(clim_var, "_", day, ".bil.zip"))
      download.file(url, destfile = dest_file, mode = "wb")

      unzip(dest_file, exdir = dir)

      if(remove){
        file.remove(dest_file)
      }

      Sys.sleep(2)  # polite pause
    }

  }

  else{dates <- seq(as.Date(start_date),
               as.Date(end_date),
               by = "1 day")

  for (i in seq_along(dates)) {
    day <- strftime(dates[i], "%Y%m%d")
    url <- paste0(base_url, "/", clim_var, "/", day, "?format=bil")

    # Download file into temp folder
    dest_file <- file.path(dir, paste0(clim_var, "_", day, ".bil.zip"))
    download.file(url, destfile = dest_file, mode = "wb")

    Sys.sleep(2)  # polite pause
  }

  zip_files <- list.files(dir, pattern = "\\.zip$", full.names = TRUE)

  for (z in zip_files) {
    unzip(z, exdir = dir)
    unzip(dest_file, exdir = dir)

    if(remove){
      file.remove(dest_file)
    }

    Sys.sleep(2)  # polite pause
  }
  }

}
