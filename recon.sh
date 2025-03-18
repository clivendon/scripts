#!/bin/bash

# Check if the required tools are installed
if ! command -v nmap &> /dev/null; then
    echo "Nmap is not installed. Please install it."
    exit 1
fi

if ! command -v gobuster &> /dev/null; then
    echo "Gobuster is not installed. Please install it."
    exit 1
fi

if ! command -v whatweb &> /dev/null; then
    echo "WhatWeb is not installed. Please install it."
    exit 1
fi

# Check for target IP and port
if [ -z "$1" ]; then
    echo "You need to supply the target IP and port as an argument"
    echo "Usage: ./recon.sh <TARGET IP>:<PORT>"
    exit 1
fi

# Validate the target IP and port
if ! [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$ ]]; then
    echo "Invalid target IP and port format. Please use the format <IP>:<PORT>"
    exit 1
fi

TARGET_IP=$(echo $1 | cut -d: -f1)
TARGET_PORT=$(echo $1 | cut -d: -f2)

# Check for wordlist existence
WORDLIST="/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt"
if [ ! -f "$WORDLIST" ]; then
    echo "Wordlist not found at $WORDLIST. Please provide the correct path."
    read -p "Enter the path to the wordlist: " WORDLIST
    if [ ! -f "$WORDLIST" ]; then
        echo "Wordlist not found at $WORDLIST. Exiting."
        exit 1
    fi
fi

# Create a temporary directory for intermediate files
TEMP_DIR=$(mktemp -d)
NMAP_OUTPUT="$TEMP_DIR/nmap.txt"
GOBUSTER_OUTPUT="$TEMP_DIR/gobuster.txt"
WHATWEB_OUTPUT="$TEMP_DIR/whatweb.txt"
RESULTS_FILE="$TEMP_DIR/results.txt"

# Run Nmap
printf "\n------ NMAP  ------\n\n" > $RESULTS_FILE
echo "Running Nmap..."
nmap -A -p $TARGET_PORT $TARGET_IP -v -oN $NMAP_OUTPUT | tail -n +5 | head -n -3 | tee -a $RESULTS_FILE

# Extract open HTTP ports
HTTP_PORTS=$(grep -oP '(\d+)/tcp open http' $NMAP_OUTPUT | cut -d/ -f1)

# Run Gobuster and WhatWeb for open HTTP ports
if [ -n "$HTTP_PORTS" ]; then
    for PORT in $HTTP_PORTS; do
        echo "Running Gobuster for port $PORT..."
        gobuster dir -u http://$TARGET_IP:$PORT -w $WORDLIST -q -z | tee -a $GOBUSTER_OUTPUT

        echo "Running WhatWeb for port $PORT..."
        whatweb -a 3 -v --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3" http://$TARGET_IP:$PORT | tee -a $WHATWEB_OUTPUT
    done
fi

# Append Gobuster and WhatWeb results to the results file
if [ -e $GOBUSTER_OUTPUT ]; then
    printf "\n----- DIRECTORIES FOUND -----\n\n" | tee -a $RESULTS_FILE
    cat $GOBUSTER_OUTPUT | tee -a $RESULTS_FILE
fi

if [ -e $WHATWEB_OUTPUT ]; then
    printf "\n----- WEB -----\n\n" | tee -a $RESULTS_FILE
    cat $WHATWEB_OUTPUT | tee -a $RESULTS_FILE
fi

# Save results to a final output file
FINAL_OUTPUT="/home/output.txt"
echo "Results saved to $FINAL_OUTPUT for further review"
cat $RESULTS_FILE > $FINAL_OUTPUT

# Clean up temporary files
rm -rf $TEMP_DIR

# Display the results
cat $FINAL_OUTPUT
