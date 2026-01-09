coords_forest_crop <- c(-56.6223371884, -11.7572916629)
coords_degradation <- c(-56.6670901913, -11.9218749962)
coords_forest_grass <- c(-52.45200579316239, -12.332547846815746)

# Connect to the WTSS server at INPE Brazil
wtss_inpe <-  "http://www.esensing.dpi.inpe.br/wtss"


ndvi_forest_crop <- Rwtss::time_series(wtss_inpe, name = "MOD13Q1",
                              attributes = c("ndvi","evi"), longitude = coords_forest_crop[1], latitude  = coords_forest_crop[2],
                              start_date = "2000-03-01", end_date = "2018-12-31")

ndvi_degradation <- Rwtss::time_series(wtss_inpe, name = "MOD13Q1",
                                       attributes = c("ndvi","evi"), longitude = coords_degradation[1], latitude  = coords_degradation[2],
                                       start_date = "2000-03-01", end_date = "2018-12-31")

ndvi_forest_grass <- Rwtss::time_series(wtss_inpe, name = "MOD13Q1",
                                       attributes = c("ndvi","evi"), longitude = coords_forest_grass[1], latitude  = coords_forest_grass[2],
                                       start_date = "2000-03-01", end_date = "2018-12-31")

ndvi_forest_crop %>%
  dplyr::select(time_series) %>%
  tidyr::unnest(cols = time_series) %>%
  dplyr::rename(Time = Index, NDVI = ndvi, EVI = evi) %>%
  readr::write_csv("./../../../assets/data/time-series-crop.csv")

ndvi_degradation %>%
  dplyr::select(time_series) %>%
  tidyr::unnest(cols = time_series) %>%
  dplyr::rename(Time = Index, NDVI = ndvi, EVI = evi) %>%
  readr::write_csv("./../../../assets/data/time-series-degradation.csv")

ndvi_forest_grass %>%
  dplyr::select(time_series) %>%
  tidyr::unnest(cols = time_series) %>%
  dplyr::rename(Time = Index, NDVI = ndvi, EVI = evi) %>%
  readr::write_csv("./../../../assets/data/time-series-forest-grass.csv")
