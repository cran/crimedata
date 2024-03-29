% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/get_crime_data.R
\name{get_crime_data}
\alias{get_crime_data}
\title{Get Data from the Open Crime Database}
\usage{
get_crime_data(
  years = NULL,
  cities = NULL,
  type = "sample",
  cache = TRUE,
  quiet = !interactive(),
  output = "tbl"
)
}
\arguments{
\item{years}{A single integer or vector of integers specifying the years for
which data should be retrieved. If NULL (the default), data for the most
recent year will be returned.}

\item{cities}{A character vector of city names for which data should be
retrieved. Case insensitive. If NULL (the default), data for all available
cities will be returned.}

\item{type}{Either "sample" (the default), "core" or "extended".}

\item{cache}{Should the result be cached and then re-used if the function is
called again with the same arguments?}

\item{quiet}{Should messages and warnings relating to data availability and
processing be suppressed?}

\item{output}{Should the data be returned as a tibble by specifying "tbl"
(the default) or as a simple features (SF) object using WGS 84 by
specifying "sf"?}
}
\value{
A tibble containing data from the Open Crime Database.
}
\description{
Retrieves data from the Open Crime Database for the specified years. Latitude
and longitude are specified using the WGS 84 (EPSG:4326) co-ordinate
reference system.
}
\details{
By default this function returns a one-percent sample of the 'core' data.
This is the default to minimize accidentally requesting large files over a
network.

Setting type = "core" retrieves the core fields (e.g. the type, co-ordinates
and date/time of each offense) for each offense.
The data retrieved by setting type = "extended" includes all available fields
provided by the police department in each city. The extended data fields have
not been harmonized across cities, so will require further cleaning before
most types of analysis.

Requesting all data (more than 17 million rows) may lead to problems with
memory capacity. Consider downloading smaller quantities of data (e.g. using
type = "sample") for exploratory analysis.

Setting output = "sf" returns the data in simple features format by calling
\code{\link[sf:st_as_sf]{sf::st_as_sf(..., crs = 4326, remove = FALSE)}}

For more details see the help vignette:
\code{vignette("introduction", package = "crimedata")}
}
