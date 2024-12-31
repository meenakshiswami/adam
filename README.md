Overview

This repository is designed for SAS programmers and statisticians working in clinical trials. It provides tools and examples for creating ADaM datasets following CDISC standards. These datasets support statistical analysis and are derived from SDTM (Study Data Tabulation Model) datasets.

Key Features
	•	Creation of ADaM datasets (e.g., ADRS, ADTTE, ADLB).
	•	Implementation of analysis-ready variables, flags, and derivations.
	•	Compliance with CDISC ADaM standards.
	•	Examples of efficacy and safety dataset creation.
	•	Integration of datasets from multiple studies.

Folder Structure

adam/
├── data/               # Sample datasets (e.g., SDTM and raw data)
├── macros/             # Custom SAS macros for derivations
├── programs/           # Main scripts for ADaM dataset creation
├── documentation/      # Detailed documentation and guidelines
├── outputs/            # Example tables, listings, and figures
└── README.md           # Project overview

Prerequisites
	•	SAS Software: Version 9.4 or higher.
	•	Knowledge of SDTM and ADaM standards.
	•	Basic understanding of clinical trial data structures.

Installation
	1.	Clone this repository:

git clone https://github.com/meenakshiswami/adam.git
cd adam


	2.	Load sample datasets from the data/ folder into your SAS environment.
	3.	Set up library references as required in the programs folder.

Usage
	1.	Navigate to the programs/ folder.
	2.	Run the main SAS scripts in order:
	•	Example:

%include 'path-to-program/adsl_creation.sas';
%include 'path-to-program/adrs_creation.sas';


	3.	Review the outputs in the outputs/ folder.

Examples

Deriving Tumor Response (ADRS)
	•	Input: SDTM RS dataset.
	•	Output: ADRS dataset with derived flags (e.g., CR, PR, SD).

Time-to-Event Analysis (ADTTE)
	•	Input: SDTM AE and DS datasets.
	•	Output: ADTTE dataset for Kaplan-Meier analysis.

Contributing

Contributions are welcome! If you have improvements or additional examples, please create a pull request or open an issue.
