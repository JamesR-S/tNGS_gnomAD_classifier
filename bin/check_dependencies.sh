#!/bin/bash

SCRIPT_DIR=$1

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: $1 is not installed or not in the system PATH."
        exit 1
    else
        echo "$1 is installed."
    fi
}

# Check if R is installed
check_command "R"

# Check if GNU parallel is installed
check_command "parallel"

# Check if samtools is installed
check_command "samtools"

# Check if required R packages are installed
Rscript -e '
required_packages <- c("randomForest")

missing_packages <- required_packages[!sapply(required_packages, require, character.only = TRUE, quietly = TRUE)]
if (length(missing_packages) > 0) {
    cat("Error: Missing required R packages:", paste(missing_packages, collapse = ", "), "\n")
    quit(status = 1)  # Exit with status 1 if any packages are missing
} else {
    cat("All required R packages are installed.\n")
    quit(status = 0)  # Exit with status 0 if all packages are present
}
'

# Check the exit status of the Rscript command
if [ $? -ne 0 ]; then
    echo "R package check failed. Halting the script."
    exit 1
fi

# Check for LASER-2.0.4 directory in bin and download if missing
BIN_DIR="$SCRIPT_DIR/bin"
LASER_DIR="$BIN_DIR/LASER-2.04"
LASER_URL="http://csg.sph.umich.edu/chaolong/LASER/LASER-2.04.tar.gz"

if [ ! -d "$LASER_DIR" ]; then
    echo "LASER-2.0.4 not found in bin directory. Downloading and installing..."
    mkdir -p "$BIN_DIR"
    wget -q "$LASER_URL" -O "$BIN_DIR/LASER-2.04.tar.gz"
    tar -xzf "$BIN_DIR/LASER-2.04.tar.gz" -C "$BIN_DIR"
    rm "$BIN_DIR/LASER-2.04.tar.gz"
    echo "LASER-2.0.4 has been installed in the bin directory."
else
    echo "LASER-2.0.4 is already installed."
fi

# Check for reference genome file and download if missing
RESOURCES_DIR="$SCRIPT_DIR/resources/reference"
REFERENCE_FILE="$RESOURCES_DIR/Homo_sapiens.GRCh37.dna.primary_assembly.fa"
REFERENCE_URL="https://ftp.ensembl.org/pub/grch37/current/fasta/homo_sapiens/dna/Homo_sapiens.GRCh37.dna.primary_assembly.fa.gz"

if [ ! -f "$REFERENCE_FILE" ]; then
    echo "Reference genome not found. Downloading..."
    mkdir -p "$RESOURCES_DIR"
    wget -q "$REFERENCE_URL" -O "$RESOURCES_DIR/Homo_sapiens.GRCh37.dna.primary_assembly.fa.gz"
    gunzip "$RESOURCES_DIR/Homo_sapiens.GRCh37.dna.primary_assembly.fa.gz"
    samtools faidx "$REFERENCE_FILE"
    echo "Reference genome has been downloaded, unzipped, and indexed."
else
    echo "Reference genome is already present."
fi

AIMS_FILE="$RESOURCES_DIR/Reference_AIMS_800k.geno"
AIMS_PARTS=("$RESOURCES_DIR/Reference_AIMS_800k.geno.lrz.part.00" "$RESOURCES_DIR/Reference_AIMS_800k.geno.lrz.part.01" "$RESOURCES_DIR/Reference_AIMS_800k.geno.lrz.part.02" "$RESOURCES_DIR/Reference_AIMS_800k.geno.lrz.part.03" "$RESOURCES_DIR/Reference_AIMS_800k.geno.lrz.part.04" "$RESOURCES_DIR/Reference_AIMS_800k.geno.lrz.part.05")
AIMS_CHECKSUM="$RESOURCES_DIR/Reference_AIMS_800k.geno.lrz.sha256"

if [ ! -f "$AIMS_FILE" ]; then
    echo "Reference_AIMS_800k.geno not found. Checking for parts..."
    
    # Check if all parts are present
    all_parts_present=true
    for part in "${AIMS_PARTS[@]}"; do
        if [ ! -f "$part" ]; then
            all_parts_present=false
            break
        fi
    done
    
    if [ "$all_parts_present" = false ]; then
        echo "Error: Reference_AIMS_800k.geno.lrz parts are missing. Please re-download the parts."
        exit 1
    fi
    
    echo "All parts found. Combining them into a single file."
    cat "${AIMS_PARTS[@]}" > "$RESOURCES_DIR/Reference_AIMS_800k.geno.lrz"

    echo "Checking integrity using SHA-256 checksum."
    if sha256sum -c "$AIMS_CHECKSUM"; then
        echo "Checksum is correct. Proceeding to decompress."
        
        # Check if lrzip is installed
        check_command "lrzip"
        
        # Decompress the file
        lrzip -d "$RESOURCES_DIR/Reference_AIMS_800k.geno.lrz"
        echo "Decompressed Reference_AIMS_800k.geno successfully."
    else
        echo "Error: Checksum failed. The parts may be corrupted. Please re-download."
        exit 1
    fi
else
    echo "Reference_AIMS_800k.geno is already present."
fi

# If the script reaches this point, all checks have passed
echo "All dependencies are satisfied and resources are in place."
