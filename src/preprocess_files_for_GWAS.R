# install.packages("argparse")
library(argparse)

setwd(system("git rev-parse --show-toplevel", intern = TRUE))

source("utils/preprocessing_for_gwas.R")

# This script loads a phenotype file, adjusts for covariates, 
# inverse-normalize the values and excludes samples

get_args <- function() {
  
  parser <- ArgumentParser()
  
  # Phenotype file
  parser$add_argument("-p", "--phenotype_file", required=TRUE)
  parser$add_argument("--phenotypes", default=NULL, nargs="+")
  parser$add_argument("--columns_to_exclude", default=NULL, nargs="+")
  
  # Samples
  parser$add_argument("--samples_to_include", nargs="+", default="data/ids_list/cmr_british_ids.txt")
  parser$add_argument("--samples_to_exclude", nargs="+", default=NULL)
  
  # Covariates
  parser$add_argument("-c", "--covariates_config_yaml", required=TRUE)
  # parser$add_argument("--impute_with_mean_for", nargs="+", default=c("X4079", "X4080"))
  
  # Output
  parser$add_argument("-o", "--output_file", required=TRUE)
  parser$add_argument("--gwas_software", default="plink", help="Which software to format the phenotype file for. Currently only Plink and BGENIE are supported.")
 
  args <- parser$parse_args()
  args
  
}


main <- function(args) {
  generate_adj_pheno(
    args$phenotype_file, args$phenotypes, args$columns_to_exclude,
    args$samples_to_include, args$samples_to_exclude,
    args$covariates_config_yaml,
    args$gwas_software,
    args$output_file
  )
}

args <- get_args()
main(args)