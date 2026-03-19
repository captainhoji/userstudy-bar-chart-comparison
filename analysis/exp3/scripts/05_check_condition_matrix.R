suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
raw_file <- file.path(project_root, "data_raw", "Trial_linechart.csv")
table_dir <- file.path(project_root, "output", "tables")

dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(raw_file)) {
  stop("Missing raw file: ", raw_file)
}

raw_trials <- readr::read_csv(raw_file, show_col_types = FALSE)

# The design should be 2 x 2 x 2 x 2 = 16 conditions across 32 trials.
# Some files can contain setup rows where comparison_frame is missing or "NULL",
# so exclude those by default from the condition-balance check.
analysis_trials <- raw_trials %>%
  mutate(
    legend = factor(legend, levels = c("ordered", "shuffled")),
    statement_type = factor(statement_type, levels = c("main_effect", "interaction")),
    statement_truth = factor(statement_truth, levels = c(0, 1), labels = c("false", "true")),
    comparison_frame = na_if(comparison_frame, "NULL"),
    comparison_frame = factor(comparison_frame, levels = c("more", "less"))
  ) %>%
  filter(!is.na(comparison_frame))

condition_counts_long <- analysis_trials %>%
  count(legend, statement_type, statement_truth, comparison_frame, name = "n_trials") %>%
  tidyr::complete(
    legend,
    statement_type,
    statement_truth,
    comparison_frame,
    fill = list(n_trials = 0)
  ) %>%
  arrange(statement_type, statement_truth, legend, comparison_frame)

# Put legend x comparison_frame into columns so the table reads like a matrix.
condition_counts_matrix <- condition_counts_long %>%
  mutate(column_name = paste(legend, comparison_frame, sep = " | ")) %>%
  select(statement_type, statement_truth, column_name, n_trials) %>%
  pivot_wider(
    names_from = column_name,
    values_from = n_trials
  ) %>%
  arrange(statement_type, statement_truth)

readr::write_csv(
  condition_counts_long,
  file.path(table_dir, "condition_counts_legend_statement_truth_frame_long.csv")
)
readr::write_csv(
  condition_counts_matrix,
  file.path(table_dir, "condition_counts_legend_statement_truth_frame_matrix.csv")
)

message("Rows in raw file: ", nrow(raw_trials))
message("Rows used for condition matrix: ", nrow(analysis_trials))
message("Condition-count matrix:")
print(condition_counts_matrix, n = Inf)

message(
  "Matrix written to: ",
  file.path(table_dir, "condition_counts_legend_statement_truth_frame_matrix.csv")
)
