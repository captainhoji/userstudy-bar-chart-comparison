suppressPackageStartupMessages(library(lme4))

format_p_for_latex <- function(p_value, digits = 3) {
  # Format p-values the way they are usually shown in manuscript tables.
  if (is.na(p_value)) {
    return("")
  }

  if (p_value < 0.001) {
    return("$<.001$")
  }

  formatted <- sprintf(paste0("%.", digits, "f"), p_value)
  formatted <- sub("^0", "", formatted)
  paste0("$", formatted, "$")
}

format_number_for_latex <- function(x, digits = 3) {
  # Keep numeric formatting consistent across all columns in the LaTeX table.
  if (is.na(x)) {
    return("")
  }

  sprintf(paste0("%.", digits, "f"), x)
}

default_term_labels <- function(term_names) {
  # Give common model terms readable labels while leaving interaction syntax intact.
  cleaned <- gsub("\\(Intercept\\)", "Intercept", term_names)
  cleaned <- gsub("_c", "", cleaned, fixed = TRUE)
  cleaned <- gsub("_", " ", cleaned, fixed = TRUE)
  cleaned
}

extract_lmer_coefficient_table <- function(model) {
  # lmer models only report df/p in a convenient way when lmerTest methods are available.
  coef_table <- as.data.frame(summary(model)$coefficients, stringsAsFactors = FALSE)

  if (!all(c("df", "Pr(>|t|)") %in% names(coef_table))) {
    if (!requireNamespace("lmerTest", quietly = TRUE)) {
      stop(
        "This lmer summary does not contain df/p columns. Install or load `lmerTest`, ",
        "or fit the model with lmerTest so the LaTeX helper can extract df and p."
      )
    }

    coef_table <- as.data.frame(
      summary(lmerTest::as_lmerModLmerTest(model))$coefficients,
      stringsAsFactors = FALSE
    )
  }

  coef_table
}

extract_mixed_model_table <- function(model) {
  # Detect whether the model is logistic (glmer) or linear (lmer) and pull the
  # matching fixed-effect summary columns.
  if (inherits(model, "glmerMod")) {
    coef_table <- as.data.frame(summary(model)$coefficients, stringsAsFactors = FALSE)

    required_cols <- c("Estimate", "Std. Error", "z value", "Pr(>|z|)")
    if (!all(required_cols %in% names(coef_table))) {
      stop("The glmer summary does not contain the expected coefficient columns.")
    }

    list(
      model_type = "glmer",
      coef_table = coef_table,
      align = "llccc",
      header = "        \\textbf{Predictor} & \\textbf{$\\beta$} & \\textbf{SE} & \\textbf{$z$} & \\textbf{$p$}  \\\\"
    )
  } else if (inherits(model, "lmerMod")) {
    coef_table <- extract_lmer_coefficient_table(model)

    required_cols <- c("Estimate", "Std. Error", "df", "t value", "Pr(>|t|)")
    if (!all(required_cols %in% names(coef_table))) {
      stop("The lmer summary does not contain the expected coefficient columns.")
    }

    list(
      model_type = "lmer",
      coef_table = coef_table,
      align = "llcccc",
      header = "        \\textbf{Predictor} & \\textbf{$\\beta$} & \\textbf{df} & \\textbf{SE} & \\textbf{$t$} & \\textbf{$p$}  \\\\"
    )
  } else {
    stop("`model` must be either an `lmerMod` or `glmerMod` object.")
  }
}

mixed_model_summary_to_latex <- function(
    model,
    caption,
    label,
    predictor_labels = NULL,
    digits = 3,
    size_command = "\\small",
    file = NULL
) {
  # Turn an lmer/glmer fixed-effect summary into a standalone LaTeX table block.
  extracted <- extract_mixed_model_table(model)
  coef_table <- extracted$coef_table
  coef_table$term <- rownames(coef_table)
  rownames(coef_table) <- NULL

  term_labels <- default_term_labels(coef_table$term)
  if (!is.null(predictor_labels)) {
    matched_idx <- match(coef_table$term, names(predictor_labels))
    has_custom_label <- !is.na(matched_idx)
    term_labels[has_custom_label] <- predictor_labels[matched_idx[has_custom_label]]
  }

  body_lines <- if (identical(extracted$model_type, "glmer")) {
    vapply(
      seq_len(nrow(coef_table)),
      function(i) {
        paste0(
          term_labels[[i]], "  & ",
          format_number_for_latex(coef_table$Estimate[[i]], digits = digits), "  &  ",
          format_number_for_latex(coef_table$`Std. Error`[[i]], digits = digits), " & ",
          format_number_for_latex(coef_table$`z value`[[i]], digits = digits), " & ",
          format_p_for_latex(coef_table$`Pr(>|z|)`[[i]], digits = digits),
          " \\\\"
        )
      },
      character(1)
    )
  } else {
    vapply(
      seq_len(nrow(coef_table)),
      function(i) {
        paste0(
          term_labels[[i]], "  & ",
          format_number_for_latex(coef_table$Estimate[[i]], digits = digits), "  &  ",
          format_number_for_latex(coef_table$df[[i]], digits = digits), " & ",
          format_number_for_latex(coef_table$`Std. Error`[[i]], digits = digits), " & ",
          format_number_for_latex(coef_table$`t value`[[i]], digits = digits), " & ",
          format_p_for_latex(coef_table$`Pr(>|t|)`[[i]], digits = digits),
          " \\\\"
        )
      },
      character(1)
    )
  }

  latex_lines <- c(
    "\\begin{table}[H]",
    size_command,
    "   \\centering",
    paste0("   \\caption{", caption, "}"),
    paste0("   \\begin{tabular}{", extracted$align, "}"),
    "   \\hline",
    extracted$header,
    "            \\hline",
    paste0("        ", body_lines),
    "\\hline",
    "   \\end{tabular}",
    "",
    paste0("   \\label{", label, "}"),
    "",
    "\\end{table}"
  )

  latex_output <- paste(latex_lines, collapse = "\n")

  if (!is.null(file)) {
    # Save the rendered LaTeX so it can be dropped directly into a manuscript.
    writeLines(latex_output, con = file)
  }

  latex_output
}

glmer_summary_to_latex <- function(...) {
  # Backward-compatible wrapper for logistic mixed models.
  mixed_model_summary_to_latex(...)
}

lmer_summary_to_latex <- function(...) {
  # Convenience wrapper for linear mixed models.
  mixed_model_summary_to_latex(...)
}

# Example:
# source("scripts/modelSummaryToLatex.R")
cat(
  mixed_model_summary_to_latex(
    model = m_rt_pruned_dual_low,
    caption = "Experiment 1 linear mixed effects model results for RT on pruned data, within dual-task, low-more mapping.",
    label = "tab:exp1_rt_pruned_dual_low",
    predictor_labels = c(
      "lightness_mapping_c" = "Lightness",
      "attention_c" = "Task",
      "label_condition_c" = "Height",
      "lightness_mapping_c:attention_c" = "Lightness:Task",
      "label_condition_c:attention_c" = "Height:Task",
      "label_condition_c:lightness_mapping_c" = "Height:Lightness",
      "label_condition_c:lightness_mapping_c:attention_c" = "Height:Lightness:Task",
      "lightness_mapping_c:block_c" = "Lightness:Block",
      "attention_c:block_c" = "Task:Block",
      "label_condition_c:block_c" = "Height:Block",
      "lightness_mapping_c:attention_c:block_c" = "Lightness:Task:Block",
      "label_condition_c:attention_c:block_c" = "Height:Task:Block",
      "label_condition_c:lightness_mapping_c:block_c" = "Height:Lightness:Block",
      "label_condition_c:lightness_mapping_c:attention_c:block_c" = "Height:Lightness:Task:Block"
    )
  )
)
