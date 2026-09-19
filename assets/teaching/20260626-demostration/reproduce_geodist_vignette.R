# Reproduces the three distance-distribution plots from the "Target-oriented
# validation" subsection of CAST vignette cast01-CAST-intro, adds an improved
# (colour-blind-safe) version of each, and saves all of them as PNG.
#
# Methods, data and seeds (set.seed(10)) are exactly as in the vignette.
# geodist() uses sampling = "regular" (deterministic), so each distance object
# is computed once and reused for both the vignette and the improved plot;
# this is identical to the vignette's inline plot(geodist(...)) calls.
#
# One-time install if needed (CRAN):
# install.packages(c("CAST","geodata","terra","sf","caret","tmap","ggplot2"))

library(CAST)
library(geodata)
library(terra)
library(sf)
library(caret)
library(tmap)
library(ggplot2)

## --- data (bundled with CAST) ---
data(splotdata)

## --- predictors: WorldClim + elevation, cropped to the data's bounding box ---
wc   <- worldclim_global(var = "bio", res = 10, path = tempdir())
elev <- elevation_global(res = 10, path = tempdir())

predictors_sp <- crop(c(wc, elev), st_bbox(splotdata))
names(predictors_sp) <- c(paste0("bio_", 1:19), "elev")

predictors <- c("bio_1", "bio_4", "bio_5", "bio_6",
                "bio_8", "bio_9", "bio_12", "bio_13",
                "bio_14", "bio_15", "elev")

## --- random k-fold model: provides the random CV folds via $control$indexOut ---
set.seed(10) # set seed to reproduce the model
model_default <- train(st_drop_geometry(splotdata)[, predictors],
               st_drop_geometry(splotdata)$Species_richness,
               method = "rf", tuneGrid = data.frame("mtry" = 2),
               importance = TRUE, ntree = 50,
               trControl = trainControl(method = "cv", number = 3, savePredictions = "final"))

## --- leave-country-out folds ---
set.seed(10)
indices_LLO <- CreateSpacetimeFolds(splotdata, spacevar = "Country",
                                k = 3)

## --- kNNDM folds ---
set.seed(10)
indices_knndm <- knndm(splotdata, predictors_sp, k = 3, dist_fun = "great_circle")

## --- the three geodist objects (computed once; deterministic) ---
gd_random <- geodist(splotdata, predictors_sp, CVtest = model_default$control$indexOut, dist_space = "geographical", dist_fun = "great_circle")
gd_LLO    <- geodist(splotdata, predictors_sp, CVtest = indices_LLO$indexOut,           dist_space = "geographical", dist_fun = "great_circle")
gd_knndm  <- geodist(splotdata, predictors_sp, CVtest = indices_knndm$indx_test,        dist_space = "geographical", dist_fun = "great_circle")


## ======================================================================
## Part A -- the vignette visualisation
## ======================================================================
v_random <- plot(gd_random) + scale_x_log10(labels = round)
v_LLO    <- plot(gd_LLO)    + scale_x_log10(labels = round)
v_knndm  <- plot(gd_knndm)  + scale_x_log10(labels = round)
v_random; v_LLO; v_knndm


## ======================================================================
## Part B -- improved visualisation
##   * fills kept identical to CAST (ColorBrewer Dark2, alpha = 0.5)
##   * one distinct line type per curve, so the curves stay separable
##     for colour-vision-deficient viewers and in greyscale
## ======================================================================
geodist_cols <- c(
	"sample-to-sample" = "NA",
	"prediction-to-sample" = "NA",
	"CV-distances"     = "#d85a30ff"
)
geodist_fill <- c(
	"sample-to-sample" = "#5f5e5aff",
	"prediction-to-sample" = "#0f6e56ff",
	"CV-distances"     = "NA"
)
geodist_ltys <- c(
	"sample-to-sample" = "solid",
	"prediction-to-sample" = "solid",
	"CV-distances"      = "solid"
)

plot_geodist_improved <- function(gd) {
  ggplot(as.data.frame(gd),
         aes(dist, group = what, fill = what, colour = what, linetype = what)) +
    geom_density(adjust = 1.5, alpha = 0.6, linewidth = 1.5) +
    scale_fill_manual(name   = "distance function", values = geodist_fill) +
    scale_colour_manual(name = "distance function", values = geodist_cols) +
    scale_linetype_manual(name = "distance function", values = geodist_ltys) +
    scale_x_log10(labels = round) +
    theme_bw() + ylab("Density") + xlab("geographic distances (m)") +
    theme(legend.position = "bottom")
}

i_random <- plot_geodist_improved(gd_random) + ggtitle("Random k-fold CV")
i_LLO    <- plot_geodist_improved(gd_LLO)    + ggtitle("Leave-country-out CV")
i_knndm  <- plot_geodist_improved(gd_knndm)  + ggtitle("kNNDM CV")
i_random; i_LLO; i_knndm


## ======================================================================
## Part C -- save every plot as PNG (into ./figures)
## ======================================================================
dir.create("figures", showWarnings = FALSE)

ggsave("figures/geodist_random_vignette.png", v_random, width = 8.83, height = 4.5, dpi = 300)
ggsave("figures/geodist_LLO_vignette.png",    v_LLO,    width = 8.83, height = 4.5, dpi = 300)
ggsave("figures/geodist_knndm_vignette.png",  v_knndm,  width = 8.83, height = 4.5, dpi = 300)

ggsave("figures/geodist_random_improved.png", i_random, width = 8.83, height = 4.5, dpi = 300)
ggsave("figures/geodist_LLO_improved.png",    i_LLO,    width = 8.83, height = 4.5, dpi = 300)
ggsave("figures/geodist_knndm_improved.png",  i_knndm,  width = 8.83, height = 4.5, dpi = 300)


## ======================================================================
## Part D -- overview figure (3 frames):
##   a) training samples on the South American coastline
##   b) an illustration of the predictors used
##   c) predicted species richness over all of South America
## Uses the vignette's random-CV model (model_default); the training is
## unchanged. Note: species richness is a regression target (random forest
## regression), not a classification.
##
## Extra packages for this figure:
# install.packages(c("tidyterra", "patchwork"))
## ======================================================================
library(tidyterra)
library(patchwork)

sa_ext <- terra::ext(-82, -34, -56, 13)                       # South America

## coastline / country borders for South America
sa <- terra::crop(geodata::world(resolution = 5, path = tempdir()), sa_ext)

## predictors over the whole continent (same layers as the model), masked to land
predictors_sa <- terra::crop(c(wc, elev), sa_ext)
names(predictors_sa) <- c(paste0("bio_", 1:19), "elev")
predictors_sa <- terra::mask(predictors_sa, sa)

## prediction over all of South America with the vignette's random-CV model
prediction_sa <- terra::predict(predictors_sa, model_default, na.rm = TRUE)

## -- a) training samples on the coastline --
frame_a <- ggplot() +
  geom_spatvector(data = sa, fill = "grey96", colour = "grey55", linewidth = 0.25) +
  geom_sf(data = splotdata, colour = "#D2502A", size = 0.5) +
  coord_sf(xlim = c(-82, -34), ylim = c(-56, 13), expand = FALSE) +
  labs(title = "Training samples (species richness)", x = NULL, y = NULL) +
  theme_bw() +
  theme(plot.title = element_text(hjust = 0.5))

## -- b) illustration of the predictors (4 of the 11, each scaled to 0-1) --
pick <- c("bio_1", "bio_12", "elev", "bio_15")  # temp, precip, elevation, precip seasonality
pick_lab <- c("temp", "precip", "elev", "precip_seas")
pred_show <- predictors_sa[[pick]]
rng <- terra::global(pred_show, c("min", "max"), na.rm = TRUE)
pred_show <- (pred_show - rng$min) / (rng$max - rng$min)
names(pred_show) <- pick_lab
lab_df <- data.frame(lyr = factor(pick_lab, levels = pick_lab), label = pick_lab)
frame_b <- ggplot() +
  geom_spatraster(data = pred_show) +
  facet_wrap(~lyr, ncol = 2) +
  geom_label(data = lab_df, aes(label = label), x = -35.5, y = 12,
             hjust = 1, vjust = 1, size = 3, linewidth = 0, inherit.aes = FALSE) +
  scale_fill_viridis_c(na.value = "transparent", guide = "none") +
  coord_sf(xlim = c(-82, -34), ylim = c(-56, 13), expand = FALSE) +
  labs(title = "Predictors (4 of 11)", x = NULL, y = NULL) +
  theme_bw() +
  theme(strip.text = element_blank(), strip.background = element_blank(), plot.title = element_text(hjust = 0.5))

## -- c) predicted species richness over South America --
frame_c <- ggplot() +
  geom_spatraster(data = prediction_sa) +
  geom_spatvector(data = sa, fill = NA, colour = "grey55", linewidth = 0.2) +
  scale_fill_viridis_c(na.value = "transparent", name = "Species\nrichness") +
  coord_sf(xlim = c(-82, -34), ylim = c(-56, 13), expand = FALSE) +
  labs(title = "Predicted species richness", x = NULL, y = NULL) +
  theme_bw() +
  theme(plot.title = element_text(hjust = 0.5))

## combine: left | middle | right
overview <- frame_a | frame_b | frame_c
overview

dir.create("figures", showWarnings = FALSE)
ggsave("figures/overview_three_frames.png", overview, width = 13, height = 5, dpi = 300)
