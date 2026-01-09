library(dtwSat)
library(randomForest)
library(stringr)
library(dplyr)
library(tibble)
library(tidyr)
library(progress)
library(sits)
library(sitsdata)

# Read training samples
samples <- st_read(system.file("mato_grosso_brazil/samples.gpkg", package = "dtwSat"), quiet = TRUE)

# Satellite image time sereis files
tif_files <- dir(system.file("mato_grosso_brazil", package = "dtwSat"), pattern = "\\.tif$", full.names = TRUE)

# The acquisition date is in the file name are not the true acquisition date
# of each pixel. MOD13Q1 is a 16-day composite product, so the acquisition date
# is the first day of the 16-day period
acquisition_date <- as.Date(regmatches(tif_files, regexpr("[0-9]{8}", tif_files)), format = "%Y%m%d")

# Read the data as a stars object setting the time/date for each observation
# using along. This will prodcue a 4D array (data-cube) which will then be converted
# to a 3D array by spliting the 'band' dimension
dc <- read_stars(tif_files,
                 proxy = FALSE,
                 along = list(time = acquisition_date),
                 RasterIO = list(bands = 1:6))

dc <- st_set_dimensions(dc, 3, c("EVI", "NDVI", "RED", "BLUE", "NIR", "MIR"))
dc <- split(dc, c("band"))

# # TWDTW function
# fun_twdtw <- function(dc, samples){
#       m <- twdtw_knn1(x = dc,
#                   y = samples,
#                   cycle_length = 'year',
#                   time_scale = 'day',
#                   time_weight = c(steepness = 0.1, midpoint = 50),
#                   formula = band ~ s(time))
#       predict(dc, model = m)
# }

# system.time(twdtw_lu <- fun_twdtw(dc, samples))

# # RF function
# fun_rf <- function(dc, samples){
#     rf_dc <- split(dc)
#     names(rf_dc) <- str_replace_all(names(rf_dc), "\\.", "")
#     names(rf_dc) <- str_remove_all(names(rf_dc), "-")
#     rf_data <- st_extract(rf_dc, samples)
#     rf_data$label <- as.factor(samples$label) # no need for join, since the order did not change
#     rf_data <- as.data.frame(rf_data)
#     rf_data$geom <- NULL
#     rf <- randomForest(label ~ ., rf_data)
#     predict(rf_dc, rf)
# }
# system.time(rf_lu  <- fun_rf(dc, samples))

# # Visualise land use classification
# ggplot() +
#   geom_stars(data = rf_lu) +
#   theme_minimal()

# ggplot() +
#   geom_stars(data = twdtw_lu) +
#   theme_minimal()



# ##############################################################################
# # What if there was a single samples per class?
# # TWDTW function
prepare_time_series <- function(x) {

  # Remove the 'geom' column if it exists
  x$geom <- NULL
  x$x <- NULL
  x$y <- NULL
  var_names <- names(x)
  var_names <- var_names[!var_names %in% 'label']

  # Extract date and band information from the column names
  date_band <- do.call(rbind, lapply(var_names, function(name) {

    # Replace any hyphen with periods for consistent processing
    name <- gsub("-", "\\.", name)

    # Extract date and band info based on different name patterns
    if (grepl("^.+\\.\\d{4}\\.\\d{2}\\.\\d{2}$", name)) {
      date_str <- gsub("^.*?(\\d{4}\\.\\d{2}\\.\\d{2})$", "\\1", name)
      band_str <- gsub("^(.+)\\.\\d{4}\\.\\d{2}\\.\\d{2}$", "\\1", name)
    }
    else if (grepl("^X\\d{4}\\.\\d{2}\\.\\d{2}\\..+$", name)) {
      date_str <- gsub("^X(\\d{4}\\.\\d{2}\\.\\d{2})\\..+$", "\\1", name)
      band_str <- gsub("^X\\d{4}\\.\\d{2}\\.\\d{2}\\.(.+)$", "\\1", name)
    } 
    else if (grepl("^\\d{4}\\.\\d{2}\\.\\d{2}\\..+$", name)) {
      date_str <- gsub("^(\\d{4}\\.\\d{2}\\.\\d{2})\\..+$", "\\1", name)
      band_str <- gsub("^\\d{4}\\.\\d{2}\\.\\d{2}\\.(.+)$", "\\1", name)
    } 
    else {
      stop(paste("Unrecognized format in:", name))
    }

    # Convert the date string to Date format
    date <- to_date_time(gsub("\\.", "-", date_str))

    return(data.frame(time = date, band = band_str))
  }))

  # Construct tiem sereis
  ns <- nrow(x)
  x$ts_id <- 1:ns
  if (!'label' %in% names(x)) {
    x$label <- NA
  }
  x <- pivot_longer(x, !c('ts_id', 'label'), names_to = 'band_date', values_to = 'value')
  x$band <- rep(date_band$band, ns)
  x$time <- rep(date_band$time, ns)
  x$band_date <- NULL
  result_df <- pivot_wider(x, id_cols = c('ts_id', 'label', 'time'), names_from = 'band', values_from = 'value')
  result_df <- nest(result_df, .by = c('ts_id', 'label'), .key = 'observations')

  return(result_df)

}

fun_twdtw <- function(x, y){

  twdtw_args <- list(cycle_length = 'year',
                     time_scale = 'day',
                     time_weight = c(steepness = 0.1, midpoint = 50),
                     formula = band ~ s(time))

  # Compute TWDTW distances
  distances <- sapply(y$observations, function(pattern){
    sapply(x$observations, function(ts) {
      do.call(proxy::dist, c(list(x = as.data.frame(ts), y = as.data.frame(pattern), method = 'twdtw'), twdtw_args))
    })
  })

  # Find the nearest neighbor for each observation in newdata
  nearest_neighbor <- apply(distances, 1, which.min)

  as.character(y$label[nearest_neighbor])

}

fun_rf <- function(x, y){

  rf <- randomForest(label ~ ., data = y)
  pred <- predict(rf, x)

  as.character(pred)

}

twdtw_dc <- split(dc, 'time')
rf_dc <- twdtw_dc
names(rf_dc) <- str_replace_all(names(rf_dc), "\\.", "")
names(rf_dc) <- str_remove_all(names(rf_dc), "-")
samples$id <- 1:nrow(samples)
n <- 1000
samples_r <- samples |>
  group_by(label) |>
  sample_n(size = n, replace = TRUE) |>
  ungroup() |>
  mutate(s_id = rep(1:n, length(unique(samples$label))))
pb <- progress_bar$new(total = n)
class_results <- lapply(1:n, function(i){
  pb$tick()
  # get one sample per class
  ns <- filter(samples, id %in% samples_r$id[samples_r$s_id == i])
  new_data <- filter(samples, !id %in% samples_r$id[samples_r$s_id == i])
  # train and classify
  rf_train <- st_extract(rf_dc, ns)
  rf_data <- st_extract(rf_dc, new_data)
  rf_train$label <- as.factor(ns$label)
  rf_data$label <- as.factor(new_data$label)
  rf_train$geom <- NULL
  rf_data$geom <- NULL
  twdtw_train <- as.data.frame(st_extract(twdtw_dc, ns))
  twdtw_data <- as.data.frame(st_extract(twdtw_dc, new_data))
  twdtw_train$label <- as.factor(ns$label)
  twdtw_data$label <- as.factor(new_data$label)
  twdtw_train$geom <- NULL
  twdtw_data$geom <- NULL
  twdtw_train <- prepare_time_series(twdtw_train)
  twdtw_data <- prepare_time_series(twdtw_data)
  # get results
  res <- tibble(
    twdtw_pred = fun_twdtw(twdtw_data, twdtw_train),
    rf_pred = fun_rf(rf_data, rf_train),
    ref = as.character(as.factor(new_data$label)))
  # space and time distance
  #res$dist_to_correct_meters <- sapply(1:nrow(new_data), function(i) st_distance(new_data[i,], ns[ns$label==new_data[i,]$label, ]))
  #res$dist_to_correct_years <- sapply(1:nrow(new_data), function(i) abs(as.numeric(format(new_data[i,]$start_date, "%Y"))) - as.numeric(format(ns[ns$label==res$rf_pred[i], ]$start_date, "%Y")))

  res

})

saveRDS(class_results, "./class_results_dtwsat.rdf")
#class_results <- readRDS("./assets/talks/2023-10-06-oem/class_results_dtwsat.rdf")

oa <- do.call('rbind', lapply(class_results, function(x){
  twdtw_err <- table("pred" = x$twdtw_pred, "ref" = x$ref)
  rf_err <- table("pred" = x$rf_pred, "ref" = x$ref)
  tibble(
    twdtw_oa = sum(diag(twdtw_err)) / sum(twdtw_err) * 100,
    rf_oa = sum(diag(rf_err)) / sum(rf_err) * 100)
}))

df <- pivot_longer(oa, cols = c(twdtw_oa, rf_oa))

df.summary <- df |>
  group_by(name) |>
  summarise(
    sd = sd(value, na.rm = TRUE),
    value = mean(value)
  )

# ggplot(df, aes(name, value)) +
#   scale_y_continuous(limits = c(0, 100)) +
#   geom_jitter(aes(name, value), position = position_jitter(0.2), color = "darkgray", data = df) +
#   geom_pointrange(aes(ymin = value-sd, ymax = value+sd), data = df.summary)

# ggplot(df, aes(x=value, fill=name)) +
#   geom_density()


# ##########################################
# # sits samples
# fun_twdtw <- function(x, y){

#   twdtw_args <- list(cycle_length = 'year',
#                      time_scale = 'day',
#                      time_weight = c(steepness = 0.1, midpoint = 50),
#                      formula = band ~ s(time))

#   # Compute TWDTW distances
#   distances <- sapply(y$observations, function(pattern){
#     sapply(x$observations, function(ts) {
#       do.call(proxy::dist, c(list(x = as.data.frame(ts), y = as.data.frame(pattern), method = 'twdtw'), twdtw_args))
#     })
#   })

#   # Find the nearest neighbor for each observation in newdata
#   nearest_neighbor <- apply(distances, 1, which.min)

#   as.character(y$label[nearest_neighbor])

# }

# fun_rf <- function(x, y){

#   rf <- randomForest(label ~ ., data = y)
#   pred <- predict(rf, x)

#   as.character(pred)

# }


# data("samples_matogrosso_mod13q1")
# table(samples_matogrosso_mod13q1$label)
# samples_modis <- select(samples_matogrosso_mod13q1, start_date, end_date, label, observations = time_series)
# samples_modis <- filter(samples_modis, !label %in% c("Cerrado","Fallow_Cotton", "Soy_Millet", "Soy_Sunflower"))
# table(samples_modis$label)
# samples_modis$observations <- lapply(samples_modis$observations, function(x) rename(x, time = Index))
# samples_modis$id <- 1:nrow(samples_modis)

# n <- 10
# pb <- progress_bar$new(total = n)
# class_results <- lapply(1:n, function(i){
#   pb$tick()
#   # get one sample per class
#   ns <- samples_modis |>
#     group_by(label) |>
#     sample_n(size = 1) |>
#     ungroup()
#   new_data <- samples_modis[-ns$id, ]
#   # train and classify
#   rf_train <- do.call('rbind', lapply(ns$observations, function(x) pivot_wider(transmute(pivot_longer(mutate(x, time = row_number()), -time), name = str_c(name, time), value))))
#   rf_data <- do.call('rbind', lapply(new_data$observations, function(x) pivot_wider(transmute(pivot_longer(mutate(x, time = row_number()), -time), name = str_c(name, time), value))))
#   rf_train$label <- as.factor(ns$label)
#   rf_data$label <- as.factor(new_data$label)
#   # get results
#   res <- tibble(
#     twdtw_pred = fun_twdtw(new_data, ns),
#     rf_pred = fun_rf(rf_data, rf_train),
#     ref = as.character(as.factor(new_data$label)))
#   # space and time distance
#   #res$dist_to_correct_meters <- sapply(1:nrow(new_data), function(i) st_distance(new_data[i,], ns[ns$label==new_data[i,]$label, ]))
#   #res$dist_to_correct_years <- sapply(1:nrow(new_data), function(i) abs(as.numeric(format(new_data[i,]$start_date, "%Y"))) - as.numeric(format(ns[ns$label==res$rf_pred[i], ]$start_date, "%Y")))

#   res

# })

#saveRDS(class_results, "./class_results.rdf")
#class_results <- readRDS("./assets/talks/2023-10-06-oem/class_results.rdf")

# oa <- do.call('rbind', lapply(class_results, function(x){
#   x <- x[!x$ref %in% c("Fallow_Cotton", "Soy_Millet", "Soy_Sunflower"),]
#   twdtw_err <- table("pred" = x$twdtw_pred, "ref" = x$ref)
#   rf_err <- table("pred" = x$rf_pred, "ref" = x$ref)
#   tibble(
#     twdtw_oa = sum(diag(twdtw_err)) / sum(twdtw_err) * 100,
#     rf_oa = sum(diag(rf_err)) / sum(rf_err) * 100)
# }))

# df <- pivot_longer(oa, cols = c(twdtw_oa, rf_oa))

# df.summary <- df |>
#   group_by(name) |>
#   summarise(
#     sd = sd(value, na.rm = TRUE),
#     value = mean(value)
#   )

# ggplot(df, aes(name, value)) +
#   scale_y_continuous(limits = c(0, 100)) +
#   geom_jitter(aes(name, value), position = position_jitter(0.2), color = "darkgray", data = df) +
#   geom_pointrange(aes(ymin = value-sd, ymax = value+sd), data = df.summary)


# ### 
# UA <- diag(accmat) / rowSums(accmat) * 100
# UA
# ##         1         2         3         4         5         6 
# ##  68.88889  94.00000  78.00000  81.63265  94.00000 100.00000

# PA <- diag(accmat) / colSums(accmat) * 100
# PA
# ##         1         2         3         4         5         6 
# ## 100.00000  87.03704  79.59184  90.90909  72.30769  98.00000
