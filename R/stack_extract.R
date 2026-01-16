#' Extract .tif data to trap points
#'
#' @param dat Data frame. Must contain longitude and latitude columns.
#' @param state_stack Raster stack containing climate data for a state.
#' @param var Character. One of "tmean", "ppt", "tmin", "tmax", "vpdmax", or "tdmean" (variables extractable in prism8_daily).
#' @param dates Vector of dates. Optional, but HIGHLY recommended to provide this argument to avoid intense memory load.
#' @param buffer Numeric. The buffer (meters) to extract raster data to. If missing, then extracted values will be at the point.
#'
#' @import data.table

#' @export

# tif extraction helper
stack_extract <- function(dat,
                          state_stack,
                          var = c("tmean", "ppt", "tmin", "tmax", "vpdmax", "vpdmin", "tdmean"),
                          dates = NULL,
                          buffer = NULL) {

  if (!requireNamespace("data.table", quietly = TRUE)) {
    stop("Package 'data.table' is required but not installed.")
  }

  var <- match.arg(var)

  # -------------------------------
  # 1. Parse layer names
  # -------------------------------
  layer_names <- names(state_stack)

  # Expecting: prism_var_us_30s_YYYYMMDD
  layer_dt <- data.table::data.table(
    layer = layer_names,
    date = as.Date(sub(".*_(\\d{8})$", "\\1", layer_names), "%Y%m%d")
  )

  # -------------------------------
  # 2. Subset by dates if provided
  # -------------------------------
  if (!is.null(dates)) {
    target_dates <- as.Date(dates)

    matched <- layer_dt[date %in% target_dates]

    if (nrow(matched) == 0) {
      stop("No layers found matching the provided dates")
    }

    state_stack <- state_stack[[matched$layer]]
    layer_dt <- matched
  }

  # -------------------------------
  # 3. Unique coordinates
  # -------------------------------
  dat_dt <- data.table::as.data.table(dat)
  unique_coords <- unique(dat_dt[, .(longitude, latitude)])

  pts_sf <- sf::st_as_sf(unique_coords,
                         coords = c("longitude", "latitude"),
                         crs = 4326)

  pts_vect <- terra::vect(pts_sf)
  pts_vect <- terra::project(pts_vect, state_stack)

  if (!is.null(buffer)) {
    pts_vect <- terra::buffer(pts_vect, width = buffer)
  }

  # -------------------------------
  # 4. Extract values
  # -------------------------------
  extracted <- terra::extract(state_stack, pts_vect, xy = FALSE)
  extracted_dt <- data.table::as.data.table(extracted)
  extracted_dt[, c("longitude", "latitude") := unique_coords]

  # -------------------------------
  # 5. Melt to long format
  # -------------------------------
  long_dt <- data.table::melt(
    extracted_dt,
    id.vars = c("ID", "longitude", "latitude"),
    variable.name = "layer",
    value.name = var
  )

  long_dt <- merge(long_dt, layer_dt, by = "layer")

  # -------------------------------
  # 6. Final tidy output
  # -------------------------------
  out <- long_dt[, .(date, longitude, latitude, get(var))]
  data.table::setnames(out, "V4", var)

  return(out)
}
