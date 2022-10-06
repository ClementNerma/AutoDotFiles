#!/usr/bin/zsh

#
# This file contains the obfuscator module
#

# Input alphabet location
export ADF_OBF_INPUT_ALPHABET_FILE="$ADF_DATA_DIR/adf-obfuscator-alphabet.input.txt"
export ADF_OBF_OUTPUT_ALPHABET_FILE="$ADF_DATA_DIR/adf-obfuscator-alphabet.output.txt"

# Generate a random alphabet
function adf_obf_gen_alphabet() {
    local str="$(awk 'BEGIN{for(i=32;i<128;i++)printf "%c\n",i; print}')$(awk 'BEGIN{for(i=160;i<255;i++)printf "%c\n",i; print}')"
    local shuffled=$(echo "$str" | sort -R | tr "\n" "\n")
    local chars=${(@f)shuffled}
    local alphabet=${(j::)${(@f)shuffled}}

    if [[ ${#alphabet} != 191 ]]; then
        echoerr "Internal error: invalid alphabet length (${#alphabet})"
        echodata "$alphabet"
        return 1
    fi

    echo "$alphabet"
}

# Ensure the random alphabets exist locally
function adf_obf_init_alphabets() {
    if [[ ! -f "$ADF_OBF_INPUT_ALPHABET_FILE" || $1 == "--regen" ]]; then
        echoinfo "Generating input alphabet..."

        if ! adf_obf_gen_alphabet > "$ADF_OBF_INPUT_ALPHABET_FILE"; then
            echoerr "Internal: failed to generate the input alphabet."
            return 1
        fi
    fi

    if [[ ! -f "$ADF_OBF_OUTPUT_ALPHABET_FILE" || $1 == "--regen" ]]; then
        echoinfo "Generating output alphabet..."
    
        if ! adf_obf_gen_alphabet > "$ADF_OBF_OUTPUT_ALPHABET_FILE"; then
            echoerr "Internal: failed to generate the output alphabet."
            return 2
        fi
    fi

    echoinfo "Loading alphabets from disk..."

    export __ADF_OBF_INPUT_ALPHABET=$(command cat "$ADF_OBF_INPUT_ALPHABET_FILE")
    export __ADF_OBF_OUTPUT_ALPHABET=$(command cat "$ADF_OBF_OUTPUT_ALPHABET_FILE")

    echosuccess "Done."
}

# Display the current input alphabet
function adf_obf_current_input_alphabet() {
    echo "$__ADF_OBF_INPUT_ALPHABET"
}

# Display the current output alphabet
function adf_obf_current_output_alphabet() {
    echo "$__ADF_OBF_OUTPUT_ALPHABET"
}

# Transform (obfuscate / unobfuscate) a string
# Usage: "adf_obf_transform <message> <base alphabet> <converted alphabet>"
function adf_obf_transform() {    
    if [[ -z $2 ]]; then
        echoerr "Please provide a base alphabet."
        echoerr "Usage: $0 <message> <base alphabet> <converted alphabet>"
        return 1
    fi

    if [[ -z $3 ]]; then
        echoerr "Please provide a converted alphabet."
        echoerr "Usage: $0 <message> <base alphabet> <converted alphabet>"
        return 1
    fi

    if [[ ${#2} != 191 ]]; then
        echoerr "Base alphabet is not 191 characters long."
        return 2
    fi

    if [[ ${#3} != 191 ]]; then
        echoerr "Converted alphabet is not 191 characters long."
        return 2
    fi

    local input=""

    if [[ -z "$1" ]]; then
        read input
    else
        input="$1"
    fi

    local out=()

    for i in {1..${#1}}; do
        local char=${1[i]}
        local index=${2[(I)$char]}

        if [[ $index == 0 ]]; then
            echoerr "Failed to encode character \z[yellow]°$char\z[]°: unknown character"
            return 1
        fi

        out+=("${3[$index]}")
    done

    echo ${(j::)out}
}

# Obfuscate a string
# Useful for storing mildly-sensitive data in source codes
# The local alphabet is used
function adf_obf_encode() {
    if ! ADF_SILENT=1 adf_obf_init_alphabets; then return 1; fi

    if [[ ! -z $1 ]]; then
        echowarn "ENSURE TO NOT PROVIDE ANY SENSITIVE DATA AS AN ARGUMENT!"
    fi

    adf_obf_transform "$1" "$__ADF_OBF_INPUT_ALPHABET" "$__ADF_OBF_OUTPUT_ALPHABET"
}

# Unobfuscate a string generated by the obfuscation function
# The local alphabet is used
function adf_obf_decode() {
    if ! ADF_SILENT=1 adf_obf_init_alphabets; then return 1; fi

    adf_obf_transform "$1" "$__ADF_OBF_OUTPUT_ALPHABET" "$__ADF_OBF_INPUT_ALPHABET"
}
