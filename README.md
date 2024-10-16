This is a pipileine for determining the most genetically similar population group in gnomAD to samples that have been sequenced using targeted next generation sequencing techniques.

The pipeline takes a newline separated list of GRCh37 aligned bam file paths as an input and outputs pricipal component values and random forest derived probabilities for a match to each of the gnomAD population groups for each supplied sample.

This can be used for determining optimum reference/control populations for genetic analyses. 

It has the following dependencies:

- R (v4.0.0+) https://www.r-project.org/
- samtools (v1.0.0+) https://github.com/samtools/samtools
- GNU Parallel https://www.gnu.org/software/parallel/
- lrzip (https://github.com/ckolivas/lrzip)
  
It also reduires the following R package:
- randomForest https://cran.r-project.org/web/packages/randomForest/index.html

The pipeline is run as follows:
```
./run_pipeline.sh -i <input_file_list> -o <output_prefix> -t <threads>
```

The supplied flags are:
  -  -i  Input file containing newline separated list of target bam file paths (required)
  -  -o  Output file prefix (required)
  -  -t  Number of threads for parallel commands (default: 8)
  -  -h  Show help message

When running for the first time, the LASER (http://csg.sph.umich.edu/chaolong/LASER/) dependency will automatically downloaded alongside the GRCh37 reference files. The reference aim genotype file will also be decompressed.
These steps will only occur once after a fresh install and may take some time to complete.
