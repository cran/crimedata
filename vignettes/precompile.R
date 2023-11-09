# Pre-compiled vignettes to ensure that any API issues do not stop package being
# built on CRAN
knitr::knit("README.Rmd.orig", "README.Rmd")
