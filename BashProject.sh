#!/bin/bash

# Usage: bash BashProject.sh path/to/ref_sequences/ path/to/proteomes/ path/to/muscle path/to/hmmer/bin/
# assumptions: when putting the path to directories, it ends with a "/"

# initialization
mkdir muscle_files/
mkdir hmm_files/
mkdir result_files/
mkdir gene_files/
touch gene_files/hsp70gene.fasta
touch gene_files/mcrAgene.fasta
ref_files=$(ls $1)
pro_files=$(ls $2)
muscle=$3
hmmbuild=$4hmmbuild
hmmsearch=$4hmmsearch

# append files
for file in $ref_files; do
	if [[ ${file:0:5} == "hsp70" ]]; then
		cat $1$file >> gene_files/hsp70gene.fasta
	else 
		cat $1$file >> gene_files/mcrAgene.fasta
	fi
done

# make muscle files
for file in $(ls gene_files); do
	$muscle -in gene_files/$file -out muscle_files/$file
done

# build hmm profiles
for file in $(ls muscle_files); do
	filename=$(basename $file .fasta)
	$hmmbuild hmm_files/$filename.hmm muscle_files/$file
done


# create results for each proteome from profiles
echo proteome_number,hsp70_count,mcrAgene_count >> results.csv
for proteome in $pro_files; do
	prot=$(basename $proteome .fasta)
	line=""
	for profile in $(ls hmm_files); do
		$hmmsearch --tblout result_files/result.txt hmm_files/$profile $2$proteome
		count=$(cat result_files/result.txt | grep '^WP*' | wc -l)
		line+=",$count"
	done
	echo $prot$line >> results.csv
done

# find candidate proteomes while checking for best proteome
echo Candidate Proteomes: >> proteomes.txt
maxhsp=0
maxname=""
while read line; do 
	# parse results file
	name=$(echo $line | cut -d , -f 1)
	hspCount=$(echo $line | cut -d , -f 2)
	mcrACount=$(echo $line | cut -d , -f 3)	
	# check if proteome has at least 1 of each gene
	if [[ hspCount -ge 1 ]] && [[ mcrACount -ge 1 ]] ; then
		# add to proteomes.txt if it does
		echo $name >> proteomes.txt
		# if the proteome is candidate, then check if it has highest hsp70 gene count
		if [[ $hspCount -eq $maxhsp ]]; then
			maxname+=", $name"
		elif [[ $hspCount -gt $maxhsp ]]; then
			maxhsp=$hspCount
			maxname=$name
		fi
	fi
done < results.csv

# add best proteome into the file
echo >> proteomes.txt
echo Best Proteome: >> proteomes.txt
echo $maxname >> proteomes.txt


# cleanup
rm gene_files/*
rm muscle_files/*
rm hmm_files/*
rm result_files/*
rmdir gene_files
rmdir muscle_files
rmdir hmm_files
rmdir result_files



# both genes, more hsp
