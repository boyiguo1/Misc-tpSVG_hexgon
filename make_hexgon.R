# Load packages -----------------------------------------------------------

library(SpatialExperiment)
library(STexampleData)
library(mgcv)
library(hexSticker)


# Load & prep data ---------------------------------------------------------------

spe <- Visium_humanDLPFC()
spe <- spe[, colData(spe)$in_tissue == 1]
# spe <- logNormCounts(spe, log = FALSE)

# Calculate library size
spe$total <- counts(spe) |> colSums()



# Fit gam surface ---------------------------------------------------------
coords <- spatialCoords(spe)
colnames(coords) <- c("coord_x", "coord_y")
fit.df <- data.frame(
  coords
)

idx_MOBP <- which(rowData(spe)$gene_name %in% "MOBP")

fit.df$tmp_y <- counts(spe)[idx_MOBP,]

tp_mdl <- gam(
  formula = tmp_y~s(coord_x, coord_y, bs='tp'),
  family = poisson, data = fit.df,
  offset = log(spe$total))


tmp_pred <- predict(tp_mdl, type = "terms")
spe$margin_spatialVar <- tmp_pred[, "s(coord_x,coord_y)"] |> exp()


# Create 3D surface -----------------------------------------------------------------
steps <- 50
coord_x <- with(fit.df, seq(min(coord_x), max(coord_x), length = steps) )
coord_y <-  with(fit.df, seq(min(coord_y), max(coord_y), length = steps) )
newdat <- expand.grid(coord_x = coord_x, coord_y = coord_y)
surf_df <- matrix(predict(tp_mdl, newdat), steps, steps)


# Color pattern on the surface
x <- seq(-1.95, 1.95, length.out = 30)
y <- seq(-1.95, 1.95, length.out = 35)
z <- outer(x, y, function(a, b) a*b^2)
nrz <- nrow(z)
ncz <- ncol(z)

nbcol <- 100
Lab.palette <- colorRampPalette(
  c("red", "orange", "blue"),
  space = "Lab")
color <- Lab.palette(nbcol)

# Compute the z-value at the facet centres
zfacet <- z[-1, -1] + z[-1, -ncz] + z[-nrz, -1] + z[-nrz, -ncz]
# Recode facet z-values into color indices
facetcol <- cut(zfacet, nbcol)

# Create & save fitted surface
png("figures/tpSVG_raw.png")
persp(coord_x, coord_y, surf_df,
      col = color[facetcol], theta = 45,
      border = NA,
      box = FALSE
)
dev.off()


# Make hexgon sticker -----------------------------------------------------
imgurl <- here::here("figures/tpSVG_raw.png")
sticker(
  imgurl,
  package="tpSVG",
  h_fill = "white",
  p_size=20, p_color = "black", p_y = 0.4,
  s_x=0.9, s_y=1,
  s_width=1, s_height=1,
  filename="tpSVG_logo.png")



