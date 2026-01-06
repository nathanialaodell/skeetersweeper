#' Extract .tif data to trap points
#'
#' @param dat Data frame. Must contain longitude and latitude columns.
#' @param state_stack Raster stack containing climate data for a state.
#' @param var Character. One of "tmean", "ppt", "tmin", "tmax", "vpdmax", or "tdmean" (variables extractable in prism8_daily).
#' @param dates Vector of dates. Optional, but HIGHLY recommended to provide this argument to avoid intense memory load.
#'
#' @import data.table

#' @export

# tif extraction helper
stack_extract <- function(dat,
                          state_stack,
                          var = c("tmean", "ppt", "tmin", "tmax", "vpdmax", "vpdmin", "tdmean"),
                          dates = NULL) {

  if (!requireNamespace("data.table", quietly = TRUE)) {
    stop("Package 'data.table' is required but not installed.")
  }

  # Match argument
  var <- match.arg(var)

  if (!is.null(dates)) {
    original_length <- terra::nlyr(state_stack)
    # create pattern for the variable
    var_pattern <- paste0("prism_", var, "_")
    # convert dates to the format in layer names (YYYYMMDD)
    date_strings <- format(as.Date(dates), "%Y%m%d")
    # get layer names
    layer_names <- names(state_stack)
    # find which layers match our dates
    matching_layers <- unique(unlist(lapply(date_strings, function(d) {
      grep(d, layer_names, value = FALSE)
    })))
    if (length(matching_layers) == 0) {
      stop("No layers found matching the provided dates")
    }
    # subset the stack to only those layers
    state_stack <- state_stack[[matching_layers]]
    message(
      paste(
        "Extracting",
        length(matching_layers),
        "of",
        original_length,
        "possible layers due to dates argument."
      )
    )
  }

  # convert to data.table and get unique coordinates
  dat_dt <- data.table::as.data.table(dat)
  unique_coords <- unique(dat_dt[, .(longitude, latitude)])

  # create sf object
  dat_sf <- sf::st_as_sf(unique_coords,
                         coords = c("longitude", "latitude"),
                         remove = FALSE,
                         crs = 4326)

  # store original coordinates
  orig_coords <- data.table::as.data.table(sf::st_drop_geometry(dat_sf))

  # transform to spatvector
  state_vect <- terra::vector(dat_sf)
  state_vect_proj <- terra::project(state_vect, state_stack)



  var_pattern <- paste0("prism_", var, "_")

  # extract values
  extracted_points <- terra::extract(state_stack, terra::vect(dat_sf), xy = FALSE)

  # convert to data.table and add original coordinates
  extracted_dt <- data.table::as.data.table(extracted_points)
  extracted_dt[, c("longitude", "latitude") := orig_coords]

  # melt to long format
  id_vars <- c("ID", "longitude", "latitude")
  value_vars <- names(extracted_dt)[grepl(var_pattern, names(extracted_dt))]

  extracted_long <- data.table::melt(extracted_dt,
                                     id.vars = id_vars,
                                     measure.vars = value_vars,
                                     variable.name = "date_string",
                                     value.name = var)

  # process date strings
  extracted_long[, date_string := gsub(paste0(var_pattern, "us_30s_"), "", date_string)]
  extracted_long[, date := as.Date(date_string, format = "%Y%m%d")]

  # select and reorder columns, remove ID column
  result <- extracted_long[, .(date, longitude, latitude, get(var))]
  data.table::setnames(result, "V4", var)

  return(result)
}
