#' Get Data from the Open Crime Database
#'
#' Retrieves data from the Open Crime Database for the specified years. Latitude
#' and longitude are specified using the WGS 84 (EPSG:4326) co-ordinate
#' reference system.
#'
#' By default this function returns a one-percent sample of the 'core' data.
#' This is the default to minimize accidentally requesting large files over a
#' network.
#'
#' Setting type = "core" retrieves the core fields (e.g. the type, co-ordinates
#' and date/time of each offense) for each offense.
#' The data retrieved by setting type = "extended" includes all available fields
#' provided by the police department in each city. The extended data fields have
#' not been harmonized across cities, so will require further cleaning before
#' most types of analysis.
#'
#' Requesting all data (more than 17 million rows) may lead to problems with
#' memory capacity. Consider downloading smaller quantities of data (e.g. using
#' type = "sample") for exploratory analysis.
#'
#' Setting output = "sf" returns the data in simple features format by calling
#' \code{\link[sf:st_as_sf]{sf::st_as_sf(..., crs = 4326, remove = FALSE)}}
#'
#' For more details see the help vignette:
#' \code{vignette("introduction", package = "crimedata")}
#'
#' @param years A single integer or vector of integers specifying the years for
#'   which data should be retrieved. If NULL (the default), data for the most
#'   recent year will be returned.
#' @param cities A character vector of city names for which data should be
#'   retrieved. Case insensitive. If NULL (the default), data for all available
#'   cities will be returned.
#' @param type Either "sample" (the default), "core" or "extended".
#' @param cache Should the result be cached and then re-used if the function is
#'   called again with the same arguments?
#' @param quiet Should messages and warnings relating to data availability and
#'   processing be suppressed?
#' @param output Should the data be returned as a tibble by specifying "tbl"
#'   (the default) or as a simple features (SF) object using WGS 84 by
#'   specifying "sf"?
#'
#' @return A tibble containing data from the Open Crime Database.
#'
#' @export
#'
#'
get_crime_data <- function(
  years = NULL,
  cities = NULL,
  type = "sample",
  cache = TRUE,
  quiet = !interactive(),
  output = "tbl"
) {

  # Check for errors
  rlang::arg_match(type, c("core", "extended", "sample"))
  if (!rlang::is_null(cities) & !rlang::is_character(cities))
    rlang::abort("`cities` must be `NULL` or a character vector of city names.")
  if (!rlang::is_null(years) & !rlang::is_integerish(years))
    rlang::abort("`years` must be `NULL` or an integer vector.")
  if (!rlang::is_logical(quiet, n = 1))
    rlang::abort("`quiet` must be `TRUE` or `FALSE`.")
  rlang::arg_match(output, c("tbl", "sf"))

  # Get tibble of available data
  urls <- get_file_urls(quiet = quiet)
  urls$city <- tolower(urls$city)

  # If years are not specified, use the most recent available year
  if (is.null(years)) years <- max(urls$year)

  # If cities are not specified, use all available cities
  if (is.null(cities)) {
    cities <- "All cities"
  }

  # Convert city names to lower case
  cities <- tolower(cities)

  # Make sure years is of type integer, since there is a difference between the
  # hashed values of the same numbers stored as numeric and stored as integer,
  # which makes a difference when specifying the cache file name
  years <- as.integer(years)

  # Check if all specified years are available
  if (!all(years %in% unique(urls$year))) {
    rlang::abort(
      c(
        "One or more of the requested years of data is not available",
        "i" = stringr::str_glue(
          "For details of data available in the Crime Open Database, see ",
          "<https://osf.io/zyaqn/>"
        ),
        "i" = stringr::str_glue(
          "Data for the current year are not available because the database ",
          "is updated annually."
        )
      )
    )
  }

  # check if all specified cities are available
  if (cities[1] != "all cities" & !all(cities %in% unique(urls$city))) {
    rlang::abort(
      c(
        "Data is not available for one or more of the specified cities.",
        "*" = "Have you spelled the city names correctly?",
        "i" = stringr::str_glue(
          "For details of data available in the Crime Open Database, see ",
          "<https://osf.io/zyaqn/>"
        )
      )
    )
  }

  # extract URLs for requested data
  urls <- urls[urls$data_type == type & urls$year %in% years &
                 urls$city %in% cities, ]

  # check if specified combination of years and cities is available
  if (nrow(urls) == 0) {

    rlang::abort(stringr::str_glue(
      "The Crime Open Database does not contain data for any of the ",
      "specified cities for the specified years."
    ))

  } else {

    throw_away <- apply(
      expand.grid(year = years, city = cities),
      1,
      function(x) {
        if (
          nrow(urls[urls$year == x[[1]] & urls$city == x[[2]], ]) == 0 &
          quiet == FALSE
        ) {
          rlang::warn(stringr::str_glue(
            "Data are not available for crimes in ",
            "{stringr::str_to_title(x[[2]])} in {x[[1]]}"
          ))
        }
      }
    )

    rm(throw_away)

  }

  # `digest()` produces an MD5 hash of the type and years of data requested, so
  # that repeated calls to this function with the same arguments results in data
  # being retrieved from the cache, while calls with different arguments results
  # in fresh data being downloaded
  hash <- digest::digest(c(type, years, cities))
  cache_file <- tempfile(
    pattern = paste0("crimedata_", hash, "_"),
    fileext = ".Rds"
  )
  cache_files <- dir(tempdir(), pattern = hash, full.names = TRUE)

  # Delete cached data if cache = FALSE
  if (cache == FALSE & length(cache_files) > 0) {

    lapply(cache_files, file.remove)
    if (quiet == FALSE)
      rlang::inform("Deleting cached data and re-downloading from server.")

  }

  # Check if requested data are available in cache
  if (cache == TRUE & length(cache_files) > 0) {

    if (quiet == FALSE) {
      rlang::inform(c(
        "Loading cached data from previous request in this session.",
        "i" = stringr::str_glue(
          "The data is updated only once per year, so this is almost ",
          "certainly safe."
        ),
        "i" = "To download data again, use `cache = FALSE`."
      ))
    }

    crime_data <- readRDS(cache_files[1])

  } else {

    # Create temporary directory
    temp_dir <- stringr::str_glue("{tempdir()}/crime_data/")
    if (!dir.exists(temp_dir)) dir.create(temp_dir)

    # Download files
    osfr::osf_download(
      urls,
      path = temp_dir,
      conflicts = "overwrite",
      progress = !quiet
    )

    # Load data
    crime_data <- purrr::map_dfr(
      dir(
        path = temp_dir,
        pattern = "^crime_open_database(.+?).Rds$",
        full.names = TRUE
      ),
      readRDS
    )

    # Sort data
    crime_data <- crime_data[order(crime_data$uid), ]

    # Store data in cache
    saveRDS(crime_data, cache_file)

  }

  # Convert to SF format if necessary
  if (output == "sf") {

    crime_data <- sf::st_as_sf(
      crime_data,
      coords = c("longitude", "latitude"),
      crs = 4326,
      remove = FALSE
    )

  }

  # Change type of some variables
  crime_data <- dplyr::mutate_at(
    crime_data,
    dplyr::vars(dplyr::one_of(c(
      "city_name", "offense_code", "offense_type", "offense_group",
      "offense_against"
    ))),
    as.factor
  )
  crime_data <- dplyr::mutate_at(
    crime_data,
    dplyr::vars("date_single"),
    as.POSIXct, format = "%Y-%m-%d %H:%M"
  )
  if (
    "location_type" %in% names(crime_data) |
    "location_category" %in% names(crime_data)
  ) {
    crime_data <- dplyr::mutate_at(
      crime_data,
      dplyr::vars(dplyr::one_of(c("location_type", "location_category"))),
      as.factor
    )
  }
  if ("date_start" %in% names(crime_data) | "date_end" %in% names(crime_data)) {
    crime_data <- dplyr::mutate_at(
      crime_data,
      dplyr::vars(dplyr::one_of(c("date_start", "date_end"))),
      as.POSIXct, format = "%Y-%m-%d %H:%M"
    )
  }

  # return data
  crime_data

}
