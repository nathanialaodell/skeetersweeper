#' Extract .tif data to trap points
#'
#' @param dat Data frame. Must contain longitude and latitude columns.
#' @param state_stack Raster stack containing climate data for a state.
#' @param var Character. One of "tmean", "ppt", "tmin", "tmax", "vpdmax", or "tdmean" (variables extractable in prism8_daily).
#' @param dates Vector of dates. Optional, but HIGHLY recommended to provide this argument to avoid intense memory load.

#' @export

# tif extraction helper
stack_extract <- function(dat,
                          state_stack,
                          var = c("tmean", "ppt", "tmin", "tmax", "vpdmax", "vpdmin", "tdmean"),
                          dates = NULL
                          ) {

  if (!is.null(dates)) {
    original_length <- terra::nlyr(state_stack)

    # create pattern for the variable
    var_pattern <- paste0("prism_", var, "_")

    # convert dates to the format in layer names (YYYYMMDD)
    date_strings <- format(as.Date(dates), "%Y%m%d")

    # get layer names
    layer_names <- names(state_stack)

    # find which layers match our dates
    matching_layers <- sapply(date_strings, function(d) {
      grep(d, layer_names, value = FALSE)
    }) %>% unlist() %>% unique()

    if (length(matching_layers) == 0) {
      stop("No layers found matching the provided dates")
    }

    # subset the stack to only those layers
    state_stack <- state_stack[[matching_layers]]

    message(paste("Extracting", length(matching_layers), "of",
                  length(original_length), "possible layers due to dates argument."))
  }

  dat_sf <- dat %>% sf::st_as_sf(coords = c("longitude", "latitude"), crs = 4326) %>%
    dplyr::group_by(geometry) %>%
    dplyr::summarise(dum = sum(total), .groups = "drop")

  # when transforming to the different CRS, there is a slight shift in coordinates. Add them back
  orig_coords <- dat_sf %>%
    dplyr::mutate(
      longitude = sf::st_coordinates(.)[, 1],
      latitude = sf::st_coordinates(.)[, 2]
    ) %>%
    sf::st_drop_geometry()

  dat_sf <- sf::st_transform(dat_sf, terra::crs(state_stack))
  var_pattern <- paste0("prism_", var, "_")

  # testing extraction speed
  extracted_points <- terra::extract(state_stack, terra::vect(dat_sf), xy = F)

  extracted_points <- cbind(extracted_points, orig_coords)

  extracted_points <- extracted_points %>% # the method detailed in my PRISM write up is outdated... remaking this
    tidyr::pivot_longer(
      cols = tidyselect::starts_with(var_pattern),
      names_to = "date_string",
      values_to = var
    ) %>%
    # extract the date from the column name
    dplyr::mutate(
      # remove the prefix to get just the date portion (YYYYMMDD)
      date_string = stringr::str_replace(date_string, paste0(var_pattern, "us_30s_"), ""),
      # convert to proper date format
      date = as.Date(date_string, format = "%Y%m%d")
    ) %>%
    # remove the intermediate date_string column and reorder
    dplyr::select(date, longitude, latitude, var)
}
