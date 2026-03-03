library(sjPlot)
library(knitr)
library(kableExtra)

tab <- sjPlot::get_model_data(
  m1_all_blocks,
  type = "est",        # fixed effects
  transform = NULL,    # keep β (not OR)
  ci.lvl = NA          # no CI
)

tab2 <- tab |>
  mutate(
    OR = exp(estimate),
    p_display = ifelse(
      p.value < 0.001,
      paste0("<0.001", p.stars),
      paste0(sprintf("%.3f", p.value), p.stars)
    )
  ) |>
  select(term, OR, std.error, statistic, p_display)

# Rename columns
names(tab2) <- c("Predictor", "OR", "SE", "z", "p")

# Create LaTeX table
knitr::kable(
  tab2,
  format = "latex",
  booktabs = TRUE,
  digits = 3
) |>
  kableExtra::kable_styling(latex_options = c("hold_position"))
