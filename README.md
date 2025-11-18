# OSC Genome Shasta Assembly Pipeline

Pipeline for preparing input reads and generating the raw OSC genome assembly using [Shasta](https://github.com/chanzuckerberg/shasta).

Part of the **Handler et al., 2025** publication:

**The Drosophila OSC Genome: A Resource for Studies of Transposon and piRNA Biology**

## Overview

This repository contains the complete workflow to generate the raw version of the *Drosophila melanogaster* ovarian somatic cell (OSC) genome from long-read sequencing data using the Shasta assembler. The pipeline includes read preparation, quality filtering, and assembly generation steps.

## Repository Structure

```
├── script-files/       # Core pipeline scripts
├── utility-files/      # Configuration files
└── submit-assembly.sh  # Main submission script for assembly
```

## Pipeline Components

### Read Preparation
Scripts for processing and filtering raw sequencing reads prior to assembly.

### Assembly Generation
Configuration and execution scripts for running Shasta assembler with optimized parameters for the OSC genome.

## Requirements

- Apptainer


## Usage

The main assembly can be submitted using:

```bash
bash submit-assembly.sh
```

Modify parameters in the script files as needed for your specific computational environment.

## Output

The pipeline generates a raw genome assembly that serves as input for downstream polishing and curation steps.

## Related Resources

### Main Publication Repository
https://github.com/BrenneckeLab/Handler_2025-OSC-genome


### UCSC Genome Browser Hub
https://genome-euro.ucsc.edu/s/Brennecke%2DLab/OSC_r1.01_Handler_et.al._2025

## Citation

Please find the proper citation in https://github.com/BrenneckeLab/Handler_2025-OSC-genome

## Contact

For questions or additional information, please contact:
dominik.handler@imba.oeaw.ac.at

## License

MIT License
