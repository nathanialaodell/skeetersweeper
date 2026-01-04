#' Stack and save downloaded state climate data
#'
#' @param state_name Character. State abbreviation as it appears in your file directory.
#' @param write Logical. Whether to write the the raster stack as an .RDS file.
#' @param clim_path Character. The path of your .tif data.
#' @param save_path Character. If writing, where to save to.
#' @param mask sf. Converted to SpatVector prior to mask the raster stack.
#' @param remove Logical. Whether to remove the individual .tif files used to build the stack after stacking.
#' @param return Logical. Return the stack?
#'
#' @export

process_state_tifs <- function(state_name,
                               write = FALSE,
                               clim_path,
                               save_path,
                               mask,
                               remove = FALSE,
                               return = TRUE) {
  tif_files <- list.files(clim_path, pattern = paste0("^", state_name)) # MAKE THIS USEABLE FOR OTHER VARIABLES SOON!

  # create raster stacks
  state_stack <- terra::rast(paste0(clim_path, tif_files))

  vect_mask <- terra::vect(mask) %>%
    terra::project(., state_stack)

  state_stack <- state_stack %>%
    terra::mask(., vect_mask)

  if(write)
    # write the main stack
    readr::write_rds(x = state_stack, file = save_path)

  # remove original files
  if (remove) {
    unstacked <- list.files(clim_path,
                            pattern = paste0("^", state_name, "_\\w{2,6}_\\d{8}.+"))
    lapply(paste0(clim_path, unstacked), file.remove)
  }

  if (return)
    return(state_stack)
}
