#' Extract .tif data to trap points
#'
#' @param dat Data frame. Must contain longitude and latitude columns.
#' @param state_stack Raster stack containing climate data for a state.
#' @param var Character. One of "tmean", "ppt", "tmin", "tmax", "vpdmax", or "tdmean" (variables extractable in prism8_daily).
#' @param lon_ol Character.
#' @param lat_col Character.
#' @param crs_in Numeric. The coordinate reference system to apply to dat.

# tif extraction helper
stack_extract <- function(dat,
                          state_stack,
                          var = c("tmean", "ppt", "tmin", "tmax", "vpdmax", "vpdmin", "tdmean"),
                          lon_col = "longitude",
                          lat_col = "latitude",
                          crs_in = 4326) {
  var <- match.arg(var)

  # get unique coordinates and preserve mapping to original rows
  dat_unique <- dat %>%
    mutate(original_id = row_number()) %>%
    group_by(across(all_of(c(lon_col, lat_col)))) %>%
    summarise(original_ids = list(original_id), .groups = "drop")

  # convert unique coords to sf
  dat_sf <- dat_unique %>%
    st_as_sf(coords = c(lon_col, lat_col), crs = crs_in) %>%
    st_transform(crs(state_stack))

  # extract values; no repetition here!
  extracted_points <- terra::extract(state_stack, terra::vect(dat_sf), xy = TRUE)

  var_pattern <- paste0("prism_", var, "_")

  # pivot and clean column names
  extracted_long <- extracted_points %>%
    pivot_longer(
      cols = starts_with(var_pattern),
      names_to = "date_string",
      values_to = "value"
    ) %>%
    mutate(
      date_string = str_replace(date_string, paste0(var_pattern, "us_30s_"), ""),
      date = as.Date(date_string, format = "%Y%m%d")
    ) %>%
    select(ID, date, x, y, value) %>%
    rename(!!var := value)

  # add back the original IDs mapping
  extracted_long <- extracted_long %>%
    left_join(
      dat_sf %>%
        st_drop_geometry() %>%
        mutate(ID = row_number()) %>%
        select(ID, original_ids),
      by = "ID"
    ) %>%
    unnest(original_ids) %>%
    select(-ID) %>%
    rename(ID = original_ids)

  return(extracted_long)
}
