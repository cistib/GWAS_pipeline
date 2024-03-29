suppressPackageStartupMessages({
  library(tidyverse)
  library(qqman)
  library(glue)
  library(argparse)
  library(logging)
})

#TODO: Split this script into functions and a main function that call the previous.

setwd(system("git rev-parse --show-toplevel", intern = TRUE))

parser <- ArgumentParser()
parser$add_argument("--output_folder", default="output/coma")
parser$add_argument("--gwas_folder", nargs="+")
parser$add_argument("--gwas_pattern", default="GWAS__{phenotype}", help="File pattern including the \"{phenotype}\" field, *without extensions*.")
parser$add_argument("--phenotypes", nargs="+", default=sapply(0:7, function(x) paste0("z00", x)) )

parser$add_argument("--title", default=FALSE, action="store_true")
parser$add_argument("--cache_rds", action="store_true", default=FALSE)
parser$add_argument("--overwrite_rds", action="store_true", default=FALSE)
parser$add_argument("--qqplot_pooled", action="store_true", default=FALSE)
parser$add_argument("--color_odd_chr", default="mediumblue")
parser$add_argument("--color_even_chr", default="lightblue")
args <- parser$parse_args()


# TODO: put every file pattern into a configuration file
output_dir <- file.path(args$output_folder, "{args$gwas_folder}")
output_dir <- "{args$gwas_folder}"
# text files
gwas_fp <- file.path(output_dir, paste0(args$gwas_pattern, ".tsv"))
gwas_fp_rds <- file.path(output_dir, paste0(args$gwas_pattern, ".rds"))
gwas_summary_fp <- file.path(output_dir, "summaries", paste0(args$gwas_pattern, "__regionwise_summary.tsv"))

# print(gwas_fp)
# print(gwas_fp_rds)
# print(gwas_summary_fp)

# figures
figs_dir <- file.path(output_dir, "figures")
manhattan_fp <- file.path(figs_dir, paste0(args$gwas_pattern, "__manhattan.png"))
qqplot_fp <- file.path(figs_dir, paste0(args$gwas_pattern, "__QQ-plot.png"))
qqplot_all_fp <- file.path(figs_dir, "GWAS__all__QQ-plot.png")

color1 <- args$color_odd_chr
color2 <- args$color_even_chr

# color1 <- "hotpink4"
# color2 <- "palevioletred2"

# params_df <- read.csv("~/data/coma/run_parameters.csv", header=TRUE) %>% filter(run_id %in% run_ids)

# Process LD-independent genomic regions
load_ld_indep_regions <- function(ld_indep_regions_file="data/ld_indep_regions/fourier_ls-all_EUR_hg19.bed") {
  regions <- read.delim(ld_indep_regions_file, stringsAsFactors = F)
  regions <- regions %>% group_by(chr) %>% mutate(id = paste0(row_number()))
  regions$chr <-  sub("\\s+$", "", regions$chr)
  regions <- regions %>% mutate(id=paste(chr, id, sep = "_")) %>% ungroup()  
  regions
}

regions <- load_ld_indep_regions()
gwas_files <- character()

for (run_id in args$gwas_folder) {
  
  # TOFIX: run_id is not what I want here.
  logging::loginfo("Processing run with ID {run_id}" %>% glue)
 
  if ( !file.exists(glue::glue(figs_dir))) { 
    dir.create(glue::glue(figs_dir))
  }
  pvals <- vector(length = 0)
  
  # gwas_figs_dir <- file.path(run_id, "figs")
  # if (!dir.exists(gwas_figs_dir))
  #   dir.create(gwas_figs_dir)
  rds_log_flag <- TRUE
  
  for (phenotype in args$phenotypes) {
    
    if (!file.exists(glue(gwas_fp)) || file.info(glue(gwas_fp))$size == 0) {
      # print(glue(gwas_fp))
      next
    }
    
    gwas_files <- c(gwas_files, glue(gwas_fp))
    
    gwas_f <- glue(gwas_fp)
    gwas_f_rds <- glue(gwas_fp_rds)
    
    if (file.exists(gwas_f_rds) && !args$overwrite_rds) {
        if (rds_log_flag){
          logging::logwarn("Found a previously cached RDS files (e.g. {gwas_f_rds}). If you want a new file please run this script again with the --overwrite_rds flag" %>% glue)
          rds_log_flag <- FALSE
        }
        gwas_df <- readRDS(gwas_f_rds)
    } else {
        logging::loginfo("Reading the GWAS file in text format: {gwas_f}." %>% glue)
        gwas_df <- read_tsv(gwas_f, col_names = TRUE)
        if (args$cache_rds) {
          logging::loginfo(glue("Caching GWAS in RDS format."))
          saveRDS(gwas_df, glue(gwas_fp_rds))
        }
    }
    
    logging::loginfo("Processing {phenotype}..." %>% glue)
    
    gwas_df <- gwas_df %>% filter(!is.na(P) & P != 0)
    pvals <- c(pvals, gwas_df$P)

    plot_title <- ifelse(args$title, yes = "{run_id} - {phenotype}" %>% glue, no = "")
    
    # MANHATTAN PLOT
    png(glue(manhattan_fp), res=100, width = 3000, height = 1000)
    # pp <- qqman::manhattan(gwas_df, main=plot_title, cex = 1.5, cex.lab = 2, cex.axis = 2, suggestiveline = F, col = c(color1, color2), ylim=c(0,20))
    pp <- qqman::manhattan(gwas_df, main=plot_title, cex = 1.5, cex.lab = 2, cex.axis = 2, suggestiveline = F, col = c(color1, color2))
    # print(pp)
    dev.off()
    
    # Q-Q PLOT
    png(glue(qqplot_fp), res=100, width = 1000, height = 1000)
    pp <- qqman::qq(gwas_df$P, main=plot_title, cex.axis=2, col = "blue4")
    # print(pp)
    dev.off()
    
    gwas_list <- list()
    
    # Produce region-wise summary (best p-value per region)
    for (chr_number in 1:22) {
      reduced_regions <- regions %>% filter(chr==paste0("chr", chr_number))
      reduced_gwas <- gwas_df %>% filter(CHR==chr_number)
      reduced_gwas <- reduced_gwas %>% mutate(region=cut(BP, breaks=reduced_regions$start, labels=head(reduced_regions$id, -1)))
      gwas_list <- c(gwas_list, list(reduced_gwas))
    }
    
    best_p_per_region <- bind_rows(gwas_list) %>% filter(!is.na(region)) %>% group_by(region) %>% slice(which.min(P)) %>% ungroup()
    summary_file <- glue(gwas_summary_fp)
    dir.create(dirname(summary_file))
    write.csv(best_p_per_region, file = glue(gwas_summary_fp), sep = "\t", quote = FALSE, row.names = FALSE)
  }
  
  if (length(pvals) == 0)
    next
  
  # POOLED PHENOTYPES' Q-Q PLOT
  logging::loginfo("Gathering all the associations ({length(pvals)}) into a single QQ-plot..." %>% glue)
  qqplot_all_f <- glue(qqplot_all_fp)
  png(qqplot_all_f, res=100, width = 800, height = 800)
  pp <- qqman::qq(pvals, main=glue("{run_id}"), col = "blue4")
  # print(pp)
  dev.off()
  
}
