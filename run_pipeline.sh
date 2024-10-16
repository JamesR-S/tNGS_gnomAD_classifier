#!/bin/bash

# Function to display usage/help
usage() {
    echo "Usage: $0 -i <input_file_list> -o <output_prefix> -t <threads>"
    echo "    -i  Input file containing newline separated list of target bam file paths (required)"
    echo "    -o  Output file prefix (required)"
    echo "    -t  Number of threads for parallel commands (default: 8)"
    echo "    -h  Show this help message"
    exit 1
}

# Default values
THREADS=8

# Parse command-line arguments
while getopts "i:o:t:h" opt; do
    case ${opt} in
        i ) INPUT_FILE_LIST=$OPTARG ;;
        o ) OUTPUT_PREFIX=$OPTARG ;;
        t ) THREADS=$OPTARG ;;
        h ) usage ;;
        * ) usage ;;
    esac
done

# Ensure required arguments are provided
if [ -z "$INPUT_FILE_LIST" ] || [ -z "$OUTPUT_PREFIX" ]; then
    usage
fi

# Run initial check for dependencies
SCRIPT_DIR=$(dirname $(readlink -f "$0"))
export SCRIPT_DIR
$SCRIPT_DIR/bin/check_dependencies.sh $SCRIPT_DIR

if [ $? -ne 0 ]; then
    echo "Dependency check failed. Exiting the script."
    exit 1
fi

# Create necessary directories
mkdir -p temp_files/pileup_files

echo "Step 1: Making Pileup Files"

parallel -a "$INPUT_FILE_LIST" -j "$THREADS" --joblog make_pileup_log \
    "samtools mpileup -q 30 -Q 20 -f ${SCRIPT_DIR}/resources/reference/Homo_sapiens.GRCh37.dna.primary_assembly.fa -l ${SCRIPT_DIR}/resources/reference/Reference_AIMS_800k.bed {} > temp_files/pileup_files/{/.}.pileup"

echo "Pileup Done"
echo "Step 2: Creating .seq File from Pileup Files"

# Split the file names into batches, creating temporary files for each batch
find temp_files/pileup_files -type f | split -l 1000 - temp_files/temp_batch_

# Process each batch file in parallel
parallel -j"$THREADS" 'batch=$(cat {}); python2 ${SCRIPT_DIR}/bin/LASER-2.04/pileup2seq/pileup2seq.py -m ${SCRIPT_DIR}/resources/reference/Reference_AIMS_800k.site -o "{.}_800k" $batch; rm {}' ::: temp_files/temp_batch_*

echo ".seq Files Created"
echo "Step 3: Running LASER on Each .seq File in Parallel"

# Use parallel to run laser on each .seq file in parallel.
find temp_files/ -name "*.seq" | parallel "${SCRIPT_DIR}/bin/LASER-2.04/laser -nt 8 -s {} -g ${SCRIPT_DIR}/resources/reference/Reference_AIMS_800k.geno -c ${SCRIPT_DIR}/resources/reference/Reference_AIMS_800k.RefPC.coord -o {.} -k 10"

echo ".coord Files Created"
echo "Step 4: Concatenating .coord files into single output"

# Concatenate .coord files
header_file=$(find temp_files -name "*.coord" | head -n 1)

head -n 1 "$header_file" > "${OUTPUT_PREFIX}.coord"
tail -q -n +2 $(find temp_files -name "*.coord") >> "${OUTPUT_PREFIX}.coord"

echo ".coord Files Concatenated"
echo "Step 5: Running Classification Model"

Rscript ${SCRIPT_DIR}/bin/classification.r "${OUTPUT_PREFIX}.coord" 0.55 "${OUTPUT_PREFIX}.population.classification.txt"

echo "Processing Complete!"
echo "Cleaning Up Temp Files"

rm -R temp_files
