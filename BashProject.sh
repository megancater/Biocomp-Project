#!/bin/bash

# Script written by: Coleen Gillilan and Megan Cater
# This script identifies candidate pH-resistant methanogenic Archaea given reference sequences and proteomes
# Usage: bash BashProject.sh path/to/ref_sequences/ path/to/proteomes/ path/to/muscle path/to/hmmer/bin/
# Assumptions: when putting the path to directories, it ends with a "/"

# Initialization

# Directories 
mkdir muscle_files/
mkdir hmm_files/
mkdir result_files/
mkdir gene_files/

# Files
touch gene_files/hsp70gene.fasta
touch gene_files/mcrAgene.fasta

# Reference sequences and proteomes
ref_files=$(ls $1)
pro_files=$(ls $2)

# Bioinformatics tools
muscle=$3
hmmbuild=$4hmmbuild
hmmsearch=$4hmmsearch


# Analysis of reference sequences and proteomes

# Append reference sequences into two file
for file in $ref_files; do
	# If hsp70, append to hsp70 file
	if [[ ${file:0:5} == "hsp70" ]]; then
		cat $1$file >> gene_files/hsp70gene.fasta
	# Not hsp70, so append to mrcA file
	else 
		cat $1$file >> gene_files/mcrAgene.fasta
	fi
done

# Make muscle files for the hsp70 and mrcA files
for file in $(ls gene_files); do
	# Takes in files and outputs to new folder
	$muscle -in gene_files/$file -out muscle_files/$file
done

# Build hmm profiles
for file in $(ls muscle_files); do
	# Takes file name and builds profile with this name in new folder
	filename=$(basename $file .fasta)
	$hmmbuild hmm_files/$filename.hmm muscle_files/$file
done

# Create results for each proteome from profiles
# Header of results.csv file
echo proteome_number,hsp70_count,mcrAgene_count >> results.csv
for proteome in $pro_files; do
	prot=$(basename $proteome .fasta)	# Gets file name
	line=""
	# For each profile, search within each proteome and count matches
	for profile in $(ls hmm_files); do
		$hmmsearch --tblout result_files/result.txt hmm_files/$profile $2$proteome
		count=$(cat result_files/result.txt | grep '^WP*' | wc -l)
		line+=",$count"
	done
	echo $prot$line >> results.csv		# Appends results to results.csv
done

# Find candidate proteomes while checking for best proteome
echo Candidate Proteomes: >> proteomes.txt
maxhsp=0
maxname=""
while read line; do 
	# Parse results file
	name=$(echo $line | cut -d , -f 1)
	hspCount=$(echo $line | cut -d , -f 2)
	mcrACount=$(echo $line | cut -d , -f 3)	
	# Check if proteome has at least 1 of each gene
	if [[ hspCount -ge 1 ]] && [[ mcrACount -ge 1 ]] ; then
		# Add to proteomes.txt if it does
		echo $name >> proteomes.txt
		# If the proteome is candidate, then check if it has highest hsp70 gene count
		if [[ $hspCount -eq $maxhsp ]]; then
			maxname+=", $name"
		elif [[ $hspCount -gt $maxhsp ]]; then
			maxhsp=$hspCount
			maxname=$name
		fi
	fi
done < results.csv

# Add best proteome into the file
echo >> proteomes.txt
echo Best Proteomes: >> proteomes.txt
echo $maxname >> proteomes.txt


# Cleanup
rm gene_files/*
rm muscle_files/*
rm hmm_files/*
rm result_files/*
rmdir gene_files
rmdir muscle_files
rmdir hmm_files
rmdir result_files
